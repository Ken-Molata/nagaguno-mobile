// lib/core/localization/language_toggle_button.dart
//
// UW 21.9: "Language: the toggle in the header of the landing, login,
// and registration screens." Dual-mode, same authenticated-vs-pre-
// login split as core/accessibility/quick_text_size_control.dart:
// while signed in, picking a language saves straight to the account
// (reusing account_settings_screen.dart's own save/message pattern);
// while signed out, it only updates the device-local
// preLoginLanguageProvider (see that file's own comment for why there
// is no "push to the account on login" step for language, unlike the
// Aa control's text-size equivalent).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../networking/api_client.dart';
import '../../features/authentication/application/auth_controller.dart';
import '../../features/profile/data/profile_repository.dart';
import 'app_strings.dart';
import 'pre_login_language.dart';

final _profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(apiClientProvider)));

class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authenticated =
        ref.watch(authControllerProvider).status == AuthStatus.authenticated;
    final language = ref.watch(appLanguageProvider);

    return PopupMenuButton<String>(
      tooltip: 'Language / Wika',
      initialValue: language,
      icon: Text(language == 'tl' ? 'TL' : 'EN',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      itemBuilder: (context) => const [
        CheckedPopupMenuItem(value: 'en', child: Text('English')),
        CheckedPopupMenuItem(value: 'tl', child: Text('Tagalog')),
      ],
      onSelected: (lang) => authenticated
          ? _saveToAccount(context, ref, lang)
          : ref.read(preLoginLanguageProvider.notifier).setLanguage(lang),
    );
  }

  Future<void> _saveToAccount(
      BuildContext context, WidgetRef ref, String language) async {
    try {
      final message = await ref
          .read(_profileRepositoryProvider)
          .updateAccountSettings(language: language);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'We couldn\'t save this setting. It will still apply on this device. Please try again.')));
      }
    }
  }
}
