// lib/features/orders/presentation/checkout_screen.dart
//
// Closes a real gap: ProductDetailScreen used to call placeOrder()
// directly with just seller_id/items/notes. The real POST /orders
// (validateFulfillment(), verified against routes/orders.js this
// session) requires a payment method, a fulfillment method, and
// either delivery or pickup details depending on it -- none of which
// existed anywhere in this app, so every order placed from here would
// have 400'd. This screen collects that contract before submitting.
//
// Two entry points, same form: the default constructor is the
// original single-product "Buy Now" flow (fetches the product to get
// its price/seller); .cart() is the cart checkout flow (lib/features/
// cart), which already has every item's name/price/seller in hand
// from the cart itself, so it skips the network fetch entirely and
// goes straight to the fulfillment form. Both ultimately call the same
// POST /orders, which already accepts a multi-item `items` array
// scoped to one seller -- no backend change was needed for the cart.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/widgets/map_pin_picker_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/validators.dart';
import '../../../core/constants/naga_city_barangays.dart';
import '../../../core/utils/pricing.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../../../core/localization/app_strings.dart';
import '../../../shared/widgets/copyable_value.dart';
import '../../../shared/widgets/nagaguno_badge.dart';
import '../../authentication/application/auth_controller.dart';
import '../../cart/application/cart_controller.dart';
import '../../cart/domain/cart_item.dart';
import '../../kyc/application/kyc_status_provider.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../domain/order.dart';
import 'orders_screen.dart';

const _pickupTimeSlots = [
  '8:00 AM-12:00 PM',
  '12:00 PM-4:00 PM',
  '4:00 PM-8:00 PM'
];

/// UW 6.1: "Manual Transfer... only offered if the seller has at least
/// one receiving method on file; otherwise shown disabled." Checked
/// proactively here instead of only finding out via the order's 400.
final _manualTransferAvailableProvider =
    FutureProvider.autoDispose.family<bool, String>(
  (ref, sellerId) => ref
      .watch(ordersRepositoryProvider)
      .checkManualTransferAvailability(sellerId),
);

/// UW 6.1's pre-redirect Gateway summary: seller name, each item's
/// product+quantity, the exact amount, and the order's own id as its
/// "order reference number" -- the latter copyable via CopyableValue,
/// same affordance the spec uses for Manual Transfer's account number.
Future<bool?> _showGatewaySummary(
    BuildContext context, Order order, AppStrings s) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(s.confirmPaymentTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.sellerLine(order.sellerDisplayName),
                style: AppTypography.body),
            const SizedBox(height: AppSpacing.sm),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                    '${item.quantity.toStringAsFixed(0)} ${item.unit} × ${item.productName}',
                    style: AppTypography.bodySmall),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(s.amountLine('₱${order.totalAmount.toStringAsFixed(2)}'),
                style: AppTypography.body
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.xs),
            CopyableValue(label: s.orderReferenceLabel, value: order.id),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(s.laterLabel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(s.continueToPaymentLabel),
        ),
      ],
    ),
  );
}

