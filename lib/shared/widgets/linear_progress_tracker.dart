// lib/shared/widgets/linear_progress_tracker.dart
//
// Extracted after noticing the agreement and order progress trackers
// were nearly identical (same connector-line and step-circle logic,
// differing only in step count/labels/icons and which status enum
// drove them) -- rather than leave two copies of the same rendering
// logic, this takes a plain list of steps and a current index, with
// each screen responsible only for building its own step list and
// terminal-state handling (cancelled), which genuinely differs enough
// between the two to stay screen-specific.

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ProgressStep {
  const ProgressStep({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class LinearProgressTracker extends StatelessWidget {
  const LinearProgressTracker(
      {super.key,
      required this.steps,
      required this.currentIndex,
      this.labelWidth = 64});
  final List<ProgressStep> steps;
  final int currentIndex;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final leftStepIndex = i ~/ 2;
          final isCompleted = leftStepIndex < currentIndex;
          return Expanded(
            child: Container(
                height: 2,
                color: isCompleted ? AppColors.primary : AppColors.border),
          );
        }
        final stepIndex = i ~/ 2;
        final step = steps[stepIndex];
        final isCompleted = stepIndex < currentIndex;
        final isCurrent = stepIndex == currentIndex;
        final color =
            (isCompleted || isCurrent) ? AppColors.primary : AppColors.border;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: color,
              child: Icon(isCompleted ? Icons.check : step.icon,
                  size: 14, color: Colors.white),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: labelWidth,
              child: Text(
                step.label,
                style: AppTypography.label.copyWith(
                    color: (isCompleted || isCurrent)
                        ? AppColors.textPrimary
                        : AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// The shared "cancelled" terminal-state banner, since both orders and
/// agreements render an identical one -- same reasoning as the
/// tracker itself.
class CancelledStatusBanner extends StatelessWidget {
  const CancelledStatusBanner({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
          color: AppColors.statusCancelledBg,
          borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined,
              color: AppColors.statusCancelledFg, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(label,
              style: AppTypography.body.copyWith(
                  color: AppColors.statusCancelledFg,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
