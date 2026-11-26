// lib/features/orders/presentation/order_detail_screen.dart
//
// Extended after reading routes/orders.js's full fulfillment/payment
// contract this session. The previous version here only ever handled
// the plain confirm/preparing/dispatched/delivered/cancel path and
// got two things wrong against the real backend: a Pickup order has
// no Dispatched step and the SELLER (not buyer) marks it Delivered
// (UW 7.5), and cancelling a pending order actually requires a reason
// (seller: a predefined code; buyer: free text) that nothing here sent.
// Also adds payment-proof upload/review, retry payment, ready-for-
// pickup, reschedule, cancel-at-fulfillment, and decline-paid — all
// real, working endpoints with no mobile caller at all before this.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/map_pin_picker_screen.dart';
import '../../../core/localization/app_strings.dart';
import '../../authentication/application/auth_controller.dart';
import '../../buyer_mode/application/buyer_mode_controller.dart';
import '../../buyer_mode/presentation/widgets/buyer_mode_label.dart';
import '../../../shared/widgets/linear_progress_tracker.dart';
import '../../../shared/widgets/copyable_value.dart';
import '../../../core/utils/image_picking.dart';
import '../../../core/accessibility/read_aloud_button.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../domain/order.dart';
import 'orders_screen.dart';
import '../../reviews/presentation/review_dialog.dart';
import '../../reviews/presentation/product_review_dialog.dart';
import '../../conversations/data/conversations_repository.dart';
import '../../reports/presentation/report_user_screen.dart';
import '../../reports/domain/report_models.dart';
import '../../refunds/data/refunds_repository.dart';
import '../../refunds/presentation/request_refund_screen.dart';
import '../../refunds/presentation/refund_detail_screen.dart';

final _orderDetailProvider = FutureProvider.autoDispose.family(
  (ref, String id) => ref.watch(ordersRepositoryProvider).getOrderDetail(id),
);

const _codDeclineReasons = {
  'insufficient_quantity': 'Unable to fulfill the requested quantity',
  'settlement_method_unavailable':
      'Cannot accommodate the buyer\'s declared settlement method',
  'outside_service_area': 'Delivery address outside service area',
  'other': 'Other',
};

const _paidDeclineReasons = {
  'insufficient_quantity': 'Unable to fulfill the requested quantity',
  'product_no_longer_available': 'Product no longer available',
  'outside_service_area': 'Delivery address outside service area',
  'other': 'Other',
};

const _fulfillmentReasons = {
  'no_cash_on_hand': 'No cash on hand',
  'not_available': 'Not available at the scheduled time',
  'address_needs_correction': 'Delivery address needs correction',
  'other': 'Other',
};

const _proofRejectReasons = {
  'unreadable_or_incomplete': 'Proof image unreadable or incomplete',
  'amount_mismatch': 'Amount does not match the agreed price',
  'altered_or_inconsistent': 'Proof appears altered or inconsistent',
  'payment_not_received': 'Payment not received or not confirmed',
  'other': 'Other',
};

