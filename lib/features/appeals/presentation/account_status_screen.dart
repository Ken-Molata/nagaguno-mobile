// lib/features/appeals/presentation/account_status_screen.dart
//
// UW 17.5. Forced destination for a banned/suspended account (see
// app_router.dart's redirect) -- the router fix elsewhere this session
// (login() now issuing a real token for a penalized account) is what
// makes it possible for them to ever reach this screen at all. Also
// reachable normally from Profile for a COD-restricted account, which
// never blocked login in the first place.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../authentication/application/auth_controller.dart';
import '../data/appeals_repository.dart';
import '../domain/appeal.dart';
import 'appeal_form_screen.dart';

final appealsRepositoryProvider = Provider<AppealsRepository>(
    (ref) => AppealsRepository(ref.watch(apiClientProvider)));
final myAppealsProvider = FutureProvider.autoDispose<List<Appeal>>(
    (ref) => ref.watch(appealsRepositoryProvider).getMyAppeals());
final appealEligibilityProvider =
    FutureProvider.autoDispose<Map<AppealTargetType, bool>>(
        (ref) => ref.watch(appealsRepositoryProvider).getEligibility());

class AccountStatusScreen extends ConsumerWidget {
  const AccountStatusScreen({super.key});

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final appealsAsync = ref.watch(myAppealsProvider);
    final eligibility = ref.watch(appealEligibilityProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Status'),
        // A banned/suspended account has nowhere else to go -- no back
        // button, but logging out is always available.
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: user == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (user.isBanned)
                    _buildPenaltyCard(
                      context,
                      ref,
                      AppealTargetType.ban,
                      'Your account has been permanently banned.',
                      canAppeal: eligibility?[AppealTargetType.ban],
                    ),
                  if (user.isSuspended)
                    _buildPenaltyCard(
                      context,
                      ref,
                      AppealTargetType.suspension,
                      'Your account is suspended until ${_fmt(user.suspendedUntil!)}.',
                      canAppeal: eligibility?[AppealTargetType.suspension],
                    ),
                  if (user.hasCodRestriction)
                    _buildPenaltyCard(
                      context,
                      ref,
                      AppealTargetType.codRestriction,
                      'Cash-on-Delivery is unavailable on your account until ${_fmt(user.codRestrictedUntil!)}.',
                      canAppeal: eligibility?[AppealTargetType.codRestriction],
                    ),
                  if (!user.isBanned &&
                      !user.isSuspended &&
                      !user.hasCodRestriction)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text('No active penalties on your account.',
                          style: AppTypography.body),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Your Appeals', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.sm),
                  appealsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('Couldn\'t load your appeals.',
                        style: AppTypography.bodySmall),
                    data: (appeals) {
                      if (appeals.isEmpty) {
                        return const Text('No appeals submitted yet.',
                            style: AppTypography.bodySmall);
                      }
                      return Column(
                        children:
                            appeals.map((a) => _AppealTile(appeal: a)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  // UW 17.5: "once a decision is reached... the Appeal entry point for
  // that specific penalty is disabled or removed from view at the
  // source." [canAppeal] is null while GET /appeals/eligibility is
  // still loading (button hidden, nothing shown yet rather than a
  // flash of the wrong state), true shows the real button, false shows
  // an explanatory line instead -- removed, not disabled-and-clickable,
  // since the backend has nothing left to accept a resubmission anyway.
  Widget _buildPenaltyCard(BuildContext context, WidgetRef ref,
      AppealTargetType type, String message, {required bool? canAppeal}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.statusCancelledBg,
          border: Border.all(color: AppColors.statusCancelledFg),
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type.label,
              style: AppTypography.h3
                  .copyWith(color: AppColors.statusCancelledFg, fontSize: 15)),
          const SizedBox(height: 4),
          Text(message,
              style: AppTypography.body
                  .copyWith(color: AppColors.statusCancelledFg)),
          const SizedBox(height: AppSpacing.sm),
          if (canAppeal == true)
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AppealFormScreen(targetType: type))),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.statusCancelledFg),
                  foregroundColor: AppColors.statusCancelledFg),
              child: const Text('Appeal This'),
            )
          else if (canAppeal == false)
            Text('You\'ve already appealed this -- see below for its status.',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.statusCancelledFg)),
        ],
      ),
    );
  }
}

class _AppealTile extends StatelessWidget {
  const _AppealTile({required this.appeal});
  final Appeal appeal;

  Color _color(AppealStatus s) => switch (s) {
        AppealStatus.approved => AppColors.statusSuccessFg,
        AppealStatus.rejected => AppColors.statusCancelledFg,
        AppealStatus.pending => AppColors.statusPendingFg,
      };

  String _label(AppealStatus s) => switch (s) {
        AppealStatus.approved => 'Approved',
        AppealStatus.rejected => 'Rejected',
        AppealStatus.pending => 'Pending Review',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(appeal.targetType.label,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600))),
            Text(_label(appeal.status),
                style:
                    AppTypography.label.copyWith(color: _color(appeal.status))),
          ]),
          if (appeal.adminNotes != null) ...[
            const SizedBox(height: 4),
            Text(appeal.adminNotes!, style: AppTypography.bodySmall),
          ],
        ],
      ),
    );
  }
}
