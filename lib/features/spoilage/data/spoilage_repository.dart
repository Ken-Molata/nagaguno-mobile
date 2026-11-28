// lib/features/spoilage/data/spoilage_repository.dart

import 'package:dio/dio.dart';
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

  /// Puts an auto-hidden-for-spoilage listing back live on the
  /// seller's own say-so — 409s if the listing isn't actually hidden
  /// for a spoilage reason (an admin moderation hide has its own
  /// separate flow this never touches).
  Future<void> unhide(String productId) async {
    await _client.dio.post(ApiEndpoints.spoilageUnhide(productId));
  }

  /// Which crops the server-side freshness model actually covers —
  /// fetched, not bundled on-device (see freshness_classifier.dart's
  /// removal: on-device TFLite inference was abandoned after a real,
  /// confirmed Gradle plugin bug made it unbuildable; the model now
  /// runs in ml-service instead). Callers should only offer the
  /// photo-freshness-check entry point for a listing matching one of
  /// these.
  // REAL BUG FOUND AND FIXED, live-confirmed: raising the backend's own
  // axios timeout to the ml-service (services/freshnessService.js) to
  // tolerate a Render cold-start did nothing on its own -- ApiClient's
  // Dio instance carries a GLOBAL 15s receiveTimeout (api_client.dart),
  // so the mobile app itself gave up and threw well before the backend
  // could ever finish waiting on a cold ml-service, landing on the
  // exact same "Couldn't reach the freshness-checking service" message
  // the backend fix was meant to prevent. Overridden per-call here
  // (not globally, since every other endpoint on this client is
  // legitimately fast and a global 60s+ timeout would make an
  // unrelated hung request take a minute to fail instead of 15s). Set
  // to 130s -- comfortably above the backend's own 100s cold-start/429
  // retry budget (freshnessService.js's requestThroughColdStart), so
  // this client never cuts the request off a moment before the
  // backend itself would have given up.
  static final _coldStartTolerantOptions =
      Options(receiveTimeout: const Duration(seconds: 130));

  Future<List<String>> getFreshnessCoveredCrops() async {
    final response = await _client.dio.get(
      ApiEndpoints.spoilageFreshnessModelInfo,
      options: _coldStartTolerantOptions,
    );
    return (response.data['data']['covered_crops'] as List).cast<String>();
  }

  /// Uploads a photo for the server-side freshness model
  /// (photo_freshness_check_screen.dart) to classify AND apply in one
  /// call — the backend computes remaining_pct/stage itself from the
  /// photo (never trusts a client-supplied value) and applies it the
  /// same way [reportSpoilage] applies a dropdown choice, just tagged
  /// source='cv' with the evidence photo attached. Unlike
  /// [reportSpoilage] (which deliberately excludes 'fresh'), the
  /// server's result can correct the automatic estimate toward LESS
  /// spoiled too, which a seller-initiated dropdown report never
  /// could. Returns the server's own (stage, remainingPct) for the UI
  /// to display.
  Future<CvOverrideResult> applyCvOverride(
    String productId, {
    required String photoPath,
  }) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(photoPath),
    });
    final response = await _client.dio.post(
      ApiEndpoints.spoilageCvOverride(productId),
      data: formData,
      options: _coldStartTolerantOptions,
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return CvOverrideResult(
      stage: data['stage'] as String,
      remainingPct: double.tryParse(data['remaining_pct'].toString()) ?? 0,
    );
  }
}

class CvOverrideResult {
  const CvOverrideResult({required this.stage, required this.remainingPct});
  final String stage;
  final double remainingPct;
}
