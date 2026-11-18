// lib/features/spoilage/data/spoilage_repository.dart

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/spoilage_listing.dart';

class SpoilageRepository {
  SpoilageRepository(this._client);
  final ApiClient _client;

  Future<List<SpoilageListing>> getMyListings() async {
    final response = await _client.dio.get(ApiEndpoints.spoilageMyListings);
    return (response.data['data'] as List)
        .map((j) => SpoilageListing.fromJson(j))
        .toList();
  }

  /// [stage] must be 'near_spoilage', 'critical', or 'expired' —
  /// matching the real backend's exact accepted values (verified
  /// against routes/spoilage.js this session; 'fresh' is deliberately
  /// not a valid report value, since reporting is specifically for
  /// correcting the automatic estimate toward MORE spoiled, not less).
  Future<void> reportSpoilage(String productId, String stage) async {
    await _client.dio
        .post(ApiEndpoints.spoilageReport(productId), data: {'stage': stage});
  }

  /// Re-verified against the real POST /spoilage/sale/:productId this
  /// session: it was sending `{discount_pct: <fraction>}`, but the
  /// backend reads `req.body.discount` (a WHOLE number 1-50, not a
  /// fraction) and has four more fields (UW 3.5's full richness:
  /// until-removed vs. a set period, an optional minimum order
  /// quantity, and a label) that weren't being sent at all. Every call
  /// would have 400'd on `Number.isInteger(parseInt(undefined, 10))`.
  ///
  /// [discountPercent] is a whole number 1-50 (enter 15 for 15% off).
  /// [whenItApplies] is 'now' or 'set_period'; the latter requires
  /// [startDate]/[endDate], both constrained server-side to the
  /// listing's best-before date. [minimumOrderQty] is optional —
  /// qualifying orders pay bulk_price_per_unit instead of the flat
  /// discounted price. [label] must be one of the backend's
  /// DISCOUNT_LABELS ('seller_discount', 'bulk_discount',
  /// 'harvest_sale', 'clearance') or omitted to let the backend default
  /// it (bulk_discount if a minimum is set, seller_discount otherwise).
  Future<void> startSale(
    String productId, {
    required int discountPercent,
    String whenItApplies = 'now',
    DateTime? startDate,
    DateTime? endDate,
    double? minimumOrderQty,
    String? label,
  }) async {
    String isoDate(DateTime d) => d.toIso8601String().split('T').first;
    await _client.dio.post(ApiEndpoints.spoilageSale(productId), data: {
      'discount': discountPercent,
      'when_it_applies': whenItApplies,
      if (whenItApplies == 'set_period' && startDate != null)
        'start_date': isoDate(startDate),
      if (whenItApplies == 'set_period' && endDate != null)
        'end_date': isoDate(endDate),
      if (minimumOrderQty != null) 'minimum_order': minimumOrderQty,
      if (label != null) 'label': label,
    });
  }

  /// UW 3.5: "Remove this seller discount? The automatic discount
  /// stays." Had no mobile caller at all before this, despite being a
  /// real, working endpoint.
  Future<void> removeSale(String productId) async {
    await _client.dio.delete(ApiEndpoints.spoilageSale(productId));
  }

  Future<void> respondToRecommendation(String recommendationId,
      {required bool accept}) async {
    await _client.dio.post(
      ApiEndpoints.spoilageRecommendationRespond(recommendationId),
      data: {'action': accept ? 'accept' : 'dismiss'},
    );
  }
}
