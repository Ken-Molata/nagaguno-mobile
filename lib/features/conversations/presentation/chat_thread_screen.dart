// lib/features/conversations/presentation/chat_thread_screen.dart
//
// UW 13.1: polls GET /conversations/:id/messages?after=<id> every 5
// seconds while this screen is open -- the real backend already
// supports this cursor, it just had no caller at all before this.
// UW 15's proposed push channel (Supabase Realtime/FCM) to replace
// polling isn't built -- flagged in conversations.js's own header
// comment, not attempted here either.
//
// Also now builds UW 13.1's other two specific requirements, neither
// of which existed before (grepped this file for "retry"/"report":
// zero matches): "Sending shows the message immediately in the thread
// in a sent state; if it fails to send... it is marked with a retry
// option rather than silently disappearing" (the [_OutgoingMessage]
// optimistic-send/retry below -- previously a failed send just left
// the text sitting in the compose box with a generic banner, with
// nothing ever shown in the thread itself), and "Each message carries
// its own report option (long-press or a small overflow icon on the
// message itself)" (long-press here, on any message that isn't mine).
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope. The
// actual message text (m.text) is user-authored content, not UI
// chrome, and stays untranslated here the same way product/category
// names do elsewhere.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/utils/image_picking.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../../authentication/application/auth_controller.dart';
import '../../reports/domain/report_models.dart';
import '../../reports/presentation/report_user_screen.dart';
import 'conversations_list_screen.dart';
import '../domain/chat_message.dart';
import '../data/conversations_repository.dart';
import '../../../shared/widgets/verification_banner.dart';

