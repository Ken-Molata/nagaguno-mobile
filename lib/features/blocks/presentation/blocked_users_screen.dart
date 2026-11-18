// lib/features/blocks/presentation/blocked_users_screen.dart
//
// UW 9.3: lets a user review and undo their own blocks -- "blocking is
// one-directional and reversible" only means something if there's
// somewhere to see the list and reverse it, not just the per-profile
// block action itself.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../data/blocks_repository.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  Future<void> _unblock(
      BuildContext context, WidgetRef ref, String userId) async {
    try {
      final message =
          await ref.read(blocksRepositoryProvider).unblockUser(userId);
      ref.invalidate(blockedUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedUsersProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.blockedUsersTitle)),
      body: SafeArea(
        child: blockedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(s.couldntLoadBlockedUsers),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                  onPressed: () => ref.invalidate(blockedUsersProvider),
                  child: Text(s.retry)),
            ]),
          ),
          data: (blocked) {
            if (blocked.isEmpty) {
              return Center(
                  child: Text(s.noBlockedUsersYet,
                      style: AppTypography.bodySmall));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: blocked.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final u = blocked[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(u.fullName),
                  subtitle: Text(s.roleLabel(u.role)),
                  trailing: TextButton(
                    onPressed: () => _unblock(context, ref, u.blockedId),
                    child: Text(s.unblockLabel),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
