// lib/admin_web/admin_web_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/session/inactivity_listener.dart';
import '../features/admin/presentation/kyc_review_screen.dart';
import 'presentation/kyc_routes/admin_kyc_routes_screen.dart';
import '../features/admin/presentation/admin_users_screen.dart';
import 'application/admin_auth_controller.dart';
import 'presentation/admin_login_screen.dart';
import 'presentation/admin_shell.dart';
import 'presentation/admin_dashboard_screen.dart';
import 'presentation/account_recovery/admin_recovery_queue_screen.dart';
import 'presentation/listings/admin_listings_screen.dart';
import 'presentation/orders/admin_orders_agreements_screen.dart';
import 'presentation/reports_disputes/admin_reports_disputes_screen.dart';
import 'presentation/refunds/admin_refunds_screen.dart';
import 'presentation/settlements/admin_settlements_screen.dart';
import 'presentation/appeals/admin_appeals_screen.dart';
import 'presentation/corrections/admin_corrections_screen.dart';
import 'presentation/spoilage/admin_spoilage_screen.dart';
import 'presentation/platform_reports/admin_platform_reports_screen.dart';
import 'presentation/feedback/admin_feedback_screen.dart';
import 'presentation/shelf_life_feedback/admin_shelf_life_feedback_screen.dart';
import 'presentation/settings/admin_settings_screen.dart';

class _AdminAuthChangeNotifier extends ChangeNotifier {
  _AdminAuthChangeNotifier(Ref ref) {
    ref.listen(adminAuthControllerProvider, (_, __) => notifyListeners());
  }
}

final adminWebRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/admin',
    refreshListenable: _AdminAuthChangeNotifier(ref),
    // UW 2.4: a route change counts as "navigation" activity.
    observers: [
      InactivityNavigatorObserver(
          () => ref.read(adminInactivityGuardProvider).recordActivity()),
    ],
    redirect: (context, state) {
      final authState = ref.read(adminAuthControllerProvider);
      final onLogin = state.matchedLocation == '/login';
      switch (authState.status) {
        case AdminAuthStatus.unknown:
          return null;
        case AdminAuthStatus.unauthenticated:
          return onLogin ? null : '/login';
        case AdminAuthStatus.authenticated:
          return onLogin ? '/admin' : null;
      }
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const AdminLoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
              path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/kyc', builder: (_, __) => const KycReviewScreen()),
          GoRoute(
              path: '/admin/kyc-routes',
              builder: (_, __) => const AdminKycRoutesScreen()),
          GoRoute(
              path: '/admin/account-recovery',
              builder: (_, __) => const AdminRecoveryQueueScreen()),
          GoRoute(
              path: '/admin/users', builder: (_, __) => const AdminUsersScreen()),
          GoRoute(
              path: '/admin/listings',
              builder: (_, __) => const AdminListingsScreen()),
          GoRoute(
              path: '/admin/orders',
              builder: (_, __) => const AdminOrdersAgreementsScreen()),
          GoRoute(
              path: '/admin/reports-disputes',
              builder: (_, __) => const AdminReportsDisputesScreen()),
          GoRoute(
              path: '/admin/refunds',
              builder: (_, __) => const AdminRefundsScreen()),
          GoRoute(
              path: '/admin/settlements',
              builder: (_, __) => const AdminSettlementsScreen()),
          GoRoute(
              path: '/admin/appeals',
              builder: (_, __) => const AdminAppealsScreen()),
          GoRoute(
              path: '/admin/corrections',
              builder: (_, __) => const AdminCorrectionsScreen()),
          GoRoute(
              path: '/admin/spoilage',
              builder: (_, __) => const AdminSpoilageScreen()),
          GoRoute(
              path: '/admin/platform-reports',
              builder: (_, __) => const AdminPlatformReportsScreen()),
          GoRoute(
              path: '/admin/feedback',
              builder: (_, __) => const AdminFeedbackScreen()),
          GoRoute(
              path: '/admin/shelf-life-feedback',
              builder: (_, __) => const AdminShelfLifeFeedbackScreen()),
          GoRoute(
              path: '/admin/settings',
              builder: (_, __) => const AdminSettingsScreen()),
        ],
      ),
    ],
  );
});
