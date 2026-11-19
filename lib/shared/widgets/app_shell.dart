// lib/shared/widgets/app_shell.dart
//
// Real architectural note: StatefulShellRoute requires a FIXED set of
// branches defined once when the router is built — it can't have a
// different branch AT THE SAME INDEX per role. So rather than 3
// different 5-branch configurations (which would require rebuilding
// the whole GoRouter object when role becomes known, and again if it
// somehow changed), this defines ONE fixed underlying branch set
// covering the union of all destinations any role needs, and the nav
// bar itself shows only the role-relevant SUBSET as visual tabs,
// translating a tapped visual position back to the correct underlying
// branch index. The branch structure never changes; only which of its
// branches are exposed as bottom-nav destinations does.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_strings.dart';
import '../../features/authentication/application/auth_controller.dart';
import '../../features/accessibility/application/accessibility_settings.dart';

class NavTab {
  const NavTab(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.branchIndex});
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Index into the FIXED underlying branch list defined in
  /// app_router.dart's StatefulShellRoute — see branchOrder below,
  /// which is the single source of truth both files must agree on.
  final int branchIndex;
}

/// The fixed, real branch order — must exactly match the order
/// branches are declared in StatefulShellRoute.indexedStack in
/// app_router.dart. Indices: 0=Home, 1=Marketplace, 2=Agreements,
/// 3=Orders, 4=Production, 5=MyProducts, 6=Profile/More.
const branchHome = 0;
const branchMarketplace = 1;
const branchAgreements = 2;
const branchOrders = 3;
const branchProduction = 4;
const branchMyProducts = 5;
const branchProfile = 6;

List<NavTab> _buyerTabs(AppStrings s) => [
      NavTab(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: s.navHome,
          branchIndex: branchHome),
      NavTab(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront,
          label: s.navMarketplace,
          branchIndex: branchMarketplace),
      NavTab(
          icon: Icons.handshake_outlined,
          activeIcon: Icons.handshake,
          label: s.navAgreements,
          branchIndex: branchAgreements),
      NavTab(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long,
          label: s.navOrders,
          branchIndex: branchOrders),
      NavTab(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: s.navProfile,
          branchIndex: branchProfile),
    ];

List<NavTab> _farmerTabs(AppStrings s) => [
      NavTab(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: s.navHome,
          branchIndex: branchHome),
      NavTab(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront,
          label: s.navMarketplace,
          branchIndex: branchMarketplace),
      // My Products deliberately promoted to a top-level tab rather than
      // buried in "More" — it's the highest-frequency, income-critical
      // farmer workflow, per the earlier mobile UX plan's explicit
      // "keep common tasks reachable within 1-3 taps" requirement.
      NavTab(
          icon: Icons.grass_outlined,
          activeIcon: Icons.grass,
          label: s.navProduction,
          branchIndex: branchProduction),
      NavTab(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2,
          label: s.navMyProducts,
          branchIndex: branchMyProducts),
      // REAL GAP FOUND AND FIXED: a Farmer could successfully respond
      // to (or receive) a Smart Agreement request with no persistent
      // way back to check its status afterward -- the only path was a
      // small "Active Agreements" stat tile buried on the Home
      // dashboard. Every other role-relevant workflow this fixed-up
      // (Orders, My Products) already gets its own tab; Agreements,
      // where a Farmer actually responds to incoming requests, hadn't.
      NavTab(
          icon: Icons.handshake_outlined,
          activeIcon: Icons.handshake,
          label: s.navAgreements,
          branchIndex: branchAgreements),
      NavTab(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: s.navMore,
          branchIndex: branchProfile),
    ];

