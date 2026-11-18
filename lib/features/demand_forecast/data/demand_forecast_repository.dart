// lib/features/demand_forecast/data/demand_forecast_repository.dart
//
// Full rewrite against the real GET /api/demand/forecast?category=
// (routes/demand.js) — see domain/demand_forecast.dart's header
// comment for why the old batch-predict approach this replaced no
// longer matches anything the backend exposes.

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/demand_forecast.dart';

class DemandForecastRepository {
  DemandForecastRepository(this._client);
  final ApiClient _client;

  /// Farmer/vendor-only on the backend (UW 20.2: "not shown to
  /// Buyers"). [category] must be one of this app's own
  /// productCategories (core/constants/product_categories.dart).
  Future<CategoryDemandForecast> getForecast(String category) async {
    final response = await _client.dio.get(ApiEndpoints.demandForecast,
        queryParameters: {'category': category});
    return CategoryDemandForecast.fromJson(response.data['data']);
  }
}
