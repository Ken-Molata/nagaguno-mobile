// lib/features/notifications/domain/notification_item.dart
// Fields verified against the real GET /notifications query this session.

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.orderId,
    this.agreementId,
    this.entityType,
    this.entityId,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? orderId;
  final String? agreementId;

  /// Added to notifications.js this session as a generic click-through
  /// target beyond the two specific order_id/agreement_id columns --
  /// was parsed nowhere until now. Only 'conversation' is actually
  /// wired to navigation below (UW 13); other values the backend sets
  /// (e.g. kyc_submission, recovery_request) are read here but not
  /// routed anywhere yet -- flagged, not guessed at.
  final String? entityType;
  final String? entityId;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        isRead: json['is_read'] as bool,
        createdAt: DateTime.parse(json['created_at']),
        orderId: json['order_id'] as String?,
        agreementId: json['agreement_id'] as String?,
        entityType: json['entity_type'] as String?,
        entityId: json['entity_id'] as String?,
      );
}