const _pickupTimeSlots = [
  '8:00 AM-12:00 PM',
  '12:00 PM-4:00 PM',
  '4:00 PM-8:00 PM'
];

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;
  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen>
    with WidgetsBindingObserver {
  bool _busy = false;

  // REAL BUG FOUND AND FIXED: this screen never refreshed itself after
  // the buyer returned from the external GCash/Xendit checkout page --
  // the Gateway webhook that flips the order from 'pending' to
  // 'confirmed' can land a few seconds to a few minutes after the
  // redirect back into the app (same root cause already documented on
  // retry-payment/cancel's own reconciliation, see _run's comment
  // below), so the buyer could keep looking at a stale 'pending' order
  // showing "Retry Payment" after already paying successfully, and
  // tapping the stale "Cancel" button on it hit PATCH /:id/status's
  // compare-and-set guard (order.status !== transition.from, now 409
  // since the real status had moved on) -- surfacing as a generic
  // "Something went wrong" with no indication the payment had actually
  // gone through. Returning to the app from the external browser fires
  // AppLifecycleState.resumed, so refreshing there catches the webhook
  // update without the buyer having to back out and re-open the order.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(_orderDetailProvider(widget.orderId));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      // REAL BUG FOUND AND FIXED: every error on this screen -- a
      // validation message ("A reason is required..."), or the new
      // "payment already went through" reconciliation response -- was
      // discarded in favor of one generic "Something went wrong"
      // string, and the order view never refreshed on a failed action
      // even when the backend had genuinely changed server-side state
      // (as the new retry-payment/cancel reconciliation does: it
      // updates the order to 'confirmed' even though it ALSO returns
      // an error response for the cancel/retry itself). Moving the
      // invalidate calls to `finally` below means the screen always
      // re-fetches, catching that server-side change either way.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      ref.invalidate(_orderDetailProvider(widget.orderId));
      ref.invalidate(ordersListProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateStatus(String status) => _run(() => ref
      .read(ordersRepositoryProvider)
      .updateOrderStatus(widget.orderId, status));

  // Opens the pinned delivery location in whatever maps app is
  // installed, via a plain geo: URI -- no API key needed, same free
  // choice as the OpenStreetMap-based picker itself. Falls back to
  // OpenStreetMap's own web page if no app handles geo: (e.g. desktop).
  Future<void> _openInMaps(double lat, double lng) async {
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!launched && mounted) {
      await launchUrl(
          Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng'),
          mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _updateDeliveryPin(Order order) async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPinPickerScreen(
          initialLocation: order.deliveryLat != null
              ? LatLng(order.deliveryLat!, order.deliveryLng!)
              : null,
        ),
      ),
    );
    if (picked == null) return;
    await _run(() => ref
        .read(ordersRepositoryProvider)
        .updateDeliveryLocation(widget.orderId, picked.latitude, picked.longitude));
  }

  Future<void> _declineFromPending(bool isSeller) async {
    final s = ref.read(appStringsProvider);
    if (isSeller) {
      final result = await _showReasonDialog(
          title: s.declineOrderTitle,
          reasons: {
            for (final k in _codDeclineReasons.keys) k: s.codDeclineReasonLabel(k)
          });
      if (result == null) return;
      await _run(() => ref.read(ordersRepositoryProvider).updateOrderStatus(
          widget.orderId, 'cancelled',
          reasonCode: result.$1, note: result.$2));
    } else {
      final note = await _showNoteDialog(
          title: s.cancelOrderTitle, label: s.reasonForCancellingLabel);
      if (note == null) return;
      // REAL GAP FOUND AND FIXED: a cancel refused because the Gateway
      // payment already went through (routes/orders.js's ALREADY_PAID
      // reconciliation response, added alongside the Xendit live-status
      // check) used to just show that message and stop -- correct that
      // the cancel shouldn't silently succeed on a paid order, but
      // leaving the buyer with no way to actually get their money back
      // either. Opens the real refund flow (previously unreachable
      // from anywhere in this app -- see refunds/domain/
      // refund_request.dart) right where the message already told them
      // to go.
      try {
        await ref
            .read(ordersRepositoryProvider)
            .updateOrderStatus(widget.orderId, 'cancelled', note: note);
      } on DioException catch (e) {
        if (e.response?.data is Map &&
            e.response?.data['code'] == 'ALREADY_PAID') {
          if (mounted) await _openRefund(allowCreate: true);
          return;
        }
        rethrow;
      } finally {
        ref.invalidate(_orderDetailProvider(widget.orderId));
        ref.invalidate(ordersListProvider);
      }
    }
  }

  /// Opens the refund request for this order if one already exists
  /// (either party may have filed/auto-opened one), or -- only when
  /// [allowCreate] -- starts a new one. Shared by the buyer's own
  /// "Request a Refund" button, the ALREADY_PAID cancel redirect above,
  /// and the seller's decline-paid flow below (which auto-opens one
  /// server-side at 'verified', so the seller always has an existing
  /// one to jump straight into).
  Future<void> _openRefund({required bool allowCreate}) async {
    try {
      final mine = await ref.read(refundsRepositoryProvider).getMine();
      final matches = mine.where((r) => r.orderId == widget.orderId);
      final existing = matches.isEmpty ? null : matches.first;
      if (!mounted) return;
      if (existing != null) {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RefundDetailScreen(refundId: existing.id)));
      } else if (allowCreate) {
        final orderAsync = ref.read(_orderDetailProvider(widget.orderId));
        final order = orderAsync.valueOrNull;
        if (order == null) return;
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RequestRefundScreen(
                orderId: widget.orderId,
                sellerName: order.sellerDisplayName)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      ref.invalidate(_orderDetailProvider(widget.orderId));
    }
  }

  Future<void> _retryPayment() async {
    await _run(() async {
      final url =
          await ref.read(ordersRepositoryProvider).retryPayment(widget.orderId);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    });
  }

  Future<void> _readyForPickup() => _run(
      () => ref.read(ordersRepositoryProvider).readyForPickup(widget.orderId));

  Future<void> _reschedule(Order order) async {
    final s = ref.read(appStringsProvider);
    DateTime? scheduledAt = order.scheduledAt;
    DateTime? pickupDate = order.pickupDate;
    String? pickupTimeSlot = order.pickupTimeSlot;
    String? reasonCode;
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
              order.isPickup ? s.reschedulePickupTitle : s.rescheduleDeliveryTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (order.isPickup) ...[
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: pickupDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 90)));
                      if (picked != null) {
                        setDialogState(() => pickupDate = picked);
                      }
                    },
                    child: Text(pickupDate == null
                        ? s.selectNewPickupDateLabel
                        : '${pickupDate!.year}-${pickupDate!.month}-${pickupDate!.day}'),
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: pickupTimeSlot,
                    decoration: InputDecoration(labelText: s.timeSlotLabel),
                    items: _pickupTimeSlots
                        .map((slot) =>
                            DropdownMenuItem(value: slot, child: Text(slot)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => pickupTimeSlot = v),
                  ),
                ] else
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: scheduledAt ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 90)));
                      if (picked != null) {
                        setDialogState(() => scheduledAt = picked);
                      }
                    },
                    child: Text(scheduledAt == null
                        ? s.selectNewDeliveryDateLabel
                        : '${scheduledAt!.year}-${scheduledAt!.month}-${scheduledAt!.day}'),
                  ),
                const SizedBox(height: AppSpacing.sm),
                RadioGroup<String>(
                  groupValue: reasonCode,
                  onChanged: (v) => setDialogState(() => reasonCode = v),
                  child: Column(
                    children: _fulfillmentReasons.keys
                        .map((key) => RadioListTile<String>(
                              title: Text(s.fulfillmentReasonLabel(key)),
                              value: key,
                              contentPadding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                ),
                if (reasonCode == 'other')
                  TextField(
                      controller: noteController,
                      decoration:
                          InputDecoration(labelText: s.pleaseSpecifyLabel)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(s.cancel)),
            TextButton(
                onPressed: reasonCode == null
                    ? null
                    : () => Navigator.of(dialogContext).pop(true),
                child: Text(s.confirmLabel)),
          ],
        ),
      ),
    );
    if (confirmed != true || reasonCode == null) return;

    await _run(() => ref.read(ordersRepositoryProvider).reschedule(
          widget.orderId,
          scheduledAt: order.isPickup ? null : scheduledAt,
          pickupDate: order.isPickup ? pickupDate : null,
          pickupTimeSlot: order.isPickup ? pickupTimeSlot : null,
          reasonCode: reasonCode!,
          note: noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        ));
  }

  Future<void> _cancelAtFulfillment() async {
    final s = ref.read(appStringsProvider);
    final result = await _showReasonDialog(
        title: s.cancelOrderTitle,
        reasons: {
          for (final k in _fulfillmentReasons.keys) k: s.fulfillmentReasonLabel(k)
        });
    if (result == null) return;
    await _run(() => ref.read(ordersRepositoryProvider).cancelAtFulfillment(
        widget.orderId,
        reasonCode: result.$1,
        note: result.$2));
  }

  Future<void> _declinePaid() async {
    final s = ref.read(appStringsProvider);
    final result = await _showReasonDialog(
        title: s.declineOrderTitle,
        reasons: {
          for (final k in _paidDeclineReasons.keys) k: s.paidDeclineReasonLabel(k)
        });
    if (result == null) return;
    await _run(() => ref
        .read(ordersRepositoryProvider)
        .declinePaid(widget.orderId, reasonCode: result.$1, note: result.$2));
    // routes/orders.js's decline-paid auto-opens a refund_requests row
    // straight at 'verified' (UW 7.2) -- the seller needs to act on it
    // (send the money, upload proof) right away, not hunt for it
    // separately; see _openRefund's own comment for why this is shared
    // with the other two refund entry points.
    if (mounted) await _openRefund(allowCreate: false);
  }

  Future<void> _uploadProof() async {
    final file = await pickAndCompressImage();
    if (file == null) return;
    await _run(() => ref
        .read(ordersRepositoryProvider)
        .uploadProof(widget.orderId, file.path));
  }

  Future<void> _verifyProof() => _run(() => ref
      .read(ordersRepositoryProvider)
      .respondToProof(widget.orderId, proofStatus: 'verified'));

  Future<void> _rejectProof() async {
    final s = ref.read(appStringsProvider);
    final result = await _showReasonDialog(
        title: s.rejectPaymentProofTitle,
        reasons: {
          for (final k in _proofRejectReasons.keys) k: s.proofRejectReasonLabel(k)
        });
    if (result == null) return;
    await _run(() => ref.read(ordersRepositoryProvider).respondToProof(
        widget.orderId,
        proofStatus: 'rejected',
        reasonCode: result.$1,
        note: result.$2));
  }

  Future<(String, String?)?> _showReasonDialog(
      {required String title, required Map<String, String> reasons}) {
    final s = ref.read(appStringsProvider);
    String? selected;
    final noteController = TextEditingController();
    return showDialog<(String, String?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (v) => setDialogState(() => selected = v),
                  child: Column(
                    children: reasons.entries
                        .map((e) => RadioListTile<String>(
                              title: Text(e.value),
                              value: e.key,
                            ))
                        .toList(),
                  ),
                ),
                if (selected == 'other')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                        controller: noteController,
                        decoration:
                            InputDecoration(labelText: s.pleaseSpecifyLabel)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(s.cancel)),
            TextButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.of(dialogContext)
                      .pop((selected!, noteController.text.trim())),
              child: Text(s.confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  // UW 13.2: either party may add a note to the order record at any
  // time after placement, distinct from the open message thread above
  // and from the buyer's own placement-time note shown below.
  Future<void> _addReceiptNote(Order order) async {
    final s = ref.read(appStringsProvider);
    final note = await _showNoteDialog(
        title: order.receiptNote == null ? s.addNoteTitle : s.editNoteTitle,
        label: s.noteLabel,
        initialValue: order.receiptNote);
    if (note == null) return;
    await _run(() =>
        ref.read(ordersRepositoryProvider).addReceiptNote(order.id, note));
  }

  // REAL BUG FIXED: Confirm's disabled state was computed once at
  // build time with nothing to react to the TextField's own changes --
  // a dialog that starts empty (every call site except the receipt-note
  // edit case added this session) could never be submitted at all.
  // Wrapped in StatefulBuilder, same pattern already used by
  // _showReasonDialog above.
  Future<String?> _showNoteDialog(
      {required String title, required String label, String? initialValue}) {
    final s = ref.read(appStringsProvider);
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: label),
              maxLines: 2,
              autofocus: true,
              onChanged: (_) => setDialogState(() {})),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(s.backLabel)),
            TextButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () =>
                      Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(s.confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(_orderDetailProvider(widget.orderId));
    final currentUser = ref.watch(authControllerProvider).user;
    final userId = currentUser?.id;
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.orderDetailsTitle)),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(s.couldntLoadOrder)),
        data: (order) {
          final isBuyer = userId != null && userId == order.buyerId;
          final isSeller = userId != null && userId == order.sellerId;
          final isPickup = order.isPickup;

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(children: [
                  Expanded(
                    // UW 12.2: on the seller's view, the buyer's name/
                    // photo opens their full profile (UW 12.4); the
                    // buyer's own view of the seller is unchanged --
                    // UW 12.2 only specifies this one direction.
                    child: isSeller
                        ? InkWell(
                            onTap: () =>
                                context.push('/buyers/${order.buyerId}'),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.backgroundStart,
                                  backgroundImage: order.buyerAvatar != null
                                      ? NetworkImage(order.buyerAvatar!)
                                      : null,
                                  child: order.buyerAvatar == null
                                      ? const Icon(Icons.person, size: 18)
                                      : null,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Flexible(
                                  child: Text(order.counterpartyName(userId),
                                      style: AppTypography.h1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                if (order.buyerRating != null) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  const Icon(Icons.star,
                                      size: 16, color: AppColors.accent),
                                  Text(order.buyerRating!.toStringAsFixed(1),
                                      style: AppTypography.bodySmall),
                                ],
                              ],
                            ),
                          )
                        : Text(order.counterpartyName(userId),
                            style: AppTypography.h1),
                  ),
                  if (isBuyerModeRecord(
                      viewerRole: currentUser?.role,
                      viewerId: userId,
                      recordBuyerId: order.buyerId)) ...[
                    const BuyerModeLabel(),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  // UW 13: message the other party about this order.
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () async {
                      final otherId = isBuyer ? order.sellerId : order.buyerId;
                      try {
                        final conversationId = await ref
                            .read(conversationsRepositoryProvider)
                            .openConversation(
                              recipientId: otherId,
                              context: 'order',
                              contextId: order.id,
                            );
                        if (context.mounted) {
                          context.push(
                              '/conversations/$conversationId?name=${Uri.encodeComponent(order.counterpartyName(userId))}');
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  s.couldntOpenConversationTryAgain)));
                        }
                      }
                    },
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                // UW 21.6 Read Aloud, for "order status text" --
                // self-hides when the setting is off.
                Align(
                  alignment: Alignment.centerRight,
                  child: ReadAloudButton(
                      text: s.orderStatusSpokenText(
                          s.orderStatusLabel(order.status.name))),
                ),
                _OrderProgressTracker(order: order, s: s),
                const SizedBox(height: AppSpacing.lg),

                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(
                                  '${item.productName} × ${item.quantity.toStringAsFixed(0)} ${item.unit}',
                                  style: AppTypography.body)),
                          Text('₱${item.subtotal.toStringAsFixed(2)}',
                              style: AppTypography.body
                                  .copyWith(fontWeight: FontWeight.w600)),
                          // UW 14.1: a separate review of this specific
                          // product, distinct from reviewing the seller
                          // below -- buyer-only, same Delivered gate.
                          if (isBuyer && order.status == OrderStatus.delivered)
                            IconButton(
                              icon: const Icon(Icons.star_outline, size: 20),
                              tooltip: s.reviewThisProductTooltip,
                              onPressed: () => showProductReviewDialog(
                                  context, ref,
                                  orderItemId: item.id,
                                  productName: item.productName),
                            ),
                        ],
                      ),
                    )),
                const Divider(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                        child: Text(s.totalWord, style: AppTypography.h3)),
                    Text('₱${order.totalAmount.toStringAsFixed(2)}',
                        style: AppTypography.h3),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                    label: s.paymentLabel,
                    value: order.paymentMethod == 'cod'
                        ? s.cashOnDeliveryLabel
                        : (order.paymentChannel == 'gateway'
                            ? s.onlineGatewayLabel
                            : s.onlineManualTransferLabel)),
                if (order.codSettlementLabel != null)
                  _DetailRow(
                      label: s.settlementNoteLabel,
                      value: order.codSettlementLabel == 'gcash'
                          ? s.gatewayGcashLabel
                          : s.cashLabel),
                if (isPickup) ...[
                  if (order.pickupDate != null)
                    _DetailRow(
                        label: s.pickupDateLabel, value: _fmt(order.pickupDate!)),
                  if (order.pickupTimeSlot != null)
                    _DetailRow(
                        label: s.pickupTimeLabel, value: order.pickupTimeSlot!),
                ] else ...[
                  if (order.deliveryAddress != null)
                    _DetailRow(
                        label: s.deliveryAddressLabel,
                        value: order.deliveryAddress!),
                  if (order.deliveryRecipientName != null)
                    _DetailRow(
                        label: s.recipientLabel,
                        value: order.deliveryRecipientName!),
                  if (order.deliveryRecipientContact != null)
                    _DetailRow(
                        label: s.contactLabel,
                        value: order.deliveryRecipientContact!),
                  // Shopee-style delivery pin: "Open in Maps" for
                  // whoever is viewing (seller most of all -- it's
                  // their directions), "Update" for the buyer only,
                  // and only while there's still time to act on a
                  // changed pin (before dispatch).
                  if (order.deliveryLat != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            _openInMaps(order.deliveryLat!, order.deliveryLng!),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Open in Maps'),
                      ),
                    ),
                  if (isBuyer &&
                      ![
                        OrderStatus.dispatched,
                        OrderStatus.delivered,
                        OrderStatus.cancelled
                      ].contains(order.status))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _updateDeliveryPin(order),
                        icon: const Icon(Icons.edit_location_alt_outlined,
                            size: 18),
                        label: Text(order.deliveryLat == null
                            ? 'Pin delivery location'
                            : 'Update pinned location'),
                      ),
                    ),
                  if (order.scheduledAt != null)
                    _DetailRow(
                        label: s.estimatedDeliveryLabel,
                        value: _fmt(order.scheduledAt!)),
                  // REAL GAP FOUND AND FIXED: "Third-Party Delivery"
                  // was just a bare fulfillment-method value with no
                  // explanation anywhere of what it actually means --
                  // neither party could tell from this screen alone
                  // that the BUYER is the one who books and pays their
                  // own courier here, not the seller (the opposite of
                  // Vendor Delivery). Role-specific wording since the
                  // two sides need to know different things: the buyer
                  // needs the "go arrange a courier" instruction, the
                  // seller just needs to know not to expect to deliver
                  // it themselves.
                  if (order.fulfillmentMethod == 'third_party_delivery') ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                          color: AppColors.backgroundStart,
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Text(
                          isSeller
                              ? s.thirdPartyDeliverySellerNote
                              : s.thirdPartyDeliveryExplanation,
                          style: AppTypography.bodySmall),
                    ),
                  ],
                ],
                if (order.notes != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(s.notesSectionTitle, style: AppTypography.label),
                  Text(order.notes!, style: AppTypography.body),
                ],
                // UW 13.2: a second note either party may add after
                // placement, kept separate from the buyer's own note above.
                if (order.receiptNote != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(s.noteLabel, style: AppTypography.label),
                  Text(order.receiptNote!, style: AppTypography.body),
                ],
                if (isBuyer || isSeller) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _addReceiptNote(order),
                      icon: const Icon(Icons.note_add_outlined, size: 18),
                      label: Text(order.receiptNote == null
                          ? s.addNoteButtonLabel
                          : s.editNoteButtonLabel),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),

                // ── Payment proof (Online — Manual Transfer only) ──
                if (order.paymentMethod == 'online' &&
                    order.paymentChannel == 'manual_transfer' &&
                    order.status == OrderStatus.pending) ...[
                  Text(s.paymentProofSectionTitle, style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.sm),
                  if (order.sellerPaymentMethods.isNotEmpty && isBuyer) ...[
                    Text(s.sendPaymentToLabel,
                        style: AppTypography.bodySmall),
                    // REAL BUG FOUND AND FIXED, live-confirmed: this
                    // read m['provider']/m['account_number']/
                    // m['account_details'] -- keys that never existed
                    // on the real payment-method shape routes/orders.js
                    // actually returns (gcash_number, bank_name,
                    // bank_account_number, bank_account_name -- see
                    // refund_detail_screen.dart's own proven-working
                    // rendering of the exact same shape). label ended
                    // up '' (not null, so CopyableValue still rendered
                    // its "label: value" format) and value ended up ''
                    // too -- a bare copy icon next to a lone colon,
                    // with nothing useful to actually copy.
                    ...order.sellerPaymentMethods.expand((m) => [
                          if (m['gcash_number'] != null)
                            CopyableValue(
                                label: 'GCash',
                                value: m['gcash_number'].toString()),
                          if (m['bank_name'] != null)
                            CopyableValue(
                                label: m['bank_name'].toString(),
                                value:
                                    '${m['bank_account_number']} (${m['bank_account_name']})'),
                        ]),
                    const SizedBox(height: AppSpacing.xs),
                    // UW 6.1's exact reminder, shown alongside the
                    // receiving details -- previously absent entirely.
                    _PaymentReminder(s.paymentReminderBeforeSending),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (order.paymentProofUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Image.network(order.paymentProofUrl!,
                          height: 200, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // UW 6.2's exact reminder, shown to the seller
                  // alongside the proof they're about to accept/reject.
                  if (isSeller &&
                      order.proofStatus == ProofStatus.pending) ...[
                    _PaymentReminder(s.paymentReminderBeforeAccepting),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Text(_proofStatusLabel(order.proofStatus, s),
                      style: AppTypography.bodySmall.copyWith(
                          color: _proofStatusColor(order.proofStatus))),
                  const SizedBox(height: AppSpacing.sm),
                  if (isBuyer &&
                      (order.proofStatus == ProofStatus.none ||
                          order.proofStatus == ProofStatus.rejected))
                    ElevatedButton.icon(
                        onPressed: _busy ? null : _uploadProof,
                        icon: const Icon(Icons.upload_file),
                        label: Text(s.uploadPaymentProofLabel)),
                  if (isSeller && order.proofStatus == ProofStatus.pending)
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: _busy ? null : _rejectProof,
                              child: Text(s.rejectLabel))),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: ElevatedButton(
                              onPressed: _busy ? null : _verifyProof,
                              child: Text(s.verifyLabel))),
                    ]),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ── Retry payment (Gateway, still pending) ──
                if (isBuyer &&
                    order.status == OrderStatus.pending &&
                    order.paymentChannel == 'gateway') ...[
                  ElevatedButton.icon(
                      onPressed: _busy ? null : _retryPayment,
                      icon: const Icon(Icons.replay),
                      label: Text(s.retryPaymentLabel)),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // ── Seller-side status actions ──
                // REAL BUG FOUND AND FIXED: this button was shown for every
                // Pending order including Manual Transfer ones, calling the
                // exact same generic status-update endpoint the proof-verify
                // action does NOT gate on proof_status either -- a seller
                // could "Confirm Order" a Manual Transfer order without ever
                // reviewing the buyer's payment proof above, bypassing UW
                // 6.2's entire review step. Confirmation for Manual Transfer
                // now only ever happens via Verify (which already flips
                // status to 'confirmed' itself) -- this button is COD-only.
                if (isSeller &&
                    order.status == OrderStatus.pending &&
                    order.paymentChannel != 'manual_transfer')
                  ElevatedButton(
                      onPressed:
                          _busy ? null : () => _updateStatus('confirmed'),
                      child: Text(s.confirmOrderLabel)),
                if (isSeller && order.status == OrderStatus.confirmed) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton(
                      onPressed:
                          _busy ? null : () => _updateStatus('preparing'),
                      child: Text(s.markAsPreparingLabel)),
                ],
                if (isSeller &&
                    order.status == OrderStatus.preparing &&
                    !isPickup) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton(
                      onPressed:
                          _busy ? null : () => _updateStatus('dispatched'),
                      child: Text(s.markAsDispatchedLabel)),
                ],
                if (isSeller &&
                    order.status == OrderStatus.preparing &&
                    isPickup) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                      onPressed: _busy ? null : _readyForPickup,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text(s.notifyReadyForPickupLabel)),
                  const SizedBox(height: AppSpacing.sm),
                  // UW 7.5: Pickup has no Dispatched step — the seller
                  // marks it Delivered directly from Preparing.
                  ElevatedButton(
                      onPressed:
                          _busy ? null : () => _updateStatus('delivered'),
                      child: Text(s.markAsPickedUpLabel)),
                ],
                if (isSeller &&
                    (order.status == OrderStatus.confirmed ||
                        order.status == OrderStatus.preparing) &&
                    order.paymentMethod == 'online') ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: _busy ? null : _declinePaid,
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error),
                    child: Text(s.declineOrderRefundBuyerLabel),
                  ),
                ],

                // ── Buyer-side status actions ──
                // UW 7.5: for Vendor/Third-Party Delivery the buyer marks
                // Delivered from Dispatched; Pickup has no such step for
                // the buyer at all (the seller handles it above).
                if (isBuyer &&
                    order.status == OrderStatus.dispatched &&
                    !isPickup)
                  ElevatedButton(
                      onPressed:
                          _busy ? null : () => _updateStatus('delivered'),
                      child: Text(s.markAsReceivedLabel)),
                if (isBuyer && order.status == OrderStatus.pending) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _declineFromPending(false),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error),
                    child: Text(s.cancelOrderTitle),
                  ),
                ],
                // UW 9.4: a buyer who paid online can request a refund
                // regardless of status (the real backend has no status
                // restriction either) -- not just as the ALREADY_PAID
                // cancel redirect's fallback. _openRefund reuses
                // whatever request already exists rather than letting
                // a second one be filed for the same order.
                if (isBuyer && order.paymentMethod == 'online') ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed:
                        _busy ? null : () => _openRefund(allowCreate: true),
                    child: const Text('Request a Refund'),
                  ),
                ],
                if (isSeller && order.status == OrderStatus.pending) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _declineFromPending(true),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error),
                    child: Text(s.declineOrderTitle),
                  ),
                ],

                // UW 14.1/14.2: either party may review the other once
                // the order reaches a final outcome. No "already
                // reviewed" flag exists on the order itself, so a
                // repeat attempt just surfaces the real backend's own
                // 409 message rather than this screen tracking that
                // state separately.
                //
                // REAL GAP FOUND AND FIXED: this used to only show for
                // Delivered -- a cancelled order is just as real and
                // finished an interaction with this counterparty
                // (routes/reviews.js now accepts it too, for the same
                // reason: "they cancelled on me" is honest, legitimate
                // feedback, not a review from someone who never
                // actually transacted with this person at all). The
                // product-specific review button above stays
                // Delivered-only on purpose -- you can't honestly rate
                // a product's quality from an order you never
                // received.
                if (order.status == OrderStatus.delivered ||
                    order.status == OrderStatus.cancelled) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => showReviewDialog(context, ref,
                        orderId: order.id,
                        counterpartyName: order.counterpartyName(userId)),
                    icon: const Icon(Icons.star_outline),
                    label: Text(s.leaveAReviewLabel),
                  ),
                ],

                // ── Buyer, at the point of fulfillment (UW 7.4) ──
                if (isBuyer &&
                    ((order.status == OrderStatus.dispatched && !isPickup) ||
                        (order.status == OrderStatus.preparing &&
                            isPickup))) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: _busy ? null : () => _reschedule(order),
                            child: Text(isPickup
                                ? s.reschedulePickupTitle
                                : s.rescheduleDeliveryTitle))),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _cancelAtFulfillment,
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            foregroundColor: AppColors.error),
                        child: Text(s.cancel),
                      ),
                    ),
                  ]),
                ],

                // UW 7.6: Delivery fulfillment only ("Pickup... has no
                // delivery date to miss, since the buyer either
                // collects in person or reschedules/cancels doing
                // so"), only once the estimated delivery time has
                // actually passed, and only while the order hasn't
                // already reached a terminal state -- matching
                // routes/reports.js's own server-side gate exactly, so
                // this button simply isn't offered rather than being
                // shown and then rejected.
                if (isBuyer &&
                    !isPickup &&
                    order.status != OrderStatus.delivered &&
                    order.status != OrderStatus.cancelled &&
                    order.scheduledAt != null &&
                    order.scheduledAt!.isBefore(DateTime.now())) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReportUserScreen(
                        reportedUserId: order.sellerId,
                        reportedUserName: order.sellerName,
                        fixedGroup: ViolationGroup.nonArrival,
                        orderId: order.id,
                      ),
                    )),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error),
                    icon: const Icon(Icons.report_outlined, size: 18),
                    label: Text(s.reportOrderNotArrivedLabel),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _proofStatusLabel(ProofStatus status, AppStrings s) => switch (status) {
        ProofStatus.none => s.proofNoneLabel,
        ProofStatus.pending => s.proofPendingLabel,
        ProofStatus.verified => s.proofVerifiedLabel,
        ProofStatus.rejected => s.proofRejectedLabel,
      };

  Color _proofStatusColor(ProofStatus s) => switch (s) {
        ProofStatus.none => AppColors.textMuted,
        ProofStatus.pending => AppColors.accentDark,
        ProofStatus.verified => AppColors.statusSuccessFg,
        ProofStatus.rejected => AppColors.statusCancelledFg,
      };
}

