// lib/core/session/inactivity_listener.dart
//
// The two "resets on any user interaction" hooks UW 2.4 names --
// "input" and "navigation" -- feeding an InactivityGuard. App-agnostic
// (plain VoidCallback), so both main.dart and main_web_admin.dart can
// reuse these against their own guard instance.
import 'package:flutter/widgets.dart';

/// Wraps the whole app; any tap/drag/scroll anywhere resets the idle
/// timer without every individual screen needing to know about it.
class InactivityListener extends StatelessWidget {
  const InactivityListener({
    super.key,
    required this.onActivity,
    required this.child,
  });

  final VoidCallback onActivity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onActivity(),
      onPointerMove: (_) => onActivity(),
      onPointerSignal: (_) => onActivity(),
      child: child,
    );
  }
}

/// Passed to GoRouter's `observers`; a route push/pop/replace counts as
/// "navigation" even when it wasn't itself a direct pointer event (a
/// redirect, a programmatic go()).
class InactivityNavigatorObserver extends NavigatorObserver {
  InactivityNavigatorObserver(this.onActivity);
  final VoidCallback onActivity;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onActivity();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onActivity();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onActivity();
}
