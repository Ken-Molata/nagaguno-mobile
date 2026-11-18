// lib/core/push/push_notification_service.dart
//
// UW 15's proposed push channel for UW 13 chat -- FCM, not Supabase
// Realtime (see backend/utils/fcmService.js's own comment for why:
// this app authenticates against its own `users` table with backend-
// issued JWTs, never Supabase Auth, so Realtime's RLS-aware
// subscriptions have nothing to evaluate auth.uid() against without a
// second, parallel auth mechanism just for this one feature).
//
// Real, researched firebase_messaging usage -- functionally untested
// in this environment (no Flutter SDK, no real Firebase project; see
// android/app/google-services.json's own placeholder-file comment and
// PLATFORM_SETUP.md). Scoped to chat only, matching the one gap this
// was built to close -- not retrofitted into every notification type
// in the app.
//
// Deliberately does NOT add a second, manually-built in-app banner
// for a foreground message: the already-working 5-second poll
// (UW 13.1) and the in-app notifications screen both already surface
// a new message while the app is open. This only handles the two
// things neither of those cover -- showing a system notification
// while backgrounded/terminated (FCM's own default Android behavior
// for a `notification`-payload message, nothing to build) and
// navigating to the right conversation when one is tapped.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../navigation/root_navigator_key.dart';
import '../networking/api_client.dart';
import '../networking/api_endpoints.dart';
import '../configuration/firebase_config.dart';

/// Must be a top-level function -- Firebase's plugin requirement for
/// the background-isolate handler. Deliberately empty: the
/// `notification` payload fcmService.js already sends is displayed by
/// FCM's own default Android handling without any app code running;
/// nothing here needs to react to the message itself while
/// backgrounded (only a tap, handled by onMessageOpenedApp/
/// getInitialMessage below, re-enters the normal foreground app).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService {
  PushNotificationService(this._client);
  final ApiClient _client;

  String? _registeredToken;

  Future<void> initialize() async {
    // Firebase.initializeApp() in main.dart is itself guarded by this
    // same check -- without it, FirebaseMessaging.instance below would
    // throw since no Firebase app was ever initialized to back it.
    if (!FirebaseConfig.isConfigured) return;
    final messaging = FirebaseMessaging.instance;

    // iOS-only prompt; a no-op on Android (permission is declared in
    // the manifest, and OS-level grant on API 33+ happens the same way
    // any other runtime permission would, outside this call).
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final token = await messaging.getToken();
    if (token != null) await _registerToken(token);
    messaging.onTokenRefresh.listen(_registerToken);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Covers the app having been fully terminated and launched BY
    // tapping the notification -- onMessageOpenedApp alone misses this
    // specific case (it only fires for an already-running app resuming).
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(initialMessage);
  }

  Future<void> _registerToken(String token) async {
    if (_registeredToken == token) return;
    try {
      await _client.dio.post(ApiEndpoints.devices,
          data: {'token': token, 'platform': 'android'});
      _registeredToken = token;
    } catch (_) {
      // Best-effort: chat still works via the 5-second poll without this.
    }
  }

  /// Called on logout so a shared/reused device doesn't keep
  /// receiving a previous account's message notifications.
  Future<void> unregister() async {
    final token = _registeredToken;
    if (token == null) return;
    try {
      await _client.dio.delete(ApiEndpoints.deviceToken(token));
    } catch (_) {
      // Best-effort, same reasoning as AuthRepository.logout()'s own
      // server-call failure handling -- never block logging out.
    } finally {
      _registeredToken = null;
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (message.data['type'] != 'conversation') return;
    final conversationId = message.data['conversationId'];
    if (conversationId == null) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).push('/conversations/$conversationId');
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(ref.watch(apiClientProvider)),
);
