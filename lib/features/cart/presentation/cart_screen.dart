// lib/features/cart/presentation/cart_screen.dart
//
// REAL GAP FOUND AND FIXED: this screen used to have no cart-wide way
// to check out at all -- only a small "Checkout" button buried inside
// each seller group's own footer, which always sent every item in
// that one group with no way to leave any of them out short of
// deleting them from the cart first, and no single action could span
// items from more than one store. Every item now has its own
// checkbox (defaulting to selected -- see cartSelectionProvider's own
// doc comment), and a single cart-wide bar at the bottom checks out
// exactly what's ticked: straight into CheckoutScreen when everything
// selected is from one seller (unchanged from before), or into
// MultiStoreCheckoutScreen -- one continuous flow running the same
// checkout form once per store -- when the selection spans more than
// one (POST /orders itself stays one seller per call; see that
// screen's own header comment for why).
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../../shared/widgets/verification_banner.dart';
import '../../orders/presentation/checkout_screen.dart';
import '../application/cart_controller.dart';
import '../domain/cart_item.dart';
import 'multi_store_checkout_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartControllerProvider);
    final s = ref.watch(appStringsProvider);

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(s.cartTitle)),
        body: Center(child: Text(s.yourCartIsEmpty)),
      );
    }

    final allIds = items.map((i) => i.productId).toSet();
    final selectedIds = ref.watch(cartSelectionProvider) ?? allIds;

    final bySeller = <String, List<CartItem>>{};
    for (final item in items) {
      bySeller.putIfAbsent(item.sellerId, () => []).add(item);
    }

    final selectedItems =
        items.where((i) => selectedIds.contains(i.productId)).toList();
    final selectedTotal =
        selectedItems.fold<double>(0, (sum, i) => sum + i.lineTotal);

    return Scaffold(
      appBar: AppBar(title: Text(s.cartTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: bySeller.entries
                    .map((entry) => _SellerGroup(
                        sellerId: entry.key,
                        items: entry.value,
                        selectedIds: selectedIds))
                    .toList(),
              ),
            ),
            _CheckoutBar(
              selectedCount: selectedItems.length,
              selectedTotal: selectedTotal,
              onCheckout: selectedItems.isEmpty
                  ? null
                  : () => _goToCheckout(context, selectedItems),
            ),
          ],
        ),
      ),
    );
  }

  void _goToCheckout(BuildContext context, List<CartItem> selectedItems) {
    final bySeller = <String, List<CartItem>>{};
    for (final item in selectedItems) {
      bySeller.putIfAbsent(item.sellerId, () => []).add(item);
    }
    if (bySeller.length == 1) {
      final entry = bySeller.entries.first;
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) =>
                CheckoutScreen.cart(items: entry.value, sellerId: entry.key)),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiStoreCheckoutScreen(
          groups: bySeller.entries
              .map((e) => StoreCartGroup(sellerId: e.key, items: e.value))
              .toList(),
        ),
      ),
    );
  }
}

/// Sets exactly [productId]'s membership in the cart-wide selection,
/// materializing cartSelectionProvider's `null` ("everything") default
/// into an explicit set the first time anything is unchecked.
void _setItemSelected(WidgetRef ref, Set<String> currentSelectedIds,
    String productId, bool selected) {
  final updated = Set<String>.from(currentSelectedIds);
  if (selected) {
    updated.add(productId);
  } else {
    updated.remove(productId);
  }
  ref.read(cartSelectionProvider.notifier).state = updated;
}

