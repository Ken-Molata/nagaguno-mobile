// lib/features/farmers/data/farmers_repository.dart

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/farmer_summary.dart';

class FarmersRepository {
  FarmersRepository(this._client);
  final ApiClient _client;

  Future<List<FarmerSummary>> getFarmers() async {
    final response = await _client.dio.get(ApiEndpoints.profileFarmers);
    return (response.data['data'] as List)
        .map((j) => FarmerSummary.fromJson(j))
        .toList();
  }

  Future<FarmerSummary> getFarmerDetail(String id) async {
    final response =
        await _client.dio.get(ApiEndpoints.profileFarmerDetail(id));
    return FarmerSummary.fromJson(response.data['data']);
  }

  Future<List<FarmerSummary>> getSavedFarmers() async {
    final response = await _client.dio.get(ApiEndpoints.savedFarmers);
    return (response.data['data'] as List)
        .map((j) => FarmerSummary.fromJson(j))
        .toList();
  }

  Future<void> saveFarmer(String farmerId) async {
    await _client.dio.post(ApiEndpoints.saveFarmer(farmerId));
  }

  Future<void> unsaveFarmer(String farmerId) async {
    await _client.dio.delete(ApiEndpoints.saveFarmer(farmerId));
  }
}
