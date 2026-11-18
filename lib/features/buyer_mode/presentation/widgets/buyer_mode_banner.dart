// lib/features/buyer_mode/presentation/widgets/buyer_mode_banner.dart
//
// UW 1.5's exact copy: "Browsing as a buyer. Orders you place here
// are separate from your own listings." plus a visible switch-back
// control in the same banner. Shown on every screen tied to
// "browsing, ordering, and Smart Agreement actions" the spec calls
// out by name: Marketplace, product detail, and the new-agreement
// flow -- plus Home, since that's where the toggle itself lives.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/buyer_mode_controller.dart';

class BuyerModeBanner extends ConsumerWidget {
  const BuyerModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inBuyerMode = ref.watch(buyerModeProvider);
    if (!inBuyerMode) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.statusPreparingBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(children: [
        const Icon(Icons.shopping_bag_outlined,
            size: 18, color: AppColors.statusPreparingFg),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Browsing as a buyer. Orders you place here are separate from your own listings.',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.statusPreparingFg),
          ),
        ),
        TextButton(
          onPressed: () => ref.read(buyerModeProvider.notifier).state = false,
          style: TextButton.styleFrom(
              foregroundColor: AppColors.statusPreparingFg,
              padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: const Text('Switch Back'),
        ),
      ]),
    );
  }
}
