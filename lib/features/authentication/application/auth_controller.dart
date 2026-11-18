// lib/features/authentication/application/auth_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/navigation/root_navigator_key.dart';
import '../../../core/session/inactivity_guard.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/push/push_notification_service.dart';
import '../../../core/accessibility/pre_login_text_scale.dart';
import '../../cart/application/cart_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../data/auth_repository.dart';
import '../domain/nagaguno_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.user});
  final AuthStatus status;
  final NagagunoUser? user;

  static const initial = AuthState(status: AuthStatus.unknown);

  AuthState copyWith({AuthStatus? status, NagagunoUser? user}) =>
      AuthState(status: status ?? this.status, user: user ?? this.user);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    pushService: ref.watch(pushNotificationServiceProvider),
    cartController: ref.watch(cartControllerProvider.notifier),
  );
});

/// This is what actually connects ApiClient's session-expiry callback
/// to AuthController, WITHOUT the circular dependency the previous
/// version had (apiClientProvider used to be defined right here, and
/// its own builder called ref.read(authControllerProvider.notifier)
/// directly -- a genuine top-level type-inference cycle:
/// apiClientProvider -> authControllerProvider -> authRepositoryProvider
/// -> apiClientProvider, which broke `flutter analyze` outright with a
/// top_level_cycle error and left apiClientProvider undefined in every
/// other file that correctly expected to find it in api_client.dart).
///
/// This provider sits ABOVE both apiClientProvider and
/// authControllerProvider in the dependency graph -- it depends on
/// both of them, but neither of THEM depends on this, so there's no
/// cycle. Must be read once, early, for the wiring to actually take
/// effect (Riverpod providers are lazy) -- see main.dart.
final authSessionWiringProvider = Provider<void>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  apiClient.onSessionExpired =
      () => ref.read(authControllerProvider.notifier).forceLogout();
});

/// UW 2.4: a real server-revoking logout() (not forceLogout(), which is
/// reserved for "the server already rejected this session") when 5
/// minutes pass with no pointer activity or navigation -- see
/// InactivityGuard's own doc comment for why those two are the only
/// reset triggers. Must be read once, early, same lazy-provider caveat
/// as authSessionWiringProvider above -- see main.dart.
final inactivityGuardProvider = Provider<InactivityGuard<AuthState>>((ref) {
  return InactivityGuard<AuthState>(
    ref: ref,
    stateListenable: authControllerProvider,
    isAuthenticated: (s) => s.status == AuthStatus.authenticated,
    onTimeout: () => ref.read(authControllerProvider.notifier).logout(),
  );
});

/// UW 21.6's "Aa" quick-access control reconciliation rule: "at login,
/// the account's saved settings apply, and if the account has none
/// saved, the device's choice is saved to the account." Runs once per
/// genuine sign-in transition, not on every rebuild -- refreshUser()
/// first, since login/register/verifyLogin2FA/googleAuth responses
/// never carry text_size_set_by_user (same documented gap as
/// language/twoFactorEnabled -- see NagagunoUser's own doc comments),
/// so the just-logged-in session's cached user can't be trusted here
/// without it. Must be read once, early, same lazy-provider caveat as
/// authSessionWiringProvider above -- see main.dart.
class TextSizeReconciler {
  TextSizeReconciler({
    required this.ref,
    required ProviderListenable<AuthState> stateListenable,
  }) {
    ref.listen<AuthState>(stateListenable, (previous, next) {
      final becameAuthenticated =
          previous?.status != AuthStatus.authenticated &&
              next.status == AuthStatus.authenticated;
      if (becameAuthenticated) {
        // ignore: discarded_futures
        _reconcile();
      }
    });
  }

  final Ref ref;

