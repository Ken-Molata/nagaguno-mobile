// lib/features/buyer_mode/presentation/widgets/buyer_mode_pill.dart
//
// UW 1.5: "A pill-shaped toggle sits in the navbar, visible only to
// Farmer and Vendor accounts... two options side by side: the
// account's own role... and Buyer." This app has no single shared top
// navbar (each screen owns its own Scaffold/app bar, see README's
// architecture note) -- placed on HomeScreen specifically, the
// landing dashboard every Farmer/Vendor session starts on, as the one
// consistent, always-reachable spot. Tapping either side switches
// immediately, no loading state or confirmation, exactly as specified
// (nothing is submitted -- only the active browsing context changes).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/buyer_mode_controller.dart';

class BuyerModePill extends ConsumerWidget {
  const BuyerModePill({super.key, required this.ownRoleLabel});
  final String ownRoleLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inBuyerMode = ref.watch(buyerModeProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundStart,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Segment(
          label: ownRoleLabel,
          selected: !inBuyerMode,
          onTap: () => ref.read(buyerModeProvider.notifier).state = false,
        ),
        _Segment(
          label: 'Buyer',
          selected: inBuyerMode,
          onTap: () => ref.read(buyerModeProvider.notifier).state = true,
        ),
      ]),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: selected ? Colors.white : AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
