// test/features/orders/order_test.dart
//
// UW 13.2 "Order & Delivery Notes": receiptNote is a second, distinct
// field from notes (set once at checkout) -- this covers only the
// parsing, since order.dart has no other test coverage to extend.
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/orders/domain/order.dart';

Map<String, dynamic> _baseOrderJson({String? notes, String? receiptNote}) => {
      'id': 'order-1',
      'buyer_id': 'buyer-1',
      'seller_id': 'seller-1',
      'status': 'delivered',
      'total_amount': '100.00',
      'buyer_name': 'Juana',
      'seller_name': 'Mang Teroy',
      'seller_role': 'farmer',
      'items': [],
      'created_at': '2026-10-01T00:00:00Z',
      if (notes != null) 'notes': notes,
      if (receiptNote != null) 'receipt_note': receiptNote,
    };

void main() {
  group('Order.fromJson receiptNote', () {
    test('parses receipt_note when present', () {
      final order =
          Order.fromJson(_baseOrderJson(receiptNote: 'Left with the guard.'));
      expect(order.receiptNote, 'Left with the guard.');
    });

    test('receiptNote is null when absent', () {
      final order = Order.fromJson(_baseOrderJson());
      expect(order.receiptNote, isNull);
    });

    test('notes and receiptNote are independent fields', () {
      final order = Order.fromJson(_baseOrderJson(
          notes: 'Deliver after 5pm', receiptNote: 'Received, missing one item'));
      expect(order.notes, 'Deliver after 5pm');
      expect(order.receiptNote, 'Received, missing one item');
    });
  });

  group('Order.fromJson buyer inline preview (UW 12.2)', () {
    test('parses buyer_avatar and buyer_rating when present', () {
      final json = _baseOrderJson()
        ..['buyer_avatar'] = 'https://example.com/a.jpg'
        ..['buyer_rating'] = '4.5';
      final order = Order.fromJson(json);
      expect(order.buyerAvatar, 'https://example.com/a.jpg');
      expect(order.buyerRating, 4.5);
    });

    test('buyerAvatar/buyerRating are null when absent', () {
      final order = Order.fromJson(_baseOrderJson());
      expect(order.buyerAvatar, isNull);
      expect(order.buyerRating, isNull);
    });
  });
}
