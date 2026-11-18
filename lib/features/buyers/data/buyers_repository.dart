// lib/features/buyers/data/buyers_repository.dart

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/buyer_profile.dart';

class BuyersRepository {
  BuyersRepository(this._client);
  final ApiClient _client;

  Future<BuyerProfile> getBuyerDetail(String id) async {
    final response = await _client.dio.get(ApiEndpoints.buyerDetail(id));
    return BuyerProfile.fromJson(response.data['data']);
  }
}
