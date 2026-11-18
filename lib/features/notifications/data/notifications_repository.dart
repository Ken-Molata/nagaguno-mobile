// lib/features/notifications/data/notifications_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/notification_item.dart';

// Was previously defined in notifications_screen.dart (a presentation
// file) and only transitively reachable by files that happened to
// import that screen -- the same accidental-visibility bug already
// caught and fixed for adminRepositoryProvider/conversationsRepositoryProvider
// earlier this session. Every repository's provider belongs here. This
// endpoint is role-agnostic (just scoped by req.user.id), so it's
// reused as-is by the admin web notification bell below -- no admin-
// specific backend route was needed.
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
    (ref) => NotificationsRepository(ref.watch(apiClientProvider)));

class NotificationsResult {
  const NotificationsResult({required this.items, required this.unreadCount});
  final List<NotificationItem> items;
  final int unreadCount;
}

class NotificationsRepository {
  NotificationsRepository(this._client);
  final ApiClient _client;

  Future<NotificationsResult> getNotifications() async {
    final response = await _client.dio.get(ApiEndpoints.notifications);
    return NotificationsResult(
      items: (response.data['data'] as List)
          .map((j) => NotificationItem.fromJson(j))
          .toList(),
      unreadCount: response.data['unread'] as int? ?? 0,
    );
  }

  Future<void> markAsRead(String id) async {
    await _client.dio.patch(ApiEndpoints.notificationRead(id));
  }

  Future<void> markAllAsRead() async {
    await _client.dio.patch(ApiEndpoints.notificationsReadAll);
  }
}
