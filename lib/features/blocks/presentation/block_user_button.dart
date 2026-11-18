// lib/features/blocks/presentation/block_user_button.dart
//
// UW 9.3: "Users may block another specific user independently of
// filing a report... A blocked user's listings and profile are hidden
// from the blocker's view[;] the blocked user can no longer message
// the blocker[;] blocking is one-directional and reversible." REAL
// GAP FOUND AND FIXED: the backend (routes/blocks.js) has always
// fully supported this -- block/unblock endpoints, and the browsing/
// messaging exclusion wired across marketplace.js, recommendation.js,
// and conversations.js -- but nothing in the mobile app ever called
// it; there was no screen anywhere a user could actually block
// someone from.
//
// A separate button from ReportMenuButton (report_menu_button.dart),
// not a shared menu -- these are semantically different actions
// (report = flagged for Admin review; block = a private preference
// with no Admin involvement at all), so collapsing them under one
// icon would misrepresent what each one does.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../data/blocks_repository.dart';

class BlockUserButton extends ConsumerStatefulWidget {
  const BlockUserButton(
      {super.key, required this.userId, required this.userName});
  final String userId;
  final String userName;

  @override
  ConsumerState<BlockUserButton> createState() => _BlockUserButtonState();
}

class _BlockUserButtonState extends ConsumerState<BlockUserButton> {
  bool? _isBlocked; // null while the initial status check is in flight
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final blocked =
          await ref.read(blocksRepositoryProvider).getBlockedUsers();
      if (mounted) {
        setState(() =>
            _isBlocked = blocked.any((b) => b.blockedId == widget.userId));
      }
    } catch (_) {
      // Best-effort -- shows as "not blocked" rather than hiding the
      // control outright, same as every other non-critical status
      // check in this app.
      if (mounted) setState(() => _isBlocked = false);
    }
  }

  Future<void> _toggle() async {
    final wasBlocked = _isBlocked ?? false;
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(wasBlocked
            ? s.unblockUserQuestion(widget.userName)
            : s.blockUserQuestion(widget.userName)),
        content: Text(wasBlocked ? s.unblockExplanation : s.blockExplanation),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.cancel)),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(wasBlocked ? s.unblockLabel : s.blockLabel)),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(blocksRepositoryProvider);
      final message = wasBlocked
          ? await repo.unblockUser(widget.userId)
          : await repo.blockUser(widget.userId);
      if (mounted) {
        setState(() => _isBlocked = !wasBlocked);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBlocked == null) return const SizedBox.shrink();
    final s = ref.watch(appStringsProvider);
    return IconButton(
      tooltip: _isBlocked! ? s.unblockLabel : s.blockLabel,
      icon: Icon(_isBlocked! ? Icons.block : Icons.block_outlined),
      onPressed: _busy ? null : _toggle,
    );
  }
}
