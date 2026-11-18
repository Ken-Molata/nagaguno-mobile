// lib/features/accessibility/application/accessibility_settings.dart
//
// UW 21.6: "The settings belong to the account, so they follow the
// user to every device." REAL BUG FOUND AND FIXED this pass: this
// used to be genuinely local, device-only state (shared_preferences,
// explicitly documented here as having "no backend counterpart") --
// directly contradicting that requirement, same class of mistake as
// language/notification preferences before an earlier fix this
// session. Now derived straight from the authenticated user's own
// account record (routes/profile.js's PATCH /account-settings is
// what actually saves it), the same pattern
// features/profile/presentation/account_settings_screen.dart already
// uses for language and notification channels.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/application/auth_controller.dart';
import '../../../admin_web/application/admin_auth_controller.dart';

class AccessibilitySettings {
  const AccessibilitySettings({
    this.textSize = 'standard',
    this.highContrast = false,
    this.boldText = false,
    this.reduceMotion = false,
    this.readAloudEnabled = false,
    this.easyModeEnabled = false,
  });

  /// UW 21.6's exact four named tiers: 'standard' | 'large' |
  /// 'extra_large' | 'maximum' -- never a continuous percentage.
  final String textSize;
  final bool highContrast;
  final bool boldText;
  final bool reduceMotion;

  /// UW 21.6 Read Aloud -- the account-level toggle this pass adds
  /// (see NagagunoUser.readAloudEnabled's own comment). The actual
  /// speaker button/TTS playback lives in
  /// core/accessibility/read_aloud_button.dart, not here -- this is
  /// just the setting, same split as [textSize] vs. main.dart's own
  /// MediaQuery application.
  final bool readAloudEnabled;

  /// UW 21.6 Easy Mode -- see NagagunoUser.easyModeEnabled's own
  /// comment. Applied in app_shell.dart (larger nav tap targets) and
  /// app_router.dart (swaps HomeScreen for EasyModeHomeScreen), not
  /// here -- same setting/application split as [readAloudEnabled].
  final bool easyModeEnabled;

  /// The actual multiplier main.dart applies via MediaQuery.textScaler
  /// -- UW 21.6: "Standard (100%, default), Large (125%), Extra Large
  /// (150%), or Maximum (175%)."
  double get textScale => switch (textSize) {
        'large' => 1.25,
        'extra_large' => 1.5,
        'maximum' => 1.75,
        _ => 1.0,
      };
}

/// Derived, not stored -- automatically reflects whatever
/// authControllerProvider's cached user currently has, the same
/// "re-fetch after a save" flow as every other account setting.
final accessibilitySettingsProvider = Provider<AccessibilitySettings>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return const AccessibilitySettings();
  return AccessibilitySettings(
    textSize: user.textSize,
    highContrast: user.highContrast,
    boldText: user.boldText,
    reduceMotion: user.reduceMotion,
    readAloudEnabled: user.readAloudEnabled,
    easyModeEnabled: user.easyModeEnabled,
  );
});

/// UW 21.10: "Admin accounts have ... Accessibility & Display."
/// REAL BUG FOUND AND FIXED this pass: admin_settings_screen.dart lets
/// an admin pick a text size / toggle high contrast etc., and those
/// choices save and come back from GET /me correctly, but nothing in
/// main_web_admin.dart ever read them back into a MediaQuery -- same
/// "field exists, never rendered" class of bug as several others this
/// session, just on the admin side. Mirrors accessibilitySettingsProvider
/// above exactly, off AdminAuthState instead of AuthState.
final adminAccessibilitySettingsProvider =
    Provider<AccessibilitySettings>((ref) {
  final user = ref.watch(adminAuthControllerProvider).user;
  if (user == null) return const AccessibilitySettings();
  return AccessibilitySettings(
    textSize: user.textSize,
    highContrast: user.highContrast,
    boldText: user.boldText,
    reduceMotion: user.reduceMotion,
  );
});