List<NavTab> _vendorTabs(AppStrings s) => [
      NavTab(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: s.navHome,
          branchIndex: branchHome),
      NavTab(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront,
          label: s.navMarketplace,
          branchIndex: branchMarketplace),
      NavTab(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2,
          label: s.navListings,
          branchIndex: branchMyProducts),
      NavTab(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long,
          label: s.navOrders,
          branchIndex: branchOrders),
      // REAL GAP FOUND AND FIXED: agreementsListProvider (agreements_
      // screen.dart) already permanently views a Vendor as the buyer
      // side of every Smart Agreement (a Vendor is a reseller, never a
      // plan owner, so this is the only side they're ever on) -- but
      // nothing in this nav bar led there. A Vendor who just sent an
      // agreement request to a Farmer had no persistent way to check
      // its status afterward, only the small "Active Agreements" stat
      // tile on the Home dashboard.
      NavTab(
          icon: Icons.handshake_outlined,
          activeIcon: Icons.handshake,
          label: s.navAgreements,
          branchIndex: branchAgreements),
      NavTab(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: s.navMore,
          branchIndex: branchProfile),
    ];

List<NavTab> tabsForRole(String role, AppStrings s) {
  switch (role) {
    case 'farmer':
      return _farmerTabs(s);
    case 'vendor':
      return _vendorTabs(s);
    default:
      return _buyerTabs(s); // buyer, and admin (admin is web-primary per the earlier UX plan, but falls back sanely here)
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    // Real fix: ConsumerState<T>.build takes only (BuildContext) --
    // matching plain State -- with `ref` accessed via the inherited
    // `ref` property, not as a second build parameter. That two-
    // parameter signature only belongs to ConsumerWidget (stateless).
    // Using it here caused a genuine invalid_override compile error,
    // not a lint suggestion -- caught via real flutter analyze output.
    final role = ref.watch(authControllerProvider).user?.role ?? 'buyer';
    final tabs = tabsForRole(role, ref.watch(appStringsProvider));
    // UW 21.6 Easy Mode: "larger tap targets with more space between
    // them" -- NavigationBar's own height/icon-size knobs, not a
    // separate nav bar implementation.
    final easyMode = ref.watch(accessibilitySettingsProvider).easyModeEnabled;

    // Translate the real underlying branch index back to this role's
    // visual tab position, so the correct tab shows as selected even
    // though tab position and branch index aren't the same number.
    final selectedVisualIndex = tabs.indexWhere(
        (t) => t.branchIndex == widget.navigationShell.currentIndex);

    return PopScope(
      // Previously no back-button handling existed at all -- the
      // default behavior meant a single back-press from the Home tab
      // closed the app instantly, which isn't the common, expected
      // Android convention (relevant specifically now that Android is
      // the sole confirmed target, not a minor polish item for a
      // platform not being shipped). Only intercepts on the Home tab
      // specifically -- other tabs still pop their own stack normally
      // via go_router's default StatefulNavigationShell behavior.
      canPop: widget.navigationShell.currentIndex != branchHome,
      // onPopInvokedWithResult is the current PopScope callback name
      // as of recent Flutter versions (it replaced the older
      // onPopInvoked) -- this matches the real, confirmed Flutter
      // 3.41.9 in use, but this environment has no way to verify it
      // against that exact SDK's API directly. If `flutter analyze`
      // flags this specific callback name, check PopScope's actual
      // current signature in your installed version first -- this is
      // the one line in this widget most likely to need a small
      // rename, not the overall back-button-handling approach.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || widget.navigationShell.currentIndex != branchHome) return;
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Press back again to exit'),
                duration: Duration(seconds: 2)),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedVisualIndex < 0 ? 0 : selectedVisualIndex,
          onDestinationSelected: (visualIndex) {
            final branchIndex = tabs[visualIndex].branchIndex;
            widget.navigationShell.goBranch(branchIndex,
                initialLocation:
                    branchIndex == widget.navigationShell.currentIndex);
          },
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.backgroundStart,
          height: easyMode ? 88 : 64,
          destinations: tabs
              .map((t) => NavigationDestination(
                    icon: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: easyMode ? AppSpacing.sm : 0),
                      child: Icon(t.icon,
                          size: easyMode ? 32 : 24,
                          color: AppColors.textMuted),
                    ),
                    selectedIcon: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: easyMode ? AppSpacing.sm : 0),
                      child: Icon(t.activeIcon,
                          size: easyMode ? 32 : 24, color: AppColors.primary),
                    ),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
