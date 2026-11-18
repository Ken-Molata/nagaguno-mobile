// lib/features/crop_plans/data/crop_plans_repository.dart

import 'package:dio/dio.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/crop_plan.dart';

class CropPlansRepository {
  CropPlansRepository(this._client);
  final ApiClient _client;

  Future<List<CropPlan>> getCropPlans({CropStage? stage}) async {
    final response =
        await _client.dio.get(ApiEndpoints.cropPlans, queryParameters: {
      if (stage != null) 'stage': stage.name,
    });
    return (response.data['data'] as List)
        .map((j) => CropPlan.fromJson(j))
        .toList();
  }

  /// Field names match the real backend's expected body exactly:
  /// name, category, quantity, unit, price_per_unit, field_location,
  /// planting_date, expected_harvest_date, notes — note
  /// expected_harvest_date (not expected_harvest) is what the
  /// CREATE/UPDATE body uses, even though the response/DB column is
  /// expected_harvest. Barangay is never sent — the backend pulls it
  /// from the farmer's own profile.
  ///
  /// [pricePerUnit] is required server-side (re-verified this
  /// session: POST /production 400s with "price_per_unit... are
  /// required" without it) — it was missing from this call entirely,
  /// so every crop plan creation from this app would have failed.
  Future<CropPlan> addCropPlan({
    required String name,
    required double quantity,
    required double pricePerUnit,
    required String fieldLocation,
    required DateTime plantingDate,
    required DateTime expectedHarvestDate,
    String category = 'others',
    String unit = 'kg',
    String? notes,
    String? photoPath,
  }) async {
    if (!expectedHarvestDate.isAfter(plantingDate)) {
      throw ArgumentError('Harvest date must be after planting date.');
    }
    final formData = FormData.fromMap({
      'name': name,
      'category': category,
      'quantity': quantity.toString(),
      'unit': unit,
      'price_per_unit': pricePerUnit.toString(),
      'field_location': fieldLocation,
      'planting_date': _dateOnly(plantingDate),
      'expected_harvest_date': _dateOnly(expectedHarvestDate),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (photoPath != null) 'photo': await MultipartFile.fromFile(photoPath),
    });
    final response =
        await _client.dio.post(ApiEndpoints.cropPlans, data: formData);
    return CropPlan.fromJson(response.data['data']);
  }

  /// Every field the real backend's PATCH /:id actually supports
  /// (verified against routes/cropPlans.js this session) — an earlier
  /// version of this method only exposed stage/name/quantity/notes/
  /// photo, missing category/unit/fieldLocation/plantingDate/
  /// expectedHarvestDate, which the backend has supported all along.
  Future<CropPlan> updateCropPlan({
    required String id,
    CropStage? stage,
    String? name,
    String? category,
    double? quantity,
    String? unit,
    double? pricePerUnit,
    String? fieldLocation,
    DateTime? plantingDate,
    DateTime? expectedHarvestDate,
    String? notes,
    String? photoPath,
  }) async {
    final formData = FormData.fromMap({
      if (stage != null) 'stage': stage.name,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (quantity != null) 'quantity': quantity.toString(),
      if (unit != null) 'unit': unit,
      if (pricePerUnit != null) 'price_per_unit': pricePerUnit.toString(),
      if (fieldLocation != null) 'field_location': fieldLocation,
      if (plantingDate != null) 'planting_date': _dateOnly(plantingDate),
      if (expectedHarvestDate != null)
        'expected_harvest_date': _dateOnly(expectedHarvestDate),
      if (notes != null) 'notes': notes,
      if (photoPath != null) 'photo': await MultipartFile.fromFile(photoPath),
    });
    final response = await _client.dio
        .patch(ApiEndpoints.cropPlanDetail(id), data: formData);
    return CropPlan.fromJson(response.data['data']);
  }

  /// UW 4.3: once an agreement exists against this plan, PATCH /:id
  /// above refuses any quantity/harvest edit outright -- but it has no
  /// path to raise the plan's own total quantity. This is that path:
  /// adds [additionalQuantity] to quantity_kg and, server-side,
  /// reopens any request that previously expired specifically because
  /// this plan sold out (routes/agreement.js's reopenExpiredAgreements,
  /// now also covering that reason). [message] is the real backend's
  /// own confirmation text (states exactly how many requests, if any,
  /// were reopened), worth surfacing as-is rather than a generic
  /// "Saved."
  Future<(CropPlan plan, String message)> addQuantity(
      String id, double additionalQuantity) async {
    final response = await _client.dio.post(
        ApiEndpoints.cropPlanAddQuantity(id),
        data: {'additional_quantity': additionalQuantity});
    return (
      CropPlan.fromJson(response.data['data']),
      response.data['message'] as String,
    );
  }

  /// Real backend does a HARD delete here (DELETE FROM crop_plans),
  /// unlike products' soft-delete pattern — verified this session.
  /// No "undo" is possible after this call.
  Future<void> deleteCropPlan(String id) async {
    await _client.dio.delete(ApiEndpoints.cropPlanDetail(id));
  }

  String _dateOnly(DateTime d) => d.toIso8601String().split('T').first;
}
