// lib/features/agreements/domain/agreement.dart
//
// Re-verified against the real GET /agreements and GET /agreements/:id
// queries after this session's UW 4.1 negotiation-loop rewrite. Payment
// proof is no longer part of the agreement at all -- it lives on the
// order created by POST /:id/accept (agreements.order_id), handled by
// orders.js's own proof endpoints -- so proof_status/payment_proof_url
// are gone from here. Delivery is a date RANGE
// (delivery_date_start/delivery_date_end), not a single date.

enum AgreementStatus {
  pending,
  negotiating,
  active,
  fulfilled,
  cancelled,
  rejected,
  expired
}

class Agreement {
  const Agreement({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.cropPlanId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.totalPrice,
    required this.buyerName,
    required this.sellerName,
    required this.sellerRole,
    required this.createdAt,
    this.awaitingParty,
    this.orderId,
    this.rejectionReason,
    this.expiredReason,
    this.buyerPhone,
    this.buyerBarangay,
    this.sellerBarangay,
    this.farmName,
    this.businessName,
    this.deliveryDateStart,
    this.deliveryDateEnd,
    this.deliveryAddress,
    this.notes,
    this.sellerPaymentMethods = const [],
    this.cropPlanPricePerUnit,
  });

  final String id;
  final String buyerId;
  final String sellerId;
  final AgreementStatus status;
  final String? cropPlanId;
  final String productName;
  final double quantity;
  final String unit;
  final double pricePerUnit;

  /// Generated DB column (quantity * price_per_unit) — never sent by
  /// the client, only ever read back.
  final double totalPrice;
  final String buyerName;
  final String sellerName;
  final String sellerRole; // 'farmer' | 'vendor'
  final DateTime createdAt;

  /// 'buyer' | 'seller' | null — whose turn it is to Accept/Reject/
  /// Propose. Null once the agreement is Active or any terminal state.
  final String? awaitingParty;
  final String? orderId;
  final String? rejectionReason;

  /// 'quantity_exhausted' | 'harvest_timeline_passed' | null.
  final String? expiredReason;
  final String? buyerPhone;
  final String? buyerBarangay;
  final String? sellerBarangay;
  final String? farmName;
  final String? businessName;
  final DateTime? deliveryDateStart;
  final DateTime? deliveryDateEnd;
  final String? deliveryAddress;
  final String? notes;

  /// UW 1.2/21.3: the seller's registered receiving details, included
  /// only once Active and only for the buyer. Minimal raw passthrough —
  /// no dedicated payment-methods feature module exists in this app yet
  /// to render these richly.
  final List<Map<String, dynamic>> sellerPaymentMethods;

  /// The farmer's originally-posted price on the crop plan this
  /// agreement was made against -- null for an agreement whose plan
  /// no longer exists. Distinct from [pricePerUnit], which is whatever
  /// the current round of negotiation proposes.
  final double? cropPlanPricePerUnit;

  String get sellerDisplayName => farmName ?? businessName ?? sellerName;

  String counterpartyName(String? currentUserId) {
    if (currentUserId == sellerId) return buyerName;
    return sellerDisplayName;
  }

  /// Mirrors the backend's currentRespondingParty(): only meaningful
  /// while Pending/Negotiating. Null (nobody's turn) once Active or
  /// terminal.
  String? respondingParty() {
    if (status != AgreementStatus.pending &&
        status != AgreementStatus.negotiating) {
      return null;
    }
    return awaitingParty;
  }

  bool canRespond(String? currentUserId) {
    final party = respondingParty();
    if (party == null || currentUserId == null) return false;
    final callerRole = currentUserId == buyerId ? 'buyer' : 'seller';
    return party == callerRole;
  }

  static AgreementStatus _statusFrom(String? s) => AgreementStatus.values
      .firstWhere((e) => e.name == s, orElse: () => AgreementStatus.pending);

  factory Agreement.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) =>
        v == null ? 0 : (double.tryParse(v.toString()) ?? 0);
    double? asDoubleOrNull(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());
    DateTime? asDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return Agreement(
      id: json['id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      status: _statusFrom(json['status'] as String?),
      cropPlanId: json['crop_plan_id'] as String?,
      productName: json['product_name'] as String,
      quantity: asDouble(json['quantity']),
      unit: json['unit'] as String,
      pricePerUnit: asDouble(json['price_per_unit']),
      totalPrice: asDouble(json['total_price']),
      buyerName: json['buyer_name'] as String,
      sellerName: json['seller_name'] as String,
      sellerRole: json['seller_role'] as String,
      createdAt: DateTime.parse(json['created_at']),
      awaitingParty: json['awaiting_party'] as String?,
      orderId: json['order_id'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      expiredReason: json['expired_reason'] as String?,
      buyerPhone: json['buyer_phone_number'] as String?,
      buyerBarangay: json['buyer_barangay'] as String?,
      sellerBarangay: json['seller_barangay'] as String?,
      farmName: json['farm_name'] as String?,
      businessName: json['business_name'] as String?,
      deliveryDateStart: asDate(json['delivery_date_start']),
      deliveryDateEnd: asDate(json['delivery_date_end']),
      deliveryAddress: json['delivery_address'] as String?,
      notes: json['notes'] as String?,
      sellerPaymentMethods: (json['seller_payment_methods'] as List? ?? [])
          .cast<Map<String, dynamic>>(),
      cropPlanPricePerUnit: asDoubleOrNull(json['crop_plan_price_per_unit']),
    );
  }
}
