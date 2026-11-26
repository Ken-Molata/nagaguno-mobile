// lib/features/spoilage/presentation/spoilage_monitoring_screen.dart
//
// Closes a real gap: an entire, heavily-verified backend feature
// (routes/spoilage.js) had zero Flutter integration at all despite
// extensive documentation of its exact mechanism earlier this
// session.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../data/spoilage_repository.dart';
import '../domain/spoilage_listing.dart';
import 'photo_freshness_check_screen.dart';

final spoilageRepositoryProvider = Provider<SpoilageRepository>(
    (ref) => SpoilageRepository(ref.watch(apiClientProvider)));
final spoilageListingsProvider =
    FutureProvider.autoDispose<List<SpoilageListing>>(
        (ref) => ref.watch(spoilageRepositoryProvider).getMyListings());

/// Which crops the server-side freshness model actually covers --
/// fetched once per session, not bundled on-device (see
/// photo_freshness_check_screen.dart's header for why on-device
/// inference was abandoned).
final freshnessCoveredCropsProvider = FutureProvider<List<String>>(
    (ref) => ref.watch(spoilageRepositoryProvider).getFreshnessCoveredCrops());

class SpoilageMonitoringScreen extends ConsumerWidget {
  const SpoilageMonitoringScreen({super.key});

