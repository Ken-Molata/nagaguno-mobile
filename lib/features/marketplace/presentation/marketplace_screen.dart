// lib/features/marketplace/presentation/marketplace_screen.dart
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.
// Category names (_categories, from the shared productCategories list)
// are deliberately left in English, same reasoning as
// onboarding_flow_screen.dart's category labels: those same strings
// render on listings and elsewhere not yet covered by this pass, so
// translating them only here would be a worse, inconsistent
// experience than staying in English everywhere until that whole
// surface is covered.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/product_categories.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../../shared/widgets/verification_banner.dart';
import '../../recommendations/presentation/recommendations_widget.dart';
import '../../cart/presentation/widgets/cart_icon_button.dart';
import '../../buyer_mode/presentation/widgets/buyer_mode_banner.dart';
import '../application/marketplace_providers.dart';
import 'widgets/product_card.dart';
import 'widgets/production_plan_card.dart';

// Categories matching the real, verified spoilage_category_defaults
// table values this session (§ the spoilage/flash-sale audit) — kept
// as the single source of truth for category names across the app
// rather than a separately-invented list here.
// 'All' prepended specifically for this screen's filter row -- derived
// from the shared productCategories list rather than a separately
// hardcoded copy, so it can't drift out of sync with it.
const _categories = ['All', ...productCategories];

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

