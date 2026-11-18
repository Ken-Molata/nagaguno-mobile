// test/core/pricing_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/core/utils/pricing.dart';

void main() {
  group('calculateTotal', () {
    test('multiplies quantity by price per unit', () {
      expect(calculateTotal(quantity: 3, pricePerUnit: 25.5), 76.5);
    });

    test('zero quantity gives zero total', () {
      expect(calculateTotal(quantity: 0, pricePerUnit: 100), 0);
    });
  });

  group('parsePositiveDoubleOrZero', () {
    test('parses a valid positive number', () {
      expect(parsePositiveDoubleOrZero('12.5'), 12.5);
    });

    test('empty input defaults to 0', () {
      expect(parsePositiveDoubleOrZero(''), 0);
    });

    test('non-numeric input defaults to 0', () {
      expect(parsePositiveDoubleOrZero('abc'), 0);
    });

    test(
        'negative input is clamped to 0 — this is the real fix, not equivalent to the original inline code',
        () {
      // The original inline version this replaced (double.tryParse(...)
      // ?? 0) would have returned -5 unclamped for this exact input.
      // This test exists specifically to lock in the corrected
      // behavior and catch any future regression back to the
      // un-clamped version.
      expect(parsePositiveDoubleOrZero('-5'), 0);
    });

    test('trims surrounding whitespace before parsing', () {
      expect(parsePositiveDoubleOrZero('  42  '), 42);
    });
  });
}