/// UW 6.1/6.2's two near-identical Manual Transfer disclaimers -- real
/// backend/spec copy, reused verbatim, not reworded.
class _PaymentReminder extends StatelessWidget {
  const _PaymentReminder(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.verificationPendingBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.accentDark),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text, style: AppTypography.bodySmall)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    // REAL BUG FOUND AND FIXED: `value` was a plain, unbounded Row
    // child -- fine for a short value ("Nicole Kidman", "09810185943"),
    // but a long one (a full delivery address) demanded enough width
    // to squeeze the Expanded label down to near-zero, wrapping it one
    // character per line (confirmed live: "Delivery Address" rendered
    // as a vertical column of single characters around the address
    // value). Same bug class as cart_screen.dart's checkout bar, just
    // the unbounded sibling and the starved one are swapped. Giving
    // both a flex share means neither can ever collapse the other --
    // a long value now wraps onto its own lines instead.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 2,
              child: Text(label, style: AppTypography.bodySmall)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.right,
                style: AppTypography.body
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Uses the shared LinearProgressTracker (see shared/widgets/
/// linear_progress_tracker.dart). Pickup has no Dispatched step (UW
/// 7.5), so a Pickup order's tracker omits that step entirely rather
/// than showing a step the backend's own TRANSITIONS table skips.
class _OrderProgressTracker extends StatelessWidget {
  const _OrderProgressTracker({required this.order, required this.s});
  final Order order;
  final AppStrings s;

  List<(OrderStatus, ProgressStep)> _deliverySteps() => [
        (
          OrderStatus.pending,
          ProgressStep(label: s.statusPending, icon: Icons.receipt_long_outlined)
        ),
        (
          OrderStatus.confirmed,
          ProgressStep(
              label: s.statusConfirmed, icon: Icons.check_circle_outline)
        ),
        (
          OrderStatus.preparing,
          ProgressStep(
              label: s.statusPreparing, icon: Icons.inventory_2_outlined)
        ),
        (
          OrderStatus.dispatched,
          ProgressStep(
              label: s.statusDispatched, icon: Icons.local_shipping_outlined)
        ),
        (
          OrderStatus.delivered,
          ProgressStep(label: s.statusDelivered, icon: Icons.home_outlined)
        ),
      ];

  List<(OrderStatus, ProgressStep)> _pickupSteps() => [
        (
          OrderStatus.pending,
          ProgressStep(label: s.statusPending, icon: Icons.receipt_long_outlined)
        ),
        (
          OrderStatus.confirmed,
          ProgressStep(
              label: s.statusConfirmed, icon: Icons.check_circle_outline)
        ),
        (
          OrderStatus.preparing,
          ProgressStep(
              label: s.statusPreparing, icon: Icons.inventory_2_outlined)
        ),
        (
          OrderStatus.delivered,
          ProgressStep(label: s.pickedUpLabel, icon: Icons.home_outlined)
        ),
      ];

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.cancelled) {
      return CancelledStatusBanner(label: s.orderCancelledLabel);
    }
    final steps = order.isPickup ? _pickupSteps() : _deliverySteps();
    final currentIndex = steps.indexWhere((step) => step.$1 == order.status);
    return LinearProgressTracker(
        steps: steps.map((step) => step.$2).toList(),
        currentIndex: currentIndex,
        labelWidth: 56);
  }
}
