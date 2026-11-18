// lib/features/marketplace/data/marketplace_repository.dart

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/product.dart';
import '../domain/production_plan_listing.dart';

class MarketplaceRepository {
  MarketplaceRepository(this._client);
  final ApiClient _client;

  Future<List<Product>> getProducts({
    String? category,
    String? search,
    String sort =
        'newest', // 'newest' | 'price_asc' | 'price_desc' | 'stock' | 'discount' — matches the real backend's sortMap exactly
    double? minPrice,
    double? maxPrice,
    String? barangay,
    bool flashSaleOnly = false,
  }) async {
    final response = await _client.dio
        .get(ApiEndpoints.marketplaceProducts, queryParameters: {
      if (category != null && category != 'all') 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      'sort': sort,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (barangay != null && barangay.isNotEmpty) 'barangay': barangay,
      if (flashSaleOnly) 'flash_sale': 'true',
    });
    return (response.data['data'] as List)
        .map((j) => Product.fromJson(j))
        .toList();
  }

  Future<List<Product>> getFlashSaleProducts({int limit = 20}) async {
    final response = await _client.dio.get(ApiEndpoints.marketplaceFlashSale,
        queryParameters: {'limit': limit});
    return (response.data['data'] as List)
        .map((j) => Product.fromJson(j))
        .toList();
  }

  Future<Product> getProductDetail(String id) async {
    final response =
        await _client.dio.get(ApiEndpoints.marketplaceProductDetail(id));
    return Product.fromJson(response.data['data']);
  }

  /// UW 5.1: the marketplace's "Production Plans" view -- market-wide,
  /// switched to from the default Crop Listings view (Section 3).
  Future<List<ProductionPlanListing>> getProductionPlans({
    String? category,
    String? search,
    String? barangay,
  }) async {
    final response = await _client.dio
        .get(ApiEndpoints.marketplaceProductionPlans, queryParameters: {
      if (category != null && category != 'all') 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      if (barangay != null && barangay.isNotEmpty) 'barangay': barangay,
    });
    return (response.data['data'] as List)
        .map((j) => ProductionPlanListing.fromJson(j))
        .toList();
  }
}
