// lib/features/recommendations/data/recommendations_repository.dart
//
// Full rewrite against the real GET /recommendations and GET
// /recommendations/farmers (routes/recommendation.js) after this
// session's security rewrite of that file — see domain/recommendation.dart's
// header comment for why the old POST /recommendations/all shape this
// replaces doesn't exist any more. Buyer identity now comes only from
// the authenticated session (never a client-supplied buyer_id); a
// farmer/vendor caller must explicitly pass buyerMode=true or gets a
// 403 (UW 20.1: "available to Buyers, and to Farmers/Vendors in buyer
// mode"). This widget is shown to every role as a buyer-browsing
// feature, so buyerMode is always sent — there's no seller-mode use
// of it here.
//
// Neither endpoint supports a category filter for PRODUCTS server-side
// (verified: GET /recommendations only reads limit/buyerMode) — the
// category chips in the UI narrow the already-fetched product list
// client-side instead of inventing a server capability that doesn't
// exist. The farmers endpoint DOES support filter_category server-side,
// so that one is passed through properly.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/recommendation.dart';

class RecommendationsRepository {
  RecommendationsRepository(this._client);
  final ApiClient _client;

  Future<RecommendationsResult> getRecommendations({
    required bool buyerMode,
    int productsLimit = 24,
    int farmersLimit = 10,
    String? filterCategory,
  }) async {
    final results = await Future.wait([
      _client.dio.get(ApiEndpoints.recommendations, queryParameters: {
        'limit': productsLimit,
        if (buyerMode) 'buyerMode': 'true',
      }),
      _client.dio.get(ApiEndpoints.recommendationsFarmers, queryParameters: {
        'limit': farmersLimit,
        if (buyerMode) 'buyerMode': 'true',
        if (filterCategory != null) 'filter_category': filterCategory,
      }),
    ]);

    return RecommendationsResult.fromProductsAndFarmers(
      results[0].data as Map<String, dynamic>,
      (results[1].data['farmers'] as List?) ?? [],
    );
  }

  Future<List<SimilarProduct>> getSimilarProducts(String productId,
      {int topN = 8}) async {
    final response = await _client.dio.get(
      ApiEndpoints.recommendationsSimilar(productId),
      queryParameters: {'limit': topN},
    );
    final products = (response.data['products'] as List?) ?? [];
    return products.map((p) => SimilarProduct.fromJson(p)).toList();
  }
}

final recommendationsRepositoryProvider = Provider<RecommendationsRepository>(
  (ref) => RecommendationsRepository(ref.watch(apiClientProvider)),
);
