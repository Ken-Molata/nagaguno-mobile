// lib/features/notifications/application/notifications_unread_provider.dart
//
// Same pattern as conversations_unread_provider.dart: polls every 30s,
// scoped to whatever screen is actually watching it (autoDispose), not
// a true always-on background poll.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notifications_repository.dart';

final notificationsUnreadCountProvider =
    StreamProvider.autoDispose<int>((ref) async* {
  final repo = ref.watch(notificationsRepositoryProvider);
  while (true) {
    try {
      yield (await repo.getNotifications()).unreadCount;
    } catch (_) {
      // Silent, same reasoning as the conversations/admin pollers: a
      // missed tick just tries again in 30s.
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});
