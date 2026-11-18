// lib/features/marketplace/domain/production_plan_listing.dart
//
// UW 5.1: the marketplace's "Production Plans" view -- a crop that is
// planted or still growing, open to Smart Agreement requests (Section
// 4), distinct from an already-harvested crop listing (Product). Field
// shape mirrors GET /profiles/farmers/:id's crop_plans sub-array
// exactly (same columns), since this market-wide endpoint
// (GET /marketplace/production-plans) reuses that same SELECT.

class ProductionPlanListing {
  const ProductionPlanListing({
    required this.id,
    required this.cropName,
    required this.category,
    required this.quantityKg,
    required this.unit,
    required this.availableQuantity,
    required this.expectedHarvest,
    required this.sellerId,
    required this.sellerRole,
    required this.sellerName,
    this.pricePerUnit,
    this.fieldLocation,
    this.imageUrl,
    this.sellerBarangay,
    this.farmName,
    this.farmPhotoUrl,
    this.businessName,
    this.businessPhotoUrl,
    this.sellerRating,
  });

  final String id;
  final String cropName;
  final String category;
  final double quantityKg;
  final String unit;

  /// quantityKg minus whatever's already committed to Active
  /// agreements -- the quantity actually still requestable.
  final double availableQuantity;
  final DateTime expectedHarvest;
  final String sellerId;
  final String sellerRole; // 'farmer' | 'vendor'
  final String sellerName;
  final double? pricePerUnit;
  final String? fieldLocation;
  final String? imageUrl;
  final String? sellerBarangay;
  final String? farmName;
  final String? farmPhotoUrl;
  final String? businessName;
  final String? businessPhotoUrl;

  /// UW 12.1: "Seller's current rating" -- null when the seller has no
  /// reviews yet.
  final double? sellerRating;

  String get displaySellerName => farmName ?? businessName ?? sellerName;
  String? get displaySellerPhoto => farmPhotoUrl ?? businessPhotoUrl;

  factory ProductionPlanListing.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());
    return ProductionPlanListing(
      id: json['id'] as String,
      cropName: json['crop_name'] as String,
      category: json['category'] as String,
      quantityKg: asDouble(json['quantity_kg']) ?? 0,
      unit: json['unit'] as String,
      availableQuantity: asDouble(json['available_quantity']) ?? 0,
      expectedHarvest: DateTime.parse(json['expected_harvest']),
      sellerId: json['seller_id'] as String,
      sellerRole: json['seller_role'] as String,
      sellerName: json['seller_name'] as String,
      pricePerUnit: asDouble(json['price_per_unit']),
      fieldLocation: json['field_location'] as String?,
      imageUrl: json['image_url'] as String?,
      sellerBarangay: json['seller_barangay'] as String?,
      farmName: json['farm_name'] as String?,
      farmPhotoUrl: json['farm_photo_url'] as String?,
      businessName: json['business_name'] as String?,
      businessPhotoUrl: json['business_photo_url'] as String?,
      sellerRating: asDouble(json['seller_rating']),
    );
  }
}
