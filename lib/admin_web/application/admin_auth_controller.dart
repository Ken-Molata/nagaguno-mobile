// lib/admin_web/application/admin_auth_controller.dart
//
// UW 2.6: "Admin accounts sign in on the NagaGuno website." A
// deliberately separate, minimal controller from the consumer app's
// AuthController -- that one pulls in CartController and
// PushNotificationService (mobile-consumer concerns an admin session
// has no use for), and its login() calls the regular /auth/login
// endpoint, which the real backend explicitly rejects admin accounts
// from. Reuses AuthRepository.adminLogin/getMe/logout directly, same
// token storage (AuthTokenHolder, SecureStorage) as the consumer app,
// since both are the same ApiClient instance either way.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/session/inactivity_guard.dart';
import '../../core/storage/secure_storage.dart';
import '../../features/authentication/application/auth_controller.dart'
    show authRepositoryProvider;
import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/domain/nagaguno_user.dart';

enum AdminAuthStatus { unknown, authenticated, unauthenticated }

class AdminAuthState {
  const AdminAuthState({required this.status, this.user});
  final AdminAuthStatus status;
  final NagagunoUser? user;

  static const initial = AdminAuthState(status: AdminAuthStatus.unknown);

  AdminAuthState copyWith({AdminAuthStatus? status, NagagunoUser? user}) =>
      AdminAuthState(status: status ?? this.status, user: user ?? this.user);
}

final adminAuthControllerProvider =
    StateNotifierProvider<AdminAuthController, AdminAuthState>((ref) {
  return AdminAuthController(ref.watch(authRepositoryProvider));
});

class AdminAuthController extends StateNotifier<AdminAuthState> {
  AdminAuthController(this._repository, {SecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorage.instance,
        super(AdminAuthState.initial) {
    _tryRestoreSession();
  }

  final AuthRepository _repository;
  final SecureStorage _secureStorage;

  Future<void> _tryRestoreSession() async {
    final storedRefreshToken = await _secureStorage.readRefreshToken();
    if (storedRefreshToken == null) {
      state = state.copyWith(status: AdminAuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _repository.getMe();
      if (!user.isAdmin) {
        // A non-admin's leftover session token (e.g. the same browser
        // profile used for the consumer web build at some point) --
        // never silently treat it as an admin session.
        state = state.copyWith(status: AdminAuthStatus.unauthenticated);
        return;
      }
      state =
          state.copyWith(status: AdminAuthStatus.authenticated, user: user);
    } on DioException {
      state = state.copyWith(status: AdminAuthStatus.unauthenticated);
    }
  }

  Future<AuthException?> login(
      {required String email, required String password}) async {
    try {
      final result =
          await _repository.adminLogin(email: email, password: password);
      state = state.copyWith(
          status: AdminAuthStatus.authenticated, user: result.user);
      return null;
    } on AuthException catch (e) {
      return e;
    }
  }

  /// Mirrors AuthController.refreshUser -- re-fetches GET /me and
  /// replaces the cached user after a Settings change that doesn't
  /// itself return a full user object.
  Future<void> refreshUser() async {
    if (state.status != AdminAuthStatus.authenticated) return;
    try {
      final user = await _repository.getMe();
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AdminAuthState(status: AdminAuthStatus.unauthenticated);
  }

  void forceLogout() {
    state = const AdminAuthState(status: AdminAuthStatus.unauthenticated);
  }
}

/// UW 2.4 applies to every role this document names, Admin included --
/// mirrors authControllerProvider's own inactivityGuardProvider. See
/// InactivityGuard's doc comment for the shared reasoning.
final adminInactivityGuardProvider =
    Provider<InactivityGuard<AdminAuthState>>((ref) {
  return InactivityGuard<AdminAuthState>(
    ref: ref,
    stateListenable: adminAuthControllerProvider,
    isAuthenticated: (s) => s.status == AdminAuthStatus.authenticated,
    onTimeout: () => ref.read(adminAuthControllerProvider.notifier).logout(),
  );
});
