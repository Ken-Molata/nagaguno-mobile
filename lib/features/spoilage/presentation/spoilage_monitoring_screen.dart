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
    //
    // SECOND REAL BUG FOUND AND FIXED, also live-confirmed: the
    // backend's getModelInfo() call to nagaguno-ml-service (a separate
    // Render service that spins down when idle and takes ~30-90s to
    // cold-start) used to time out after just 5s, which this screen's
    // own catch-and-fall-back-to-[] then quietly swallowed -- and
    // because freshnessCoveredCropsProvider is a plain (non-autoDispose)
    // FutureProvider, ONE cold-start failure left it permanently stuck
    // in an error state for the rest of the app session: every
    // following tap, on every crop, kept hitting the same cached
    // failure with no way to recover short of restarting the app.
    // Invalidating before re-reading here means each tap gets a fresh
    // attempt. The backend timeout itself is also fixed (see
    // services/freshnessService.js), but this still matters as a
    // safety net for whatever timeout value is ever set.
    if (ref.read(freshnessCoveredCropsProvider) is AsyncError) {
      ref.invalidate(freshnessCoveredCropsProvider);
    }

    // REAL GAP FOUND AND FIXED: with the backend's own cold-start/429
    // retry budget now up to ~170s (services/freshnessService.js,
    // widened after live-testing showed a shorter one wasn't always
    // enough), this await could previously leave the screen looking
    // completely frozen -- no spinner, no message -- for up to that
    // long on the very first check after a period of inactivity.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                  'Checking freshness service availability... this can take a couple of minutes if it hasn\'t been used in a while.'),
            ),
          ],
        ),
      ),
    );

    List<String> coveredCrops;
    bool fetchFailed = false;
    try {
      coveredCrops = await ref.read(freshnessCoveredCropsProvider.future);
    } catch (_) {
      coveredCrops = const [];
      fetchFailed = true;
    }

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    final matchedCrop =
        fetchFailed ? null : resolveCoveredCrop(listing.name, coveredCrops);
    if (!context.mounted) return;

    if (fetchFailed) {
      // Distinct from "this crop genuinely isn't covered" below --
      // claiming a crop list here (when none was actually fetched)
      // would contradict itself, exactly the confusing message this
      // bug used to show.
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Freshness Check Unavailable'),
          content: const Text(
              'Couldn\'t reach the freshness-checking service just now. '
              'Please wait a moment and try again.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    if (matchedCrop == null) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Photo Verification Not Available'),
          content: Text(
              'Photo-verified freshness checking isn\'t available for "${listing.name}" yet. '
              'It currently only covers: ${coveredCrops.join(', ')}.'),
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

  // Still used to show an existing discount's label on the card below
  // (a discount could carry one set before the creation dialog was
  // simplified, or via direct API/admin use) -- just no longer offered
  // as a choice when starting a new sale.
  static const _discountLabels = {
    'seller_discount': 'Seller Discount',
    'bulk_discount': 'Bulk Discount',
    'harvest_sale': 'Harvest Sale',
    'clearance': 'Clearance',
  };

  // REAL CHANGE, BY EXPLICIT REQUEST: this dialog used to also ask for
  // a time-box period (until removed vs. set period with start/end
  // dates), a minimum order quantity, and a cosmetic label. Stripped
  // down to just the percentage -- every sale now starts immediately
  // and runs until the seller removes it, with no minimum order
  // quantity and the default label, matching the "1 to 75 percent
  // discount, nothing else" ask exactly. The backend fields these
  // omitted values map to (when_it_applies/start_date/end_date/
  // minimum_order/label) are left untouched -- they still default
  // correctly when absent from the request, and the generated-column/
  // bulk-pricing logic those fields drive is unrelated, working
  // infrastructure this change has no reason to touch.
  Future<void> _showSaleDialog(BuildContext context, WidgetRef ref) async {
    final percentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start a Sale'),
        content: TextField(
          controller: percentController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Discount (whole number, 1-75)', suffixText: '%'),
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
    );
    if (confirmed != true) return;

    final percent = int.tryParse(percentController.text.trim());
    if (percent == null || percent < 1 || percent > 75) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Enter a whole number from 1 to 75.')));
      }
      return;
    }
    try {
      await ref.read(spoilageRepositoryProvider).startSale(
            listing.productId,
            discountPercent: percent,
            whenItApplies: 'now',
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
            // REAL BUG FOUND AND FIXED, by explicit request: this always
            // showed the raw calendar days-elapsed/shelf-life text, even
            // once a CV photo had overridden the displayed stage
            // (migration 062) and its own remaining_pct (migration 063)
            // -- a listing could show "NEAR SPOILAGE" at the top while
            // this very line, right below it, still read something like
            // "0% of shelf life remaining (30 of 4 days elapsed)": real
            // calendar numbers from before the photo was ever taken,
            // flatly contradicting the stage shown next to them. Once a
            // CV report is on file, remaining_pct itself is already the
            // photo-verified number (backend fix), so this just drops
            // the now-stale, now-misleading "X of Y days elapsed" half
            // of the sentence for that case rather than showing it
            // alongside a result it no longer matches.
            Text(
                listing.manualSpoilageSource == 'cv'
                    ? '${(listing.remainingPct * 100).toStringAsFixed(0)}% of shelf life remaining (from your photo verification)'
                    : '${(listing.remainingPct * 100).toStringAsFixed(0)}% of shelf life remaining '
                      '(${listing.daysElapsed ?? '?'} of ${listing.shelfLifeDays ?? '?'} days elapsed)',
                style: AppTypography.bodySmall),
          ],
          if (listing.isManuallyReported) ...[
            const SizedBox(height: 4),
            Text(
                // By explicit request: say plainly that this was an
                // automatic, photo-based OVERRIDE of the system's own
                // status, never "manually reported" -- that wording
                // belongs only to the unverified dropdown self-report,
                // a genuinely different, lower-trust kind of claim.
                listing.manualSpoilageSource == 'cv'
                    ? 'Status overridden by photo verification'
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
