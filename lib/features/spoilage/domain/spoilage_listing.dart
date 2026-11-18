// lib/features/spoilage/domain/spoilage_listing.dart
//
// Fields verified against the real product_spoilage_status view
// definition (fetched live this session) and the GET /spoilage/
// my-listings route's own shape (view row + nested `recommendation`
// object). remaining_pct is a fraction (0-1), same convention as
// discount_pct — a real bug earlier this session came from conflating
// this exact kind of fraction-vs-percentage field, so it's called out
// explicitly here too.

class SpoilageRecommendation {
  const SpoilageRecommendation({
    required this.id,
    required this.stage,
    required this.originalPrice,
    required this.recommendedDiscountPct, // fraction, e.g. 0.30
    required this.recommendedPrice,
    required this.source, // 'system' | 'seller'
  });

  final String id;
  final String stage;
  final double originalPrice;
  final double recommendedDiscountPct;
  final double recommendedPrice;
  final String source;

  factory SpoilageRecommendation.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return SpoilageRecommendation(
      id: json['id'] as String,
      stage: json['stage'] as String,
      originalPrice: asDouble(json['original_price']),
      recommendedDiscountPct: asDouble(json['recommended_discount_pct']),
      recommendedPrice: asDouble(json['recommended_price']),
      source: json['source'] as String,
    );
  }
}

/// UW 3.5's seller-initiated discount (richer than the system
/// recommendation above: a 1-50 whole-number percent, until-removed or
/// a date-bounded window, an optional minimum order quantity, and a
/// label). Added to GET /spoilage/my-listings this session — the
/// underlying product_spoilage_status view has no seller_discount_*
/// columns at all, so this is joined in separately by the route.
class ActiveSellerDiscount {
  const ActiveSellerDiscount({
    required this.discountPct,
    required this.active,
    this.minOrderQty,
    this.label,
    this.startDate,
    this.endDate,
  });

  /// A fraction (0-1) on the wire — convert ×100 for display, same
  /// convention as [SpoilageRecommendation.recommendedDiscountPct].
  final double discountPct;
  final bool active;
  final double? minOrderQty;
  final String?
      label; // seller_discount | bulk_discount | harvest_sale | clearance
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isSetPeriod => startDate != null && endDate != null;

  factory ActiveSellerDiscount.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());
    DateTime? asDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return ActiveSellerDiscount(
      discountPct: asDouble(json['seller_discount_pct']) ?? 0,
      active: json['seller_discount_active'] as bool? ?? false,
      minOrderQty: asDouble(json['seller_discount_min_order_qty']),
      label: json['seller_discount_label'] as String?,
      startDate: asDate(json['seller_discount_start_date']),
      endDate: asDate(json['seller_discount_end_date']),
    );
  }
}

class SpoilageListing {
  const SpoilageListing({
    required this.productId,
    required this.name,
    required this.category,
    required this.remainingPct,
    required this.isManuallyReported,
    this.stage,
    this.daysElapsed,
    this.shelfLifeDays,
    this.recommendation,
    this.sellerDiscount,
  });

  final String productId;
  final String name;
  final String category;

  /// A fraction (0-1), NOT a percentage number — same real convention
  /// as discount_pct elsewhere in this app.
  final double remainingPct;
  final bool isManuallyReported;

  /// 'fresh' | 'near_spoilage' | 'critical' | 'expired' | null (null
  /// only if shelf_life_days couldn't be resolved for this category —
  /// see the view definition's own NULL branch).
  final String? stage;
  final int? daysElapsed;
  final int? shelfLifeDays;
  final SpoilageRecommendation? recommendation;
  final ActiveSellerDiscount? sellerDiscount;

  bool get hasActiveSellerDiscount => sellerDiscount?.active == true;

  factory SpoilageListing.fromJson(Map<String, dynamic> json) {
    return SpoilageListing(
      productId: json['product_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      remainingPct: double.tryParse(json['remaining_pct'].toString()) ?? 0,
      isManuallyReported: json['is_manually_reported'] as bool? ?? false,
      stage: json['stage'] as String?,
      daysElapsed: json['days_elapsed'] != null
          ? int.tryParse(json['days_elapsed'].toString())
          : null,
      shelfLifeDays: json['shelf_life_days'] != null
          ? int.tryParse(json['shelf_life_days'].toString())
          : null,
      recommendation: json['recommendation'] != null
          ? SpoilageRecommendation.fromJson(json['recommendation'])
          : null,
      sellerDiscount: json['seller_discount'] != null
          ? ActiveSellerDiscount.fromJson(json['seller_discount'])
          : null,
    );
  }
}
