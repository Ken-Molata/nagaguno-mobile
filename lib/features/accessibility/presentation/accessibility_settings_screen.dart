// lib/features/accessibility/presentation/accessibility_settings_screen.dart
//
// UW 21.6. Each control saves immediately on change -- "take effect
// the moment they are chosen, with no separate Save step" -- the same
// one-field-per-call pattern as
// features/profile/presentation/account_settings_screen.dart's
// language/notification toggles, now extended to these four fields.
//
// Every item UW 21.6 names is now built:
// - The "Aa" quick-access control, in the header of every screen
//   including pre-login ones -- see
//   core/accessibility/quick_text_size_control.dart, wired in main.dart.
// - Read Aloud -- the toggle below, and the speaker button itself in
//   core/accessibility/read_aloud_button.dart, wired into a
//   representative set of listing/notification/order-status screens,
//   not literally every occurrence of such text app-wide; see that
//   widget's own header comment for the exact scope.
// - Easy Mode -- the toggle below; larger nav tap targets in
//   shared/widgets/app_shell.dart, and the simplified large-button home
//   screen in features/dashboard/presentation/easy_mode_home_screen.dart,
//   swapped in by app_router.dart's Home route. Every other tab/feature
//   stays exactly as reachable as when Easy Mode is off -- see that
//   screen's own header comment.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/localization/app_strings.dart';
import '../../authentication/application/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../application/accessibility_settings.dart';

final _profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(apiClientProvider)));

// Keys are the stored data values (unchanged -- the backend's CHECK
// constraint and every existing user's saved preference still expect
// exactly these 4 strings); only the display labels were renamed, by
// rank, to the conventional Small/Default/Large/Extra Large ladder.
Map<String, String> _textSizeLabels(AppStrings s) => {
      'standard': s.textSizeSmall,
      'large': s.textSizeDefault,
      'extra_large': s.textSizeLarge,
      'maximum': s.textSizeExtraLarge,
    };

class AccessibilitySettingsScreen extends ConsumerStatefulWidget {
  const AccessibilitySettingsScreen({super.key});
  @override
  ConsumerState<AccessibilitySettingsScreen> createState() =>
      _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState
    extends ConsumerState<AccessibilitySettingsScreen> {
  bool _saving = false;

  Future<void> _save({
    String? textSize,
    bool? highContrast,
    bool? boldText,
    bool? reduceMotion,
    bool? readAloudEnabled,
    bool? easyModeEnabled,
  }) async {
    setState(() => _saving = true);
    try {
      final message =
          await ref.read(_profileRepositoryProvider).updateAccountSettings(
                textSize: textSize,
                highContrast: highContrast,
                boldText: boldText,
                reduceMotion: reduceMotion,
                readAloudEnabled: readAloudEnabled,
                easyModeEnabled: easyModeEnabled,
              );
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ref
                .read(appStringsProvider)
                .couldntSaveSettingStillAppliesLocally)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(accessibilitySettingsProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.accessibilityTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // UW 21.6: "a preview card at the top of the screen shows
            // the effect."
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: settings.highContrast
                    ? Colors.white
                    : AppColors.backgroundStart,
                border: settings.highContrast
                    ? Border.all(color: Colors.black, width: 2)
                    : Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                s.previewTextAtThisSize,
                style: AppTypography.body.copyWith(
                  fontSize: 15 * settings.textScale,
                  fontWeight:
                      settings.boldText ? FontWeight.bold : FontWeight.normal,
                  color: settings.highContrast ? Colors.black : null,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(s.textSize, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            RadioGroup<String>(
              groupValue: settings.textSize,
              onChanged: (v) {
                if (!_saving && v != null) _save(textSize: v);
              },
              child: Column(
                children: _textSizeLabels(s)
                    .entries
                    .map((e) => RadioListTile<String>(
                        title: Text(e.value),
                        value: e.key,
                        contentPadding: EdgeInsets.zero))
                    .toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.highContrast),
              subtitle: Text(s.highContrastSubtitle),
              value: settings.highContrast,
              onChanged: _saving ? null : (v) => _save(highContrast: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.boldText),
              subtitle: Text(s.boldTextSubtitle),
              value: settings.boldText,
              onChanged: _saving ? null : (v) => _save(boldText: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.reduceMotion),
              subtitle: Text(s.reduceMotionSubtitle),
              value: settings.reduceMotion,
              onChanged: _saving ? null : (v) => _save(reduceMotion: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.readAloud),
              subtitle: Text(s.readAloudSubtitle),
              value: settings.readAloudEnabled,
              onChanged: _saving ? null : (v) => _save(readAloudEnabled: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.easyMode),
              subtitle: Text(s.easyModeSubtitle),
              value: settings.easyModeEnabled,
              onChanged: _saving ? null : (v) => _save(easyModeEnabled: v),
            ),
          ],
        ),
      ),
    );
  }
}
