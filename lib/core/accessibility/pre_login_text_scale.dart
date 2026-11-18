// lib/core/accessibility/pre_login_text_scale.dart
//
// UW 21.6's "Aa" quick-access control must work "in the header of
// every screen, including pre-login ones" -- before there's an
// authenticated account to save a choice to, it's still remembered
// device-locally (shared_preferences, same local-only pattern as
// features/cart/application/cart_controller.dart), and reconciled into
// the account the moment one becomes available (see
// AuthController's textSizeReconcilerProvider in auth_controller.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreLoginTextSizeNotifier extends StateNotifier<String> {
  PreLoginTextSizeNotifier() : super('standard') {
    _load();
  }

  static const _storageKey = 'pre_login_text_size';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored != null) state = stored;
  }

  /// UW 21.6's exact four named tiers: 'standard' | 'large' |
  /// 'extra_large' | 'maximum'.
  Future<void> setTextSize(String textSize) async {
    state = textSize;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, textSize);
  }
}

final preLoginTextSizeProvider =
    StateNotifierProvider<PreLoginTextSizeNotifier, String>(
        (ref) => PreLoginTextSizeNotifier());