  Color _stageColor(String? stage) {
    switch (stage) {
      case 'near_spoilage':
        return AppColors.spoilageNear;
      case 'critical':
        return AppColors.spoilageCritical;
      case 'expired':
        return AppColors.spoilageExpired;
      default:
        return AppColors.spoilageFresh;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(spoilageListingsProvider);
    // Pre-warms freshnessCoveredCropsProvider the moment this screen
    // opens, so by the time a seller actually taps "Verify Freshness"
    // the request has very likely already resolved and _showReportDialog's
    // own await returns instantly instead of waiting on the network
    // right at the moment of the tap.
    ref.watch(freshnessCoveredCropsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spoilage Monitoring')),
      body: listingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Couldn\'t load your listings.'),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
                onPressed: () => ref.invalidate(spoilageListingsProvider),
                child: const Text('Retry')),
          ]),
        ),
        data: (listings) {
          if (listings.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('No perishable listings to monitor yet.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(spoilageListingsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: listings.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) =>
                  _ListingCard(listing: listings[i], stageColor: _stageColor),
            ),
          );
        },
      ),
    );
  }
}

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.listing, required this.stageColor});
  final SpoilageListing listing;
  final Color Function(String?) stageColor;

  // REAL BEHAVIOR CHANGE, BY EXPLICIT REQUEST: the manual Near
  // Spoilage/Critical/Expired dropdown has been removed from this
  // screen entirely -- the only way to override the calendar-computed
  // stage is now the photo-verified CV model, never a bare, unverified
  // seller claim. A listing whose crop the model was never trained on
  // (only Ampalaya, Banana, Cucumber, Eggplant, Orange, Papaya,
  // Pineapple, Tomato are covered -- see freshness_model_info.json)
  // has no override path at all: its spoilage status is purely the
  // calendar-based automatic stage from Part I, never seller-reported.
  // routes/spoilage.js's POST /report/:productId backend endpoint and
  // SpoilageRepository.reportSpoilage() are deliberately left in place
  // (not deleted) -- this is a UI-entry-point change, not a decision
  // to remove that backend capability.
  Future<void> _showReportDialog(BuildContext context, WidgetRef ref) async {
    // REAL BUG FOUND AND FIXED, live-confirmed: this used to read the
    // provider's CURRENT snapshot synchronously (`ref.read(provider)`
    // + `.valueOrNull`) instead of awaiting it. Since nothing else on
    // this screen ever watches freshnessCoveredCropsProvider, the very
    // first tap of this button each time was also the very first
    // moment anything ever asked for it -- the network request hadn't
    // had time to complete yet, so `.valueOrNull` was reliably still
    // null (AsyncLoading), and every listing, including a plainly
    // covered crop like Eggplant, fell through to "Photo Verification
    // Not Available" regardless of its real name. `.future` awaits the
    // actual result (using the cached value once it has resolved, or
    // the in-flight request the first time), closing the race.
    List<String> coveredCrops;
    try {
      coveredCrops = await ref.read(freshnessCoveredCropsProvider.future);
    } catch (_) {
      coveredCrops = const [];
    }
    final matchedCrop = resolveCoveredCrop(listing.name, coveredCrops);
    if (!context.mounted) return;

    if (matchedCrop == null) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Photo Verification Not Available'),
          content: Text(
              'Photo-verified freshness checking isn\'t available for "${listing.name}" yet. '
              'It currently only covers: ${coveredCrops.isEmpty ? 'Ampalaya, Banana, Cucumber, Eggplant, Orange, Papaya, Pineapple, Tomato' : coveredCrops.join(', ')}.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final applied = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PhotoFreshnessCheckScreen(listing: listing, matchedCrop: matchedCrop),
      ),
    );
    if (applied == true) ref.invalidate(spoilageListingsProvider);
  }

  static const _discountLabels = {
    'seller_discount': 'Seller Discount',
    'bulk_discount': 'Bulk Discount',
    'harvest_sale': 'Harvest Sale',
    'clearance': 'Clearance',
  };

  Future<void> _showSaleDialog(BuildContext context, WidgetRef ref) async {
    final percentController = TextEditingController();
    final minOrderController = TextEditingController();
    String whenItApplies = 'now';
    DateTime? startDate;
    DateTime? endDate;
    String? label;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Start a Sale'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: percentController,
                  keyboardType: TextInputType.number,
                  // UW 3.5: "a whole number from 1 to 50."
                  decoration: const InputDecoration(
                      labelText: 'Discount (whole number, 1-50)',
                      suffixText: '%'),
                ),
                const SizedBox(height: AppSpacing.sm),
                RadioGroup<String>(
                  groupValue: whenItApplies,
                  onChanged: (v) => setDialogState(() => whenItApplies = v!),
                  child: const Column(children: [
                    RadioListTile<String>(
                        title: Text('Until removed'),
                        value: 'now',
                        contentPadding: EdgeInsets.zero),
                    RadioListTile<String>(
                        title: Text('Set period'),
                        value: 'set_period',
                        contentPadding: EdgeInsets.zero),
                  ]),
                ),
                if (whenItApplies == 'set_period')
                  Row(children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)));
                          if (picked != null) {
                            setDialogState(() => startDate = picked);
                          }
                        },
                        child: Text(startDate == null
                            ? 'Start date'
                            : '${startDate!.year}-${startDate!.month}-${startDate!.day}'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: startDate ?? DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)));
                          if (picked != null) {
                            setDialogState(() => endDate = picked);
                          }
                        },
                        child: Text(endDate == null
                            ? 'End date'
                            : '${endDate!.year}-${endDate!.month}-${endDate!.day}'),
                      ),
                    ),
                  ]),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: minOrderController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Minimum order quantity (optional)'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: label,
                  decoration:
                      const InputDecoration(labelText: 'Label (optional)'),
                  items: _discountLabels.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => label = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Start Sale')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final percent = int.tryParse(percentController.text.trim());
    if (percent == null || percent < 1 || percent > 50) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Enter a whole number from 1 to 50.')));
      }
      return;
    }
    try {
      await ref.read(spoilageRepositoryProvider).startSale(
            listing.productId,
            discountPercent: percent,
            whenItApplies: whenItApplies,
            startDate: startDate,
            endDate: endDate,
            minimumOrderQty: double.tryParse(minOrderController.text.trim()),
            label: label,
          );
      ref.invalidate(spoilageListingsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn\'t start the sale. Please try again.')));
      }
    }
  }

  Future<void> _removeSale(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(spoilageRepositoryProvider).removeSale(listing.productId);
      ref.invalidate(spoilageListingsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn\'t remove the discount. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // REAL GAP FOUND AND FIXED: this card only ever rendered a LIVE
    // listing's stage/percentage -- a hidden-for-spoilage listing (now
    // surfaced by GET /spoilage/my-listings alongside the live ones,
    // see that route's own comment) had no distinct rendering at all,
    // so the user asked for explicitly: a "Hidden" label, how many days
    // past its own shelf life it is, and a way to undo it.
    final color = listing.isHidden ? AppColors.spoilageExpired : stageColor(listing.stage);
    return Container(
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
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                  child: Text(listing.name,
                      style: AppTypography.h3.copyWith(fontSize: 15))),
              Text(
                  listing.isHidden
                      ? 'HIDDEN'
                      : (listing.stage ?? 'unknown').toUpperCase(),
                  style: AppTypography.label.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (listing.isHidden) ...[
            Text(
                '${listing.autoHiddenReason ?? 'Spoilage'} -- '
                '${listing.daysOverdue ?? 0} day${(listing.daysOverdue ?? 0) == 1 ? '' : 's'} past its '
                '${listing.shelfLifeDays ?? '?'}-day shelf life',
                style: AppTypography.bodySmall),
            if (listing.manualSpoilageSource == 'cv' &&
                listing.manualSpoilagePhotoUrl != null) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.network(listing.manualSpoilagePhotoUrl!,
                    height: 100, fit: BoxFit.cover),
              ),
            ],
          ] else ...[
            // remaining_pct is a real fraction (0-1) -- ×100 for display, same conversion discipline as the discount field elsewhere.
            Text(
                '${(listing.remainingPct * 100).toStringAsFixed(0)}% of shelf life remaining '
                '(${listing.daysElapsed ?? '?'} of ${listing.shelfLifeDays ?? '?'} days elapsed)',
                style: AppTypography.bodySmall),
          ],
          if (listing.isManuallyReported) ...[
            const SizedBox(height: 4),
            Text(
                listing.manualSpoilageSource == 'cv'
                    ? 'Verified with photo'
                    : 'Manually reported',
                style:
                    AppTypography.label.copyWith(color: AppColors.accentDark)),
          ],

          if (listing.recommendation != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                  color: AppColors.backgroundStart,
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suggested: ${(listing.recommendation!.recommendedDiscountPct * 100).toStringAsFixed(0)}% off -> ₱${listing.recommendation!.recommendedPrice.toStringAsFixed(2)}',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(spoilageRepositoryProvider)
                                .respondToRecommendation(
                                    listing.recommendation!.id,
                                    accept: false);
                            ref.invalidate(spoilageListingsProvider);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Something went wrong. Please try again.')));
                            }
                          }
                        },
                        child: const Text('Dismiss'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(spoilageRepositoryProvider)
                                .respondToRecommendation(
                                    listing.recommendation!.id,
                                    accept: true);
                            ref.invalidate(spoilageListingsProvider);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Something went wrong. Please try again.')));
                            }
                          }
                        },
                        child: const Text('Accept'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],

          if (listing.hasActiveSellerDiscount) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                  color: AppColors.statusSuccessBg,
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Text(
                '${(listing.sellerDiscount!.discountPct * 100).toStringAsFixed(0)}% off'
                '${listing.sellerDiscount!.label != null ? ' (${_discountLabels[listing.sellerDiscount!.label] ?? listing.sellerDiscount!.label})' : ''}'
                '${listing.sellerDiscount!.isSetPeriod ? ' until ${listing.sellerDiscount!.endDate!.year}-${listing.sellerDiscount!.endDate!.month}-${listing.sellerDiscount!.endDate!.day}' : ' (until removed)'}',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.statusSuccessFg),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),
          if (listing.isHidden)
            // REAL BEHAVIOR CHANGE, BY EXPLICIT REQUEST: "Unhide This
            // Listing" let a seller bring a hidden listing straight
            // back to 'live' with zero evidence it had actually
            // stopped being expired -- the same unverified-claim gap
            // the manual dropdown removal above closed, just reached
            // through a different button. The only way back now is
            // the same photo-verified check as everything else:
            // routes/spoilage.js's POST /cv-override/:productId
            // already sets status back to 'live' (and clears
            // auto_hidden_reason) whenever the model's own stage comes
            // back as anything other than 'expired', so this one
            // button already does the right thing for a hidden
            // listing with no backend change needed.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showReportDialog(context, ref),
                child: const Text('Verify Freshness'),
              ),
            )
          else
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => _showReportDialog(context, ref),
                      child: const Text('Verify Freshness'))),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: listing.hasActiveSellerDiscount
                    ? OutlinedButton(
                        onPressed: () => _removeSale(context, ref),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            foregroundColor: AppColors.error),
                        child: const Text('Remove Discount'),
                      )
                    : OutlinedButton(
                        onPressed: () => _showSaleDialog(context, ref),
                        child: const Text('Start a Sale')),
              ),
            ]),
        ],
      ),
    );
  }
}
