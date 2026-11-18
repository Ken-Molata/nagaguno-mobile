// lib/features/farmers/data/vendors_repository.dart
//
// Mirrors farmers_repository.dart. No saved-vendors equivalent: no
// saved_vendors table exists on the backend (grepped for it this
// session — zero matches), so that half of the Farmers feature simply
// doesn't have a vendor counterpart to call, not an oversight here.

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/vendor_summary.dart';

class VendorsRepository {
  VendorsRepository(this._client);
  final ApiClient _client;

  Future<List<VendorSummary>> getVendors() async {
    final response = await _client.dio.get(ApiEndpoints.vendors);
    return (response.data['data'] as List)
        .map((j) => VendorSummary.fromJson(j))
        .toList();
  }

  Future<VendorSummary> getVendorDetail(String id) async {
    final response = await _client.dio.get(ApiEndpoints.vendorDetail(id));
    return VendorSummary.fromJson(response.data['data']);
  }
}
