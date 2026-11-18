// lib/features/conversations/application/conversations_unread_provider.dart
//
// UW 13.1/15.2: "the client polls... the unread count every 30 seconds
// otherwise" -- i.e. whenever no specific thread is open (that case is
// chat_thread_screen.dart's own 5s poll instead). Scope decision: this
// polls only while something is actually watching it (autoDispose), so
// in practice that's whichever screen(s) show the badge -- not a
// true always-on background poll, matching how the 5s thread poll is
// also scoped to its own screen's lifetime rather than running app-wide.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/conversations_repository.dart';

final conversationsUnreadCountProvider =
    StreamProvider.autoDispose<int>((ref) async* {
  final repo = ref.watch(conversationsRepositoryProvider);
  while (true) {
    try {
      yield await repo.getUnreadCount();
    } catch (_) {
      // Silent, same reasoning as chat_thread_screen.dart's own poll:
      // a missed tick just tries again in 30s.
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});
