// lib/features/conversations/presentation/conversations_list_screen.dart
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../data/conversations_repository.dart';
import '../domain/conversation.dart';

final conversationsListProvider =
    FutureProvider.autoDispose<List<Conversation>>(
        (ref) => ref.watch(conversationsRepositoryProvider).getConversations());

class ConversationsListScreen extends ConsumerWidget {
  const ConversationsListScreen({super.key});

  String _fmtTime(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsListProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.messagesTitle)),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.couldntLoadConversations),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
                onPressed: () => ref.invalidate(conversationsListProvider),
                child: Text(s.retry)),
          ]),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(child: Text(s.noConversationsYet));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(conversationsListProvider.future),
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = conversations[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.backgroundStart,
                    backgroundImage: c.otherUserAvatar != null
                        ? NetworkImage(c.otherUserAvatar!)
                        : null,
                    child: c.otherUserAvatar == null
                        ? Text(c.otherUserName.isNotEmpty
                            ? c.otherUserName[0].toUpperCase()
                            : '?')
                        : null,
                  ),
                  title: Text(c.otherUserName,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    c.lastMessageText ?? s.noMessagesYet,
                    style: AppTypography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: c.lastMessageAt != null
                      ? Text(_fmtTime(c.lastMessageAt!),
                          style: AppTypography.label)
                      : null,
                  onTap: () => context.push(
                      '/conversations/${c.id}?name=${Uri.encodeComponent(c.otherUserName)}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