  Future<void> _reconcile() async {
    await ref.read(authControllerProvider.notifier).refreshUser();
    final user = ref.read(authControllerProvider).user;
    if (user == null || user.textSizeSetByUser) return;
    final deviceTextSize = ref.read(preLoginTextSizeProvider);
    try {
      await ref
          .read(_reconcilerProfileRepositoryProvider)
          .updateAccountSettings(textSize: deviceTextSize);
      await ref.read(authControllerProvider.notifier).refreshUser();
    } catch (_) {
      // Best-effort, same as every other account-settings save in
      // this app -- the account keeps its unset default until the
      // next sign-in retries this.
    }
  }
}

final _reconcilerProfileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(apiClientProvider)));

final textSizeReconcilerProvider = Provider<TextSizeReconciler>((ref) {
  return TextSizeReconciler(ref: ref, stateListenable: authControllerProvider);
});

class AuthController extends StateNotifier<AuthState> {
  /// [secureStorage] is injectable specifically so this class can be
  /// unit tested without touching the real Keychain/Keystore-backed
  /// singleton (which requires real platform channels and would
  /// throw/hang in a plain unit test) — defaults to the real one in
  /// production, matching the same injectable-dependency pattern used
  /// for BlinkStateMachine's clock.
  AuthController(this._repository,
      {SecureStorage? secureStorage,
      PushNotificationService? pushService,
      CartController? cartController})
      : _secureStorage = secureStorage ?? SecureStorage.instance,
        _pushService = pushService,
        _cartController = cartController,
        super(AuthState.initial) {
    _tryRestoreSession();
  }

  final AuthRepository _repository;
  final SecureStorage _secureStorage;

  /// Nullable (not defaulted the way [_secureStorage] is) so a plain
  /// unit test constructing AuthController directly doesn't need a
  /// real Firebase/platform-channel setup just to exist -- every call
  /// site below is a no-op push registration when this is null, same
  /// "optional, best-effort" stance PushNotificationService itself takes.
  final PushNotificationService? _pushService;

  /// Same nullable, optional-dependency reasoning as [_pushService] --
  /// clears the local cart on logout so a shared/reused device doesn't
  /// show the next signed-in account items the previous one added
  /// (see features/cart/domain/cart_item.dart for why the cart is
  /// local-only in the first place).
  final CartController? _cartController;

  /// UW 15's proposed push channel (FCM): fire-and-forget by design --
  /// chat already works via the 5-second poll (UW 13.1) without this,
  /// so a slow/failing push registration must never delay or block
  /// the auth flow that triggers it.
  void _registerForPush() {
    // ignore: discarded_futures
    _pushService?.initialize();
  }

