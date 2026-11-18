// lib/core/session/inactivity_guard.dart
//
// UW 2.4 Session Management & Logout: "Automatic logout: the system
// ends the session after 5 minutes of continuous account inactivity...
// The inactivity timer resets on any user interaction (navigation,
// input, or a request sent to the system), and only elapses during a
// period of complete inactivity." This was entirely unbuilt before --
// only the 15-minute fixed-lifetime access token existed, which is a
// different thing (expires regardless of activity, never reset by it).
//
// Generic over the auth state type T so both the consumer app's
// AuthController/AuthState and the web admin app's
// AdminAuthController/AdminAuthState (admin_web/application/
// admin_auth_controller.dart -- UW 2.4's actor list explicitly
// includes Admin) can share one implementation rather than duplicating
// the timer logic twice.
//
// Deliberately NOT reset by background network activity (the admin
// notification bell's 30s poll, UW 13.1's 5-second chat poll) -- only
// by a real pointer event ("input") or a route change ("navigation"),
// which InactivityListener and InactivityNavigatorObserver in
// inactivity_listener.dart wire up. A genuinely user-triggered request
// ("a request sent to the system") is always preceded by the tap that
// triggered it, which already resets the timer via the pointer hook --
// a separate Dio-interceptor reset would only double-count that, while
// wrongly keeping an idle session alive forever once a background poll
// is added to the mix.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const kInactivityTimeout = Duration(minutes: 5);

class InactivityGuard<T> {
  InactivityGuard({
    required Ref ref,
    required ProviderListenable<T> stateListenable,
    required bool Function(T state) isAuthenticated,
    required Future<void> Function() onTimeout,
  })  : _onTimeout = onTimeout {
    ref.listen<T>(stateListenable, (previous, next) {
      _authenticated = isAuthenticated(next);
      if (_authenticated) {
        recordActivity();
      } else {
        _cancel();
      }
    }, fireImmediately: true);
    ref.onDispose(_cancel);
  }

  final Future<void> Function() _onTimeout;
  Timer? _timer;
  bool _authenticated = false;

  /// Called on every pointer event and route change (see
  /// InactivityListener/InactivityNavigatorObserver below) -- a no-op
  /// while unauthenticated, so stray taps on the login screen never
  /// start a timer with no session to time out.
  void recordActivity() {
    if (!_authenticated) return;
    _timer?.cancel();
    _timer = Timer(kInactivityTimeout, () {
      _timer = null;
      // ignore: discarded_futures
      _onTimeout();
    });
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
