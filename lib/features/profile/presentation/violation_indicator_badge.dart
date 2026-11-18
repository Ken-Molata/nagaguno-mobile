// lib/features/profile/presentation/violation_indicator_badge.dart
//
// UW 17.3's "red indicator": shown only on the account holder's own
// profile (never on another user's profile view -- VerificationBadge
// in shared/widgets is the correct widget for that case) and to Admin
// (already wired separately in admin_users_screen.dart). Was entirely
// missing from the user's own profile before this.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/profile_repository.dart';
import '../domain/violation_indicator.dart';

final _violationStatusProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(apiClientProvider)));
final violationIndicatorProvider =
    FutureProvider.autoDispose<ViolationIndicator?>(
        (ref) => ref.watch(_violationStatusProvider).getViolationStatus());

class ViolationIndicatorBadge extends ConsumerWidget {
  const ViolationIndicatorBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(violationIndicatorProvider);
    final status = statusAsync.valueOrNull;
    if (status == null || !status.hasIndicator) return const SizedBox.shrink();

    final isSuspended = status.isSuspended;
    // UW 17.3: "Notification states the count and the category by
    // name... 'You have committed 2 Cash-on-Delivery cancellation
    // violations. One more will result in a one-week Cash-on-Delivery
    // suspension.'" -- the indicator itself names the same categories.
    final categoryText = status.categories.map((c) => c.label).join(', ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusCancelledBg,
        border: Border.all(color: AppColors.statusCancelledFg),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(isSuspended ? Icons.block : Icons.warning_amber_rounded,
              color: AppColors.statusCancelledFg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isSuspended ? 'Suspended' : 'Near Suspension',
                    style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusCancelledFg)),
                Text(
                  isSuspended
                      ? (status.suspendedUntil != null
                          ? 'Access restricted until ${status.suspendedUntil!.toLocal().toString().split(' ').first}.'
                          : 'Your account is currently suspended.')
                      : 'One more violation in $categoryText will result in a suspension.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.statusCancelledFg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
