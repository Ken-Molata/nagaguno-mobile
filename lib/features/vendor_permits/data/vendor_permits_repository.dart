// lib/features/vendor_permits/data/vendor_permits_repository.dart
//
// Matches routes/vendorPermits.js exactly: multipart POST / with
// {document, permit_type, permit_number, business_name}; admin review
// via GET /admin, GET /admin/:id/document (signed URL), GET
// /admin/demo-registry, POST /admin/:id/decide.

import 'package:dio/dio.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/vendor_permit_models.dart';

class VendorPermitsRepository {
  VendorPermitsRepository(this._client);
  final ApiClient _client;

  Future<List<BusinessPermitType>> getReferenceTypes() async {
    final response = await _client.dio.get(ApiEndpoints.vendorPermitsReference);
    return (response.data['data'] as List)
        .map((j) => BusinessPermitType.fromJson(j))
        .toList();
  }

  Future<List<VendorPermitSubmission>> getMySubmissions() async {
    final response = await _client.dio.get(ApiEndpoints.vendorPermitsMine);
    return (response.data['data'] as List)
        .map((j) => VendorPermitSubmission.fromJson(j))
        .toList();
  }

  Future<void> submit({
    required String permitType,
    required String permitNumber,
    required String businessName,
    required String tin,
    required String businessAddress,
    required String issuingAuthority,
    required DateTime dateIssued,
    DateTime? expiryDate,
    required String documentPath,
  }) async {
    final formData = FormData.fromMap({
      'permit_type': permitType,
      'permit_number': permitNumber,
      'business_name': businessName,
      'tin': tin,
      'business_address': businessAddress,
      'issuing_authority': issuingAuthority,
      'date_issued': dateIssued.toIso8601String().split('T').first,
      if (expiryDate != null)
        'expiry_date': expiryDate.toIso8601String().split('T').first,
      'document': await MultipartFile.fromFile(documentPath),
    });
    await _client.dio.post(ApiEndpoints.vendorPermitsSubmit, data: formData);
  }

  // ── Admin review ────────────────────────────────────────────────

  Future<List<AdminVendorPermitRow>> getAdminQueue({String status = 'pending'}) async {
    final response = await _client.dio.get(
      ApiEndpoints.vendorPermitsAdminQueue,
      queryParameters: {'status': status},
    );
    return (response.data['data'] as List)
        .map((j) => AdminVendorPermitRow.fromJson(j))
        .toList();
  }

  Future<String> getAdminDocumentUrl(String id) async {
    final response =
        await _client.dio.get(ApiEndpoints.vendorPermitsAdminDocument(id));
    return response.data['data']['url'] as String;
  }

  Future<List<DemoRegisteredVendor>> getDemoRegistry() async {
    final response =
        await _client.dio.get(ApiEndpoints.vendorPermitsAdminDemoRegistry);
    return (response.data['data'] as List)
        .map((j) => DemoRegisteredVendor.fromJson(j))
        .toList();
  }

  Future<void> decide(String id, {required bool approve, String? rejectionReason}) async {
    await _client.dio.post(
      ApiEndpoints.vendorPermitsAdminDecide(id),
      data: {
        'action': approve ? 'approve' : 'reject',
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
      },
    );
  }
}