  /// App cold start: a stored refresh token doesn't itself prove the
  /// session is valid (it could be expired/revoked server-side) — the
  /// only reliable check is asking the backend. This intentionally
  /// forces one /auth/refresh + /auth/me round trip on every app
  /// launch rather than trusting local storage alone.
  Future<void> _tryRestoreSession() async {
    final storedRefreshToken = await _secureStorage.readRefreshToken();
    if (storedRefreshToken == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _repository.getMe();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      _registerForPush();
    } on DioException {
      // Access token isn't set yet on cold start, so this first getMe()
      // call is expected to 401 and trigger the interceptor's refresh
      // flow using the stored refresh token — if THAT also fails, the
      // session is genuinely gone.
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// REAL, SEVERE BUG FOUND AND FIXED this pass: POST /auth/register's
  /// real response carries no tokens at all (see AuthRepository
  /// .register's own doc comment) -- this used to trust whatever
  /// [AuthRepository.register] returned as an already-authenticated
  /// session, which would have thrown a type-cast error on every
  /// successful registration. Now logs in immediately afterward with
  /// the same credentials, matching authController.js's own "the
  /// client logs in afterward" design comment -- the caller still sees
  /// one `register()` call that either returns null (now genuinely
  /// authenticated) or an [AuthException], same external contract as
  /// before.
  Future<AuthException?> register({
    required String fullName,
    required String password,
    required String role,
    required String dateOfBirth,
    String? email,
    String? phoneNumber,
    String? barangay,
  }) async {
    try {
      await _repository.register(
        fullName: fullName,
        password: password,
        role: role,
        email: email,
        dateOfBirth: dateOfBirth,
        phoneNumber: phoneNumber,
        barangay: barangay,
      );
    } on AuthException catch (e) {
      return e;
    }
    return login(email: email, phoneNumber: phoneNumber, password: password);
  }

  /// Lets [TwoFactorRequiredException] propagate uncaught (it isn't an
  /// [AuthException]) so the login screen can catch it specifically
  /// and navigate to the 2FA code screen, rather than it being
  /// swallowed into a generic error here.
  Future<AuthException?> login(
      {String? email, String? phoneNumber, required String password}) async {
    try {
      final result = await _repository.login(
          email: email, phoneNumber: phoneNumber, password: password);
      state =
          state.copyWith(status: AuthStatus.authenticated, user: result.user);
      _registerForPush();
      return null;
    } on AuthException catch (e) {
      return e;
    }
  }

  Future<AuthException?> verifyLogin2FA(
      {required String userId, required String otp}) async {
    try {
      final result = await _repository.verifyLogin2FA(userId: userId, otp: otp);
      state =
          state.copyWith(status: AuthStatus.authenticated, user: result.user);
      _registerForPush();
      return null;
    } on AuthException catch (e) {
      return e;
    }
  }

  /// Returns null on success, an AuthException on a real failure, or
  /// rethrows GoogleAuthNeedsRoleException specifically (rather than
  /// swallowing it into a generic error) so the calling screen can
  /// show a role picker and retry -- that's a real, meaningful UX
  /// branch, not just another error state.
  Future<AuthException?> googleAuth(
      {required String idToken, String? role}) async {
    try {
      final result = await _repository.googleAuth(idToken: idToken, role: role);
      state =
          state.copyWith(status: AuthStatus.authenticated, user: result.user);
      _registerForPush();
      return null;
    } on AuthException catch (e) {
      return e;
    }
  }

  /// Re-fetches GET /me and replaces the cached user -- for a change
  /// made through some other repository (e.g. UW 21.5/21.7's account
  /// settings) that doesn't itself return a full user object to
  /// update the session with. Not called from every profile-editing
  /// flow in this app; only where the authenticated session's own
  /// cached fields (role, account_status, language, notification
  /// prefs) are what the UI actually reads afterward.
  Future<void> refreshUser() async {
    if (state.status != AuthStatus.authenticated) return;
    try {
      final user = await _repository.getMe();
      state = state.copyWith(user: user);
    } catch (_) {
      // Best-effort -- the save itself already succeeded or failed on
      // its own terms; a refresh failure just means the UI keeps
      // showing the pre-save cached values until the next natural
      // getMe() (e.g. next app start).
    }
  }

  Future<void> logout() async {
    // So a shared/reused device doesn't keep receiving a previous
    // account's message notifications. Best-effort, same as the
    // repository's own server-call handling below.
    await _pushService?.unregister();
    _cartController?.clear();
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Called by the API client itself when a refresh attempt fails
  /// outright — distinct from the user-initiated logout() above.
  void forceLogout() {
    // Partial mitigation for the documented architectural limitation
    // (see README.md): pops any imperatively-pushed screen (add/edit
    // product, crop plan forms, the liveness camera flow, etc.) back
    // to go_router's own root before the auth-state change triggers
    // its redirect, so a forced session expiry doesn't leave one of
    // those 7 screens stuck on top of the login redirect underneath.
    // Doesn't fully solve the underlying mismatch between imperative
    // Navigator.push and go_router's declarative stack (see the
    // README section for why that needs a larger refactor), but
    // handles the one scenario where it actually matters.
    rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    state = const AuthState(status: AuthStatus.unauthenticated);
    _cartController?.clear();
    // Fire-and-forget, same reasoning as _registerForPush() -- this
    // callback itself can't be async (it's invoked synchronously from
    // ApiClient's interceptor).
    // ignore: discarded_futures
    _pushService?.unregister();
  }
}
