// lib/features/dashboard/presentation/easy_mode_home_screen.dart
//
// UW 21.6 Easy Mode: "a simplified home screen that shows the user's
// most-used actions as large buttons. It never removes a feature;
// everything else stays under 'More.'" Swapped in for the regular
// HomeScreen (app_router.dart's Home branch) only -- every other
// bottom-nav tab (Marketplace, Orders, Production/My Products/
// Listings, Agreements, and Profile/More) is completely unaffected by
// this toggle, still showing its full normal content exactly as
// before. That's the literal mechanism behind "nothing is removed":
// Easy Mode only changes what the Home tab itself shows and how big
// the nav bar's tap targets are (shared/widgets/app_shell.dart), never
// which tabs or screens exist.
//
// "Most-used actions" per role, picked from this app's own existing
// top-level destinations (not new screens): the ones judged highest-
// frequency for each role, same reasoning already used for which
// destinations get a dedicated bottom-nav tab in app_shell.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../authentication/application/auth_controller.dart';
import '../application/greeting.dart';

class _EasyAction {
  const _EasyAction(
      {required this.icon, required this.label, required this.path});
  final IconData icon;
  final String label;
  final String path;
}

List<_EasyAction> _buyerActions(AppStrings s) => [
      _EasyAction(
          icon: Icons.storefront,
          label: s.browseMarketplace,
          path: '/marketplace'),
      _EasyAction(
          icon: Icons.receipt_long, label: s.myOrders, path: '/orders'),
      _EasyAction(
          icon: Icons.handshake, label: s.myAgreements, path: '/agreements'),
      _EasyAction(
          icon: Icons.chat_bubble, label: s.messages, path: '/conversations'),
    ];

List<_EasyAction> _farmerActions(AppStrings s) => [
      _EasyAction(
          icon: Icons.inventory_2, label: s.myProducts, path: '/my-products'),
      _EasyAction(
          icon: Icons.grass, label: s.productionPlans, path: '/crop-plans'),
      _EasyAction(
          icon: Icons.receipt_long, label: s.myOrders, path: '/orders'),
      _EasyAction(
          icon: Icons.handshake, label: s.myAgreements, path: '/agreements'),
      _EasyAction(
          icon: Icons.chat_bubble, label: s.messages, path: '/conversations'),
    ];

List<_EasyAction> _vendorActions(AppStrings s) => [
      _EasyAction(
          icon: Icons.inventory_2, label: s.myListings, path: '/my-products'),
      _EasyAction(
          icon: Icons.receipt_long, label: s.myOrders, path: '/orders'),
      _EasyAction(
          icon: Icons.handshake, label: s.myAgreements, path: '/agreements'),
      _EasyAction(
          icon: Icons.chat_bubble, label: s.messages, path: '/conversations'),
    ];

List<_EasyAction> _actionsForRole(String role, AppStrings s) => switch (role) {
      'farmer' => _farmerActions(s),
      'vendor' => _vendorActions(s),
      _ => _buyerActions(s),
    };

class EasyModeHomeScreen extends ConsumerWidget {
  const EasyModeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const SizedBox.shrink();

    final s = ref.watch(appStringsProvider);
    final greeting = timeBasedGreeting(DateTime.now(), language: s.language);
    final actions = _actionsForRole(user.role, s);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('$greeting, ${user.fullName.split(' ').first}',
                  style: AppTypography.display.copyWith(fontSize: 26)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                s.everythingElseUnderMore,
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ListView.separated(
                  itemCount: actions.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final action = actions[i];
                    return _BigActionButton(
                      icon: action.icon,
                      label: action.label,
                      onTap: () => context.go(action.path),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// UW 21.6: "larger tap targets with more space between them" applies
/// to the home screen's own actions too, not only the nav bar -- a
/// tall, full-width button rather than a compact list tile.
class _BigActionButton extends StatelessWidget {
  const _BigActionButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 36, color: AppColors.primary),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(label,
                    style: AppTypography.h3.copyWith(fontSize: 20)),
              ),
              const Icon(Icons.chevron_right, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
