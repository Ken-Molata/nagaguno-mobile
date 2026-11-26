// lib/features/products/domain/my_product.dart
//
// Shape verified against the real GET /products (own-listings) query
// this session — deliberately simpler/fewer fields than the
// marketplace Product model, since this is the seller's own
// management view, not the public browsing shape.

class MyProduct {
  const MyProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.pricePerUnit,
    required this.stockQty,
    required this.status,
    required this.createdAt,
    required this.harvestedAt,
    this.description,
    this.imageUrl,
    this.barangay,
    this.storageCondition,
    this.shelfLifeDays,
    this.autoDiscountPct,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final double pricePerUnit;
  final double stockQty;
  final String
      status; // 'live' | 'hidden' | 'deleted' (deleted never returned by GET /, filtered server-side)
  final DateTime createdAt;

  /// Required on creation server-side ("Harvest date is required.",
  /// re-verified this session) — was missing from this model and the
  /// create/edit screen entirely, so every product creation 400'd.
  final DateTime harvestedAt;
  final String? description;
  final String? imageUrl;
  final String? barangay;
  final String? storageCondition; // 'room_temperature' | 'refrigerated'
  final int? shelfLifeDays;
  /// Already returned by GET / (routes/products.js) but never parsed
  /// here before -- needed so add_edit_product_screen.dart can lock
  /// the price field while the automatic spoilage discount (Part I of
  /// the project documentation) is currently active, instead of
  /// letting a seller quietly raise listed_price to cancel out its
  /// real economic effect while the "% off" badge still shows.
  final double? autoDiscountPct;

  bool get isLive => status == 'live';
  bool get hasActiveAutoDiscount => (autoDiscountPct ?? 0) > 0;

  factory MyProduct.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return MyProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      unit: json['unit'] as String,
      pricePerUnit: asDouble(json['price_per_unit']),
      stockQty: asDouble(json['stock_qty']),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at']),
      harvestedAt: DateTime.parse(json['harvested_at']),
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      barangay: json['barangay'] as String?,
      storageCondition: json['storage_condition'] as String?,
      shelfLifeDays: json['shelf_life_days'] != null
          ? int.tryParse(json['shelf_life_days'].toString())
          : null,
      autoDiscountPct: json['auto_discount_pct'] != null
          ? double.tryParse(json['auto_discount_pct'].toString())
          : null,
    );
  }
}
