// lib/core/accessibility/quick_text_size_control.dart
//
// UW 21.6's "Aa" quick-access control: "a quick-access text-size
// control appears in the header of every screen, including pre-login
// ones, letting the text size be changed without opening Settings."
// Dual-mode, same account-vs-device split as
// features/accessibility/application/accessibility_settings.dart:
// while signed in, picking a size saves straight to the account
// (reusing accessibility_settings_screen.dart's own save/message/error
// pattern); while signed out, it only updates the device-local
// preLoginTextSizeProvider, which the reconciler in auth_controller.dart
// pushes to the account on the next successful sign-in.
//
// REAL BUG FOUND AND FIXED (caught on a real device/emulator run):
// this widget lives in main.dart's MaterialApp.router builder, as a
// SIBLING of the routed app content, not a descendant of it -- so it
// has no Navigator/Overlay ancestor of its own. A plain
// PopupMenuButton here crashed on every launch with "No Overlay widget
// found" (its Tooltip needs one to build) and, once that was fixed,
// would still have had nowhere for showMenu() to open its dropdown
// into. See main.dart's own header comment for the two earlier fix
// attempts that introduced a dedicated Navigator/Overlay here instead
// of this one -- the worst of them made the ENTIRE app untappable by
// accident, since Overlay's render object hit-tests as opaque across
// its full bounds regardless of what it paints.
//
// The real fix: no tooltip (IconButton only wraps in one if `tooltip`
// is non-null, so simply omitting it here needs no Overlay at all),
// and the dropdown is opened by calling showMenu() directly against
// this app's own existing rootNavigatorKey (core/navigation/
// root_navigator_key.dart, already used by push_notification_service.dart
// and auth_controller.dart to reach the real app Navigator from
// outside the widget tree for the same structural reason) -- the
// REAL, already-correctly-sized app Navigator that's safely embedded
// inside `child` in main.dart, introducing no new Overlay/Navigator
// anywhere and so no risk of blocking touches meant for the rest of
// the app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../networking/api_client.dart';
import '../navigation/root_navigator_key.dart';
import '../../features/authentication/application/auth_controller.dart';
import '../../features/accessibility/application/accessibility_settings.dart';
import '../../features/profile/data/profile_repository.dart';
import 'pre_login_text_scale.dart';

const _textSizeLabels = {
  'standard': 'Standard',
  'large': 'Large',
  'extra_large': 'Extra Large',
  'maximum': 'Maximum',
};

final _profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(apiClientProvider)));

class QuickTextSizeControl extends ConsumerWidget {
  const QuickTextSizeControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authenticated = ref.watch(authControllerProvider).status ==
        AuthStatus.authenticated;
    final currentTextSize = authenticated
        ? ref.watch(accessibilitySettingsProvider).textSize
        : ref.watch(preLoginTextSizeProvider);

    return IconButton(
      icon: const Text('Aa',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      onPressed: () =>
          _showTextSizeMenu(context, ref, currentTextSize, authenticated),
    );
  }

  Future<void> _showTextSizeMenu(BuildContext buttonContext, WidgetRef ref,
      String currentTextSize, bool authenticated) async {
    final overlayContext = rootNavigatorKey.currentContext;
    if (overlayContext == null) return;
    final button = buttonContext.findRenderObject() as RenderBox;
    final overlayBox =
        Navigator.of(overlayContext).overlay!.context.findRenderObject()
            as RenderBox;
    // Global-coordinate math, not localToGlobal(..., ancestor: ...):
    // the button and the real app's Overlay are on separate branches
    // of the tree (siblings far up, not ancestor/descendant of each
    // other) precisely because of the structural gap this whole fix is
    // about, so there's no ancestor relationship for that parameter to
    // walk -- plain global (screen) coordinates are the one coordinate
    // space both share regardless.
    final buttonTopLeft = button.localToGlobal(Offset.zero);
    final buttonBottomRight =
        button.localToGlobal(button.size.bottomRight(Offset.zero));
    final overlayTopLeft = overlayBox.localToGlobal(Offset.zero);
    final position = RelativeRect.fromLTRB(
      buttonTopLeft.dx - overlayTopLeft.dx,
      buttonTopLeft.dy - overlayTopLeft.dy,
      overlayBox.size.width - (buttonBottomRight.dx - overlayTopLeft.dx),
      overlayBox.size.height - (buttonBottomRight.dy - overlayTopLeft.dy),
    );

    final selected = await showMenu<String>(
      context: overlayContext,
      position: position,
      items: _textSizeLabels.entries
          .map((e) => CheckedPopupMenuItem<String>(
                value: e.key,
                checked: e.key == currentTextSize,
                child: Text(e.value),
              ))
          .toList(),
    );
    if (selected == null) return;
    if (authenticated) {
      if (buttonContext.mounted) {
        await _saveToAccount(buttonContext, ref, selected);
      }
    } else {
      ref.read(preLoginTextSizeProvider.notifier).setTextSize(selected);
    }
  }

  Future<void> _saveToAccount(
      BuildContext context, WidgetRef ref, String textSize) async {
    try {
      final message = await ref
          .read(_profileRepositoryProvider)
          .updateAccountSettings(textSize: textSize);
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
