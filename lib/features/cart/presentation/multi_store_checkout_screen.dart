// lib/features/cart/presentation/multi_store_checkout_screen.dart
//
// REAL GAP FOUND AND FIXED: the cart could hold items from several
// different sellers, but there was no single action that could check
// any of them out together -- only one "Checkout" button per seller
// group, each a dead end into its own separate CheckoutScreen with no
// way back into the others. POST /orders itself stays one seller per
// call (routes/orders.js, unchanged -- see CheckoutScreen's own header
// comment), so "one single checkout" across stores is really this
// screen running CheckoutScreen's own form once per store in
// sequence, under one continuous flow the buyer never has to
// re-navigate into by hand.
//
// Reached from cart_screen.dart's cart-wide checkout bar only when the
// buyer's selected items span more than one seller; a single-seller
// selection still goes straight to CheckoutScreen.cart() as before.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../orders/presentation/checkout_screen.dart';
import '../domain/cart_item.dart';

class StoreCartGroup {
  const StoreCartGroup({required this.sellerId, required this.items});
  final String sellerId;
  final List<CartItem> items;
}

class MultiStoreCheckoutScreen extends ConsumerStatefulWidget {
  const MultiStoreCheckoutScreen({super.key, required this.groups});
  final List<StoreCartGroup> groups;

  @override
  ConsumerState<MultiStoreCheckoutScreen> createState() =>
      _MultiStoreCheckoutScreenState();
}

class _MultiStoreCheckoutScreenState
    extends ConsumerState<MultiStoreCheckoutScreen> {
  // Index into widget.groups; equal to widget.groups.length once every
  // store's order has been placed, which this screen reads as "done."
  int _index = 0;

  void _advanceToNextStore() {
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    if (_index >= widget.groups.length) {
      return Scaffold(
        appBar: AppBar(title: Text(s.checkoutTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    size: 64, color: AppColors.statusSuccessFg),
                const SizedBox(height: AppSpacing.md),
                Text(s.allOrdersPlacedTitle,
                    style: AppTypography.h2, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xs),
                Text(s.ordersPlacedCount(widget.groups.length),
                    style: AppTypography.body, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () => context.go('/orders'),
                  child: Text(s.viewMyOrdersLabel),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final group = widget.groups[_index];
    // A fresh key per store forces a brand-new CheckoutScreen state --
    // the previous store's payment/fulfillment choices and text fields
    // should NOT carry over, since a different seller may have
    // different manual-transfer availability and delivery details.
    return CheckoutScreen.cart(
      key: ValueKey(group.sellerId),
      items: group.items,
      sellerId: group.sellerId,
      onOrderPlaced: _advanceToNextStore,
      progressLabel:
          s.storeProgressLabel(_index + 1, widget.groups.length),
    );
  }
}
