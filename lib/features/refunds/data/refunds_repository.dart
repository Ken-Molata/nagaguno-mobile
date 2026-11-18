// lib/features/refunds/data/refunds_repository.dart
//
// UW 9.4: see domain/refund_request.dart's header comment for the real
// gap this closes -- every one of these endpoints already worked on
// the backend with no mobile caller at all.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/refund_request.dart';

final refundsRepositoryProvider = Provider<RefundsRepository>(
    (ref) => RefundsRepository(ref.watch(apiClientProvider)));

class RefundsRepository {
  RefundsRepository(this._client);
  final ApiClient _client;

  /// Buyer files a new request against [orderId]. [reasonCode] is one
  /// of refundReasonLabels' keys ('other' requires [note]); at least
  /// one of [note]/[photoPaths] is required (matches the real
  /// backend's own validation: "Provide a description and/or at least
  /// one photo.").
  Future<RefundRequest> fileRequest({
    required String orderId,
    required String reasonCode,
    String? note,
    List<String> photoPaths = const [],
  }) async {
    final formData = FormData.fromMap({
      'orderId': orderId,
      'reasonCode': reasonCode,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    for (final path in photoPaths) {
      formData.files.add(MapEntry('photos', await MultipartFile.fromFile(path)));
    }
    final response = await _client.dio.post(ApiEndpoints.refunds, data: formData);
    return RefundRequest.fromJson(response.data['data']);
  }

  /// Every request this user filed (as buyer) or needs to act on (as
  /// seller) -- the real backend has no per-order filter, so the
  /// caller (e.g. order_detail_screen.dart, looking for one specific
  /// order's request) filters this list client-side.
  Future<List<RefundRequest>> getMine() async {
    final response = await _client.dio.get(ApiEndpoints.refundsMine);
    return (response.data['data'] as List)
        .map((j) => RefundRequest.fromJson(j))
        .toList();
  }

  Future<RefundRequest> getDetail(String id) async {
    final response = await _client.dio.get(ApiEndpoints.refundDetail(id));
    return RefundRequest.fromJson(response.data['data']);
  }

  /// Seller-only. [action] is 'accept' or 'decline'; declining requires
  /// [reasonCode] (refundDeclineReasonLabels' keys, or 'other' with
  /// [note]).
  Future<void> respond(String id,
      {required String action, String? reasonCode, String? note}) async {
    await _client.dio.post(ApiEndpoints.refundRespond(id), data: {
      'action': action,
      if (reasonCode != null) 'reasonCode': reasonCode,
      if (note != null) 'note': note,
    });
  }

  /// Buyer-only, only from a 'declined' request.
  Future<void> escalate(String id) async {
    await _client.dio.post(ApiEndpoints.refundEscalate(id));
  }

  /// Seller-only, only from 'verified'. Defers the refund without
  /// completing it (UW 9.4's "Process Later").
  Future<void> processLater(String id) async {
    await _client.dio.post(ApiEndpoints.refundProcessLater(id));
  }

  /// Seller-only, from 'verified' or 'in_progress'. [proofPath] is
  /// evidence the transfer was actually sent -- same contract as the
  /// Manual Transfer/Gateway settlement proof uploads elsewhere in
  /// this app.
  Future<void> complete(String id, {required String proofPath}) async {
    final formData = FormData.fromMap(
        {'proof': await MultipartFile.fromFile(proofPath)});
    await _client.dio.post(ApiEndpoints.refundComplete(id), data: formData);
  }
}
