// lib/features/orders/data/orders_repository.dart
//
// Rewritten against the real routes/orders.js after reading its full
// checkout + fulfillment + payment-proof contract this session.
// placeOrder in particular was sending none of the fields
// validateFulfillment() requires -- every call would have 400'd.

import 'package:dio/dio.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/order.dart';

class OrdersRepository {
  OrdersRepository(this._client);
  final ApiClient _client;

  /// UW 6.1: Manual Transfer is only offered if the seller has at least
  /// one receiving method on file; checkout should disable the option
  /// up front with "Manual Transfer unavailable for this seller.", not
  /// let the buyer pick it and find out via a rejected order.
  Future<bool> checkManualTransferAvailability(String sellerId) async {
    final response =
        await _client.dio.get(ApiEndpoints.paymentMethodAvailability(sellerId));
    return response.data['data']['available'] as bool;
  }

  /// [view] should be 'buyer' when a farmer/vendor wants to see their
  /// own purchases instead of their sales (matches the backend's own
  /// view=buyer query param). Omit for the backend's default
  /// (seller-side for farmer/vendor, buyer-side for a buyer account).
  Future<List<Order>> getOrders({String? status, String? view}) async {
    final response =
        await _client.dio.get(ApiEndpoints.orders, queryParameters: {
      if (status != null && status != 'all') 'status': status,
      if (view != null) 'view': view,
    });
    return (response.data['data'] as List)
        .map((j) => Order.fromJson(j))
        .toList();
  }

  Future<Order> getOrderDetail(String id) async {
    final response = await _client.dio.get(ApiEndpoints.orderDetail(id));
    return Order.fromJson(response.data['data']);
  }

