// lib/features/marketplace/application/marketplace_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../data/marketplace_repository.dart';
import '../domain/product.dart';
import '../domain/production_plan_listing.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(ref.watch(apiClientProvider));
});

class MarketplaceFilters {
  const MarketplaceFilters({
    this.category,
    this.search,
    this.sort = 'newest',
    this.flashSaleOnly = false,
    this.minPrice,
    this.maxPrice,
    this.barangay,
  });
  final String? category;
  final String? search;
  final String sort;
  final bool flashSaleOnly;
  final double? minPrice;
  final double? maxPrice;
  final String? barangay;

  MarketplaceFilters copyWith(
          {String? category,
          String? search,
          String? sort,
          bool? flashSaleOnly}) =>
      MarketplaceFilters(
        category: category ?? this.category,
        search: search ?? this.search,
        sort: sort ?? this.sort,
        flashSaleOnly: flashSaleOnly ?? this.flashSaleOnly,
        minPrice: minPrice,
        maxPrice: maxPrice,
        barangay: barangay,
      );

  /// Deliberately separate from copyWith: standard copyWith's `?? this.x`
  /// pattern can't distinguish "field not touched" from "field
  /// explicitly cleared to null" for nullable fields — both look
  /// identical (nothing passed). This constructs price/barangay
  /// filters directly instead, so a user clearing a price field in
  /// the filter sheet genuinely clears it, rather than silently
  /// keeping the old value.
  MarketplaceFilters withPriceAndLocation(
          {double? minPrice, double? maxPrice, String? barangay}) =>
      MarketplaceFilters(
        category: category,
        search: search,
        sort: sort,
        flashSaleOnly: flashSaleOnly,
        minPrice: minPrice,
        maxPrice: maxPrice,
        barangay: barangay,
      );
}

final marketplaceFiltersProvider =
    StateProvider<MarketplaceFilters>((ref) => const MarketplaceFilters());

final marketplaceProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final filters = ref.watch(marketplaceFiltersProvider);
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.getProducts(
    category: filters.category,
    search: filters.search,
    sort: filters.sort,
    flashSaleOnly: filters.flashSaleOnly,
    minPrice: filters.minPrice,
    maxPrice: filters.maxPrice,
    barangay: filters.barangay,
  );
});

final productDetailProvider =
    FutureProvider.autoDispose.family<Product, String>((ref, id) async {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.getProductDetail(id);
});

/// UW 3/5.1: which of the two marketplace views is currently shown --
/// "the default Crop Listings view," switched to the "Production
/// Plans" view. Lives alongside marketplaceFiltersProvider since both
/// are marketplace-screen-level UI state, not feature-specific.
final marketplaceViewProvider =
    StateProvider.autoDispose<MarketplaceView>((ref) => MarketplaceView.cropListings);

enum MarketplaceView { cropListings, productionPlans }

final productionPlansProvider =
    FutureProvider.autoDispose<List<ProductionPlanListing>>((ref) async {
  final filters = ref.watch(marketplaceFiltersProvider);
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.getProductionPlans(
    category: filters.category,
    search: filters.search,
    barangay: filters.barangay,
  );
});
