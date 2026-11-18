// lib/features/conversations/domain/chat_message.dart

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.createdAt,
    this.text,
    this.imageUrl,
  });

  final String id;
  final String senderId;
  final DateTime createdAt;
  final String? text;

  /// Short-lived signed URL -- re-fetch rather than cache across sessions.
  final String? imageUrl;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        createdAt: DateTime.parse(json['created_at']),
        text: json['text'] as String?,
        imageUrl: json['image_url'] as String?,
      );
}
