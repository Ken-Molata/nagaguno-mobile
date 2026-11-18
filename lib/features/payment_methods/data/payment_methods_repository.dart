// lib/features/payment_methods/data/payment_methods_repository.dart
//
// Matches the real routes/paymentMethods.js exactly: POST / takes a
// GCash number and/or QR image and/or bank account (at least one of
// the three), and both add/remove are blocked for 3 days after a
// UW 2.5 account-recovery approval (payment_details_locked_until) --
// surfaced here as a distinct exception so the UI can show the real
// reason rather than a generic error.

import 'package:dio/dio.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/payment_method.dart';

class PaymentDetailsLockedException implements Exception {
  PaymentDetailsLockedException(this.message);
  final String message;
}

class PaymentMethodsRepository {
  PaymentMethodsRepository(this._client);
  final ApiClient _client;

  Future<List<PaymentMethod>> getMyPaymentMethods() async {
    final response = await _client.dio.get(ApiEndpoints.paymentMethodsMe);
    return (response.data['data'] as List)
        .map((j) => PaymentMethod.fromJson(j))
        .toList();
  }

  /// UW 21.3: "While the gateway is in test mode (Section 6.4), the
  /// note adds: 'The gateway is in test mode. No real money is
  /// charged.'" A second call to the same endpoint rather than
  /// reshaping getMyPaymentMethods()'s return type -- this is a small,
  /// infrequent GET, not worth coupling two screens' data shapes over.
  Future<bool> getGatewayTestMode() async {
    final response = await _client.dio.get(ApiEndpoints.paymentMethodsMe);
    return response.data['gateway_test_mode'] as bool? ?? false;
  }

  /// At least one of [gcashNumber], [gcashQrPath], or
  /// ([bankName] + [bankAccountNumber]) is required — matches the
  /// real backend's own "Provide at least a GCash number, a GCash QR
  /// code, or a bank account." rule. [gcashNumber] must be an
  /// 11-digit PH mobile number starting with 09 (server-validated).
  ///
  /// UW 21.2 top: "Password confirmation is required for every add,
  /// edit, or removal, because these details decide where money
  /// goes." [password] is required by the server for every method
  /// below.
  Future<PaymentMethod> addPaymentMethod({
    required String password,
    String? gcashNumber,
    String? gcashQrPath,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
  }) async {
    final formData = FormData.fromMap({
      'password': password,
      if (gcashNumber != null && gcashNumber.isNotEmpty)
        'gcash_number': gcashNumber,
      if (gcashQrPath != null)
        'gcash_qr': await MultipartFile.fromFile(gcashQrPath),
      if (bankName != null && bankName.isNotEmpty) 'bank_name': bankName,
      if (bankAccountNumber != null && bankAccountNumber.isNotEmpty)
        'bank_account_number': bankAccountNumber,
      if (bankAccountName != null && bankAccountName.isNotEmpty)
        'bank_account_name': bankAccountName,
    });
    try {
      final response =
          await _client.dio.post(ApiEndpoints.paymentMethods, data: formData);
      return PaymentMethod.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// UW 21.3: "Add, edit, remove. Each method is managed separately."
  /// [removeQr] clears an existing QR code without replacing it with a
  /// new one (ignored if [gcashQrPath] is also given).
  Future<PaymentMethod> editPaymentMethod(
    String id, {
    required String password,
    String? gcashNumber,
    String? gcashQrPath,
    bool removeQr = false,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
  }) async {
    final formData = FormData.fromMap({
      'password': password,
      if (gcashNumber != null && gcashNumber.isNotEmpty)
        'gcash_number': gcashNumber,
      if (gcashQrPath != null)
        'gcash_qr': await MultipartFile.fromFile(gcashQrPath)
      else if (removeQr)
        'remove_qr': 'true',
      if (bankName != null && bankName.isNotEmpty) 'bank_name': bankName,
      if (bankAccountNumber != null && bankAccountNumber.isNotEmpty)
        'bank_account_number': bankAccountNumber,
      if (bankAccountName != null && bankAccountName.isNotEmpty)
        'bank_account_name': bankAccountName,
    });
    try {
      final response = await _client.dio
          .patch(ApiEndpoints.paymentMethodDetail(id), data: formData);
      return PaymentMethod.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deletePaymentMethod(String id, {required String password}) async {
    try {
      await _client.dio.delete(ApiEndpoints.paymentMethodDetail(id),
          data: {'password': password});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Exception _mapError(DioException e) {
    final message = (e.response?.data is Map
        ? e.response?.data['message']
        : null) as String?;
    if (e.response?.statusCode == 403 &&
        message != null &&
        message.contains('payment details')) {
      return PaymentDetailsLockedException(message);
    }
    return e;
  }
}
