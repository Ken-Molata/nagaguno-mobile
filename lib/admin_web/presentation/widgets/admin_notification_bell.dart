// lib/admin_web/presentation/widgets/admin_notification_bell.dart
//
// UW 15: admin-facing notifications had nowhere to surface at all --
// not even the ones the backend was already generating (routes/kyc.js's
// kyc_allowance_notice, routes/accountRecovery.js's "new request
// waiting in the Account Recovery queue" badge per UW 9.1/2.5, etc.).
// GET /notifications (routes/notifications.js) is role-agnostic --
// just scoped by req.user.id -- so an admin account's own rows are
// already reachable through the exact same endpoint/repository the
// consumer app uses; nothing admin-specific was needed on the backend.
// Polls every 30s, same cadence as UW 15's own spec for "elsewhere"
// (not viewing the panel itself) -- see conversations_unread_provider.dart
// for the identical pattern used for message unread counts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/notifications/data/notifications_repository.dart';
import '../../../features/notifications/domain/notification_item.dart';

final _adminNotificationsProvider =
    StreamProvider.autoDispose<NotificationsResult>((ref) async* {
  final repo = ref.watch(notificationsRepositoryProvider);
  while (true) {
    try {
      yield await repo.getNotifications();
    } catch (_) {
      // Silent, same reasoning as every other poller this session: a
      // missed tick just tries again in 30s.
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});

class AdminNotificationBell extends ConsumerWidget {
  const AdminNotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(_adminNotificationsProvider);
    final unread = resultAsync.valueOrNull?.unreadCount ?? 0;

    return PopupMenuButton<void>(
      tooltip: 'Notifications',
      offset: const Offset(0, 40),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined, color: Colors.white70),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: SizedBox(
            width: 360,
            child: _NotificationPanel(result: resultAsync.valueOrNull),
          ),
        ),
      ],
    );
  }
}

class _NotificationPanel extends ConsumerWidget {
  const _NotificationPanel({required this.result});
  final NotificationsResult? result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = result?.items ?? const <NotificationItem>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
                child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('Notifications', style: AppTypography.label),
            )),
            if (items.any((n) => !n.isRead))
              TextButton(
                onPressed: () async {
                  await ref
                      .read(notificationsRepositoryProvider)
                      .markAllAsRead();
                  ref.invalidate(_adminNotificationsProvider);
                },
                child: const Text('Mark all read'),
              ),
          ],
        ),
        const Divider(height: 1),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('No notifications yet.', style: AppTypography.bodySmall),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = items[i];
                return ListTile(
                  dense: true,
                  tileColor: n.isRead ? null : AppColors.backgroundStart,
                  title: Text(n.title, style: AppTypography.body),
                  subtitle: Text(n.message, style: AppTypography.bodySmall),
                  onTap: n.isRead
                      ? null
                      : () async {
                          await ref
                              .read(notificationsRepositoryProvider)
                              .markAsRead(n.id);
                          ref.invalidate(_adminNotificationsProvider);
                        },
                );
              },
            ),
          ),
      ],
    );
  }
}
