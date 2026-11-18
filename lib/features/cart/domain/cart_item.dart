// lib/features/cart/domain/cart_item.dart
//
// A genuinely local, device-only cart -- there is no cart concept
// anywhere in the real backend (verified: no cart table, no cart
// routes). This is intentional, not a gap: POST /orders already takes
// an `items` array scoped to a single seller in one call
// (routes/orders.js), so a cart only needs to accumulate
// {productId, quantity} pairs per seller client-side before handing
// that array to the existing endpoint at checkout -- no new backend
// capability is required. Persisted via shared_preferences, same
// local-only pattern already used for accessibility settings
// (features/accessibility/application/accessibility_settings.dart),
// and cleared on logout so one account's cart can't bleed into
// another on a shared device.
class CartItem {
  const CartItem({
    required this.productId,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.quantity,
    this.imageUrl,
    this.maxStock,
  });

  final String productId;
  final String sellerId;
  final String sellerName;
  final String name;
  final String unit;
  final double unitPrice;
  final double quantity;
  final String? imageUrl;
  final int? maxStock;

  double get lineTotal => unitPrice * quantity;

  CartItem copyWith({double? quantity}) => CartItem(
        productId: productId,
        sellerId: sellerId,
        sellerName: sellerName,
        name: name,
        unit: unit,
        unitPrice: unitPrice,
        quantity: quantity ?? this.quantity,
        imageUrl: imageUrl,
        maxStock: maxStock,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'name': name,
        'unit': unit,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'imageUrl': imageUrl,
        'maxStock': maxStock,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: json['productId'] as String,
        sellerId: json['sellerId'] as String,
        sellerName: json['sellerName'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String,
        unitPrice: (json['unitPrice'] as num).toDouble(),
        quantity: (json['quantity'] as num).toDouble(),
        imageUrl: json['imageUrl'] as String?,
        maxStock: json['maxStock'] as int?,
      );
}
