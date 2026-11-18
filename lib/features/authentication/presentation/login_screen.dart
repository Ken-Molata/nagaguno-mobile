// lib/features/authentication/presentation/login_screen.dart
//
// UW 21.5/21.9: the first, complete translated vertical slice -- see
// core/localization/app_strings.dart's own header comment for the
// real scope of what this is and isn't.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/configuration/env_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_toggle_button.dart';
import '../../../shared/widgets/nagaguno_badge.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import 'forgot_password_screen.dart';
import 'login_2fa_screen.dart';
import '../../account_recovery/presentation/account_recovery_screen.dart';
import '../../account_recovery/presentation/recovery_status_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController =
      TextEditingController(); // email or phone — backend accepts either
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorMessage;
  Map<String, String>? _fieldErrors;

  bool get _identifierIsEmail => _identifierController.text.contains('@');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
      _fieldErrors = null;
    });

    try {
      final error = await ref.read(authControllerProvider.notifier).login(
            email:
                _identifierIsEmail ? _identifierController.text.trim() : null,
            phoneNumber:
                !_identifierIsEmail ? _identifierController.text.trim() : null,
            password: _passwordController.text,
          );

      if (!mounted) return;
      setState(() => _submitting = false);

      if (error != null) {
        setState(() {
          _errorMessage = error.message;
          _fieldErrors = error.fieldErrors;
        });
      }
      // On success, authControllerProvider's state change triggers the
      // router's redirect to /home automatically — no explicit
      // navigation call needed here.
    } on TwoFactorRequiredException catch (e) {
      // UW 2.2: this account has 2FA on -- credentials were correct,
      // but there's a second step before any tokens exist. Previously
      // uncaught here, which crashed the app at this exact point.
      if (!mounted) return;
      setState(() => _submitting = false);
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => Login2FAScreen(userId: e.userId)));
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      // Real, necessary distinction: idToken (not accessToken) is
      // what the backend actually verifies (googleClient.verifyIdToken
      // on the Node side) — sending the wrong one would fail
      // verification entirely, not just with a confusing error.
      final googleUser = await GoogleSignIn(
        serverClientId: EnvConfig.googleServerClientId,
      ).signIn();
      if (googleUser == null) {
        // User cancelled the Google account picker -- not an error.
        if (mounted) setState(() => _submitting = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        if (mounted) {
          setState(() {
            _submitting = false;
            _errorMessage = ref.read(appStringsProvider).googleSignInNoToken;
          });
        }
        return;
      }

      final error = await ref
          .read(authControllerProvider.notifier)
          .googleAuth(idToken: idToken);
      if (!mounted) return;
      if (error != null) {
        setState(() {
          _submitting = false;
          _errorMessage = error.message;
        });
      }
      // Success: same auto-redirect as regular login, no explicit nav needed.
    } on GoogleAuthNeedsRoleException {
      // Real backend business rule: a genuinely new Google account
      // needs a role, which its own Joi schema doesn't require but
      // the actual creation logic does. Prompt for one and retry
      // with it included, rather than fail with a confusing error.
      if (!mounted) return;
      setState(() => _submitting = false);
      await _promptForRoleAndRetryGoogleAuth();
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = ref.read(appStringsProvider).googleSignInFailed;
        });
      }
    }
  }

  Future<void> _promptForRoleAndRetryGoogleAuth() async {
    final s = ref.read(appStringsProvider);
    final role = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(s.almostDoneWhatDescribesYou),
        children: [
          SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop('buyer'),
              child: Text(s.buyer)),
          SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop('farmer'),
              child: Text(s.farmer)),
          SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop('vendor'),
              child: Text(s.vendor)),
        ],
      ),
    );
    if (role == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      final googleUser = await GoogleSignIn(
        serverClientId: EnvConfig.googleServerClientId,
      ).signInSilently();
      final idToken = (await googleUser?.authentication)?.idToken;
      if (idToken == null) {
        // The silent re-auth genuinely can fail in some edge cases
        // (token expired between the two calls) -- rather than leave
        // the user stuck, ask them to just start over cleanly.
        if (mounted) {
          setState(() {
            _submitting = false;
            _errorMessage = s.tapSignInWithGoogleAgain;
          });
        }
        return;
      }
      final error = await ref
          .read(authControllerProvider.notifier)
          .googleAuth(idToken: idToken, role: role);
      if (!mounted) return;
      setState(() => _submitting = false);
      if (error != null) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = s.somethingWentWrongTryAgain;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    // Same green-header + cream-curtain contrast layout as the home
    // dashboard (lib/features/dashboard/presentation/home_screen.dart)
    // -- deliberately reused rather than reinvented, so the two
    // "first things a user sees" (home, and this) read as one design
    // language. The badge/language toggle and title sit directly on
    // the green header; the form itself is the curtain content.
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // UW 21.9: "the toggle in the header of the landing,
                  // login, and registration screens."
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      NagaGunoBadge(),
                      SizedBox(width: AppSpacing.sm),
                      LanguageToggleButton(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(s.welcomeBack,
                      style:
                          AppTypography.display.copyWith(color: Colors.white)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(s.logInToYourAccount,
                      style: AppTypography.bodySmall
                          .copyWith(color: Colors.white70)),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.backgroundStart,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    topRight: Radius.circular(AppRadius.xl),
                  ),
                ),
                // REAL BUG FOUND AND FIXED (caught on a real device/
                // emulator run, at a larger text size -- not by
                // analyze/test, which never exercises a non-default
                // text scale): this screen had no scroll wrapper at
                // all. At the default text size the content happened
                // to fit, but switching the "Aa" control to Large/
                // Extra Large/Maximum -- the exact feature this app
                // offers its stated low-vision/elderly audience --
                // made the form taller than the viewport, with "Sign
                // in with Google" and "Register" pushed off-screen and
                // unreachable, no way to scroll down to them. A
                // SingleChildScrollView fixes this for any screen size
                // or text scale, not just this one observed overflow.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.statusCancelledBg,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(_errorMessage!,
                                style: const TextStyle(
                                    color: AppColors.statusCancelledFg)),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        TextFormField(
                          controller: _identifierController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: s.emailOrMobileNumber,
                            errorText: _fieldErrors?['email'] ??
                                _fieldErrors?['phone_number'],
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? s.thisFieldIsRequired
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: s.password,
                            errorText: _fieldErrors?['password'],
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? s.passwordIsRequired
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen())),
                            child: Text(s.forgotPassword),
                          ),
                        ),
                        // UW 2.5: pushed imperatively, same as ForgotPasswordScreen
                        // above and for the same reason -- a go_router route here
                        // would be bounced straight back to /login by the
                        // redirect's unauthenticated-status guard before the user
                        // ever saw it.
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AccountRecoveryScreen())),
                            child: Text(s.cantAccessEmailOrPhone),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const RecoveryStatusScreen())),
                            child: Text(s.checkARecoveryRequest),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.accent))
                              : Text(s.logIn),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Row(children: [
                          const Expanded(child: Divider()),
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm),
                              child: Text(s.orDivider,
                                  style: AppTypography.bodySmall)),
                          const Expanded(child: Divider()),
                        ]),
                        const SizedBox(height: AppSpacing.md),

                        OutlinedButton.icon(
                          onPressed: _submitting ? null : _signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata,
                              size:
                                  24), // a real Google "G" icon asset would replace this in a production build
                          label: Text(s.signInWithGoogle),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.dontHaveAnAccount,
                                style: AppTypography.bodySmall),
                            TextButton(
                              onPressed: () => context.go('/register'),
                              child: Text(s.register),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
