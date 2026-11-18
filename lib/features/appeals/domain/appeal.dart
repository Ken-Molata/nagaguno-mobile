// lib/features/appeals/domain/appeal.dart
//
// UW 17.5: a single appeal against a ban, suspension, or Cash-on-
// Delivery restriction. Fields verified against the real
// GET /appeals/mine and POST /appeals (routes/appeals.js) this
// session — a fully working backend with no mobile screen at all
// before this (and, until the login()/middleware fix in this same
// pass, structurally unreachable for ban/suspension regardless).

enum AppealTargetType { codRestriction, suspension, ban }

enum AppealStatus { pending, approved, rejected }

extension AppealTargetTypeApi on AppealTargetType {
  String get apiValue => switch (this) {
        AppealTargetType.codRestriction => 'cod_restriction',
        AppealTargetType.suspension => 'suspension',
        AppealTargetType.ban => 'ban',
      };

  String get label => switch (this) {
        AppealTargetType.codRestriction => 'Cash-on-Delivery Restriction',
        AppealTargetType.suspension => 'Suspension',
        AppealTargetType.ban => 'Ban',
      };
}

class Appeal {
  const Appeal({
    required this.id,
    required this.targetType,
    required this.status,
    required this.createdAt,
    this.adminNotes,
    this.decidedAt,
  });

  final String id;
  final AppealTargetType targetType;
  final AppealStatus status;
  final DateTime createdAt;
  final String? adminNotes;
  final DateTime? decidedAt;

  static AppealTargetType _targetFrom(String? s) => switch (s) {
        'suspension' => AppealTargetType.suspension,
        'ban' => AppealTargetType.ban,
        _ => AppealTargetType.codRestriction,
      };

  static AppealStatus _statusFrom(String? s) => switch (s) {
        'approved' => AppealStatus.approved,
        'rejected' => AppealStatus.rejected,
        _ => AppealStatus.pending,
      };

  factory Appeal.fromJson(Map<String, dynamic> json) => Appeal(
        id: json['id'] as String,
        targetType: _targetFrom(json['target_type'] as String?),
        status: _statusFrom(json['status'] as String?),
        createdAt: DateTime.parse(json['created_at']),
        adminNotes: json['admin_notes'] as String?,
        decidedAt: json['decided_at'] != null
            ? DateTime.parse(json['decided_at'])
            : null,
      );
}
