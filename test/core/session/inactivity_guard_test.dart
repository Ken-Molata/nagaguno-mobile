// test/core/session/inactivity_guard_test.dart
//
// UW 2.4: "the system ends the session after 5 minutes of continuous
// account inactivity... The inactivity timer resets on any user
// interaction... and only elapses during a period of complete
// inactivity." Pure timer logic (no widgets involved), so tested with
// FakeAsync against a minimal fake auth provider rather than the real
// AuthController/AdminAuthController -- both of those just need to
// supply an authenticated/unauthenticated status and a logout(),
// exactly what this fake does.
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/core/session/inactivity_guard.dart';

enum _Status { authenticated, unauthenticated }

class _FakeState {
  const _FakeState(this.status);
  final _Status status;
}

class _FakeController extends StateNotifier<_FakeState> {
  _FakeController() : super(const _FakeState(_Status.unauthenticated));
  void signIn() => state = const _FakeState(_Status.authenticated);
  void signOut() => state = const _FakeState(_Status.unauthenticated);
}

void main() {
  group('InactivityGuard', () {
    test('fires onTimeout 5 minutes after the account becomes authenticated',
        () {
      fakeAsync((async) {
        var timeoutCount = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final authProvider =
            StateNotifierProvider<_FakeController, _FakeState>(
                (ref) => _FakeController());
        final guardProvider = Provider<InactivityGuard<_FakeState>>((ref) {
          return InactivityGuard<_FakeState>(
            ref: ref,
            stateListenable: authProvider,
            isAuthenticated: (s) => s.status == _Status.authenticated,
            onTimeout: () async => timeoutCount++,
          );
        });
        container.read(guardProvider);

        container.read(authProvider.notifier).signIn();
        async.elapse(const Duration(minutes: 5));

        expect(timeoutCount, 1);
      });
    });

    test('recordActivity() pushes the timeout back instead of stacking it',
        () {
      fakeAsync((async) {
        var timeoutCount = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final authProvider =
            StateNotifierProvider<_FakeController, _FakeState>(
                (ref) => _FakeController());
        final guardProvider = Provider<InactivityGuard<_FakeState>>((ref) {
          return InactivityGuard<_FakeState>(
            ref: ref,
            stateListenable: authProvider,
            isAuthenticated: (s) => s.status == _Status.authenticated,
            onTimeout: () async => timeoutCount++,
          );
        });
        final guard = container.read(guardProvider);
        container.read(authProvider.notifier).signIn();

        // A tap at the 4-minute mark must NOT let the original 5-minute
        // deadline fire at absolute minute 5.
        async.elapse(const Duration(minutes: 4));
        guard.recordActivity();
        async.elapse(const Duration(minutes: 1));
        expect(timeoutCount, 0,
            reason: 'activity at minute 4 should have reset the clock');

        // It fires 5 minutes after THAT activity instead (absolute
        // minute 9), not a second earlier.
        async.elapse(const Duration(minutes: 3, seconds: 59));
        expect(timeoutCount, 0);
        async.elapse(const Duration(seconds: 1));
        expect(timeoutCount, 1);
      });
    });

    test('never fires while the account was never authenticated', () {
      fakeAsync((async) {
        var timeoutCount = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final authProvider =
            StateNotifierProvider<_FakeController, _FakeState>(
                (ref) => _FakeController());
        final guardProvider = Provider<InactivityGuard<_FakeState>>((ref) {
          return InactivityGuard<_FakeState>(
            ref: ref,
            stateListenable: authProvider,
            isAuthenticated: (s) => s.status == _Status.authenticated,
            onTimeout: () async => timeoutCount++,
          );
        });
        final guard = container.read(guardProvider);

        guard.recordActivity();
        async.elapse(const Duration(minutes: 10));

        expect(timeoutCount, 0);
      });
    });

    test('signing out cancels the pending timer', () {
      fakeAsync((async) {
        var timeoutCount = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final authProvider =
            StateNotifierProvider<_FakeController, _FakeState>(
                (ref) => _FakeController());
        final guardProvider = Provider<InactivityGuard<_FakeState>>((ref) {
          return InactivityGuard<_FakeState>(
            ref: ref,
            stateListenable: authProvider,
            isAuthenticated: (s) => s.status == _Status.authenticated,
            onTimeout: () async => timeoutCount++,
          );
        });
        container.read(guardProvider);
        container.read(authProvider.notifier).signIn();

        async.elapse(const Duration(minutes: 3));
        container.read(authProvider.notifier).signOut();
        async.elapse(const Duration(minutes: 10));

        expect(timeoutCount, 0,
            reason: 'logging out already ended the session; the stale '
                'timer must not also fire a second logout');
      });
    });

    test('re-authenticating after sign-out starts a fresh 5-minute window',
        () {
      fakeAsync((async) {
        var timeoutCount = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final authProvider =
            StateNotifierProvider<_FakeController, _FakeState>(
                (ref) => _FakeController());
        final guardProvider = Provider<InactivityGuard<_FakeState>>((ref) {
          return InactivityGuard<_FakeState>(
            ref: ref,
            stateListenable: authProvider,
            isAuthenticated: (s) => s.status == _Status.authenticated,
            onTimeout: () async => timeoutCount++,
          );
        });
        container.read(guardProvider);

        container.read(authProvider.notifier).signIn();
        async.elapse(const Duration(minutes: 3));
        container.read(authProvider.notifier).signOut();
        container.read(authProvider.notifier).signIn();
        async.elapse(const Duration(minutes: 4, seconds: 59));
        expect(timeoutCount, 0);
        async.elapse(const Duration(seconds: 1));
        expect(timeoutCount, 1);
      });
    });
  });
}
