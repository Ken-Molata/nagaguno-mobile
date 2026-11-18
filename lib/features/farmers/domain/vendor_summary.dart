// lib/features/farmers/domain/vendor_summary.dart
//
// Mirrors farmer_summary.dart. UW 5's Actor line covers both: "Farmer
// or Vendor (creating the plan)" -- a Vendor can own production plans
// exactly like a Farmer can, but there was no public vendor browse
// path anywhere in this app before this. Lives under features/farmers
// rather than a new top-level features/vendors module since it's the
// same browse-a-seller concept the Farmers feature already models,
// just for the other seller role; a separate module would just
// duplicate this file for no real difference.

class VendorProductSummary {
  const VendorProductSummary({
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

  factory VendorProductSummary.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return VendorProductSummary(
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

/// Same shape as FarmerCropPlanSummary — see that file's comment for
/// why availableQuantity is informational only.
class VendorCropPlanSummary {
  const VendorCropPlanSummary({
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

  factory VendorCropPlanSummary.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return VendorCropPlanSummary(
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

class VendorSummary {
  const VendorSummary({
    required this.id,
    required this.fullName,
    this.barangay,
    this.businessName,
    this.businessPhotoUrl,
    this.aboutBusiness,
    this.productCount,
    this.phoneNumber,
    this.businessAddress,
    this.avatarUrl,
    this.createdAt,
    this.isVerified = false,
    this.products = const [],
    this.cropPlans = const [],
  });

  final String id;
  final String fullName;
  final String? barangay;
  final String? businessName;
  final String? businessPhotoUrl;
  final String? aboutBusiness;
  final int? productCount;
  final String? phoneNumber; // detail-endpoint only
  final String? businessAddress; // detail-endpoint only

  /// UW 12.3: "Verification badge, if identity-verified" / "Date joined
  /// the platform" -- detail-endpoint only, same as the fields above.
  final String? avatarUrl;
  final DateTime? createdAt;
  final bool isVerified;
  /// Only populated by GET /profiles/vendors/:id (the detail
  /// endpoint) — always empty for the list endpoint.
  final List<VendorProductSummary> products;

  /// Same detail-endpoint-only restriction as [products].
  final List<VendorCropPlanSummary> cropPlans;

  String get displayName => businessName ?? fullName;

  factory VendorSummary.fromJson(Map<String, dynamic> json) => VendorSummary(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        barangay: json['barangay'] as String?,
        businessName: json['business_name'] as String?,
        businessPhotoUrl: json['business_photo_url'] as String?,
        aboutBusiness: json['about_business'] as String?,
        productCount: json['product_count'] != null
            ? int.tryParse(json['product_count'].toString())
            : null,
        phoneNumber: json['phone_number'] as String?,
        businessAddress: json['business_address'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        isVerified: json['is_verified'] as bool? ?? false,
        products: (json['products'] as List? ?? [])
            .map((p) => VendorProductSummary.fromJson(p))
            .toList(),
        cropPlans: (json['crop_plans'] as List? ?? [])
            .map((p) => VendorCropPlanSummary.fromJson(p))
            .toList(),
      );
}
