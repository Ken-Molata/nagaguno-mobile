// lib/features/profile/presentation/account_settings_screen.dart
//
// UW 1.4/21.5 (Language) and UW 21.7 (Notification Preferences).
// Deliberately one screen for both: they're adjacent subsections of
// the same "Manage Account Settings" section (UW 21) and share the
// same PATCH /profiles/account-settings endpoint.
//
// This screen builds the real, working PREFERENCE itself: it's saved
// to the account, follows the user across devices, and the success
// message is shown in the newly-selected language exactly as UW 21.5
// specifies.
//
// Translating the app's actual UI text is a separate, much larger
// content-authoring undertaking ("every label, button, validation
// message, and notification" across this entire app) -- a later pass
// started on it for real: core/localization/app_strings.dart is the
// working mechanism (reactive, both pre- and post-login, switching
// "immediately, with no reload" exactly as UW 21.5 requires), and
// login_screen.dart is the first screen translated in full. Most of
// the app's UI is still English-only regardless of this setting --
// see app_strings.dart's own header comment for the honest scope of
// what's covered so far and what extending it looks like.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/localization/app_strings.dart';
import '../../authentication/application/auth_controller.dart';
import '../data/profile_repository.dart';

final _profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(apiClientProvider)));

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});
  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _savingLanguage = false;
  bool _savingSms = false;
  bool _savingEmail = false;

  Future<void> _saveLanguage(String language) async {
    setState(() => _savingLanguage = true);
    try {
      final message = await ref
          .read(_profileRepositoryProvider)
          .updateAccountSettings(language: language);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ref.read(appStringsProvider).somethingWentWrongTryAgain)));
      }
    } finally {
      if (mounted) setState(() => _savingLanguage = false);
    }
  }

  Future<void> _saveSms(bool value, bool emailCurrentlyOn) async {
    // UW 21.7: "If the user turns both off, a notice reads: 'You'll
    // only see delivery and pickup updates in the app. You may miss
    // time-sensitive updates.'" -- shown before saving, as a
    // confirmation, not after.
    if (!value && !emailCurrentlyOn) {
      final confirmed = await _confirmBothOff();
      if (confirmed != true) return;
    }
    setState(() => _savingSms = true);
    try {
      final message = await ref
          .read(_profileRepositoryProvider)
          .updateAccountSettings(smsDeliveryUpdates: value);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ref.read(appStringsProvider).somethingWentWrongTryAgain)));
      }
    } finally {
      if (mounted) setState(() => _savingSms = false);
    }
  }

  Future<void> _saveEmail(bool value, bool smsCurrentlyOn) async {
    if (!value && !smsCurrentlyOn) {
      final confirmed = await _confirmBothOff();
      if (confirmed != true) return;
    }
    setState(() => _savingEmail = true);
    try {
      final message = await ref
          .read(_profileRepositoryProvider)
          .updateAccountSettings(emailDeliveryUpdates: value);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ref.read(appStringsProvider).somethingWentWrongTryAgain)));
      }
    } finally {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  Future<bool?> _confirmBothOff() {
    final s = ref.read(appStringsProvider);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.turnOffBothQuestion),
        content: Text(s.willOnlySeeUpdatesInApp),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.cancel)),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(s.turnOff)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final s = ref.watch(appStringsProvider);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: Text(s.languageAndNotificationsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(s.languageLabel, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            RadioGroup<String>(
              groupValue: user.language,
              onChanged: (v) {
                if (!_savingLanguage && v != null) _saveLanguage(v);
              },
              child: Column(children: [
                RadioListTile<String>(
                    title: Text(s.english),
                    value: 'en',
                    contentPadding: EdgeInsets.zero),
                RadioListTile<String>(
                    title: Text(s.tagalog),
                    value: 'tl',
                    contentPadding: EdgeInsets.zero),
              ]),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text(s.notificationPreferences, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.inAppNotificationsAlwaysOn,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.smsForDeliveryUpdates),
              subtitle: Text(s.textMessagesToPhoneOnAccount),
              value: user.smsDeliveryUpdates,
              onChanged: _savingSms
                  ? null
                  : (v) => _saveSms(v, user.emailDeliveryUpdates),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.emailForDeliveryUpdates),
              subtitle: Text(s.emailsToAddressOnAccount),
              value: user.emailDeliveryUpdates,
              onChanged: _savingEmail
                  ? null
                  : (v) => _saveEmail(v, user.smsDeliveryUpdates),
            ),
          ],
        ),
      ),
    );
  }
}