void _showPriceLocationFilterSheet(
    BuildContext context, WidgetRef ref, MarketplaceFilters filters) {
  final minController =
      TextEditingController(text: filters.minPrice?.toStringAsFixed(0) ?? '');
  final maxController =
      TextEditingController(text: filters.maxPrice?.toStringAsFixed(0) ?? '');
  final barangayController =
      TextEditingController(text: filters.barangay ?? '');
  final s = ref.read(appStringsProvider);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.filtersLabel, style: AppTypography.h2),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.minPriceLabel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: maxController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.maxPriceLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
              controller: barangayController,
              decoration: InputDecoration(labelText: s.barangayLabel)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(marketplaceFiltersProvider.notifier).state =
                        filters.withPriceAndLocation(
                            minPrice: null, maxPrice: null, barangay: null);
                    Navigator.of(sheetContext).pop();
                  },
                  child: Text(s.clearLabel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(marketplaceFiltersProvider.notifier).state =
                        filters.withPriceAndLocation(
                      minPrice: double.tryParse(minController.text.trim()),
                      maxPrice: double.tryParse(maxController.text.trim()),
                      barangay: barangayController.text.trim().isEmpty
                          ? null
                          : barangayController.text.trim(),
                    );
                    Navigator.of(sheetContext).pop();
                  },
                  child: Text(s.applyLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(marketplaceFiltersProvider);
    final productsAsync = ref.watch(marketplaceProductsProvider);
    final view = ref.watch(marketplaceViewProvider);
    final isProductionPlans = view == MarketplaceView.productionPlans;
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      appBar: AppBar(
          title: Text(s.marketplaceTitle), actions: const [CartIconButton()]),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(marketplaceProductsProvider.future),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: s.searchTheMarketplaceHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: (value) {
                      ref.read(marketplaceFiltersProvider.notifier).state =
                          filters.copyWith(search: value);
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: BuyerModeBanner()),
              const SliverToBoxAdapter(child: VerificationBanner()),
              // Shown to every logged-in user on the marketplace,
              // regardless of role -- the real backend endpoint has
              // no role restriction, it only personalizes against
              // whichever user's own id is sent.
              const SliverToBoxAdapter(child: RecommendationsWidget()),
              // UW 3/5.1: "switched to from the default Crop Listings
              // view" -- the toggle into the Production Plans view.
              // Previously there was no way to reach a market-wide
              // Production Plans browse at all (a buyer could only
              // discover a plan by already knowing which farmer's
              // profile to visit first).
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: SegmentedButton<MarketplaceView>(
                    segments: [
                      ButtonSegment(
                          value: MarketplaceView.cropListings,
                          label: Text(s.cropListingsLabel)),
                      ButtonSegment(
                          value: MarketplaceView.productionPlans,
                          label: Text(s.productionPlansLabel)),
                    ],
                    selected: {view},
                    onSelectionChanged: (s) => ref
                        .read(marketplaceViewProvider.notifier)
                        .state = s.first,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, i) {
                      final cat = _categories[i];
                      final apiValue = cat == 'All' ? null : cat;
                      final selected = filters.category == apiValue ||
                          (filters.category == null && cat == 'All');
                      return ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected: (_) {
                          ref.read(marketplaceFiltersProvider.notifier).state =
                              filters.copyWith(category: apiValue);
                        },
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
              // Flash Sale / price-location filter / sort -- none of
              // these concepts apply to not-yet-harvested production
              // plans (no stock, no discount), so this row is Crop
              // Listings-only.
              if (!isProductionPlans)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(s.flashSaleLabel),
                        avatar: const Icon(Icons.local_fire_department_outlined,
                            size: 16),
                        selected: filters.flashSaleOnly,
                        onSelected: (value) {
                          ref.read(marketplaceFiltersProvider.notifier).state =
                              filters.copyWith(flashSaleOnly: value);
                        },
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showPriceLocationFilterSheet(
                            context, ref, filters),
                        icon: const Icon(Icons.tune, size: 16),
                        label: Text(
                          (filters.minPrice != null ||
                                  filters.maxPrice != null ||
                                  (filters.barangay?.isNotEmpty ?? false))
                              ? s.filtersActiveLabel
                              : s.filtersLabel,
                        ),
                      ),
                      // Real backend sort keys, verified against
                      // routes/marketplace.js's own sortMap exactly —
                      // an unrecognized value falls back to 'newest'
                      // server-side, so no client-side validation
                      // beyond sending one of these five is needed.
                      PopupMenuButton<String>(
                        initialValue: filters.sort,
                        onSelected: (value) {
                          ref.read(marketplaceFiltersProvider.notifier).state =
                              filters.copyWith(sort: value);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'newest', child: Text(s.sortNewest)),
                          PopupMenuItem(
                              value: 'price_asc',
                              child: Text(s.sortPriceAsc)),
                          PopupMenuItem(
                              value: 'price_desc',
                              child: Text(s.sortPriceDesc)),
                          PopupMenuItem(
                              value: 'stock', child: Text(s.sortStock)),
                          PopupMenuItem(
                              value: 'discount',
                              child: Text(s.sortDiscount)),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort,
                                size: 18, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(s.sortLabel, style: AppTypography.label),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
              if (isProductionPlans)
                Consumer(builder: (context, ref, _) {
                  final plansAsync = ref.watch(productionPlansProvider);
                  return plansAsync.when(
                    loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator())),
                    error: (err, _) => SliverFillRemaining(
                    hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off,
                                  size: 40, color: AppColors.textMuted),
                              const SizedBox(height: AppSpacing.sm),
                              Text(s.couldntLoadProductionPlans,
                                  textAlign: TextAlign.center),
                              const SizedBox(height: AppSpacing.sm),
                              ElevatedButton(
                                  onPressed: () =>
                                      ref.invalidate(productionPlansProvider),
                                  child: Text(s.retry)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    data: (plans) {
                      if (plans.isEmpty) {
                        return SliverFillRemaining(
                    hasScrollBody: false,
                          child: Center(
                              child: Text(s.noProductionPlansOpenForRequests)),
                        );
                      }
                      return SliverPadding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.62,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) =>
                                ProductionPlanCard(plan: plans[i]),
                            childCount: plans.length,
                          ),
                        ),
                      );
                    },
                  );
                })
              else
              productsAsync.when(
                loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator())),
                error: (err, _) => SliverFillRemaining(
                    hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off,
                              size: 40, color: AppColors.textMuted),
                          const SizedBox(height: AppSpacing.sm),
                          Text(s.couldntLoadMarketplace,
                              textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.sm),
                          ElevatedButton(
                              onPressed: () =>
                                  ref.invalidate(marketplaceProductsProvider),
                              child: Text(s.retry)),
                        ],
                      ),
                    ),
                  ),
                ),
                data: (products) {
                  if (products.isEmpty) {
                    return SliverFillRemaining(
                    hasScrollBody: false,
                      child: Center(
                          child: Text(s.noProductsFoundTryDifferent)),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        // REAL BUG FOUND AND FIXED (caught live): 0.68
                        // left every card ~8.6px short of what its own
                        // content (image + name + price row + seller
                        // row + optional barangay row) actually needs,
                        // overflowing on every real product. The sibling
                        // Production Plans grid already uses 0.62 for
                        // similarly dense cards; this card has slightly
                        // more content (an extra seller-location row),
                        // so it gets a little more headroom still.
                        childAspectRatio: 0.58,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => ProductCard(
                          product: products[i],
                          onTap: () => context
                              .push('/marketplace/product/${products[i].id}'),
                        ),
                        childCount: products.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
