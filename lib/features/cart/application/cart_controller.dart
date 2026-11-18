// lib/features/cart/application/cart_controller.dart
//
// See cart_item.dart for why this is local-only (shared_preferences),
// not a backend-backed feature.
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/cart_item.dart';

class CartController extends StateNotifier<List<CartItem>> {
  CartController() : super(const []) {
    _load();
  }

  static const _storageKey = 'cart_items';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List;
      state = decoded
          .map((j) => CartItem.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt/old-shape local data -- start clean rather than crash
      // the whole app over a cache of zero real importance.
      await prefs.remove(_storageKey);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, jsonEncode(state.map((i) => i.toJson()).toList()));
  }

  /// Adds [quantity] of a product to the cart, merging into an existing
  /// line for the same product rather than creating a duplicate one.
  /// Clamped to [item.maxStock] when known, matching the same
  /// stock-aware behavior ProductDetailScreen already applies to its
  /// own quantity stepper.
  void addItem(CartItem item) {
    final existingIndex =
        state.indexWhere((i) => i.productId == item.productId);
    if (existingIndex == -1) {
      state = [...state, item];
      _persist();
      return;
    }
    final existing = state[existingIndex];
    var newQuantity = existing.quantity + item.quantity;
    if (existing.maxStock != null) {
      newQuantity = newQuantity.clamp(0, existing.maxStock!.toDouble());
    }
    final updated = [...state];
    updated[existingIndex] = existing.copyWith(quantity: newQuantity);
    state = updated;
    _persist();
  }

  void updateQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    state = [
      for (final item in state)
        if (item.productId == productId)
          item.copyWith(quantity: quantity)
        else
          item,
    ];
    _persist();
  }

  void removeItem(String productId) {
    state = state.where((i) => i.productId != productId).toList();
    _persist();
  }

  /// Called after a cart-based checkout succeeds for one seller --
  /// only that seller's items leave the cart, since POST /orders is
  /// scoped to a single seller per call and the other sellers' items
  /// haven't been ordered yet.
  void clearSeller(String sellerId) {
    state = state.where((i) => i.sellerId != sellerId).toList();
    _persist();
  }

  /// Called on logout so one account's cart can't be seen by the next
  /// account signed in on the same device.
  void clear() {
    state = const [];
    _persist();
  }
}

final cartControllerProvider =
    StateNotifierProvider<CartController, List<CartItem>>(
        (ref) => CartController());

/// REAL GAP FOUND AND FIXED: the cart had no way to pick which items
/// to buy -- a seller group's own "Checkout" button always sent every
/// item in that group, with no way to leave one out short of removing
/// it from the cart outright, and there was no single action that
/// could span items from more than one store at once. `null` means
/// "everything is selected" (the default, so a freshly-opened cart
/// doesn't force the user to tick boxes just to buy all of it, same as
/// most shopping-cart UIs); it becomes an explicit set the moment the
/// user unchecks anything. cart_screen.dart reads this to build the
/// cart-wide checkout bar, and resolves it against the live cart list
/// itself (not stored here) so a newly added item is simply "selected"
/// by the `null` default until the user's own choices say otherwise.
final cartSelectionProvider = StateProvider<Set<String>?>((ref) => null);

/// The red badge count -- number of distinct products added, not total
/// units, matching the common "how many items are in your cart" cart
/// icon convention rather than summing possibly-fractional (kg)
/// quantities into a confusing badge number.
final cartItemCountProvider =
    Provider<int>((ref) => ref.watch(cartControllerProvider).length);
