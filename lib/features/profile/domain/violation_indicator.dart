// lib/features/profile/domain/violation_indicator.dart
//
// UW 17.3: "the account is marked with a red indicator showing one of
// two states, Near Suspension (from this second-violation warning
// until either a third violation or the count resets) or Suspended
// (for the duration of an active one-week suspension). This indicator
// is visible only to the account holder, on their own profile, and to
// Admin; it is never shown to other users viewing that profile."
// Fields verified against GET /profiles/violation-status
// (utils/violations.js's getViolationIndicator) exactly.

class ViolationCategoryStatus {
  const ViolationCategoryStatus(
      {required this.category, required this.label, required this.count});
  final String category;
  final String label;
  final int count;

  factory ViolationCategoryStatus.fromJson(Map<String, dynamic> json) =>
      ViolationCategoryStatus(
        category: json['category'] as String,
        label: json['label'] as String,
        count: json['count'] as int,
      );
}

class ViolationIndicator {
  const ViolationIndicator({
    required this.indicator,
    this.suspendedUntil,
    this.codRestrictedUntil,
    this.categories = const [],
  });

  /// null | 'near_suspension' | 'suspended' -- "Suspended takes
  /// priority over Near Suspension if somehow both are true at once."
  final String? indicator;
  final DateTime? suspendedUntil;
  final DateTime? codRestrictedUntil;

  /// Only the categories currently at the Near Suspension count (one
  /// violation short of the next suspension) -- empty when
  /// [indicator] is 'suspended' or null.
  final List<ViolationCategoryStatus> categories;

  bool get isSuspended => indicator == 'suspended';
  bool get isNearSuspension => indicator == 'near_suspension';
  bool get hasIndicator => indicator != null;

  factory ViolationIndicator.fromJson(Map<String, dynamic> json) =>
      ViolationIndicator(
        indicator: json['indicator'] as String?,
        suspendedUntil: json['suspended_until'] != null
            ? DateTime.tryParse(json['suspended_until'].toString())
            : null,
        codRestrictedUntil: json['cod_restricted_until'] != null
            ? DateTime.tryParse(json['cod_restricted_until'].toString())
            : null,
        categories: (json['categories'] as List? ?? [])
            .map((c) => ViolationCategoryStatus.fromJson(c))
            .toList(),
      );
}
