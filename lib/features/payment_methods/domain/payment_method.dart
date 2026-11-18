// lib/features/payment_methods/domain/payment_method.dart
//
// Fields verified against the real GET /payment-methods/me response
// (routes/paymentMethods.js). UW 1.2/21.3's "Linked Payment Account" —
// a seller's own GCash number/QR or bank account, shown to a buyer
// paying via Manual Transfer (UW 6.1). No mobile feature existed for
// a seller to manage these at all before this, which meant Manual
// Transfer could never actually become available for any seller.

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.createdAt,
    this.gcashNumber,
    this.gcashQrUrl,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
  });

  final String id;
  final DateTime createdAt;
  final String? gcashNumber;

  /// Short-lived signed URL — re-fetch the list rather than cache this
  /// across app sessions.
  final String? gcashQrUrl;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;

  bool get hasGcash => gcashNumber != null || gcashQrUrl != null;
  bool get hasBank => bankName != null && bankAccountNumber != null;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at']),
        gcashNumber: json['gcash_number'] as String?,
        gcashQrUrl: json['gcash_qr_url'] as String?,
        bankName: json['bank_name'] as String?,
        bankAccountNumber: json['bank_account_number'] as String?,
        bankAccountName: json['bank_account_name'] as String?,
      );
}
