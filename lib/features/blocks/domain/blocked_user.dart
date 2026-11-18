// lib/features/blocks/domain/blocked_user.dart
//
// UW 9.3: fields verified against the real GET /api/blocks response
// (routes/blocks.js) -- one row per user this account has blocked.

class BlockedUser {
  const BlockedUser({
    required this.blockedId,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  final String blockedId;
  final String fullName;
  final String role;
  final DateTime createdAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        blockedId: json['blocked_id'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
