// lib/features/notifications/presentation/notifications_screen.dart
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope. The
// notification title/message text itself (n.title, n.message) is
// server-generated content, not UI chrome, and stays untranslated here
// the same way product/category names do elsewhere.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/accessibility/read_aloud_button.dart';
import '../data/notifications_repository.dart';
import '../../reports/presentation/my_reports_screen.dart';

final notificationsProvider = FutureProvider.autoDispose<NotificationsResult>(
    (ref) => ref.watch(notificationsRepositoryProvider).getNotifications());

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(notificationsProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.notificationsTitle),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref.read(notificationsRepositoryProvider).markAllAsRead();
                ref.invalidate(notificationsProvider);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(s.couldntMarkAllAsReadTryAgain)));
                }
              }
            },
            child: Text(s.markAllReadLabel),
          ),
        ],
      ),
      body: resultAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.couldntLoadNotifications),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                child: Text(s.retry)),
          ]),
        ),
        data: (result) {
          if (result.items.isEmpty) {
            return Center(child: Text(s.noNotificationsYet));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsProvider.future),
            child: ListView.separated(
              itemCount: result.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = result.items[i];
                return ListTile(
                  tileColor: n.isRead ? null : AppColors.backgroundStart,
                  leading: CircleAvatar(
                    backgroundColor:
                        n.isRead ? AppColors.border : AppColors.accent,
                    child: Icon(_iconFor(n.type),
                        size: 18,
                        color: n.isRead ? AppColors.textMuted : Colors.white),
                  ),
                  title: Text(n.title,
                      style: AppTypography.body.copyWith(
                          fontWeight:
                              n.isRead ? FontWeight.w400 : FontWeight.w700)),
                  subtitle: Text(n.message, style: AppTypography.bodySmall),
                  // UW 21.6 Read Aloud -- self-hides when the setting
                  // is off (see ReadAloudButton's own comment).
                  trailing: ReadAloudButton(text: '${n.title}. ${n.message}'),
                  onTap: () async {
                    try {
                      if (!n.isRead) {
                        await ref
                            .read(notificationsRepositoryProvider)
                            .markAsRead(n.id);
                        ref.invalidate(notificationsProvider);
                      }
                    } catch (_) {
                      // Deliberately silent here, not a SnackBar: this
                      // is a background side-effect of tapping through
                      // to the order/agreement below, not the primary
                      // action the user is taking. Failing to mark as
                      // read shouldn't block or interrupt navigating
                      // to the actual thing they tapped for.
                    }
                    if (!context.mounted) return;
                    // Real navigation, not just a mark-as-read no-op —
                    // orderId/agreementId were already being parsed
                    // from the real backend but never actually used
                    // for anything until now.
                    if (n.orderId != null) {
                      context.push('/orders/${n.orderId}');
                    } else if (n.agreementId != null) {
                      context.push('/agreements/${n.agreementId}');
                    } else if (n.entityType == 'conversation' &&
                        n.entityId != null) {
                      // UW 13: a new-message notification -- the real
                      // other-party name isn't in this payload, so the
                      // thread screen falls back to a generic title
                      // rather than an extra round trip just for it.
                      context.push('/conversations/${n.entityId}');
                    } else if (n.entityType == 'crop_plan') {
                      // UW 15.2's crop lifecycle reminders -- no
                      // per-plan detail route exists in this app (the
                      // list screen itself is where every plan action,
                      // including "Create Listing from Plan", lives),
                      // so this is the real, honest destination, not a
                      // route that doesn't exist.
                      context.push('/crop-plans');
                    } else if (n.entityType == 'report') {
                      // UW 15's global click-through rule names this
                      // exact case: "a report notification opens that
                      // report." No per-report detail route exists (or
                      // is needed -- MyReportsScreen's own cards already
                      // show status and the admin's reason inline), so
                      // this is that report's real destination, matching
                      // how profile_screen.dart already reaches this
                      // same screen (Navigator, not go_router, since no
                      // path is registered for it in app_router.dart).
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const MyReportsScreen()));
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(String type) {
    if (type.startsWith('order')) return Icons.receipt_long;
    if (type.startsWith('agreement') || type.startsWith('proof')) {
      return Icons.handshake;
    }
    return Icons.notifications;
  }
}