class _SellerGroup extends ConsumerWidget {
  const _SellerGroup(
      {required this.sellerId, required this.items, required this.selectedIds});
  final String sellerId;
  final List<CartItem> items;
  final Set<String> selectedIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
    final s = ref.watch(appStringsProvider);
    final groupIds = items.map((i) => i.productId).toSet();
    final allSelected = groupIds.every(selectedIds.contains);
    final someSelected = groupIds.any(selectedIds.contains);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
            child: Row(
              children: [
                // Selects/deselects every item in this store at once --
                // a tri-state convenience on top of each item's own
                // checkbox below, not a separate source of truth.
                Checkbox(
                  value: someSelected && !allSelected ? null : allSelected,
                  tristate: true,
                  onChanged: (_) {
                    final makeSelected = !allSelected;
                    final updated = Set<String>.from(selectedIds);
                    if (makeSelected) {
                      updated.addAll(groupIds);
                    } else {
                      updated.removeAll(groupIds);
                    }
                    ref.read(cartSelectionProvider.notifier).state = updated;
                  },
                ),
                const Icon(Icons.storefront_outlined,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: Text(items.first.sellerName,
                        style: AppTypography.h3.copyWith(fontSize: 15))),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.map((item) => _CartItemRow(
              item: item, selected: selectedIds.contains(item.productId))),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
            child: Text(s.subtotalLine('₱${subtotal.toStringAsFixed(2)}'),
                style: AppTypography.body),
          ),
        ],
      ),
    );
  }
}

class _CartItemRow extends ConsumerWidget {
  const _CartItemRow({required this.item, required this.selected});
  final CartItem item;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: (checked) {
              final allIds = ref
                  .read(cartControllerProvider)
                  .map((i) => i.productId)
                  .toSet();
              final current =
                  ref.read(cartSelectionProvider) ?? allIds;
              _setItemSelected(
                  ref, current, item.productId, checked ?? false);
            },
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 48,
              height: 48,
              child: item.imageUrl != null
                  ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.backgroundStart,
                      child: const Icon(Icons.image_outlined,
                          size: 20, color: AppColors.textMuted)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: AppTypography.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('₱${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                    style: AppTypography.label),
              ],
            ),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: () => ref
                .read(cartControllerProvider.notifier)
                .updateQuantity(item.productId, item.quantity - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
              width: 28,
              child: Text(
                  item.quantity.toStringAsFixed(
                      item.quantity.truncateToDouble() == item.quantity
                          ? 0
                          : 1),
                  textAlign: TextAlign.center)),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed:
                (item.maxStock != null && item.quantity >= item.maxStock!)
                    ? null
                    : () => ref
                        .read(cartControllerProvider.notifier)
                        .updateQuantity(item.productId, item.quantity + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: () => ref
                .read(cartControllerProvider.notifier)
                .removeItem(item.productId),
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

/// The cart-wide "Checkout" action -- see this file's own header
/// comment for why this replaced the old per-seller-group button.
class _CheckoutBar extends ConsumerWidget {
  const _CheckoutBar({
    required this.selectedCount,
    required this.selectedTotal,
    required this.onCheckout,
  });
  final int selectedCount;
  final double selectedTotal;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.itemsSelectedCount(selectedCount),
                      style: AppTypography.label),
                  Text('₱${selectedTotal.toStringAsFixed(2)}',
                      style: AppTypography.h3),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // REAL BUG FOUND AND FIXED: the global ElevatedButtonTheme
            // sets minimumSize: Size.fromHeight(48), i.e. an infinite
            // minimum WIDTH (meant for full-width CTA buttons elsewhere
            // in the app) -- placed as a plain, non-Expanded Row child
            // here, that infinite-width demand starved the price
            // Column above down to near-zero width, wrapping its text
            // one character per line (confirmed live: "3 items
            // selected"/"₱51.85" rendered as a vertical column of
            // single characters). Same bug class already found once
            // this session in admin_listings_screen.dart's ListTile
            // trailing. IntrinsicWidth makes the button size to its own
            // label's natural width instead of the theme's infinite one.
            IntrinsicWidth(
              child: onCheckout != null
                  ? LockedButton(
                      label: s.checkoutSelectedLabel,
                      onPressed: onCheckout!,
                    )
                  : ElevatedButton(
                      onPressed: null,
                      child: Text(s.checkoutSelectedLabel),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
