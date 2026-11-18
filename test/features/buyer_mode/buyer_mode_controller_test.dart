// test/features/buyer_mode/buyer_mode_controller_test.dart
//
// UW 1.5: isBuyerModeRecord is the whole reason this feature needs no
// schema change -- a record is correctly labeled "Buyer Mode" purely
// from data that already exists (viewer's role + whether they're the
// buyer_id on this specific record), not from a toggle the server has
// any awareness of. These tests exist to pin that logic down exactly.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nagaguno_mobile/features/buyer_mode/application/buyer_mode_controller.dart';

void main() {
  group('isBuyerModeRecord', () {
    test('a Farmer who is the buyer_id on this record IS a buyer-mode record',
        () {
      expect(
        isBuyerModeRecord(
            viewerRole: 'farmer', viewerId: 'u1', recordBuyerId: 'u1'),
        isTrue,
      );
    });

    test('a Vendor who is the buyer_id on this record IS a buyer-mode record',
        () {
      expect(
        isBuyerModeRecord(
            viewerRole: 'vendor', viewerId: 'u1', recordBuyerId: 'u1'),
        isTrue,
      );
    });

    test(
        'a Farmer who is NOT the buyer_id (i.e. this is their own sale, seller side) is NOT a buyer-mode record',
        () {
      expect(
        isBuyerModeRecord(
            viewerRole: 'farmer',
            viewerId: 'u1',
            recordBuyerId: 'someone-else'),
        isFalse,
      );
    });

    test(
        'a plain Buyer account never carries the label -- they have nothing to switch between',
        () {
      expect(
        isBuyerModeRecord(
            viewerRole: 'buyer', viewerId: 'u1', recordBuyerId: 'u1'),
        isFalse,
      );
    });

    test('an Admin account never carries the label either', () {
      expect(
        isBuyerModeRecord(
            viewerRole: 'admin', viewerId: 'u1', recordBuyerId: 'u1'),
        isFalse,
      );
    });

    test(
        'a null viewerId (logged out / not yet loaded) never carries the label, rather than crashing on a null comparison',
        () {
      expect(
        isBuyerModeRecord(
            viewerRole: 'farmer', viewerId: null, recordBuyerId: 'u1'),
        isFalse,
      );
    });
  });

  group('buyerModeProvider', () {
    test('defaults to false (own role, not buyer mode) on a fresh app start',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(buyerModeProvider), isFalse);
    });
  });
}
