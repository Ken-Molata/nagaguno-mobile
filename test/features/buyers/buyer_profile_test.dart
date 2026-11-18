// test/features/buyers/buyer_profile_test.dart
//
// UW 12.4 Buyer Profile (Full View). Covers BuyerProfile.fromJson,
// including the orders+agreements merge-and-sort into one transaction
// history list (newest first) -- the one piece of real logic in this
// model, not just field parsing.
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/buyers/domain/buyer_profile.dart';

void main() {
  group('BuyerProfile.fromJson', () {
    test('parses core fields', () {
      final buyer = BuyerProfile.fromJson({
        'id': 'buyer-1',
        'full_name': 'Juana',
        'barangay': 'Calauag',
        'avatar_url': 'https://example.com/a.jpg',
        'created_at': '2026-01-01T00:00:00Z',
        'is_verified': true,
        'orders': [],
        'agreements': [],
      });
      expect(buyer.id, 'buyer-1');
      expect(buyer.fullName, 'Juana');
      expect(buyer.barangay, 'Calauag');
      expect(buyer.avatarUrl, 'https://example.com/a.jpg');
      expect(buyer.isVerified, isTrue);
      expect(buyer.transactions, isEmpty);
    });

    test('defaults isVerified to false and handles missing created_at', () {
      final buyer = BuyerProfile.fromJson({
        'id': 'buyer-1',
        'full_name': 'Juana',
      });
      expect(buyer.isVerified, isFalse);
      expect(buyer.createdAt, isNull);
    });

    test('merges orders and agreements into one list, newest first', () {
      final buyer = BuyerProfile.fromJson({
        'id': 'buyer-1',
        'full_name': 'Juana',
        'orders': [
          {
            'id': 'o1',
            'status': 'delivered',
            'total_amount': '100.00',
            'created_at': '2026-01-01T00:00:00Z',
          },
        ],
        'agreements': [
          {
            'id': 'a1',
            'status': 'fulfilled',
            'total_price': '500.00',
            'created_at': '2026-02-01T00:00:00Z',
          },
        ],
      });
      expect(buyer.transactions, hasLength(2));
      // Agreement (Feb) is newer than the order (Jan), so it comes first.
      expect(buyer.transactions[0].kind, 'agreement');
      expect(buyer.transactions[0].amount, 500.00);
      expect(buyer.transactions[1].kind, 'order');
      expect(buyer.transactions[1].amount, 100.00);
    });
  });
}
