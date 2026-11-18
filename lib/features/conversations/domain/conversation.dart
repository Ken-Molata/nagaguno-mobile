// lib/features/conversations/domain/conversation.dart
//
// UW 13 (In-App Communication). Fields verified against the real
// GET /conversations and POST /conversations (routes/conversations.js)
// this session -- a fully built backend (list, find-or-create,
// message polling, send) with no mobile screen at all before this,
// and -- found while building this -- silently broken the whole time
// regardless (conversations/messages both had RLS enabled with zero
// policies; fixed via migration alongside this).

class Conversation {
  const Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.lastMessageText,
    this.lastMessageAt,
    this.context,
    this.contextId,
  });

  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? lastMessageText;
  final DateTime? lastMessageAt;

  /// 'order' | 'agreement' | null -- what this conversation was opened
  /// about, if anything (optional context passed to POST /conversations).
  final String? context;
  final String? contextId;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        otherUserId: json['other_user_id'] as String,
        otherUserName: json['other_user_name'] as String,
        otherUserAvatar: json['other_user_avatar'] as String?,
        lastMessageText: json['last_message_text'] as String?,
        lastMessageAt: json['last_message_at'] != null
            ? DateTime.parse(json['last_message_at'])
            : null,
        context: json['context'] as String?,
        contextId: json['context_id'] as String?,
      );
}
