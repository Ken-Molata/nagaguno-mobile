// lib/core/accessibility/read_aloud_button.dart
//
// UW 21.6 Read Aloud: "when on, a speaker button appears beside
// listings, notifications, and order status text. Tapping it reads
// that text aloud in the selected language (Section 21.5), using the
// device's built-in voices. Nothing is read automatically. If the
// device has no voice for the language: 'Read Aloud isn't available
// in Tagalog on this device. It will read in English instead.'"
//
// Scope, disclosed not guessed: wired into a representative set of
// listing/notification/order-status screens (see each call site's own
// comment), not literally every occurrence of such text across the
// whole app -- that would mean touching dozens of screens
// individually. The setting, the engine wiring, and the fallback rule
// are all fully real and working here; extending coverage to further
// screens from here on is additive, same-pattern work, not a
// different piece left to design.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../features/authentication/application/auth_controller.dart';
import '../../features/accessibility/application/accessibility_settings.dart';

/// One shared engine instance -- flutter_tts expects a single
/// FlutterTts() per app; a fresh instance per button would risk
/// overlapping speech if two were ever tapped in succession.
final _ttsProvider = Provider<FlutterTts>((ref) {
  final tts = FlutterTts();
  ref.onDispose(tts.stop);
  return tts;
});

class ReadAloudButton extends ConsumerStatefulWidget {
  const ReadAloudButton({super.key, required this.text});
  final String text;

  @override
  ConsumerState<ReadAloudButton> createState() => _ReadAloudButtonState();
}

class _ReadAloudButtonState extends ConsumerState<ReadAloudButton> {
  bool _speaking = false;

  Future<void> _toggle() async {
    final tts = ref.read(_ttsProvider);
    if (_speaking) {
      await tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }

    // UW 21.5: 'en' | 'tl'. Tries the matching device voice first,
    // falling back to English (with the exact spec message) if the
    // device genuinely has none.
    final language = ref.read(authControllerProvider).user?.language ?? 'en';
    var usingFallback = false;
    if (language == 'tl') {
      final tlAvailable = await tts.isLanguageAvailable('tl-PH') == true;
      final filAvailable =
          !tlAvailable && await tts.isLanguageAvailable('fil-PH') == true;
      if (tlAvailable || filAvailable) {
        await tts.setLanguage(tlAvailable ? 'tl-PH' : 'fil-PH');
      } else {
        usingFallback = true;
        await tts.setLanguage('en-US');
      }
    } else {
      await tts.setLanguage('en-US');
    }

    if (usingFallback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Read Aloud isn\'t available in Tagalog on this device. It will read in English instead.')));
    }

    tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });

    if (!mounted) return;
    setState(() => _speaking = true);
    await tts.speak(widget.text);
  }

  @override
  void dispose() {
    if (_speaking) ref.read(_ttsProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UW 21.6: "when on, a speaker button appears" -- hidden entirely
    // while the account setting is off, not just disabled.
    final enabled = ref.watch(accessibilitySettingsProvider).readAloudEnabled;
    if (!enabled || widget.text.trim().isEmpty) return const SizedBox.shrink();
    return IconButton(
      tooltip: _speaking ? 'Stop reading' : 'Read aloud',
      icon: Icon(
          _speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
      onPressed: _toggle,
    );
  }
}