  /// Full checkout, matching the real POST /orders exactly
  /// (validateFulfillment() rejects anything short of this):
  /// - [paymentMethod]: 'cod' | 'online'.
  /// - [fulfillmentMethod]: 'pickup' | 'vendor_delivery' | 'third_party_delivery'.
  ///   Pickup is only valid with paymentMethod 'online'.
  /// - Pickup needs [pickupDate] + [pickupTimeSlot]; any other
  ///   fulfillment method needs [deliveryAddress] +
  ///   [deliveryRecipientName] + [deliveryRecipientContact].
  /// - Online needs [paymentChannel]: 'gateway' | 'manual_transfer'.
  /// Returns the created order, including gatewayCheckoutUrl when
  /// payment_channel is 'gateway' and PayMongo session creation
  /// succeeded (null otherwise -- the order still exists either way,
  /// retryable via [retryPayment]).
  /// UW/backend workflow: an idempotency key lets a retried submit (e.g.
  /// after a timeout) return the original order instead of creating a
  /// duplicate. Optional server-side -- a caller that omits it is just
  /// unprotected, not rejected -- so the same key should be reused
  /// across retries of ONE checkout attempt, not regenerated per call.
  Future<Order> placeOrder({
    required String sellerId,
    required List<({String productId, double quantity})> items,
    required String paymentMethod,
    required String fulfillmentMethod,
    String? paymentChannel,
    String? deliveryAddress,
    String? deliveryRecipientName,
    String? deliveryRecipientContact,
    String? deliveryNote,
    double? deliveryLat,
    double? deliveryLng,
    DateTime? pickupDate,
    String? pickupTimeSlot,
    String? codSettlementLabel,
    String? notes,
    String? idempotencyKey,
  }) async {
    final response = await _client.dio.post(
      ApiEndpoints.orders,
      options: idempotencyKey != null
          ? Options(headers: {'Idempotency-Key': idempotencyKey})
          : null,
      data: {
        'seller_id': sellerId,
        'items': items
            .map((i) => {'product_id': i.productId, 'quantity': i.quantity})
            .toList(),
        'payment_method': paymentMethod,
        'fulfillment_method': fulfillmentMethod,
        if (paymentChannel != null) 'payment_channel': paymentChannel,
        if (deliveryAddress != null) 'delivery_address': deliveryAddress,
        if (deliveryRecipientName != null)
          'delivery_recipient_name': deliveryRecipientName,
        if (deliveryRecipientContact != null)
          'delivery_recipient_contact': deliveryRecipientContact,
        if (deliveryNote != null && deliveryNote.isNotEmpty)
          'delivery_note': deliveryNote,
        if (deliveryLat != null) 'delivery_lat': deliveryLat,
        if (deliveryLng != null) 'delivery_lng': deliveryLng,
        if (pickupDate != null)
          'pickup_date': pickupDate.toIso8601String().split('T').first,
        if (pickupTimeSlot != null) 'pickup_time_slot': pickupTimeSlot,
        if (codSettlementLabel != null && codSettlementLabel.isNotEmpty)
          'cod_settlement_label': codSettlementLabel,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return Order.fromJson(response.data['data']);
  }

  /// [status] must be one of: confirmed, preparing, dispatched,
  /// delivered, cancelled. Cancelling requires a reason: sellers
  /// (declining a pending order) must pass [reasonCode] from the
  /// backend's COD_DECLINE_REASONS ('insufficient_quantity',
  /// 'settlement_method_unavailable', 'outside_service_area') or
  /// 'other' with [note]; a buyer cancelling their own pending order
  /// needs only a free-text [note].
  Future<void> updateOrderStatus(String orderId, String status,
      {String? reasonCode, String? note, DateTime? scheduledAt}) async {
    await _client.dio.patch(ApiEndpoints.orderStatus(orderId), data: {
      'status': status,
      if (reasonCode != null) 'reasonCode': reasonCode,
      if (note != null && note.isNotEmpty) 'note': note,
      if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
    });
  }

  /// Buyer-only. Returns a short-lived signed URL to the just-uploaded
  /// proof image.
  Future<String> uploadProof(String orderId, String filePath) async {
    final formData =
        FormData.fromMap({'proof': await MultipartFile.fromFile(filePath)});
    final response = await _client.dio
        .post(ApiEndpoints.orderProof(orderId), data: formData);
    return response.data['data']['url'] as String;
  }

  /// Seller-only. [proofStatus] must be 'verified' or 'rejected';
  /// rejecting requires [reasonCode] from the backend's
  /// PROOF_REJECT_REASONS or 'other' with [note].
  Future<void> respondToProof(String orderId,
      {required String proofStatus, String? reasonCode, String? note}) async {
    await _client.dio.patch(ApiEndpoints.orderDetail(orderId), data: {
      'proof_status': proofStatus,
      if (reasonCode != null) 'reasonCode': reasonCode,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Buyer-only: drops or updates the Shopee-style delivery pin, while
  /// the order is still pending/confirmed/preparing (before dispatch).
  Future<void> updateDeliveryLocation(
      String orderId, double lat, double lng) async {
    await _client.dio.patch(ApiEndpoints.orderDeliveryLocation(orderId),
        data: {'delivery_lat': lat, 'delivery_lng': lng});
  }

  /// Buyer-only, only valid while the order is still pending with
  /// payment_channel 'gateway' (UW 6.1: "buyer closed the gateway
  /// page"). Returns a fresh checkout URL to open.
  Future<String> retryPayment(String orderId) async {
    final response =
        await _client.dio.post(ApiEndpoints.orderRetryPayment(orderId));
    return response.data['data']['gateway_checkout_url'] as String;
  }

  /// Seller-only, Pickup orders only, while still Preparing. A
  /// notification trigger, not a status change.
  Future<void> readyForPickup(String orderId) async {
    await _client.dio.post(ApiEndpoints.orderReadyForPickup(orderId));
  }

  /// Buyer-only, at the point of fulfillment (Dispatched for
  /// delivery, Preparing for Pickup). Pass [pickupDate]/[pickupTimeSlot]
  /// for a Pickup order, [scheduledAt] otherwise. [reasonCode] must be
  /// one of the backend's FULFILLMENT_REASONS ('no_cash_on_hand',
  /// 'not_available', 'address_needs_correction') or 'other' with [note].
  Future<void> reschedule(
    String orderId, {
    DateTime? scheduledAt,
    DateTime? pickupDate,
    String? pickupTimeSlot,
    required String reasonCode,
    String? note,
  }) async {
    await _client.dio.patch(ApiEndpoints.orderReschedule(orderId), data: {
      if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
      if (pickupDate != null)
        'pickupDate': pickupDate.toIso8601String().split('T').first,
      if (pickupTimeSlot != null) 'pickupTimeSlot': pickupTimeSlot,
      'reasonCode': reasonCode,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Buyer-only, at the point of fulfillment. For a Cash-on-Delivery
  /// order, this is the specific event UW 17.1 counts toward
  /// Cash-on-Delivery abuse. Same FULFILLMENT_REASONS as [reschedule].
  Future<void> cancelAtFulfillment(String orderId,
      {required String reasonCode, String? note}) async {
    await _client.dio
        .post(ApiEndpoints.orderCancelAtFulfillment(orderId), data: {
      'reasonCode': reasonCode,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Seller-only. Declines an already-paid (Online Payment) order from
  /// Confirmed/Preparing; the backend restocks and auto-opens a refund
  /// request for the buyer. [reasonCode] must be one of the backend's
  /// PAID_DECLINE_REASONS ('insufficient_quantity',
  /// 'product_no_longer_available', 'outside_service_area') or 'other'
  /// with [note].
  Future<void> declinePaid(String orderId,
      {required String reasonCode, String? note}) async {
    await _client.dio.post(ApiEndpoints.orderDeclinePaid(orderId), data: {
      'reasonCode': reasonCode,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// UW 13.2: either party may attach a note to the order record at any
  /// time after placement, most naturally when confirming receipt.
  /// Distinct from [placeOrder]'s [notes], which is set once at checkout.
  Future<void> addReceiptNote(String orderId, String note) async {
    await _client.dio
        .patch(ApiEndpoints.orderNote(orderId), data: {'note': note});
  }
}
