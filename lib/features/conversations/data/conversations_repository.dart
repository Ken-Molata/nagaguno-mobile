// lib/features/conversations/data/conversations_repository.dart
//
// Matches the real routes/conversations.js exactly.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/conversation.dart';
import '../domain/chat_message.dart';

class ConversationException implements Exception {
  ConversationException(this.message);
  final String message;
}

// Was previously defined in conversations_list_screen.dart (a
// presentation file) and only transitively reachable by files that
// happened to import that screen -- the same accidental-visibility
// bug already caught and fixed for adminRepositoryProvider earlier
// this session. Every repository's provider belongs here, in its own
// data file.
final conversationsRepositoryProvider = Provider<ConversationsRepository>(
    (ref) => ConversationsRepository(ref.watch(apiClientProvider)));

class ConversationsRepository {
  ConversationsRepository(this._client);
  final ApiClient _client;

  Future<List<Conversation>> getConversations() async {
    final response = await _client.dio.get(ApiEndpoints.conversations);
    return (response.data['data'] as List)
        .map((j) => Conversation.fromJson(j))
        .toList();
  }

  /// Finds or creates the one conversation with [recipientId]. A 403
  /// means one of you has blocked the other.
  Future<String> openConversation(
      {required String recipientId, String? context, String? contextId}) async {
    try {
      final response =
          await _client.dio.post(ApiEndpoints.conversations, data: {
        'recipientId': recipientId,
        if (context != null) 'context': context,
        if (contextId != null) 'contextId': contextId,
      });
      return response.data['data']['id'] as String;
    } on DioException catch (e) {
      final message = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      throw ConversationException(message ?? 'Failed to open conversation.');
    }
  }

  /// UW 13.1: the caller polls this every 5 seconds while the thread
  /// is open, passing [after] as the last message id it already has
  /// so only new ones come back.
  Future<List<ChatMessage>> getMessages(String conversationId,
      {String? after}) async {
    final response = await _client.dio.get(
        ApiEndpoints.conversationMessages(conversationId),
        queryParameters: {
          if (after != null) 'after': after,
        });
    return (response.data['data'] as List)
        .map((j) => ChatMessage.fromJson(j))
        .toList();
  }

  /// UW 13.1/15.2: the caller polls this every 30 seconds whenever no
  /// conversation thread is open (see chat_thread_screen.dart's 5s
  /// poll for the open-thread case instead). Read-only -- messages are
  /// marked read as a side effect of polling their own thread, not of
  /// checking this count.
  Future<int> getUnreadCount() async {
    final response =
        await _client.dio.get(ApiEndpoints.conversationsUnreadCount);
    return response.data['data']['count'] as int? ?? 0;
  }

  Future<ChatMessage> sendMessage(String conversationId,
      {String? text, String? imagePath}) async {
    try {
      final formData = FormData.fromMap({
        if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
        if (imagePath != null) 'image': await MultipartFile.fromFile(imagePath),
      });
      final response = await _client.dio.post(
          ApiEndpoints.conversationMessages(conversationId),
          data: formData);
      return ChatMessage.fromJson(response.data['data']);
    } on DioException catch (e) {
      final message = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      throw ConversationException(message ?? 'Failed to send message.');
    }
  }
}
