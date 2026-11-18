// lib/features/farmers/domain/farmer_summary.dart
// Fields verified against the real GET /profiles/farmers and
// GET /profiles/farmers/:id queries this session.

class FarmerProductSummary {
  const FarmerProductSummary({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.pricePerUnit,
    required this.stockQty,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final double pricePerUnit;
  final double stockQty;
  final String? imageUrl;

  factory FarmerProductSummary.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return FarmerProductSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      unit: json['unit'] as String,
      pricePerUnit: asDouble(json['price_per_unit']),
      stockQty: asDouble(json['stock_qty']),
      imageUrl: json['image_url'] as String?,
    );
  }
}

/// An open (not yet 'done'-stage) production plan a buyer can request a
/// Smart Agreement against (UW 4.1/5.1). Added to GET
/// /profiles/farmers/:id this session, since /api/production itself is
/// farmer/vendor-only and self-scoped — buyers had no endpoint at all to
/// discover these before. availableQuantity is informational only; the
/// real, locked check happens server-side on request/accept.
class FarmerCropPlanSummary {
  const FarmerCropPlanSummary({
    required this.id,
    required this.cropName,
    required this.category,
    required this.quantityKg,
    required this.availableQuantity,
    required this.unit,
    required this.pricePerUnit,
    required this.expectedHarvest,
    this.fieldLocation,
    this.barangay,
    this.imageUrl,
  });

  final String id;
  final String cropName;
  final String category;
  final double quantityKg;
  final double availableQuantity;
  final String unit;
  final double pricePerUnit;
  final DateTime expectedHarvest;
  final String? fieldLocation;
  final String? barangay;
  final String? imageUrl;

  factory FarmerCropPlanSummary.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return FarmerCropPlanSummary(
      id: json['id'] as String,
      cropName: json['crop_name'] as String,
      category: json['category'] as String,
      quantityKg: asDouble(json['quantity_kg']),
      availableQuantity: asDouble(json['available_quantity']),
      unit: json['unit'] as String,
      pricePerUnit: asDouble(json['price_per_unit']),
      expectedHarvest: DateTime.parse(json['expected_harvest']),
      fieldLocation: json['field_location'] as String?,
      barangay: json['barangay'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class FarmerSummary {
  const FarmerSummary({
    required this.id,
    required this.fullName,
    this.barangay,
    this.farmName,
    this.farmPhotoUrl,
    this.aboutFarm,
    this.productCount,
    this.phoneNumber,
    this.farmAddress,
    this.avatarUrl,
    this.createdAt,
    this.isVerified = false,
    this.products = const [],
    this.cropPlans = const [],
  });

  final String id;
  final String fullName;
  final String? barangay;
  final String? farmName;
  final String? farmPhotoUrl;
  final String? aboutFarm;
  final int? productCount;
  final String? phoneNumber; // detail-endpoint only
  final String? farmAddress; // detail-endpoint only

  /// UW 12.3: "Verification badge, if identity-verified" / "Date joined
  /// the platform" -- detail-endpoint only, same as the fields above.
  final String? avatarUrl;
  final DateTime? createdAt;
  final bool isVerified;
  /// Only populated by GET /profiles/farmers/:id (the detail
  /// endpoint) — always empty for the list endpoint, which doesn't
  /// return this at all.
  final List<FarmerProductSummary> products;

  /// Same detail-endpoint-only restriction as [products].
  final List<FarmerCropPlanSummary> cropPlans;

  String get displayName => farmName ?? fullName;

  factory FarmerSummary.fromJson(Map<String, dynamic> json) => FarmerSummary(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        barangay: json['barangay'] as String?,
        farmName: json['farm_name'] as String?,
        farmPhotoUrl: json['farm_photo_url'] as String?,
        aboutFarm: json['about_farm'] as String?,
        productCount: json['product_count'] != null
            ? int.tryParse(json['product_count'].toString())
            : null,
        phoneNumber: json['phone_number'] as String?,
        farmAddress: json['farm_address'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        isVerified: json['is_verified'] as bool? ?? false,
        products: (json['products'] as List? ?? [])
            .map((p) => FarmerProductSummary.fromJson(p))
            .toList(),
        cropPlans: (json['crop_plans'] as List? ?? [])
            .map((p) => FarmerCropPlanSummary.fromJson(p))
            .toList(),
      );
}
