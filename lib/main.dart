// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/connectivity/offline_banner.dart';
import 'core/configuration/firebase_config.dart';
import 'core/session/inactivity_listener.dart';
import 'core/accessibility/pre_login_text_scale.dart';
import 'core/accessibility/quick_text_size_control.dart';
import 'features/accessibility/application/accessibility_settings.dart';
import 'features/authentication/application/auth_controller.dart';
import 'features/kyc/presentation/kyc_resume_refresher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // UW 15's proposed push channel (FCM) -- required before any
  // firebase_messaging call, including the ones AuthController makes
  // on a successful login. Uses explicit FirebaseOptions (see
  // firebase_config.dart's own comment for why, over the Gradle-
  // plugin route) built from --dart-define values that genuinely
  // can't be fabricated here. Guarded: a real chat message is never
  // only delivered via push (UW 13.1's 5-second poll always works
  // regardless), so a missing/invalid Firebase config must not crash
  // the whole app at startup -- it should just mean push notifications
  // silently don't fire.
  if (FirebaseConfig.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: FirebaseConfig.apiKey,
          appId: FirebaseConfig.appId,
          messagingSenderId: FirebaseConfig.messagingSenderId,
          projectId: FirebaseConfig.projectId,
        ),
      );
    } catch (_) {
      // Real credentials present but invalid/unreachable -- still
      // never worth blocking app startup over.
    }
  }
  runApp(const ProviderScope(child: NagagunoApp()));
}

class NagagunoApp extends ConsumerWidget {
  const NagagunoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Must be read here, early, for the fix to actually take effect --
    // Riverpod providers are lazy, so ApiClient's session-expiry
    // callback would never actually get wired to AuthController
    // without something reading this at least once. See the provider's
    // own doc comment in auth_controller.dart for the full context
    // (this replaced a genuine circular-dependency bug).
    ref.watch(authSessionWiringProvider);
    // UW 2.4: must also be read here, early, for the same lazy-provider
    // reason as authSessionWiringProvider above -- InactivityGuard's
    // ref.listen(authControllerProvider, ...) never actually runs until
    // something reads this provider at least once.
    final inactivityGuard = ref.watch(inactivityGuardProvider);
    // UW 21.6's reconciliation rule ("at login, the account's saved
    // settings apply, and if the account has none saved, the device's
    // choice is saved to the account") -- same lazy-provider caveat as
    // the two providers above, it never actually runs until something
    // reads it at least once.
    ref.watch(textSizeReconcilerProvider);

    final router = ref.watch(routerProvider);
    final authenticated =
        ref.watch(authControllerProvider).status == AuthStatus.authenticated;
    final accessibility = ref.watch(accessibilitySettingsProvider);
    // While signed out, there's no account setting to read yet -- fall
    // back to the device-local pre-login choice instead of always
    // showing Standard, matching UW 21.6's "including pre-login ones."
    final effectiveTextScale = authenticated
        ? accessibility.textScale
        : AccessibilitySettings(textSize: ref.watch(preLoginTextSizeProvider))
            .textScale;

    return MaterialApp.router(
      title: 'NagaGuno',
      theme: nagagunoTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // textScale genuinely applied app-wide here, not just previewed
        // on the settings screen itself — MediaQuery.textScaler affects
        // every Text widget in the tree below this point.
        //
        // REAL BUG FOUND AND FIXED (caught on a real device/emulator
        // run, not by analyze/test): QuickTextSizeControl sits in
        // MaterialApp.router's builder, as a SIBLING of the routed
        // `child`, not a descendant of it -- meaning it's outside the
        // app's own Navigator/Overlay entirely. Its PopupMenuButton
        // needed both a Tooltip-hosting Overlay to even build, and a
        // Navigator for showMenu() to open its dropdown -- with
        // neither available, it crashed on every single launch with
        // "No Overlay widget found" before a user ever saw a screen.
        //
        // Two earlier fix attempts were each caught and reverted before
        // landing (see git-free history in this comment's prior
        // revisions if you have it, or just trust this account): a tiny
        // (40x40) Navigator around just the button stopped the crash
        // but clipped the dropdown menu to that same tiny box; routing
        // the ENTIRE reactive Column through one Navigator's
        // PageRouteBuilder.pageBuilder gave the menu proper room but
        // would have frozen `child`/text-scale/inactivity updates
        // forever (pageBuilder runs once); a FULL-SCREEN Navigator
        // layered on top via Positioned.fill fixed both of those, but
        // introduced something far worse, caught only by trying to
        // actually tap the Log In button afterward: Overlay's render
        // object (_RenderTheater) hit-tests as opaque across its ENTIRE
        // bounds regardless of what it visually paints, so a
        // full-screen Navigator anywhere in the tree swallows every
        // touch meant for whatever is underneath it -- the entire rest
        // of the app became untappable, on both the emulator and (very
        // likely the real explanation for) the user's own physical
        // phone.
        //
        // The actual fix introduces no extra Navigator/Overlay
        // anywhere: QuickTextSizeControl is reached for via this app's
        // own existing rootNavigatorKey (core/navigation/
        // root_navigator_key.dart, already used by push notifications
        // and auth_controller.dart for the same reason) to open its
        // menu through the real, legitimate app Navigator that's
        // already safely embedded inside `child` -- see that widget's
        // own header comment for exactly how.
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(effectiveTextScale),
          ),
          child: KycResumeRefresher(
            child: InactivityListener(
              onActivity: inactivityGuard.recordActivity,
              child: Column(
                children: [
                  // Single shared SafeArea for both rows below, rather
                  // than one each -- each row only reserves top inset
                  // for itself when both OfflineBanner (conditional) and
                  // the always-visible Aa control are showing together.
                  const SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        OfflineBanner(),
                        // UW 21.6's "Aa" quick-access control: "appears
                        // in the header of every screen, including
                        // pre-login ones." A dedicated always-visible
                        // top strip, same precedent as OfflineBanner
                        // right above, rather than a floating overlay
                        // that would risk colliding with existing
                        // AppBars/FABs across dozens of untested screens.
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: QuickTextSizeControl(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: child!),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
