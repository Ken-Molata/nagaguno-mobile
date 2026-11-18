// lib/features/products/presentation/my_products_screen.dart
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
import '../../payment_methods/presentation/payment_methods_screen.dart';
import '../data/my_products_repository.dart';
import '../domain/my_product.dart';
import 'add_edit_product_screen.dart';

final myProductsRepositoryProvider = Provider<MyProductsRepository>(
    (ref) => MyProductsRepository(ref.watch(apiClientProvider)));

final myProductsProvider =
    FutureProvider.autoDispose<List<MyProduct>>((ref) async {
  return ref.watch(myProductsRepositoryProvider).getMyProducts();
});

/// Client-side filter, not a server-side one, deliberately: unlike
/// Orders/Agreements (which can genuinely grow large and benefit from
/// server-side filtering), a seller's own catalog is typically small,
/// and filtering the one already-fetched list locally means the stat
/// cards can double as instant, always-accurate filter buttons
/// without a second network round-trip every time the filter changes.
final _statusFilterProvider = StateProvider<String?>((ref) => null);

class MyProductsScreen extends ConsumerWidget {
  const MyProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(myProductsProvider);
    final statusFilter = ref.watch(_statusFilterProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.myProductsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.eco_outlined),
            tooltip: s.spoilageMonitoringTooltip,
            onPressed: () => context.push('/my-products/spoilage'),
          ),
        ],
      ),
      floatingActionButton: LockedButton(
        label: s.addProductLabel,
        onPressed: () async {
          await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddEditProductScreen()));
          ref.invalidate(myProductsProvider);
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VerificationBanner(),
            const _NoPaymentMethodBanner(),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.couldntLoadProducts),
                      const SizedBox(height: AppSpacing.sm),
                      ElevatedButton(
                          onPressed: () => ref.invalidate(myProductsProvider),
                          child: Text(s.retry)),
                    ],
                  ),
                ),
                data: (products) {
                  if (products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(s.noProductsAddedYetTapAddProduct,
                            textAlign: TextAlign.center),
                      ),
                    );
                  }
                  final liveCount = products.where((p) => p.isLive).length;
                  final hiddenCount = products.length - liveCount;
                  final displayedProducts = switch (statusFilter) {
                    'live' => products.where((p) => p.isLive).toList(),
                    'hidden' => products.where((p) => !p.isLive).toList(),
                    _ => products,
                  };
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(myProductsProvider.future),
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        // REAL GAP FOUND AND FIXED: this row still used
                        // the bordered, colored-box "bento" card style
                        // (_StatCard below) with AppTypography.display's
                        // curvy Fraunces face for the numbers -- the
                        // exact treatment already deliberately removed
                        // from Home's own stat cluster (see
                        // home_screen.dart's _StatsRow/_StatCell: "no
                        // card/border/background tile at all... a
                        // dashboard stat number reads better as a crisp
                        // sans figure than a curvy serif one"). Matched
                        // to that same established pattern here instead
                        // of leaving one inconsistent screen behind.
                        _StatsRow(
                          stats: [
                            (s.totalLabel, '${products.length}', null),
                            (s.liveLabel, '$liveCount', 'live'),
                            (s.hiddenLabel, '$hiddenCount', 'hidden'),
                          ],
                          selectedFilter: statusFilter,
                          onSelect: (filter) => ref
                              .read(_statusFilterProvider.notifier)
                              .state = filter,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (displayedProducts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.lg),
                            child: Text(
                                s.noProductsWithFilter(statusFilter ?? ''),
                                textAlign: TextAlign.center),
                          )
                        else
                          ...displayedProducts
                              .map((p) => _ProductListTile(product: p)),
                        const SizedBox(height: 80), // clearance for the FAB
                      ],
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

