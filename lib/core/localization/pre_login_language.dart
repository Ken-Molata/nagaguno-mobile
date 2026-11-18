// lib/core/localization/pre_login_language.dart
//
// UW 21.9: "Language: the toggle in the header of the landing, login,
// and registration screens and in the navigation bar (Section 21.5)."
// REAL GAP FOUND AND FIXED (first slice): before login there's no
// account yet to read a saved language from, so the choice is kept
// device-locally (shared_preferences, same local-only pattern as
// core/accessibility/pre_login_text_scale.dart) -- and, unlike that
// file's reconciliation rule, UW 1.4/21.5 describe no "account has
// none saved, device's choice is saved to the account" carry-over for
// language specifically, so this stays a plain device preference, not
// something pushed to the account on login.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreLoginLanguageNotifier extends StateNotifier<String> {
  PreLoginLanguageNotifier() : super('en') {
    _load();
  }

  static const _storageKey = 'pre_login_language';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored != null) state = stored;
  }

  /// 'en' | 'tl', UW 1.4's exact two options.
  Future<void> setLanguage(String language) async {
    state = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, language);
  }
}

final preLoginLanguageProvider =
    StateNotifierProvider<PreLoginLanguageNotifier, String>(
        (ref) => PreLoginLanguageNotifier());
