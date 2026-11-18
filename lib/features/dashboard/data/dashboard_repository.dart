// lib/features/dashboard/data/dashboard_repository.dart

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._client);
  final ApiClient _client;

  Future<BuyerDashboard> getBuyerDashboard() async {
    final response = await _client.dio.get(ApiEndpoints.dashboardBuyer);
    return BuyerDashboard.fromJson(response.data['data']);
  }

  Future<FarmerDashboard> getFarmerDashboard() async {
    final response = await _client.dio.get(ApiEndpoints.dashboardFarmer);
    return FarmerDashboard.fromJson(response.data['data']);
  }

  Future<VendorDashboard> getVendorDashboard() async {
    final response = await _client.dio.get(ApiEndpoints.dashboardVendor);
    return VendorDashboard.fromJson(response.data['data']);
  }
}
