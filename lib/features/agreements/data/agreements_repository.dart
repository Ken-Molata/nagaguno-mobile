// lib/features/agreements/data/agreements_repository.dart
//
// Rewritten against the real routes/agreement.js after this session's
// UW 4.1 negotiation-loop / UW 4.3 expiry / UW 5.2 rewrite. The old
// version here (free-text product_name create, generic PATCH cancel,
// a `/:id/proof` confirm/reject pair) no longer matches anything the
// backend exposes -- every one of those calls would 404 or 405 against
// the current API. Payment proof now happens on the agreement's linked
// order (agreements.order_id) via orders.js, not here.

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/agreement.dart';
import '../domain/agreement_round.dart';

class AgreementsRepository {
  AgreementsRepository(this._client);
  final ApiClient _client;

  /// [view] should be 'buyer' when a vendor wants to see agreements
  /// where they're the buyer (matches the backend's own view=buyer
  /// query param -- a vendor can be either side). Omit for the
  /// backend's default (seller for farmer/vendor, buyer for buyer).
  Future<List<Agreement>> getAgreements({String? status, String? view}) async {
    final response =
        await _client.dio.get(ApiEndpoints.agreements, queryParameters: {
      if (status != null && status != 'all') 'status': status,
      if (view != null) 'view': view,
    });
    return (response.data['data'] as List)
        .map((j) => Agreement.fromJson(j))
        .toList();
  }

  Future<Agreement> getAgreementDetail(String id) async {
    final response = await _client.dio.get(ApiEndpoints.agreementDetail(id));
    return Agreement.fromJson(response.data['data']);
  }

  /// UW 4.1/5.1: every Smart Agreement originates from a production
  /// plan, never a crop listing -- the backend requires crop_plan_id
  /// and has no concept of requesting against a seller/product_name
  /// directly any more. price_per_unit is optional (defaults to the
  /// plan's own price server-side); the delivery range is validated
  /// server-side against the plan's harvest month.
  Future<Agreement> createAgreement({
    required String cropPlanId,
    required double quantity,
    required DateTime deliveryDateStart,
    required DateTime deliveryDateEnd,
    double? pricePerUnit,
    String? deliveryAddress,
    String? notes,
  }) async {
    String isoDate(DateTime d) => d.toIso8601String().split('T').first;
    final response = await _client.dio.post(ApiEndpoints.agreements, data: {
      'crop_plan_id': cropPlanId,
      'quantity': quantity,
      if (pricePerUnit != null) 'price_per_unit': pricePerUnit,
      'delivery_date_start': isoDate(deliveryDateStart),
      'delivery_date_end': isoDate(deliveryDateEnd),
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return Agreement.fromJson(response.data['data']);
  }

  /// Only valid for the current responding party (see
  /// Agreement.canRespond). Creates and links an order on success.
  Future<void> accept(String id) async {
    await _client.dio.post(ApiEndpoints.agreementAccept(id));
  }

  /// [reasonCode] must be one of the backend's REJECT_REASONS keys
  /// ('price_too_low_or_high', 'quantity_unavailable_or_unneeded',
  /// 'delivery_window_unworkable', 'no_longer_interested') or 'other'
  /// with [note] supplying the free-text reason.
  Future<void> reject(String id,
      {required String reasonCode, String? note}) async {
    await _client.dio.post(ApiEndpoints.agreementReject(id), data: {
      'reasonCode': reasonCode,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Counter-proposal: only the field(s) passed are changed, the rest
  /// carry over from the live terms server-side. Flips whose turn it
  /// is to the other party.
  Future<void> propose(
    String id, {
    double? quantity,
    double? pricePerUnit,
    DateTime? deliveryDateStart,
    DateTime? deliveryDateEnd,
    String? note,
  }) async {
    String isoDate(DateTime d) => d.toIso8601String().split('T').first;
    await _client.dio.post(ApiEndpoints.agreementPropose(id), data: {
      if (quantity != null) 'quantity': quantity,
      if (pricePerUnit != null) 'price_per_unit': pricePerUnit,
      if (deliveryDateStart != null)
        'delivery_date_start': isoDate(deliveryDateStart),
      if (deliveryDateEnd != null)
        'delivery_date_end': isoDate(deliveryDateEnd),
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// UW 5.2, farmer-only. Revises committed quantity and/or the
  /// production plan's harvest month/year for reasons the system can't
  /// detect itself. Valid on Pending/Negotiating/Active agreements;
  /// on Active, the backend only allows this while the linked order is
  /// still unpaid ('pending') and will cancel that order outright if a
  /// response ends up required.
  Future<void> farmerAdjustment(
    String id, {
    double? quantity,
    int? harvestMonth,
    int? harvestYear,
    required String reasonCode,
    String? note,
  }) async {
    await _client.dio.post(ApiEndpoints.agreementFarmerAdjustment(id), data: {
      if (quantity != null) 'quantity': quantity,
      if (harvestMonth != null) 'harvest_month': harvestMonth,
      if (harvestYear != null) 'harvest_year': harvestYear,
      'reasonCode': reasonCode,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<List<AgreementRound>> getRounds(String id) async {
    final response = await _client.dio.get(ApiEndpoints.agreementRounds(id));
    return (response.data['data'] as List)
        .map((j) => AgreementRound.fromJson(j))
        .toList();
  }

  /// Either party, valid only while Pending/Negotiating (UW 4.1: "before
  /// it becomes Active"). [reasonCode] must be one of the backend's
  /// CANCEL_REASONS keys ('found_better_option', 'changed_mind',
  /// 'circumstances_changed') or 'other' with [note].
  Future<void> cancel(String id,
      {required String reasonCode, String? note}) async {
    await _client.dio.delete(ApiEndpoints.agreementDetail(id), data: {
      'reasonCode': reasonCode,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }
}
