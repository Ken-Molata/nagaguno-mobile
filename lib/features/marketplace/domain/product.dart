// lib/features/marketplace/domain/product.dart
//
// Every field verified against the real GET /marketplace/products and
// GET /marketplace/products/:id queries this session — including the
// LEFT JOIN LATERAL flash-sale fields and the product_spoilage_status
// view fields, which only appear if a spoilage record/accepted
// recommendation exists (hence all nullable).

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.pricePerUnit,
    required this.sellerId,
    required this.sellerRole,
    required this.sellerName,
    this.description,
    this.stockQty,
    this.imageUrl,
    this.barangay,
    this.sellerBarangay,
    this.farmName,
    this.farmPhotoUrl,
    this.businessName,
    this.businessPhotoUrl,
    this.spoilageStage,
    this.spoilageRemainingPct,
    this.flashSaleOriginalPrice,
    this.flashSaleDiscountPct,
    this.flashSaleSource,
    this.sellerPhone,
    this.aboutFarm,
    this.aboutBusiness,
    this.sellerRating,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final double pricePerUnit;
  final String sellerId;
  final String sellerRole; // 'farmer' | 'vendor'
  final String sellerName;
  final String? description;
  final int? stockQty;
  final String? imageUrl;
  final String? barangay;
  final String? sellerBarangay;
  final String? farmName;
  final String? farmPhotoUrl;
  final String? businessName;
  final String? businessPhotoUrl;

  /// 'fresh' | 'near_spoilage' | 'critical' | 'expired' | null (null
  /// when the product isn't marked is_perishable, or has no spoilage
  /// record at all — see the product_spoilage_status view definition
  /// verified this session).
  final String? spoilageStage;
  final double? spoilageRemainingPct;

  /// All three null together when there's no accepted discount —
  /// present together when there is (either seller-initiated flash
  /// sale or an accepted system spoilage recommendation).
  final double? flashSaleOriginalPrice;
  final double? flashSaleDiscountPct;
  final String? flashSaleSource; // 'seller' | 'system'

  // Product-detail-only fields (not present on the marketplace list query)
  final String? sellerPhone;
  final String? aboutFarm;
  final String? aboutBusiness;

  /// UW 12.1/12.5: "Seller's current rating," shown on every product
  /// card and the seller inline preview. Null when the seller has no
  /// reviews yet, same as every other "no reviews yet" average in this
  /// app (not forced to 0).
  final double? sellerRating;

  bool get hasActiveDiscount => flashSaleOriginalPrice != null;

  /// flashSaleDiscountPct is a FRACTION (0.30 for 30% off), not a
  /// percentage number (30) -- verified directly against the real
  /// backend: routes/marketplace.js selects spr.recommended_discount_pct
  /// with no transformation, and it's stored/inserted as a fraction in
  /// routes/spoilage.js (e.g. `const discount = 0.30`). This was
  /// genuinely wrong in an earlier version of this getter (divided by
  /// 100 as if it were a percentage number, which would have applied
  /// essentially no discount at all for any real value) -- fixed here,
  /// not assumed correct.
  double get displayPrice => hasActiveDiscount
      ? pricePerUnit * (1 - (flashSaleDiscountPct ?? 0))
      : pricePerUnit;

  String get displaySellerName => farmName ?? businessName ?? sellerName;

  String? get displaySellerPhoto => farmPhotoUrl ?? businessPhotoUrl;

  factory Product.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());
    // REAL BUG FOUND AND FIXED: stock_qty is a Postgres NUMERIC column,
    // which (like price_per_unit and every other NUMERIC field this
    // file already parses with asDouble) arrives as a decimal string/
    // number such as "44.00", never a clean int -- `as int?` threw for
    // every real product, crashing the entire marketplace list.
    // double.tryParse first, then truncate, so "44.00" parses correctly
    // instead of failing int.tryParse's stricter format.
    int? asInt(dynamic v) =>
        v == null ? null : double.tryParse(v.toString())?.toInt();
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      unit: json['unit'] as String,
      pricePerUnit: asDouble(json['price_per_unit']) ?? 0,
      sellerId: json['seller_id'] as String,
      sellerRole: json['seller_role'] as String,
      sellerName: json['seller_name'] as String,
      description: json['description'] as String?,
      stockQty: asInt(json['stock_qty']),
      imageUrl: json['image_url'] as String?,
      barangay: json['barangay'] as String?,
      sellerBarangay: json['seller_barangay'] as String?,
      farmName: json['farm_name'] as String?,
      farmPhotoUrl: json['farm_photo_url'] as String?,
      businessName: json['business_name'] as String?,
      businessPhotoUrl: json['business_photo_url'] as String?,
      spoilageStage: json['spoilage_stage'] as String?,
      spoilageRemainingPct: asDouble(json['spoilage_remaining_pct']),
      flashSaleOriginalPrice:
          asDouble(json['flash_sale_original_price'] ?? json['original_price']),
      flashSaleDiscountPct: asDouble(
          json['flash_sale_discount_pct'] ?? json['recommended_discount_pct']),
      flashSaleSource:
          json['flash_sale_source'] as String? ?? json['source'] as String?,
      sellerPhone: json['seller_phone'] as String?,
      aboutFarm: json['about_farm'] as String?,
      aboutBusiness: json['about_business'] as String?,
      sellerRating: asDouble(json['seller_rating']),
    );
  }
}
