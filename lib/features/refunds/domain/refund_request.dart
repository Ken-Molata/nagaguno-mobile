// lib/features/refunds/domain/refund_request.dart
//
// UW 9.4 Refund Requests. The real backend (routes/refunds.js) has
// always had this whole flow built -- buyer files, seller verifies/
// declines, seller sends the money and uploads proof, buyer can
// escalate a decline to Admin -- but nothing in the mobile app ever
// called any of it except the web admin's own escalation queue.
// Confirmed live: a buyer blocked from cancelling an already-paid
// order had no way to actually request a refund at all.

enum RefundStatus {
  pending,
  declined,
  verified,
  inProgress,
  refunded,
  underAdminReview,
  dismissed,
}

RefundStatus _statusFrom(String s) => switch (s) {
      'pending' => RefundStatus.pending,
      'declined' => RefundStatus.declined,
      'verified' => RefundStatus.verified,
      'in_progress' => RefundStatus.inProgress,
      'refunded' => RefundStatus.refunded,
      'under_admin_review' => RefundStatus.underAdminReview,
      'dismissed' => RefundStatus.dismissed,
      _ => RefundStatus.pending,
    };

class RefundRequest {
  const RefundRequest({
    required this.id,
    required this.orderId,
    required this.buyerId,
    required this.sellerId,
    required this.reasonCode,
    required this.status,
    required this.createdAt,
    this.essay,
    this.photoUrls = const [],
    this.declineReason,
    this.adminReason,
    this.refundProofUrl,
    // Minimal raw passthrough, same convention Order.sellerPaymentMethods
    // already established for this exact shape (routes/paymentMethods.js's
    // getPaymentMethodsForUser) -- only present once a seller is viewing
    // their own 'verified' request (UW 9.4/1.2: where to actually send it).
    this.buyerPaymentMethods = const [],
    required this.totalAmount,
  });

  final String id;
  final String orderId;
  final String buyerId;
  final String sellerId;
  final String reasonCode;
  final String? essay;
  final List<String> photoUrls;
  final RefundStatus status;
  final String? declineReason;
  final String? adminReason;
  final String? refundProofUrl;
  final DateTime createdAt;
  final List<Map<String, dynamic>> buyerPaymentMethods;

  /// The order's full payment amount -- a refund is always for the
  /// whole order, there's no partial-refund concept here. Joined in
  /// from orders.total_amount server-side (refund_requests has no
  /// amount column of its own); used to show the real figure on the
  /// Refund Detail screen once status is Refunded, not just buried in
  /// the 'refund_sent' notification text.
  final double totalAmount;

  factory RefundRequest.fromJson(Map<String, dynamic> json) => RefundRequest(
        id: json['id'] as String,
        orderId: json['order_id'] as String,
        buyerId: json['buyer_id'] as String,
        sellerId: json['seller_id'] as String,
        reasonCode: json['reason_code'] as String,
        essay: json['essay'] as String?,
        photoUrls: (json['photo_urls'] as List? ?? []).cast<String>(),
        status: _statusFrom(json['status'] as String),
        declineReason: json['decline_reason'] as String?,
        adminReason: json['admin_reason'] as String?,
        refundProofUrl: json['refund_proof_url'] as String?,
        createdAt: DateTime.parse(json['created_at']),
        buyerPaymentMethods: (json['buyer_payment_methods'] as List? ?? [])
            .cast<Map<String, dynamic>>(),
        totalAmount:
            double.tryParse(json['total_amount']?.toString() ?? '') ?? 0,
      );
}

// REASONS from routes/refunds.js -- kept in sync by hand since the
// backend doesn't expose them as their own lookup endpoint (same
// pattern this app already uses for COD_DECLINE_REASONS etc.).
const refundReasonLabels = {
  'order_not_received': 'Order not received',
  'significantly_different': 'Product significantly different from what was described',
  'damaged_or_spoiled': 'Product arrived damaged or spoiled',
  'duplicate_or_accidental': 'Duplicate or accidental order',
  'other': 'Other',
};

const refundDeclineReasonLabels = {
  'as_described': 'Product was as described',
  'delivered': 'Order was in fact delivered or received',
  'insufficient_evidence': 'Insufficient evidence provided',
  'other': 'Other',
};
