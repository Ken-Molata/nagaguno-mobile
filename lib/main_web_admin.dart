// lib/main_web_admin.dart
//
// UW 2.6's web-based Admin Dashboard -- a separate entrypoint into the
// SAME Flutter project as main.dart (not a second app/repo), built
// with `flutter build web -t lib/main_web_admin.dart`. Deliberately
// its own router (admin_web/admin_web_router.dart) and auth controller
// (admin_web/application/admin_auth_controller.dart), not
// app_router.dart/AuthController -- those pull in bottom-nav shell
// structure, cart, and push-notification concerns that only make
// sense for the consumer mobile app, and the consumer login screen
// explicitly rejects admin accounts (authController.js's login()),
// so this needed its own sign-in call to POST /auth/admin/login from
// the start.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_web/admin_web_router.dart';
import 'admin_web/application/admin_auth_controller.dart';
import 'core/session/inactivity_listener.dart';
import 'core/theme/app_theme.dart';
import 'core/networking/api_client.dart';
import 'features/accessibility/application/accessibility_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: NagagunoAdminApp()));
}

/// Mirrors main.dart's authSessionWiringProvider, pointed at
/// AdminAuthController instead -- without this, a 401-triggered
/// refresh failure would never actually sign the admin out.
final _adminAuthSessionWiringProvider = Provider<void>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  apiClient.onSessionExpired =
      () => ref.read(adminAuthControllerProvider.notifier).forceLogout();
});

class NagagunoAdminApp extends ConsumerWidget {
  const NagagunoAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_adminAuthSessionWiringProvider);
    // UW 2.4: same early-read requirement as the consumer app's
    // inactivityGuardProvider (main.dart) -- see InactivityGuard's own
    // doc comment.
    final inactivityGuard = ref.watch(adminInactivityGuardProvider);
    final router = ref.watch(adminWebRouterProvider);
    // UW 21.10: admin_settings_screen.dart's "Accessibility & Display"
    // section saves real values -- this is what actually applies them
    // app-wide (see adminAccessibilitySettingsProvider's doc comment
    // for the bug this fixes).
    final accessibility = ref.watch(adminAccessibilitySettingsProvider);

    return MaterialApp.router(
      title: 'NagaGuno Admin',
      theme: nagagunoTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(accessibility.textScale),
        ),
        child: InactivityListener(
          onActivity: inactivityGuard.recordActivity,
          child: child!,
        ),
      ),
    );
  }
}