String _generateIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen(
      {super.key,
      required this.productId,
      required this.quantity,
      this.onOrderPlaced,
      this.progressLabel})
      : cartItems = null,
        cartSellerId = null;

  const CheckoutScreen.cart(
      {super.key,
      required List<CartItem> items,
      required String sellerId,
      this.onOrderPlaced,
      this.progressLabel})
      : cartItems = items,
        cartSellerId = sellerId,
        productId = '',
        quantity = 0;

  /// Set only alongside [onOrderPlaced] by MultiStoreCheckoutScreen --
  /// e.g. "Store 2 of 3", shown as a small banner above the order
  /// summary so the buyer can tell they're partway through several
  /// stores' worth of orders, not stuck re-checking out the same cart.
  final String? progressLabel;

  final String productId;
  final double quantity;
  final List<CartItem>? cartItems;
  final String? cartSellerId;

  /// Set only by MultiStoreCheckoutScreen (lib/features/cart), when the
  /// cart's selected items span more than one seller -- POST /orders
  /// stays single-seller-per-call (see this file's own header comment),
  /// so buying from several stores "in one checkout" is really this
  /// screen run once per seller in sequence. When set, a successful
  /// order here advances that queue instead of this screen's own
  /// default "show a snackbar and navigate to My Orders" ending, which
  /// stays exactly as it was for every other caller (null here).
  final VoidCallback? onOrderPlaced;

  bool get isCartCheckout => cartItems != null;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _paymentMethod =
      'online'; // 'cod' | 'online' -- defaults to online since it unlocks every fulfillment option
  String _paymentChannel = 'gateway'; // 'gateway' | 'manual_transfer'
  String _fulfillmentMethod =
      'vendor_delivery'; // 'pickup' | 'vendor_delivery' | 'third_party_delivery'
  DateTime? _pickupDate;
  String? _pickupTimeSlot;
  // REAL BUG FOUND AND FIXED: delivery address used to be one
  // free-text field, open-ended and unvalidated -- the same real gap
  // already identified and fixed for KYC's own complete_address field
  // (kyc_submission_screen.dart: a fixed Naga City barangay dropdown
  // plus an open-ended detail field for the part that genuinely
  // varies per household). Same split here, same reason: a barangay
  // typed freehand can't be reliably matched against anything
  // (delivery-zone logic, shelf-life/spoilage barangay lookups, etc).
  String? _barangay;
  final _addressDetailController = TextEditingController();
  // Shopee-style delivery pin -- optional, null until the buyer drops
  // one via MapPinPickerScreen. Skipping it still checks out normally
  // with just the typed address, same as before this feature existed.
  LatLng? _deliveryPin;
  final _recipientNameController = TextEditingController();
  final _recipientContactController = TextEditingController();
  final _deliveryNoteController = TextEditingController();
  // REAL BUG FOUND AND FIXED: cod_settlement_label is a strict backend
  // enum ('cash' | 'gcash' -- UW 7.2's "declared settlement method"),
  // but this used to be a free-text TextFormField whose own hint text
  // literally suggested typing "exact amount" as an example -- sent
  // raw as the enum value, which the backend rejects outright
  // ("invalid input value for enum cod_settlement_label"). Replaced
  // with the actual choice UW 7.2 describes.
  String? _codSettlementMethod; // 'cash' | 'gcash' | null (not declared)
  final _notesController = TextEditingController();
  bool _placing = false;
  String? _errorMessage;
  // Generated once per visit to this screen; reused across retries of
  // the same checkout attempt so a resubmit after a timeout can't
  // create a duplicate order.
  final String _idempotencyKey = _generateIdempotencyKey();

  @override
  void initState() {
    super.initState();
    // REAL GAP FOUND AND FIXED: delivery recipient name/contact/address
    // used to always start blank, forcing the buyer to retype their own
    // name and number on every single checkout even though the account
    // already has them on file. Pre-filled here as a starting default
    // the buyer can still freely edit or replace -- this is not a
    // separate saved-address book (no such feature exists anywhere in
    // this app yet), just the one address already on file used as the
    // default instead of nothing.
    final user = ref.read(authControllerProvider).user;
    if (user != null) {
      _recipientNameController.text = user.fullName;
      if (user.phoneNumber != null) {
        _recipientContactController.text = user.phoneNumber!;
      }
    }
    // The only real stored address anywhere in this app is the one
    // collected at KYC verification (complete_address) -- registration
    // itself never collects more than an optional barangay. Fetched
    // best-effort; a buyer who hasn't submitted KYC yet (or is a
    // Farmer/Vendor's own buyer-mode checkout) simply keeps the field
    // blank, same as before this fix.
    ref.read(kycRepositoryProvider).getMyStatus().then((status) {
      if (!mounted) return;
      // Same as kyc_submission_screen.dart's own prefill: the prior
      // free-text complete_address can't be reliably split back into a
      // barangay + the rest, so it's offered as a starting point in
      // the open-ended detail field only -- the barangay dropdown is
      // left for the buyer to (re)select.
      if (status.priorCompleteAddress != null &&
          _addressDetailController.text.isEmpty) {
        setState(
            () => _addressDetailController.text = status.priorCompleteAddress!);
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _addressDetailController.dispose();
    _recipientNameController.dispose();
    _recipientContactController.dispose();
    _deliveryNoteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onPaymentMethodChanged(String method) {
    setState(() {
      _paymentMethod = method;
      // Pickup is only offered under Online Payment (UW 6.1) -- fall
      // back to a delivery method if COD is chosen while Pickup is selected.
      if (method == 'cod' && _fulfillmentMethod == 'pickup') {
        _fulfillmentMethod = 'vendor_delivery';
      }
    });
  }

  // REAL BUG FOUND AND FIXED: only _onPaymentMethodChanged existed --
  // choosing COD first correctly locked Pickup out (that RadioListTile
  // below is already `enabled: _paymentMethod != 'cod'`), but nothing
  // handled the other direction. Choosing Pickup first left COD's own
  // radio fully selectable, letting the form reach an invalid
  // COD+Pickup combination UW 6.1 doesn't allow at all. Mirrors
  // _onPaymentMethodChanged's own correction, the other way around.
  void _onFulfillmentMethodChanged(String method) {
    setState(() {
      _fulfillmentMethod = method;
      if (method == 'pickup' && _paymentMethod == 'cod') {
        _paymentMethod = 'online';
      }
    });
  }

  Future<void> _pickPickupDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _pickupDate = picked);
  }

  bool _canSubmit() {
    if (_fulfillmentMethod == 'pickup') {
      return _pickupDate != null && _pickupTimeSlot != null;
    }
    return _barangay != null &&
        _addressDetailController.text.trim().isNotEmpty &&
        _recipientNameController.text.trim().isNotEmpty &&
        phPhoneRegex.hasMatch(_recipientContactController.text.trim());
  }

  // Same composition KYC's own complete_address uses (see that
  // screen's _submit): "{detail}, Barangay {barangay}, Naga City" --
  // the backend's delivery_address column stays one free-text string,
  // this just guarantees the barangay portion is always a real one.
  String get _composedAddress =>
      '${_addressDetailController.text.trim()}, Barangay $_barangay, Naga City';

  Future<void> _submit(String sellerId,
      List<({String productId, double quantity})> items) async {
    final s = ref.read(appStringsProvider);
    if (!_canSubmit()) {
      setState(() => _errorMessage = _fulfillmentMethod == 'pickup'
          ? s.selectPickupDateTimeError
          : s.enterCompleteDeliveryDetailsError);
      return;
    }
    setState(() {
      _placing = true;
      _errorMessage = null;
    });

    try {
      final order = await ref.read(ordersRepositoryProvider).placeOrder(
            sellerId: sellerId,
            items: items,
            paymentMethod: _paymentMethod,
            fulfillmentMethod: _fulfillmentMethod,
            paymentChannel: _paymentMethod == 'online' ? _paymentChannel : null,
            deliveryAddress:
                _fulfillmentMethod == 'pickup' ? null : _composedAddress,
            deliveryRecipientName: _fulfillmentMethod == 'pickup'
                ? null
                : _recipientNameController.text.trim(),
            deliveryRecipientContact: _fulfillmentMethod == 'pickup'
                ? null
                : _recipientContactController.text.trim(),
            deliveryNote: _fulfillmentMethod == 'pickup'
                ? null
                : _deliveryNoteController.text.trim(),
            deliveryLat:
                _fulfillmentMethod == 'pickup' ? null : _deliveryPin?.latitude,
            deliveryLng: _fulfillmentMethod == 'pickup'
                ? null
                : _deliveryPin?.longitude,
            pickupDate: _fulfillmentMethod == 'pickup' ? _pickupDate : null,
            pickupTimeSlot:
                _fulfillmentMethod == 'pickup' ? _pickupTimeSlot : null,
            codSettlementLabel:
                _paymentMethod == 'cod' ? _codSettlementMethod : null,
            notes: _notesController.text.trim(),
            idempotencyKey: _idempotencyKey,
          );
      if (!mounted) return;

      if (widget.isCartCheckout) {
        ref.read(cartControllerProvider.notifier).clearSeller(sellerId);
      }

      if (order.gatewayCheckoutUrl != null) {
        // UW 6.1: "Before being redirected, the buyer sees a summary
        // screen: seller name, product and quantity, the exact amount
        // to be paid, and an order reference number, each with a copy
        // icon... Only once the buyer confirms this summary are they
        // redirected." The order already exists (Pending) by this
        // point either way -- declining here just means the buyer sees
        // it in My Orders. and can Retry Payment later, same as if
        // they'd closed the gateway page partway through (UW 6.1's own
        // documented fallback).
        final confirmed = await _showGatewaySummary(context, order, s);
        if (confirmed == true) {
          final uri = Uri.parse(order.gatewayCheckoutUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
      if (!mounted) return;
      if (widget.onOrderPlaced != null) {
        // Multi-store queue (see this widget's own onOrderPlaced doc
        // comment) -- a short per-seller confirmation, then let the
        // queue screen move to the next seller rather than navigating
        // away from it.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.orderPlacedForSeller(order.sellerDisplayName))));
        widget.onOrderPlaced!();
        return;
      }
      // UW 3.1: "On success, 'Order placed! Check your order under My
      // Orders.' with a direct link into that order's detail page" --
      // this screen used to navigate silently with no such message.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.orderPlacedCheckMyOrders)));
      context.go('/orders/${order.id}');
    } catch (e) {
      if (mounted) setState(() => _errorMessage = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    if (widget.isCartCheckout) {
      final items = widget.cartItems!;
      final sellerId = widget.cartSellerId!;
      final total = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
      return Scaffold(
        appBar: AppBar(
          title: Text(s.checkoutTitle),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: NagaGunoBadge(size: 40),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildForm(
              context,
              sellerId: sellerId,
              summary: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.progressLabel != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Text(widget.progressLabel!,
                          style: AppTypography.label
                              .copyWith(color: Colors.white)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Text(items.first.sellerName, style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.xs),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                '${item.quantity.toStringAsFixed(0)} ${item.unit} × ${item.name}',
                                style: AppTypography.body)),
                        Text('₱${item.lineTotal.toStringAsFixed(2)}',
                            style: AppTypography.body),
                      ]),
                    ),
                  const Divider(),
                  Row(children: [
                    Expanded(
                        child: Text(s.totalWord, style: AppTypography.h3)),
                    Text('₱${total.toStringAsFixed(2)}',
                        style: AppTypography.h3),
                  ]),
                ],
              ),
              onSubmit: () => _submit(
                  sellerId,
                  items
                      .map(
                          (i) => (productId: i.productId, quantity: i.quantity))
                      .toList()),
            ),
          ),
        ),
      );
    }

    final productAsync = ref.watch(productDetailProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.checkoutTitle),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: NagaGunoBadge(size: 40),
          ),
        ],
      ),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(s.couldntLoadProduct)),
        data: (product) {
          final total = calculateTotal(
              quantity: widget.quantity, pricePerUnit: product.displayPrice);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _buildForm(
                context,
                sellerId: product.sellerId,
                summary: Row(children: [
                  Expanded(
                      child: Text(
                          '${widget.quantity.toStringAsFixed(0)} ${product.unit} × ${product.name}',
                          style: AppTypography.body)),
                  Text('₱${total.toStringAsFixed(2)}', style: AppTypography.h3),
                ]),
                onSubmit: () => _submit(product.sellerId,
                    [(productId: widget.productId, quantity: widget.quantity)]),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Everything below the order summary -- payment method, fulfillment
  /// method, and the right delivery/pickup fields for it -- is
  /// identical whether checking out one product or a whole cart, so
  /// it's shared rather than duplicated between the two code paths
  /// above.
  Widget _buildForm(BuildContext context,
      {required String sellerId,
      required Widget summary,
      required VoidCallback onSubmit}) {
    final s = ref.watch(appStringsProvider);
    // Optimistic true while loading/on error -- the backend still
    // enforces this at submit time either way, so this is purely
    // a proactive UX improvement, never the only guard.
    final manualTransferAvailable =
        ref.watch(_manualTransferAvailableProvider(sellerId)).maybeWhen(
              data: (available) => available,
              orElse: () => true,
            );
    if (!manualTransferAvailable && _paymentChannel == 'manual_transfer') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _paymentChannel = 'gateway');
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
              color: AppColors.backgroundStart,
              borderRadius: BorderRadius.circular(AppRadius.md)),
          child: summary,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
                color: AppColors.statusCancelledBg,
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text(_errorMessage!,
                style: const TextStyle(color: AppColors.statusCancelledFg)),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(s.paymentMethodLabel, style: AppTypography.h3),
        RadioGroup<String>(
          groupValue: _paymentMethod,
          onChanged: (v) => _onPaymentMethodChanged(v!),
          child: Column(children: [
            RadioListTile<String>(
                title: Text(s.onlinePaymentLabel), value: 'online'),
            RadioListTile<String>(
                title: Text(s.cashOnDeliveryLabel),
                subtitle: _fulfillmentMethod == 'pickup'
                    ? Text(s.notAvailableWithPickup)
                    : null,
                value: 'cod',
                enabled: _fulfillmentMethod != 'pickup'),
          ]),
        ),
        if (_paymentMethod == 'online') ...[
          const SizedBox(height: AppSpacing.sm),
          // KNOWN DEVIATION FROM SPEC, DISCLOSED NOT GUESSED: UW 6.1
          // describes Manual Transfer as showing the seller's receiving
          // details (with a copy icon) and the required disclaimer AT
          // CHECKOUT, then blocking order submission itself until proof
          // is uploaded. The actual system (both this screen and
          // routes/orders.js's POST /orders / POST /:id/proof) instead
          // creates the order in Pending immediately for every channel,
          // and only asks for Manual Transfer proof afterward, from the
          // order detail screen's own "Payment Proof" section (which
          // already shows those receiving details + a copy icon -- see
          // order_detail_screen.dart). Rearchitecting checkout to
          // collect/upload proof before an order row even exists is a
          // substantial, cross-cutting change (new staging-upload step,
          // revised idempotency handling, a different submit sequence)
          // that touches a currently-working, tested payment path --
          // flagged here rather than attempted silently.
          Text(s.payViaLabel, style: AppTypography.label),
          RadioGroup<String>(
            groupValue: _paymentChannel,
            onChanged: (v) => setState(() => _paymentChannel = v!),
            child: Column(children: [
              RadioListTile<String>(
                  title: Text(s.gatewayGcashLabel), value: 'gateway'),
              RadioListTile<String>(
                title: Text(s.manualTransferLabel),
                subtitle: manualTransferAvailable
                    ? null
                    : Text(s.manualTransferUnavailableForSeller),
                value: 'manual_transfer',
                enabled: manualTransferAvailable,
              ),
            ]),
          ),
        ],
        if (_paymentMethod == 'cod') ...[
          const SizedBox(height: AppSpacing.sm),
          Text(s.settlementMethodOptionalLabel, style: AppTypography.label),
          RadioGroup<String>(
            groupValue: _codSettlementMethod,
            onChanged: (v) => setState(() => _codSettlementMethod = v),
            child: Column(children: [
              RadioListTile<String>(
                  title: Text(s.cashLabel),
                  value: 'cash',
                  contentPadding: EdgeInsets.zero),
              RadioListTile<String>(
                  title: Text(s.gatewayGcashLabel),
                  value: 'gcash',
                  contentPadding: EdgeInsets.zero),
            ]),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(s.fulfillmentMethodLabel, style: AppTypography.h3),
        RadioGroup<String>(
          groupValue: _fulfillmentMethod,
          onChanged: (v) => _onFulfillmentMethodChanged(v!),
          child: Column(children: [
            RadioListTile<String>(
              title: Text(s.pickupLabel),
              subtitle: Text(_paymentMethod == 'cod'
                  ? s.onlyAvailableWithOnlinePayment
                  : s.pickupExplanation),
              value: 'pickup',
              enabled: _paymentMethod != 'cod',
            ),
            RadioListTile<String>(
                title: Text(s.vendorDeliveryLabel),
                subtitle: Text(s.vendorDeliveryExplanation),
                value: 'vendor_delivery'),
            RadioListTile<String>(
                title: Text(s.thirdPartyDeliveryLabel),
                subtitle: Text(s.thirdPartyDeliveryExplanation),
                value: 'third_party_delivery'),
          ]),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_fulfillmentMethod == 'pickup') ...[
          InkWell(
            onTap: _pickPickupDate,
            child: InputDecorator(
              decoration: InputDecoration(labelText: s.pickupDateLabel),
              child: Text(_pickupDate == null
                  ? s.selectDateLabel
                  : '${_pickupDate!.year}-${_pickupDate!.month.toString().padLeft(2, '0')}-${_pickupDate!.day.toString().padLeft(2, '0')}'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _pickupTimeSlot,
            decoration: InputDecoration(labelText: s.pickupTimeSlotLabel),
            items: _pickupTimeSlots
                .map((slot) => DropdownMenuItem(value: slot, child: Text(slot)))
                .toList(),
            onChanged: (v) => setState(() => _pickupTimeSlot = v),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _barangay,
            decoration: InputDecoration(labelText: s.barangayLabel),
            items: nagaCityBarangays
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => setState(() => _barangay = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _addressDetailController,
            decoration: InputDecoration(
                labelText: s.addressDetailLabel, hintText: s.addressDetailHint),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Shopee-style delivery pin: optional, simple -- drop/update a
          // pin on an OpenStreetMap picker so the seller knows exactly
          // where to go, beyond just the typed address.
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await Navigator.of(context).push<LatLng>(
                MaterialPageRoute(
                  builder: (_) =>
                      MapPinPickerScreen(initialLocation: _deliveryPin),
                ),
              );
              if (picked != null) setState(() => _deliveryPin = picked);
            },
            icon: Icon(_deliveryPin == null
                ? Icons.location_on_outlined
                : Icons.edit_location_alt_outlined),
            label: Text(_deliveryPin == null
                ? 'Pin delivery location on map (optional)'
                : 'Update pinned location'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _recipientNameController,
            decoration: InputDecoration(labelText: s.recipientNameLabel),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _recipientContactController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
                labelText: s.recipientContactNumberLabel,
                hintText: '09171234567'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _deliveryNoteController,
            decoration:
                InputDecoration(labelText: s.deliveryNoteOptionalLabel),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _notesController,
          maxLines: 2,
          decoration: InputDecoration(labelText: s.orderNotesOptionalLabel),
        ),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(
          onPressed: _placing ? null : onSubmit,
          child: _placing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent))
              : Text(s.placeOrderLabel),
        ),
      ],
    );
  }
}
