// lib/features/buyer_mode/presentation/widgets/buyer_mode_label.dart
//
// UW 1.5: "Every order and Smart Agreement placed while in buyer mode
// carries a 'Buyer Mode' label wherever it appears: in Transaction
// History, in order and agreement detail pages, and in the purchase
// analytics view." One small reusable chip rather than four separate
// copies of the same markup.
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class BuyerModeLabel extends StatelessWidget {
  const BuyerModeLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.statusPreparingBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Text(
        'BUYER MODE',
        style: TextStyle(
          color: AppColors.statusPreparingFg,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          fontFamily: 'DMSans',
        ),
      ),
    );
  }
}
