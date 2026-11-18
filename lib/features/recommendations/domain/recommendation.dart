// lib/features/recommendations/domain/recommendation.dart
//
// Re-verified against the real GET /recommendations and GET
// /recommendations/farmers (routes/recommendation.js) after this
// session's security rewrite of that file. The old POST /recommendations/
// all response this was built against no longer exists — buyer_id in
// the request body was a real vulnerability (anyone could pass an
// arbitrary buyer_id and get that buyer's history-based results back),
// fixed by removing it and the endpoint entirely in favor of two plain
// GET endpoints driven by the authenticated session only.

class RecommendedProduct {
  const RecommendedProduct({
    required this.productId,
    required this.productName,
    required this.category,
    required this.unit,
    required this.pricePhp,
    required this.stockQty,
    required this.sellerName,
    required this.rating,
    required this.recommendationScore,
    required this.recommendationReason,
    this.imageUrl,
  });

  final String productId;
  final String productName;
  final String category;
  final String unit;
  final double pricePhp;
  final double stockQty;
  final String sellerName;
  final double rating;
  final double recommendationScore; // 0.0 - 1.0
  final String recommendationReason;
  final String? imageUrl;
  // No total_orders/buyer_count field exists on the real response at
  // all (verified this session) — dropped rather than kept as a field
  // that would always silently read as 0.

  factory RecommendedProduct.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return RecommendedProduct(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      category: json['category'] as String,
      unit: json['unit'] as String,
      pricePhp: asDouble(json['price_php']),
      stockQty: asDouble(json['stock_qty']),
      sellerName: json['seller_name'] as String,
      rating: asDouble(json['rating']),
      recommendationScore: asDouble(json['recommendation_score']),
      recommendationReason: json['recommendation_reason'] as String,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class RecommendedFarmer {
  const RecommendedFarmer({
    required this.farmerId,
    required this.name,
    required this.specializations,
    required this.rating,
    required this.liveListings,
    required this.recommendationReason,
    this.barangay,
    this.farmName,
  });

  final String farmerId;
  final String name;

  /// Always false — GET /recommendations/farmers has no is_verified
  /// field in its response at all (verified this session). Kept as a
  /// real field rather than removed, since it's a genuine account
  /// property the backend could add later; just never true today.
  bool get isVerified => false;
  final List<String> specializations;
  final double rating;
  final int liveListings;
  final String recommendationReason;
  final String? barangay;
  final String? farmName;

  String get displayName => farmName ?? name;

  factory RecommendedFarmer.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return RecommendedFarmer(
      farmerId: json['farmer_id'] as String,
      name: json['name'] as String,
      specializations: (json['specializations'] as List? ?? []).cast<String>(),
      rating: asDouble(json['rating']),
      liveListings: int.tryParse(json['live_listings'].toString()) ?? 0,
      recommendationReason: json['recommendation_reason'] as String,
      barangay: json['barangay'] as String?,
      farmName: json['farm_name'] as String?,
    );
  }
}

/// GET /recommendations/similar/:product_id -- a different shape than
/// RecommendedProduct (no seller_name/rating/recommendation_score at
/// all, verified against the real SQL in both the item_cf and
/// category_popularity_fallback branches). similarity/coBuyers are
/// only ever present on the item_cf branch; totalQuantitySold only on
/// the fallback branch -- both nullable rather than defaulted to 0, so
/// a missing value never gets displayed as a fabricated real one.
class SimilarProduct {
  const SimilarProduct({
    required this.productId,
    required this.productName,
    required this.category,
    required this.unit,
    required this.pricePhp,
    required this.stockQty,
    this.imageUrl,
    this.similarity,
    this.coBuyers,
    this.totalQuantitySold,
  });

  final String productId;
  final String productName;
  final String category;
  final String unit;
  final double pricePhp;
  final double stockQty;
  final String? imageUrl;
  final double? similarity;
  final int? coBuyers;
  final int? totalQuantitySold;

  factory SimilarProduct.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return SimilarProduct(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      category: json['category'] as String,
      unit: json['unit'] as String,
      pricePhp: asDouble(json['price_php']),
      stockQty: asDouble(json['stock_qty']),
      imageUrl: json['image_url'] as String?,
      similarity:
          json['similarity'] == null ? null : asDouble(json['similarity']),
      coBuyers: json['co_buyers'] == null
          ? null
          : int.tryParse(json['co_buyers'].toString()),
      totalQuantitySold: json['total_quantity_sold'] == null
          ? null
          : int.tryParse(json['total_quantity_sold'].toString()),
    );
  }
}

class RecommendationsResult {
  const RecommendationsResult({
    required this.products,
    required this.farmers,
    required this.preferredCategories,
    required this.isNewBuyer,
  });

  final List<RecommendedProduct> products;
  final List<RecommendedFarmer> farmers;
  final List<String> preferredCategories;

  /// Drives the method badge: "Content-Based Filtering" for a
  /// genuinely new buyer with no purchase history to personalize
  /// against yet, vs. "Hybrid" once there's real history to blend in.
  /// Only GET /recommendations (products) returns this -- the farmers
  /// endpoint has no equivalent, so this reflects the products side.
  final bool isNewBuyer;

  factory RecommendationsResult.fromProductsAndFarmers(
    Map<String, dynamic> productsJson,
    List<dynamic> farmersJson,
  ) =>
      RecommendationsResult(
        products: (productsJson['products'] as List? ?? [])
            .map((p) => RecommendedProduct.fromJson(p))
            .toList(),
        farmers: farmersJson.map((f) => RecommendedFarmer.fromJson(f)).toList(),
        preferredCategories:
            (productsJson['preferred_categories'] as List? ?? [])
                .cast<String>(),
        isNewBuyer: productsJson['is_new_buyer'] as bool? ?? true,
      );
}
