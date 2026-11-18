// lib/features/conversations/presentation/widgets/messages_icon_button.dart
//
// REAL GAP FOUND AND FIXED: the conversations list (UW 13 -- every
// thread with every other user, Messenger-style) already existed at
// /conversations, but the only way to reach it was buried in Profile
// ("Messages" tile). Mirrors cart_icon_button.dart's own badge
// pattern so there's a quick-access entry point from the home
// dashboard too, not just Profile -- both still lead to the exact
// same screen/route, this is just a second door into it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/conversations_unread_provider.dart';

class MessagesIconButton extends ConsumerWidget {
  const MessagesIconButton({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(conversationsUnreadCountProvider).valueOrNull ?? 0;
    return IconButton(
      onPressed: () => context.push('/conversations'),
      icon: Badge(
        label: Text('$count'),
        isLabelVisible: count > 0,
        backgroundColor: AppColors.error,
        textColor: Colors.white,
        child: Icon(Icons.chat_bubble_outline, color: color),
      ),
    );
  }
}