// UW 21.9: "Payment details: a banner on a Farmer's or Vendor's own
// listings when no method is on file, 'Add a payment method to let
// buyers pay by Manual Transfer'... Both open Section 21.3." Reuses
// the same list provider payment_methods_screen.dart's own screen
// fetches from -- one real source of "is a payment method on file,"
// not a second, separately-fetched check. Silently absent while
// loading or on error, same "never block the real content on a
// secondary check" reasoning as the weather chip on the home screen.
class _NoPaymentMethodBanner extends ConsumerWidget {
  const _NoPaymentMethodBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(paymentMethodsListProvider);
    final hasNone = methodsAsync.valueOrNull?.isEmpty ?? false;
    if (!hasNone) return const SizedBox.shrink();
    final s = ref.watch(appStringsProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
          color: AppColors.backgroundStart,
          borderRadius: BorderRadius.circular(AppRadius.md)),
      child: InkWell(
        onTap: () => context.push('/payment-methods'),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(s.addPaymentMethodBannerText,
                  style: AppTypography.bodySmall),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Unbounded stat cluster -- see this screen's own call-site comment
/// for why this replaced the bordered-box "bento" _StatCard it used
/// to be. Each tuple is (label, value, filterValue); filterValue is
/// null for the "Total" entry (clears the filter) and the status
/// string otherwise.
class _StatsRow extends StatelessWidget {
  const _StatsRow(
      {required this.stats, required this.selectedFilter, required this.onSelect});
  final List<(String, String, String?)> stats;
  final String? selectedFilter;
  final ValueChanged<String?> onSelect;

  static const _accents = [
    AppColors.accentDark,
    AppColors.secondary,
    AppColors.lightGreen,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) SizedBox(width: i.isOdd ? AppSpacing.xl : AppSpacing.lg),
          Expanded(
            flex: i == 0 ? 4 : 3,
            child: _StatCell(
              value: stats[i].$2,
              label: stats[i].$1,
              valueFontSize: i == 0 ? 30 : 23,
              color: _accents[i % _accents.length],
              selected: selectedFilter == stats[i].$3,
              onTap: () => onSelect(stats[i].$3),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.valueFontSize,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String value;
  final String label;
  final double valueFontSize;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Plain DMSans, not the Fraunces display face used for page
          // headings elsewhere -- a stat number reads better as a
          // crisp sans figure than a curvy serif one (same reasoning
          // as home_screen.dart's own _StatCell).
          Text(value,
              style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppTypography.label, maxLines: 2),
              if (selected) ...[
                const SizedBox(width: 4),
                Icon(Icons.circle, size: 6, color: color),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductListTile extends ConsumerWidget {
  const _ProductListTile({required this.product});
  final MyProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: product.imageUrl != null
                ? Image.network(product.imageUrl!,
                    width: 56, height: 56, fit: BoxFit.cover)
                : Container(
                    width: 56,
                    height: 56,
                    color: AppColors.backgroundStart,
                    child: const Icon(Icons.image_outlined)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(
                    '₱${product.pricePerUnit.toStringAsFixed(2)}/${product.unit} · ${product.stockQty.toStringAsFixed(0)} in stock',
                    style: AppTypography.bodySmall),
                Text(product.isLive ? s.liveStatusLabel : s.hiddenStatusLabel,
                    style: AppTypography.label.copyWith(
                        color: product.isLive
                            ? AppColors.statusSuccessFg
                            : AppColors.textMuted)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              final repo = ref.read(myProductsRepositoryProvider);
              try {
                if (action == 'edit') {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AddEditProductScreen(existing: product)));
                  ref.invalidate(myProductsProvider);
                } else if (action == 'toggle') {
                  await repo.toggleProduct(product.id);
                  ref.invalidate(myProductsProvider);
                } else if (action == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(s.deleteThisListingQuestion),
                      content: Text(
                          s.productWillBeRemovedCantUndo(product.name)),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: Text(s.cancel)),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(s.deleteLabel,
                              style: const TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await repo.deleteProduct(product.id);
                    ref.invalidate(myProductsProvider);
                  }
                }
              } catch (_) {
                // Previously had no error handling at all: a failed
                // toggle/delete request would throw unhandled, with
                // no feedback to the user either way.
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(s.somethingWentWrongTryAgain)));
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(s.editTooltip)),
              PopupMenuItem(
                  value: 'toggle',
                  child: Text(product.isLive ? s.hideLabel : s.showLabel)),
              PopupMenuItem(value: 'delete', child: Text(s.deleteLabel)),
            ],
          ),
        ],
      ),
    );
  }
}
