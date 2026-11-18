// lib/features/agreements/presentation/agreements_screen.dart
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/localization/app_strings.dart';
import '../../../shared/widgets/verification_banner.dart';
import '../../authentication/application/auth_controller.dart';
import '../../buyer_mode/application/buyer_mode_controller.dart';
import '../../buyer_mode/presentation/widgets/buyer_mode_label.dart';
import '../data/agreements_repository.dart';
import '../domain/agreement.dart';

final agreementsRepositoryProvider = Provider<AgreementsRepository>(
    (ref) => AgreementsRepository(ref.watch(apiClientProvider)));

final _statusFilterProvider = StateProvider<String>((ref) => 'all');

// REAL BUG FOUND AND FIXED: the Selling/Sourcing toggle below used to
// exist because a Vendor could, until now, own a crop plan and so sit
// on either side of a Smart Agreement. Per explicit direction, a
// Vendor is a reseller, not a grower, and now sits on the SAME side a
// plain Buyer does -- never the plan-owning side -- so a Vendor's
// "Selling" view would always be empty. Removed the toggle entirely;
// a Vendor now always views as buyer here, same as a plain Buyer
// (Farmers already only ever received requests, never sent them, so
// this makes all three roles consistent: Farmer = always seller view,
// Buyer/Vendor = always buyer view).
final agreementsListProvider =
    FutureProvider.autoDispose<List<Agreement>>((ref) async {
  final status = ref.watch(_statusFilterProvider);
  final role = ref.watch(authControllerProvider).user?.role;
  final view = (role == 'buyer' || role == 'vendor') ? 'buyer' : null;
  return ref
      .watch(agreementsRepositoryProvider)
      .getAgreements(status: status, view: view);
});

const _statusFilters = [
  'all',
  'pending',
  'negotiating',
  'active',
  'fulfilled',
  'rejected',
  'expired',
  'cancelled'
];

class AgreementsScreen extends ConsumerWidget {
  const AgreementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStatus = ref.watch(_statusFilterProvider);
    final agreementsAsync = ref.watch(agreementsListProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.smartAgreementsTitle)),
      // REAL BUG FOUND AND FIXED: this used to also offer "Browse
      // Vendors" as a source of production plans to request against --
      // per explicit direction, a Vendor is a reseller, not a grower,
      // and can no longer own a crop plan at all (routes/cropPlans.js
      // is now Farmer-only), so that destination would always show
      // "No open production plans right now." Farmers are the only
      // real source of a Smart Agreement now.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/farmers'),
        icon: const Icon(Icons.add),
        label: Text(s.newAgreementLabel),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VerificationBanner(),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: _statusFilters.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, i) {
                  final statusKey = _statusFilters[i];
                  return ChoiceChip(
                    label: Text(statusKey == 'all'
                        ? s.allLabel
                        : s.agreementStatusLabel(statusKey)),
                    selected: selectedStatus == statusKey,
                    onSelected: (_) => ref
                        .read(_statusFilterProvider.notifier)
                        .state = statusKey,
                  );
                },
              ),
            ),
            Expanded(
              child: agreementsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.couldntLoadAgreements),
                    const SizedBox(height: AppSpacing.sm),
                    ElevatedButton(
                        onPressed: () => ref.invalidate(agreementsListProvider),
                        child: Text(s.retry)),
                  ]),
                ),
                data: (agreements) {
                  if (agreements.isEmpty) {
                    // Same real fix as OrdersScreen: distinguishes
                    // "no agreements at all" from "none matching the
                    // active status filter" -- previously identical,
                    // misleading generic text either way.
                    final message = selectedStatus == 'all'
                        ? s.noAgreementsYet
                        : s.noAgreementsWithStatus(
                            s.agreementStatusLabel(selectedStatus));
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(message, textAlign: TextAlign.center),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(agreementsListProvider.future),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: agreements.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => InkWell(
                        onTap: () =>
                            context.push('/agreements/${agreements[i].id}'),
                        child: _AgreementCard(agreement: agreements[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgreementCard extends ConsumerWidget {
  const _AgreementCard({required this.agreement});
  final Agreement agreement;
  Color _statusColor(AgreementStatus s) {
    switch (s) {
      case AgreementStatus.pending:
        return AppColors.statusPendingFg;
      case AgreementStatus.negotiating:
        return AppColors.statusPreparingFg;
      case AgreementStatus.active:
        return AppColors.statusSuccessFg;
      case AgreementStatus.fulfilled:
        return AppColors.statusSuccessFg;
      case AgreementStatus.cancelled:
        return AppColors.statusCancelledFg;
      case AgreementStatus.rejected:
        return AppColors.statusCancelledFg;
      case AgreementStatus.expired:
        return AppColors.statusDispatchedFg;
    }
  }

  Color _statusBg(AgreementStatus s) {
    switch (s) {
      case AgreementStatus.pending:
        return AppColors.statusPendingBg;
      case AgreementStatus.negotiating:
        return AppColors.statusPreparingBg;
      case AgreementStatus.active:
        return AppColors.statusSuccessBg;
      case AgreementStatus.fulfilled:
        return AppColors.statusSuccessBg;
      case AgreementStatus.cancelled:
        return AppColors.statusCancelledBg;
      case AgreementStatus.rejected:
        return AppColors.statusCancelledBg;
      case AgreementStatus.expired:
        return AppColors.statusDispatchedBg;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authControllerProvider).user;
    final userId = currentUser?.id;
    final showBuyerModeLabel = isBuyerModeRecord(
        viewerRole: currentUser?.role,
        viewerId: userId,
        recordBuyerId: agreement.buyerId);
    final s = ref.watch(appStringsProvider);
    return InkWell(
      onTap: () => context.push('/agreements/${agreement.id}'),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Row(children: [
                  Flexible(
                      child: Text(agreement.productName,
                          style: AppTypography.h3.copyWith(fontSize: 15),
                          overflow: TextOverflow.ellipsis)),
                  if (showBuyerModeLabel) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const BuyerModeLabel(),
                  ],
                ])),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _statusBg(agreement.status),
                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(
                      s.agreementStatusLabel(agreement.status.name)
                          .toUpperCase(),
                      style: TextStyle(
                          color: _statusColor(agreement.status),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'DMSans')),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(s.withCounterpartyName(agreement.counterpartyName(userId)),
                style: AppTypography.bodySmall),
            const SizedBox(height: 4),
            Text(
                '${agreement.quantity.toStringAsFixed(0)} ${agreement.unit} · ₱${agreement.totalPrice.toStringAsFixed(2)}',
                style: AppTypography.body),
            if (agreement.canRespond(userId)) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(s.awaitingYourResponse,
                  style: AppTypography.label
                      .copyWith(color: AppColors.accentDark)),
            ],
          ],
        ),
      ),
    );
  }
}
