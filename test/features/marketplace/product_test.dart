// test/features/marketplace/product_test.dart
//
// Tests for Product's price/discount display logic. One design
// observation verified explicitly here, not just assumed: displayPrice
// computes the discount off `pricePerUnit` (the product's current
// price), NOT off `flashSaleOriginalPrice` (the backend's own
// snapshot field name suggests it's meant to be the base). That
// backend field is only ever used here to DETECT that a discount is
// active — never as the actual calculation base, and never displayed
// directly. This is a reasonable, self-consistent design (the struck-
// through "original" price shown in the UI is also pricePerUnit, so
// everything agrees with itself) — but it does mean that if a
// seller's listed price and the recommendation's original-price
// snapshot were ever to diverge (e.g. price edited after the sale was
// flagged), the UI would silently use the current price for both,
// not the backend's snapshot. Documented explicitly rather than
// silently relied upon.

import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/marketplace/domain/product.dart';

Product _buildProduct({
  double pricePerUnit = 100.0,
  double? flashSaleOriginalPrice,
  double? flashSaleDiscountPct,
  String? farmName,
  String? businessName,
  String sellerName = 'Juan Dela Cruz',
}) {
  return Product(
    id: 'p1',
    name: 'Kamatis',
    category: 'Vegetables',
    unit: 'kg',
    pricePerUnit: pricePerUnit,
    sellerId: 's1',
    sellerRole: 'farmer',
    sellerName: sellerName,
    farmName: farmName,
    businessName: businessName,
    flashSaleOriginalPrice: flashSaleOriginalPrice,
    flashSaleDiscountPct: flashSaleDiscountPct,
  );
}

void main() {
  group('Product.hasActiveDiscount', () {
    test('false when flashSaleOriginalPrice is null', () {
      final p = _buildProduct();
      expect(p.hasActiveDiscount, isFalse);
    });

    test(
        'true when flashSaleOriginalPrice is present, regardless of the discount percentage value',
        () {
      // Even a 0% discount should still count as "active" per this
      // getter's actual logic (it only checks for presence, not
      // magnitude) — verifying that exact, real behavior.
      final p =
          _buildProduct(flashSaleOriginalPrice: 100, flashSaleDiscountPct: 0);
      expect(p.hasActiveDiscount, isTrue);
    });
  });

  group('Product.displayPrice', () {
    test('equals pricePerUnit when there is no active discount', () {
      final p = _buildProduct(pricePerUnit: 150);
      expect(p.displayPrice, 150);
    });

    test(
        'applies the discount as a FRACTION against pricePerUnit — matching the real backend format exactly',
        () {
      // flashSaleDiscountPct is 0.20 here, NOT 20 -- verified against
      // the real backend (routes/marketplace.js selects
      // recommended_discount_pct with no transformation; routes/
      // spoilage.js stores/validates it as a 0-1 fraction). An earlier
      // version of this test used 20 as if it meant 20%, matching a
      // real bug that was in the implementation at the time -- both
      // are now fixed together, not just the implementation alone.
      final p = _buildProduct(
          pricePerUnit: 100,
          flashSaleOriginalPrice: 100,
          flashSaleDiscountPct: 0.20);
      expect(p.displayPrice, 80);
    });

    test(
        'a 100% discount (fraction 1.0) correctly floors at zero, not negative',
        () {
      final p = _buildProduct(
          pricePerUnit: 100,
          flashSaleOriginalPrice: 100,
          flashSaleDiscountPct: 1.0);
      expect(p.displayPrice, 0);
    });

    test(
        'null discount percentage with hasActiveDiscount=true treats the discount as 0%, per the real ?? 0 fallback',
        () {
      final p = _buildProduct(
          pricePerUnit: 100,
          flashSaleOriginalPrice: 100,
          flashSaleDiscountPct: null);
      expect(p.displayPrice, 100,
          reason:
              'the real code does (flashSaleDiscountPct ?? 0), so a null percentage means no actual price change');
    });

    test(
        'demonstrates the documented design point: changing pricePerUnit after a discount is set changes displayPrice proportionally, NOT anchored to flashSaleOriginalPrice',
        () {
      final p = _buildProduct(
          pricePerUnit: 200,
          flashSaleOriginalPrice: 100,
          flashSaleDiscountPct: 0.50);
      // If this were anchored to flashSaleOriginalPrice (100), a 50%
      // discount would give 50. It does not -- it gives 100, because
      // the real calculation is 200 * (1 - 0.5), off the CURRENT
      // pricePerUnit, not the stored snapshot. This test exists
      // specifically to make that real behavior explicit and
      // catch it if it's ever silently "fixed" without a deliberate
      // decision to do so.
      expect(p.displayPrice, 100);
    });
  });

  group('Product.displaySellerName', () {
    test('prefers farmName when present', () {
      final p = _buildProduct(
          farmName: 'Green Valley Farm',
          businessName: 'Some Business',
          sellerName: 'Juan');
      expect(p.displaySellerName, 'Green Valley Farm');
    });

    test('falls back to businessName when farmName is absent', () {
      final p =
          _buildProduct(businessName: 'Fresh Produce Co.', sellerName: 'Juan');
      expect(p.displaySellerName, 'Fresh Produce Co.');
    });

    test(
        'falls back to the plain sellerName when neither farmName nor businessName is present',
        () {
      final p = _buildProduct(sellerName: 'Juan Dela Cruz');
      expect(p.displaySellerName, 'Juan Dela Cruz');
    });
  });
}
