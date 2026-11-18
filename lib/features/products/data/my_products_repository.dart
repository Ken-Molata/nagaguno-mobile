// lib/features/products/data/my_products_repository.dart

import 'package:dio/dio.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/my_product.dart';

/// Thrown specifically for the real backend's barangay-not-set case
/// (verified against routes/products.js this session — a listing
/// cannot be created at all until the seller's profile has a
/// barangay), so the UI can prompt "update your profile" rather than
/// show a generic error for this specific, actionable case.
class MissingBarangayException implements Exception {}

class ProductRepositoryException implements Exception {
  ProductRepositoryException(this.message);
  final String message;
}

class MyProductsRepository {
  MyProductsRepository(this._client);
  final ApiClient _client;

  Future<List<MyProduct>> getMyProducts({String? status}) async {
    final response =
        await _client.dio.get(ApiEndpoints.products, queryParameters: {
      if (status != null) 'status': status,
    });
    return (response.data['data'] as List)
        .map((j) => MyProduct.fromJson(j))
        .toList();
  }

  /// [harvestedAt] is required server-side ("Harvest date is
  /// required.", re-verified this session) — it was missing from this
  /// call entirely, so every product listing created from this app
  /// would have 400'd. [storageCondition] must be 'room_temperature'
  /// or 'refrigerated' when provided; [shelfLifeDays] overrides the
  /// per-category default the backend would otherwise resolve
  /// (UW 3.3) — both optional.
  Future<MyProduct> addProduct({
    required String name,
    required String category,
    required double pricePerUnit,
    required DateTime harvestedAt,
    String? description,
    String unit = 'kg',
    double stockQty = 0,
    String? storageCondition,
    int? shelfLifeDays,
    String? photoPath,
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      'category': category,
      'price_per_unit': pricePerUnit.toString(),
      'unit': unit,
      'stock_qty': stockQty.toString(),
      'harvested_at': harvestedAt.toIso8601String().split('T').first,
      if (storageCondition != null) 'storage_condition': storageCondition,
      if (shelfLifeDays != null) 'shelf_life_days': shelfLifeDays.toString(),
      if (description != null && description.isNotEmpty)
        'description': description,
      if (photoPath != null) 'photo': await MultipartFile.fromFile(photoPath),
    });

    try {
      final response =
          await _client.dio.post(ApiEndpoints.products, data: formData);
      return MyProduct.fromJson(response.data['data']);
    } on DioException catch (e) {
      final message = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      if (message != null && message.contains('barangay')) {
        throw MissingBarangayException();
      }
      throw ProductRepositoryException(message ?? 'Failed to add product.');
    }
  }

  Future<MyProduct> updateProduct({
    required String id,
    String? name,
    String? category,
    double? pricePerUnit,
    String? description,
    String? unit,
    double? stockQty,
    DateTime? harvestedAt,
    String? storageCondition,
    int? shelfLifeDays,
    String? photoPath,
  }) async {
    final formData = FormData.fromMap({
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (pricePerUnit != null) 'price_per_unit': pricePerUnit.toString(),
      if (unit != null) 'unit': unit,
      if (stockQty != null) 'stock_qty': stockQty.toString(),
      if (harvestedAt != null)
        'harvested_at': harvestedAt.toIso8601String().split('T').first,
      if (storageCondition != null) 'storage_condition': storageCondition,
      if (shelfLifeDays != null) 'shelf_life_days': shelfLifeDays.toString(),
      if (description != null) 'description': description,
      if (photoPath != null) 'photo': await MultipartFile.fromFile(photoPath),
    });
    final response =
        await _client.dio.patch(ApiEndpoints.productDetail(id), data: formData);
    return MyProduct.fromJson(response.data['data']);
  }

  /// UW 15.2's "reached its estimated harvest date, prompting listing
  /// or production plan update" -- the real action: creates a crop
  /// listing from an existing production plan, pre-filled server-side
  /// (name/category/price/unit come from the plan itself). Only
  /// [harvestedAt] is genuinely required here, same as [addProduct],
  /// since the plan only ever has a month/year estimate, never a real
  /// harvest date (UW 5). Everything else is an optional override of
  /// what the plan would otherwise supply.
  Future<MyProduct> createListingFromPlan({
    required String planId,
    required DateTime harvestedAt,
    double? pricePerUnit,
    double? stockQty,
    String? storageCondition,
    int? shelfLifeDays,
    String? photoPath,
  }) async {
    final formData = FormData.fromMap({
      'harvested_at': harvestedAt.toIso8601String().split('T').first,
      if (pricePerUnit != null) 'price_per_unit': pricePerUnit.toString(),
      if (stockQty != null) 'stock_qty': stockQty.toString(),
      if (storageCondition != null) 'storage_condition': storageCondition,
      if (shelfLifeDays != null) 'shelf_life_days': shelfLifeDays.toString(),
      if (photoPath != null) 'photo': await MultipartFile.fromFile(photoPath),
    });
    try {
      final response = await _client.dio
          .post(ApiEndpoints.productFromPlan(planId), data: formData);
      return MyProduct.fromJson(response.data['data']);
    } on DioException catch (e) {
      final message = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      if (message != null && message.contains('barangay')) {
        throw MissingBarangayException();
      }
      throw ProductRepositoryException(
          message ?? 'Failed to create listing from production plan.');
    }
  }

  /// Flips live <-> hidden — the real endpoint takes no body, it's a
  /// pure toggle server-side (verified this session).
  Future<String> toggleProduct(String id) async {
    final response = await _client.dio.patch(ApiEndpoints.productToggle(id));
    return response.data['data']['status'] as String;
  }

  Future<void> deleteProduct(String id) async {
    await _client.dio.delete(ApiEndpoints.productDetail(id));
  }

  /// UW 3.3 "Farmer feedback": "Next to a listing's shelf-life display,
  /// the farmer or vendor can select 'Shelf life seems wrong?'..."
  /// [direction] is 'longer' or 'shorter'. A 409 means this listing
  /// already has feedback pending review.
  Future<void> submitShelfLifeFeedback(
    String productId, {
    required String direction,
    required int observedDays,
    String? note,
  }) async {
    try {
      await _client.dio.post(
        ApiEndpoints.productShelfLifeFeedback(productId),
        data: {
          'direction': direction,
          'observed_days': observedDays.toString(),
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
    } on DioException catch (e) {
      final message = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      throw ProductRepositoryException(
          message ?? 'Failed to submit feedback.');
    }
  }
}
