// lib/admin_web/presentation/listings/admin_listings_screen.dart
// UW 2.6 "listing moderation": every seller's listings, with the
// force-hide/restore action PATCH /admin/listings/:id already built.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;
import '../widgets/admin_decision_dialogs.dart';

final _listingsProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getAllListings());

// Same stage→color mapping spoilage_monitoring_screen.dart already
// established for this exact purpose (AppColors.spoilage* was built for
// it) -- reused here so Admin can see WHY a listing is near/past its
// shelf life before deciding to hide or restore it, not just its price
// and stock.
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

class AdminListingsScreen extends ConsumerWidget {
  const AdminListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncListings = ref.watch(_listingsProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Listings', style: AppTypography.h1),
          const SizedBox(height: 2),
          const Text('Every seller\'s product listings, with the ability to hide or restore one.',
              style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: asyncListings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Couldn\'t load listings.')),
              data: (listings) => Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: ListView.separated(
                  itemCount: listings.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, i) {
                    final l = listings[i];
                    final stageColor = _stageColor(l.spoilageStage);
                    return ListTile(
                      title: Text(l.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              '${l.sellerName} (${l.sellerRole}) · ${l.category} · ₱${l.pricePerUnit.toStringAsFixed(2)}/${l.unit} · ${l.stockQty.toStringAsFixed(0)} in stock'),
                          if (l.spoilageStage != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: stageColor,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                    l.spoilageStage!
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: AppTypography.label
                                        .copyWith(color: stageColor)),
                                if (l.shelfLifeDays != null &&
                                    l.daysElapsed != null) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                      '· day ${l.daysElapsed} of ${l.shelfLifeDays}-day shelf life',
                                      style: AppTypography.bodySmall),
                                ],
                              ],
                            ),
                          ],
                          if (l.autoHiddenReason != null) ...[
                            const SizedBox(height: 2),
                            Text('Auto-hidden: ${l.autoHiddenReason}',
                                style: AppTypography.bodySmall
                                    .copyWith(color: AppColors.spoilageExpired)),
                          ],
                        ],
                      ),
                      // REAL BUG FOUND AND FIXED: an OutlinedButton used
                      // directly as ListTile.trailing has no bounded
                      // intrinsic width in this Flutter version, which
                      // throws "Trailing widget consumes the entire
                      // tile width (including ListTile.contentPadding)"
                      // -- and since that happens mid-layout inside a
                      // ListView.separated, it doesn't just break this
                      // one tile, it cascades into render-tree
                      // assertion failures for the whole frame (caught
                      // live: even the sidebar went blank, not just this
                      // screen's content). Wrapping in a fixed-width
                      // SizedBox is the standard fix -- it's what gives
                      // ListTile the bounded width it needs from the
                      // trailing slot.
                      trailing: SizedBox(
                        width: 140,
                        child: l.status == 'hidden'
                            ? OutlinedButton(
                                onPressed: () async {
                                  await ref
                                      .read(adminRepositoryProvider)
                                      .updateListingStatus(l.id,
                                          status: 'live');
                                  ref.invalidate(_listingsProvider);
                                },
                                child: const Text('Restore'))
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error),
                                onPressed: () async {
                                  final reason = await showNoteDialog(
                                      context: context,
                                      title: 'Hide Listing',
                                      label: 'Reason');
                                  if (reason == null) return;
                                  await ref
                                      .read(adminRepositoryProvider)
                                      .updateListingStatus(l.id,
                                          status: 'hidden', reason: reason);
                                  ref.invalidate(_listingsProvider);
                                },
                                child: const Text('Hide')),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
