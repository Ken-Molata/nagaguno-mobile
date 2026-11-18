// lib/features/orders/domain/order.dart
//
// Re-verified against the real GET /orders / GET /orders/:id queries
// after reading routes/orders.js's full checkout + fulfillment +
// payment-proof contract this session. The fields added here
// (paymentMethod, fulfillmentMethod, paymentChannel, delivery/pickup
// fields, proof fields, gatewayCheckoutUrl) are not optional extras --
// POST /orders requires most of them, and nothing here was ever
// sending them, so every order placed from this app would have 400'd.

class OrderItem {
  const OrderItem({
    required this.id,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.subtotal,
    required this.productName,
    this.productImageUrl,
  });

  final String id;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double subtotal;
  final String productName;
  final String? productImageUrl;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return OrderItem(
      id: json['id'] as String,
      quantity: asDouble(json['quantity']),
      unit: json['unit'] as String,
      unitPrice: asDouble(json['unit_price']),
      subtotal: asDouble(json['subtotal']),
      productName: json['name'] as String,
      productImageUrl: json['image_url'] as String?,
    );
  }
}

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  dispatched,
  delivered,
  cancelled
}

enum ProofStatus { none, pending, verified, rejected }

class Order {
  const Order({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.totalAmount,
    required this.buyerName,
    required this.sellerName,
    required this.sellerRole,
    required this.items,
    required this.createdAt,
    this.notes,
    this.buyerAvatar,
    this.buyerRating,
    this.receiptNote,
    this.buyerPhone,
    this.sellerPhone,
    this.farmName,
    this.businessName,
    this.paymentMethod,
    this.paymentChannel,
    this.fulfillmentMethod,
    this.deliveryAddress,
    this.deliveryRecipientName,
    this.deliveryRecipientContact,
    this.deliveryNote,
    this.deliveryLat,
    this.deliveryLng,
    this.pickupDate,
    this.pickupTimeSlot,
    this.codSettlementLabel,
    this.scheduledAt,
    this.proofStatus = ProofStatus.none,
    this.paymentProofUrl,
    this.gatewayCheckoutUrl,
    this.sellerPaymentMethods = const [],
  });

  final String id;
  final String buyerId;
  final String sellerId;
  final OrderStatus status;
  final double totalAmount;
  final String buyerName;
  final String sellerName;
  final String sellerRole; // 'farmer' | 'vendor'
  final List<OrderItem> items;
  final DateTime createdAt;
  final String? notes;

  /// UW 12.2: the buyer's inline preview on the seller's order view.
  final String? buyerAvatar;
  final double? buyerRating;

  /// UW 13.2: a second, later note either party can add to the order
  /// record (most naturally at receipt confirmation), distinct from
  /// [notes] (set once at checkout) so neither can overwrite the other.
  final String? receiptNote;
  final String? buyerPhone;
  final String? sellerPhone;
  final String? farmName;
  final String? businessName;
  final String? paymentMethod; // 'cod' | 'online'
  final String? paymentChannel; // 'gateway' | 'manual_transfer' | null (COD)
  final String?
      fulfillmentMethod; // 'pickup' | 'vendor_delivery' | 'third_party_delivery'
  final String? deliveryAddress;
  final String? deliveryRecipientName;
  final String? deliveryRecipientContact;
  final String? deliveryNote;

  /// Shopee-style delivery pin, dropped by the buyer at checkout (or
  /// later via PATCH .../delivery-location) -- null when they skipped
  /// pinning and only typed the address.
  final double? deliveryLat;
  final double? deliveryLng;
  final DateTime? pickupDate;
  final String? pickupTimeSlot;
  final String? codSettlementLabel;

  /// Estimated delivery/pickup time, set once dispatched (or, for
  /// pickup, reschedulable while still preparing).
  final DateTime? scheduledAt;
  final ProofStatus proofStatus;
  final String? paymentProofUrl;

  /// Only present right after POST /orders when payment_channel is
  /// 'gateway' and PayMongo checkout session creation succeeded.
  final String? gatewayCheckoutUrl;

  /// UW 1.2/6.1: the seller's registered receiving details, included
  /// only for an 'online' order's buyer. Minimal raw passthrough, same
  /// as Agreement.sellerPaymentMethods.
  final List<Map<String, dynamic>> sellerPaymentMethods;

  bool get isPickup => fulfillmentMethod == 'pickup';

  String get sellerDisplayName => farmName ?? businessName ?? sellerName;

  String counterpartyName(String? currentUserId) {
    if (currentUserId == sellerId) return buyerName;
    return sellerDisplayName;
  }

  static OrderStatus _statusFrom(String? s) => OrderStatus.values
      .firstWhere((e) => e.name == s, orElse: () => OrderStatus.pending);
  static ProofStatus _proofFrom(String? s) => ProofStatus.values
      .firstWhere((e) => e.name == s, orElse: () => ProofStatus.none);

  factory Order.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    DateTime? asDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return Order(
      id: json['id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      status: _statusFrom(json['status'] as String?),
      totalAmount: asDouble(json['total_amount']),
      buyerName: json['buyer_name'] as String,
      sellerName: json['seller_name'] as String,
      sellerRole: json['seller_role'] as String,
      items: (json['items'] as List? ?? [])
          .where((i) =>
              i != null &&
              i['id'] !=
                  null) // LEFT JOIN can produce a single null-object row when an order somehow has no items
          .map((i) => OrderItem.fromJson(i))
          .toList(),
      createdAt: DateTime.parse(json['created_at']),
      notes: json['notes'] as String?,
      buyerAvatar: json['buyer_avatar'] as String?,
      buyerRating: json['buyer_rating'] != null
          ? double.tryParse(json['buyer_rating'].toString())
          : null,
      receiptNote: json['receipt_note'] as String?,
      buyerPhone: json['buyer_phone_number'] as String?,
      sellerPhone: json['seller_phone_number'] as String?,
      farmName: json['farm_name'] as String?,
      businessName: json['business_name'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentChannel: json['payment_channel'] as String?,
      fulfillmentMethod: json['fulfillment_method'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      deliveryRecipientName: json['delivery_recipient_name'] as String?,
      deliveryRecipientContact: json['delivery_recipient_contact'] as String?,
      deliveryNote: json['delivery_note'] as String?,
      deliveryLat: json['delivery_lat'] != null
          ? double.tryParse(json['delivery_lat'].toString())
          : null,
      deliveryLng: json['delivery_lng'] != null
          ? double.tryParse(json['delivery_lng'].toString())
          : null,
      pickupDate: asDate(json['pickup_date']),
      pickupTimeSlot: json['pickup_time_slot'] as String?,
      codSettlementLabel: json['cod_settlement_label'] as String?,
      scheduledAt: asDate(json['scheduled_at']),
      proofStatus: _proofFrom(json['proof_status'] as String?),
      paymentProofUrl: json['payment_proof_url'] as String?,
      gatewayCheckoutUrl: json['gateway_checkout_url'] as String?,
      sellerPaymentMethods: (json['seller_payment_methods'] as List? ?? [])
          .cast<Map<String, dynamic>>(),
    );
  }
}
