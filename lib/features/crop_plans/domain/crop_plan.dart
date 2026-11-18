// lib/features/crop_plans/domain/crop_plan.dart
//
// Fields verified directly against routes/cropPlans.js (mounted at
// /api/production) and the real crop_plans.stage enum this session.

enum CropStage { planted, growing, harvesting, done }

class CropPlan {
  const CropPlan({
    required this.id,
    required this.cropName,
    required this.category,
    required this.quantityKg,
    required this.unit,
    required this.pricePerUnit,
    required this.fieldLocation,
    required this.plantingDate,
    required this.expectedHarvest,
    required this.stage,
    this.notes,
    this.imageUrl,
    this.barangay,
    this.daysRemaining,
    this.remainingQuantity,
  });

  final String id;
  final String cropName;
  final String category;
  final double quantityKg;
  final String unit;

  /// UW 5: "Price per unit" is a field the plan is created with, and
  /// UW 5.1 says the agreement request form pre-fills from it — added
  /// to the backend this session (POST /production now requires it)
  /// but never added here, so every plan creation 400'd on
  /// "price_per_unit... required" until this.
  final double pricePerUnit;
  final String fieldLocation;
  final DateTime plantingDate;
  final DateTime expectedHarvest;
  final CropStage stage;
  final String? notes;
  final String? imageUrl;
  final String? barangay;

  /// Only present on the GET / (list) query, which computes it via
  /// (expected_harvest - CURRENT_DATE) — not present on a raw
  /// INSERT/UPDATE RETURNING row.
  final int? daysRemaining;

  /// The "remaining unlisted quantity" ledger: quantityKg minus
  /// whatever's already been carved into listings via "Create Listing
  /// from Plan" (routes/products.js's POST /from-plan/:planId), floored
  /// at 0. Same as daysRemaining, only present on the GET / (list)
  /// query, not on a raw INSERT/UPDATE RETURNING row.
  final double? remainingQuantity;

  factory CropPlan.fromJson(Map<String, dynamic> json) {
    return CropPlan(
      id: json['id'] as String,
      cropName: json['crop_name'] as String,
      category: json['category'] as String,
      quantityKg: double.tryParse(json['quantity_kg'].toString()) ?? 0,
      unit: json['unit'] as String,
      pricePerUnit: double.tryParse(json['price_per_unit'].toString()) ?? 0,
      fieldLocation: json['field_location'] as String,
      plantingDate: DateTime.parse(json['planting_date']),
      expectedHarvest: DateTime.parse(json['expected_harvest']),
      stage: CropStage.values.firstWhere((s) => s.name == json['stage'],
          orElse: () => CropStage.planted),
      notes: json['notes'] as String?,
      imageUrl: json['image_url'] as String?,
      barangay: json['barangay'] as String?,
      daysRemaining: json['days_remaining'] != null
          ? int.tryParse(json['days_remaining'].toString())
          : null,
      remainingQuantity: json['remaining_quantity'] != null
          ? double.tryParse(json['remaining_quantity'].toString())
          : null,
    );
  }
}