/// A send attempt not yet confirmed by the server -- shown in the
/// thread immediately (optimistic), removed on success, left in place
/// with [failed] set on failure so the user can retry the SAME attempt
/// rather than it vanishing or needing to be retyped.
class _OutgoingMessage {
  _OutgoingMessage({required this.localId, this.text, this.imagePath});
  final String localId;
  final String? text;
  final String? imagePath;
  bool failed = false;
  bool sending = true;
  String? failureReason;
}

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen(
      {super.key, required this.conversationId, required this.otherUserName});
  final String conversationId;
  final String otherUserName;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _messages = <ChatMessage>[];
  final _pending = <_OutgoingMessage>[];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;
  bool _loading = true;
  String? _pickedImagePath;
  String? _errorMessage;
  int _localIdCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  Future<void> _loadInitial() async {
    try {
      final messages = await ref
          .read(conversationsRepositoryProvider)
          .getMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages.addAll(messages);
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = ref.read(appStringsProvider).couldntLoadMessages;
        });
      }
    }
  }

  Future<void> _poll() async {
    if (!mounted) return;
    try {
      final after = _messages.isNotEmpty ? _messages.last.id : null;
      final newMessages = await ref
          .read(conversationsRepositoryProvider)
          .getMessages(widget.conversationId, after: after);
      if (!mounted || newMessages.isEmpty) return;
      setState(() => _messages.addAll(newMessages));
      _scrollToBottom();
    } catch (_) {
      // Silent: a missed poll just tries again in 5s, not worth
      // interrupting the user reading/typing over.
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _pickImage() async {
    final file = await pickAndCompressImage();
    if (file != null) setState(() => _pickedImagePath = file.path);
  }

  void _reportMessage(BuildContext context, ChatMessage message) {
    // UW 13.1: "pre-linked to that specific message, with the conduct
    // and content violation options" -- both conduct groups are
    // offered (this screen doesn't know the other party's role, unlike
    // the profile-based report entry points that do, so it can't
    // narrow to buyerConduct vs sellerConduct the way those can).
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportUserScreen(
        reportedUserId: message.senderId,
        reportedUserName: widget.otherUserName,
        availableGroups: const [
          ViolationGroup.buyerConduct,
          ViolationGroup.sellerConduct,
        ],
        messageId: message.id,
      ),
    ));
  }

  bool get _canSend =>
      _textController.text.trim().isNotEmpty || _pickedImagePath != null;

  Future<void> _send() async {
    final text = _textController.text.trim();
    final imagePath = _pickedImagePath;
    if (text.isEmpty && imagePath == null) return;

    // Optimistic: shown in the thread right away, before the request
    // even starts, matching UW 13.1's "shows the message immediately
    // in the thread in a sent state."
    final outgoing = _OutgoingMessage(
        localId: 'local-${_localIdCounter++}', text: text, imagePath: imagePath);
    setState(() {
      _pending.add(outgoing);
      _textController.clear();
      _pickedImagePath = null;
      _errorMessage = null;
    });
    _scrollToBottom();
    await _attemptSend(outgoing);
  }

  Future<void> _attemptSend(_OutgoingMessage outgoing) async {
    setState(() {
      outgoing.sending = true;
      outgoing.failed = false;
    });
    try {
      final sent = await ref.read(conversationsRepositoryProvider).sendMessage(
            widget.conversationId,
            text: outgoing.text,
            imagePath: outgoing.imagePath,
          );
      if (!mounted) return;
      setState(() {
        _pending.remove(outgoing);
        _messages.add(sent);
      });
      ref.invalidate(conversationsListProvider);
      _scrollToBottom();
    } catch (e) {
      // UW 13.1: "marked with a retry option rather than silently
      // disappearing" -- stays in [_pending], flagged failed, with its
      // own retry affordance in the bubble below instead of a generic
      // top banner the user has to connect back to a specific attempt.
      //
      // REAL BUG FOUND AND FIXED: this discarded the real error
      // entirely (bare `catch (_)`) in favor of the same generic
      // "Failed. Tap to retry." every time -- the one real cause this
      // screen can now actually hit (messaging just became gated by
      // requireVerified) would show with zero indication of why, and
      // tapping retry forever would never fix it.
      if (mounted) {
        setState(() {
          outgoing.sending = false;
          outgoing.failed = true;
          outgoing.failureReason = friendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = ref.watch(authControllerProvider).user?.id;
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUserName)),
      body: SafeArea(
        child: Column(
          children: [
            // Messaging now requires full verification (contact
            // reachability + KYC approval, same as ordering/
            // agreements) -- shown proactively here, not just
            // discovered by tapping Send and hitting the error below.
            const VerificationBanner(),
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                color: AppColors.statusCancelledBg,
                child: Text(_errorMessage!,
                    style: const TextStyle(color: AppColors.statusCancelledFg)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _messages.length + _pending.length,
                      itemBuilder: (context, i) {
                        if (i < _messages.length) {
                          final m = _messages[i];
                          final isMine = m.senderId == myUserId;
                          return GestureDetector(
                            // UW 13.1: "Each message carries its own
                            // report option (long-press or a small
                            // overflow icon)" -- only makes sense on
                            // the OTHER party's messages.
                            onLongPress: isMine
                                ? null
                                : () => _reportMessage(context, m),
                            child: _MessageBubble(
                              isMine: isMine,
                              imageUrl: m.imageUrl,
                              text: m.text,
                            ),
                          );
                        }
                        final outgoing = _pending[i - _messages.length];
                        return GestureDetector(
                          onTap: outgoing.failed
                              ? () => _attemptSend(outgoing)
                              : null,
                          child: _MessageBubble(
                            isMine: true,
                            imagePath: outgoing.imagePath,
                            text: outgoing.text,
                            trailing: outgoing.failed
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline,
                                          size: 14, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                            outgoing.failureReason ??
                                                s.failedTapToRetry,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11)),
                                      ),
                                    ],
                                  )
                                : const SizedBox(
                                    height: 10,
                                    width: 10,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.white70)),
                          ),
                        );
                      },
                    ),
            ),
            if (_pickedImagePath != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(children: [
                  Text(s.imageAttachedLabel, style: AppTypography.bodySmall),
                  IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _pickedImagePath = null)),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  IconButton(
                      icon: const Icon(Icons.image_outlined),
                      onPressed: _pickImage),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration:
                          InputDecoration(hintText: s.typeAMessageHint),
                      minLines: 1,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _canSend ? _send : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

/// Shared rendering for a confirmed message (network [imageUrl]) or a
/// still-sending/failed one (local [imagePath]); [trailing] carries the
/// pending/failed status row for the latter.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.isMine,
    this.text,
    this.imageUrl,
    this.imagePath,
    this.trailing,
  });

  final bool isMine;
  final String? text;
  final String? imageUrl;
  final String? imagePath;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(AppSpacing.sm),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.surface,
          border: isMine ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null || imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: imageUrl != null
                    ? Image.network(imageUrl!, fit: BoxFit.cover)
                    : Image.file(File(imagePath!), fit: BoxFit.cover),
              ),
              if (text != null) const SizedBox(height: AppSpacing.xs),
            ],
            if (text != null)
              Text(text!,
                  style: AppTypography.body.copyWith(
                      color: isMine ? Colors.white : AppColors.textPrimary)),
            if (trailing != null) ...[
              const SizedBox(height: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
