// lib/admin_web/presentation/admin_shell.dart
//
// UW 2.6's described layout (the shared design canvas's own
// "Admin: Verification Queue (Desktop)" mockup, read earlier this
// session, models the same shape): a fixed left sidebar of admin
// sections plus a content area, not the mobile app's bottom-nav
// pattern (app_shell.dart) -- Admin has no tab structure at all, same
// reasoning app_router.dart's own redirect comment already gives for
// why Admin is routed outside the consumer shell entirely.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../application/admin_auth_controller.dart';
import 'widgets/admin_notification_bell.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}

const _navItems = [
  _NavItem('Dashboard', Icons.dashboard_outlined, '/admin'),
  _NavItem(
      'Verification Queue', Icons.verified_user_outlined, '/admin/kyc'),
  _NavItem('KYC Route Table', Icons.alt_route_outlined, '/admin/kyc-routes'),
  _NavItem('Account Recovery', Icons.lock_reset_outlined,
      '/admin/account-recovery'),
  _NavItem('Users', Icons.people_outline, '/admin/users'),
  _NavItem('Listings', Icons.inventory_2_outlined, '/admin/listings'),
  _NavItem(
      'Orders & Agreements', Icons.receipt_long_outlined, '/admin/orders'),
  _NavItem(
      'Reports & Disputes', Icons.flag_outlined, '/admin/reports-disputes'),
  _NavItem('Refunds', Icons.currency_exchange_outlined, '/admin/refunds'),
  _NavItem('Gateway Settlement', Icons.account_balance_outlined, '/admin/settlements'),
  _NavItem('Appeals', Icons.gavel_outlined, '/admin/appeals'),
  _NavItem('Profile Corrections', Icons.edit_note_outlined,
      '/admin/corrections'),
  _NavItem('Vendor Business Permits', Icons.storefront_outlined,
      '/admin/vendor-permits'),
  _NavItem('Spoilage Monitoring', Icons.eco_outlined, '/admin/spoilage'),
  _NavItem('Shelf Life Feedback', Icons.rate_review_outlined,
      '/admin/shelf-life-feedback'),
  _NavItem('Platform Reports', Icons.bar_chart_outlined, '/admin/platform-reports'),
  _NavItem('Platform Feedback', Icons.feedback_outlined, '/admin/feedback'),
  _NavItem('Settings', Icons.settings_outlined, '/admin/settings'),
];

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final user = ref.watch(adminAuthControllerProvider).user;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 240,
            color: AppColors.primary,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Image.asset('assets/icons/app_logo_transparent.png',
                            width: 28, height: 28),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: Text('NagaGuno Admin',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Fraunces')),
                        ),
                        // UW 15: previously nowhere for an admin-facing
                        // notification (e.g. the Didit allowance notice,
                        // or UW 9.1's "new Account Recovery request"
                        // badge) to surface at all in this app.
                        const AdminNotificationBell(),
                      ],
                    ),
                  ),
                  Expanded(
                    // REAL GAP FOUND AND FIXED: a plain ListView does
                    // scroll on Flutter web, but with no visible
                    // scrollbar and (by MaterialScrollBehavior's
                    // default) no response to click-and-drag with a
                    // mouse -- only the wheel/trackpad worked, so with
                    // 17 nav items now on a short window, this read as
                    // "stuck" with no way to reach e.g. Shelf Life
                    // Feedback. Scrollbar makes it visibly draggable;
                    // the ScrollConfiguration override makes an actual
                    // mouse drag work too, not just the wheel.
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                          PointerDeviceKind.stylus,
                        },
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ListView(
                      padding: EdgeInsets.zero,
                      children: _navItems.map((item) {
                        final selected = item.path == '/admin'
                            ? currentPath == '/admin'
                            : currentPath.startsWith(item.path);
                        return ListTile(
                          leading: Icon(item.icon,
                              color: selected
                                  ? AppColors.accent
                                  : Colors.white70,
                              size: 20),
                          title: Text(item.label,
                              style: TextStyle(
                                  color: selected
                                      ? AppColors.accent
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                          selected: selected,
                          selectedTileColor: Colors.white.withValues(alpha: 0.08),
                          onTap: () => context.go(item.path),
                          dense: true,
                        );
                      }).toList(),
                        ),
                      ),
                    ),
                  ),
                  if (user != null)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(user.fullName,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout,
                                color: Colors.white70, size: 18),
                            tooltip: 'Sign out',
                            onPressed: () => ref
                                .read(adminAuthControllerProvider.notifier)
                                .logout(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.backgroundStart,
              // Watermark shared by every admin feature screen -- this
              // is the one ColoredBox every route renders its content
              // on top of, so putting it here (rather than in each of
              // the ~17 individual screens) covers all of them at once.
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Opacity(
                          opacity: 0.5,
                          child: Image.asset(
                              'assets/icons/app_logo_transparent.png',
                              width: 420,
                              height: 420,
                              fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
