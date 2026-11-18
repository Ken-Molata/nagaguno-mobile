// lib/core/utils/pricing.dart
//
// Small, pure, shared calculation extracted specifically for
// testability and reuse — the same quantity × price-per-unit pattern
// appears in both NewAgreementScreen's total preview and
// ProductDetailScreen's order total, and was previously duplicated
// inline in each rather than sharing one verified implementation.

double calculateTotal(
    {required double quantity, required double pricePerUnit}) {
  return quantity * pricePerUnit;
}

/// Parses user-entered text into a non-negative double, defaulting to
/// 0 for empty/invalid input — the exact fallback behavior
/// NewAgreementScreen's total preview already relied on inline,
/// pulled out here so it's consistent everywhere it's needed.
double parsePositiveDoubleOrZero(String text) {
  final parsed = double.tryParse(text.trim());
  if (parsed == null || parsed < 0) return 0;
  return parsed;
}
