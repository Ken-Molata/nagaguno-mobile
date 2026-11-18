// test/features/authentication/auth_controller_test.dart
//
// Real, mocked-dependency tests for AuthController's state
// transitions — both AuthRepository and SecureStorage are mocked via
// mocktail, so this never touches a real network call or the real
// Keychain/Keystore-backed singleton. This was only possible after
// injecting SecureStorage as a constructor parameter (see the real
// fix in auth_controller.dart) — before that, the constructor's
// _tryRestoreSession() call would have hit the real singleton
// directly and required actual platform channels.
//
// Written against the real class this session, never actually run —
// no Dart/Flutter SDK in this environment. Ready to run the moment
// that access works.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nagaguno_mobile/core/storage/secure_storage.dart';
import 'package:nagaguno_mobile/features/authentication/application/auth_controller.dart';
import 'package:nagaguno_mobile/features/authentication/data/auth_repository.dart';
import 'package:nagaguno_mobile/features/authentication/domain/nagaguno_user.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  // forceLogout() reads rootNavigatorKey.currentState, which touches
  // WidgetsBinding.instance -- a real `flutter test` run caught this:
  // without a real binding, that getter throws before the test's own
  // assertions ever run. TestWidgetsFlutterBinding.ensureInitialized()
  // is the correct fix per Flutter's own error message, not a workaround.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository repository;
  late MockSecureStorage secureStorage;

  const fakeUser = NagagunoUser(
    id: 'user-1',
    fullName: 'Juan Dela Cruz',
    role: 'buyer',
    accountStatus: 'active',
  );

  setUp(() {
    repository = MockAuthRepository();
    secureStorage = MockSecureStorage();
  });

  group('AuthController — cold start / session restore', () {
    test(
        'with no stored refresh token, goes straight to unauthenticated without calling getMe',
        () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => null);

      final controller =
          AuthController(repository, secureStorage: secureStorage);
      // Allow the async _tryRestoreSession() to complete.
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, AuthStatus.unauthenticated);
      verifyNever(() => repository.getMe());
    });

    test(
        'with a stored refresh token and a successful getMe, restores as authenticated',
        () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => 'stored-refresh-token');
      when(() => repository.getMe()).thenAnswer((_) async => fakeUser);

      final controller =
          AuthController(repository, secureStorage: secureStorage);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user, fakeUser);
    });
  });

  group('AuthController — login', () {
    test('on success, transitions to authenticated with the returned user',
        () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => null);
      final controller =
          AuthController(repository, secureStorage: secureStorage);
      await Future<void>.delayed(Duration.zero);

      when(() =>
          repository.login(
              email: 'juan@example.com',
              phoneNumber: null,
              password: 'Password1!')).thenAnswer(
          (_) async => AuthResult(user: fakeUser, message: 'Welcome back!'));

      final error = await controller.login(
          email: 'juan@example.com', password: 'Password1!');

      expect(error, isNull);
      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user, fakeUser);
    });

    test(
        'on failure, returns the AuthException and does NOT change auth status',
        () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => null);
      final controller =
          AuthController(repository, secureStorage: secureStorage);
      await Future<void>.delayed(Duration.zero);
      // Confirm the starting state before the failed attempt, so the
      // "did not change" assertion below is meaningful, not assumed.
      expect(controller.state.status, AuthStatus.unauthenticated);

      when(() => repository.login(
              email: 'juan@example.com', phoneNumber: null, password: 'wrong'))
          .thenThrow(AuthException(
              'Invalid credentials. Please check your login details.'));

      final error =
          await controller.login(email: 'juan@example.com', password: 'wrong');

      expect(error, isNotNull);
      expect(error!.message,
          'Invalid credentials. Please check your login details.');
      expect(controller.state.status, AuthStatus.unauthenticated,
          reason: 'a failed login must not silently authenticate the user');
    });
  });

  group('AuthController — refreshUser', () {
    test(
        'when authenticated, re-fetches getMe() and replaces the cached user -- UW 21.5/21.7\'s account settings save',
        () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => 'token');
      when(() => repository.getMe()).thenAnswer((_) async => fakeUser);
      final controller =
          AuthController(repository, secureStorage: secureStorage);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.user, fakeUser);

      const updatedUser = NagagunoUser(
        id: 'user-1',
        fullName: 'Juan Dela Cruz',
        role: 'buyer',
        accountStatus: 'active',
        language: 'tl',
        smsDeliveryUpdates: false,
      );
      when(() => repository.getMe()).thenAnswer((_) async => updatedUser);

      await controller.refreshUser();

      expect(controller.state.user, updatedUser);
      expect(controller.state.status, AuthStatus.authenticated);
    });

    test('when NOT authenticated, does nothing -- never calls getMe()',
        () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => null);
      final controller =
          AuthController(repository, secureStorage: secureStorage);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, AuthStatus.unauthenticated);

      await controller.refreshUser();

      verifyNever(() => repository.getMe());
      expect(controller.state.status, AuthStatus.unauthenticated);
    });

    test(
        'a failed refresh is best-effort -- the previously cached user is kept, not cleared',
        () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => 'token');
      when(() => repository.getMe()).thenAnswer((_) async => fakeUser);
      final controller =
          AuthController(repository, secureStorage: secureStorage);
      await Future<void>.delayed(Duration.zero);

      when(() => repository.getMe()).thenThrow(Exception('network error'));

      await controller.refreshUser();

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user, fakeUser);
    });
  });

  group('AuthController — logout vs forceLogout', () {
    test('logout() calls the repository and clears state', () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => 'token');
      when(() => repository.getMe()).thenAnswer((_) async => fakeUser);
      final controller =
          AuthController(repository, secureStorage: secureStorage);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, AuthStatus.authenticated);

      when(() => repository.logout()).thenAnswer((_) async {});
      await controller.logout();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(controller.state.user, isNull);
      verify(() => repository.logout()).called(1);
    });

    test(
        'forceLogout() clears state WITHOUT calling the repository — this is the real distinction the interceptor relies on',
        () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => 'token');
      when(() => repository.getMe()).thenAnswer((_) async => fakeUser);
      final controller =
          AuthController(repository, secureStorage: secureStorage);
      await Future<void>.delayed(Duration.zero);

      controller.forceLogout();

      expect(controller.state.status, AuthStatus.unauthenticated);
      verifyNever(() => repository.logout());
    });
  });
}
