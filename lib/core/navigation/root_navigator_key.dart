// lib/core/navigation/root_navigator_key.dart
//
// A real, if partial, mitigation for the documented architectural
// limitation in README.md (mixing go_router's declarative navigation
// with imperative Navigator.push for 7 modal-style sub-screens): a
// forced session expiry can otherwise leave one of those 7 screens
// stuck on top of go_router's own navigator, since go_router's
// redirect logic doesn't automatically pop imperatively-pushed
// routes sitting above its own stack.
//
// This does NOT fully solve that architectural mismatch (see the
// README section for why a full fix means converting all 7 screens
// to real go_router routes) -- it specifically handles the forced-
// logout case, which is the one scenario where leaving a stale
// screen visible actually matters (every other case, the user is
// still authenticated and any imperative screen sitting on top is
// exactly where they'd expect it to be).
//
// Kept in its own file, separate from both app_router.dart and
// auth_controller.dart, specifically to avoid a circular import
// between the two (app_router.dart already imports
// auth_controller.dart for authControllerProvider).

import 'package:flutter/material.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
