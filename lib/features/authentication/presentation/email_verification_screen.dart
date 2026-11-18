// lib/features/authentication/presentation/email_verification_screen.dart
//
// UW 1.3: "Upon submitting the registration form, the system sends a
// verification link to the provided email address" -- the real
// backend sends a 6-digit OTP CODE instead (controllers/authController
// .js's register()/verifyEmail, a disclosed deviation its own comment
// documents, same as the email-change flow elsewhere in this app),
// and registration's own success message says so explicitly: "Log in,
// then enter the code we emailed you to verify your address."
//
// REAL, SEVERE GAP FOUND AND FIXED this pass: this screen, and every
// mobile call to POST /auth/verify-email[/resend], did not exist at
// all before now. This isn't just UW 1.3 cosmetics -- it is the ONE
// real activation step a Buyer account has. middleware/auth.js's
// requireVerified (which gates listing/ordering/agreements) checks
// is_email_verified first, and authController.js's verifyEmail is the
// only place anywhere in this codebase that ever flips a Buyer's
// account_status from 'pending_verification' to 'active' (mirroring
// how KYC approval does it for Farmer/Vendor) -- confirmed live this
// session: every "active" buyer already in the database turned out to
// be directly-seeded data with no real verification history at all.
// Without this screen, a real Buyer account could never place an
// order, write a review, or do anything else requireVerified gates,
// permanently.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, this.nextRoute = '/home'});

  /// Where to go on a successful verify when there's nothing to pop
  /// back to -- the fresh-registration entry point (app_router.dart's
  /// `/verify-email?next=/onboarding`) reaches this screen via
  /// `context.go`, which clears history, so `canPop()` is false there
  /// and onboarding would otherwise be skipped entirely. Reached later
  /// from Account & Security (a push), `canPop()` is true and this is
  /// never used -- pop() always wins when there's somewhere to pop to.
  final String nextRoute;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final _otpController = TextEditingController();
  bool _submitting = false;
  bool _resending = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    // REAL BUG FOUND AND FIXED: this screen used to show "Enter the
    // 6-digit code we sent to..." as static text without ever actually
    // sending anything -- confirmed live this session that nothing
    // calls POST /auth/verify-email/resend until the user notices and
    // taps "Resend Code" themselves. A fresh registration only has a
    // code outstanding because /auth/register separately issued one
    // seconds earlier; reaching this screen later from Settings had no
    // code outstanding at all. Sending once, unconditionally, on open
    // makes the screen's own claim true in both cases.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resend());
  }

  Future<void> _verify() async {
    if (_otpController.text.trim().length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final message = await ref
          .read(authRepositoryProvider)
          .verifyEmail(otp: _otpController.text.trim());
      if (!mounted) return;
      // REAL, SEVERE BUG FOUND AND FIXED: refreshUser() used to be
      // awaited BEFORE navigating. app_router.dart's redirect listens
      // for exactly this state change (refreshListenable) and
      // re-evaluates itself against whatever route this screen was
      // STILL on at that moment (reached from registration, that's
      // always a non-/onboarding, non-/walkthrough route) -- with
      // hasSeenWalkthrough still false, that redirect fires and sends
      // the app to /walkthrough on its own, disposing this screen
      // before the line below ever ran. The `if (!mounted) return;`
      // that used to sit AFTER refreshUser() then silently swallowed
      // the rest of this function, so the explicit
      // `context.go('/onboarding')` never executed at all -- a brand
      // new Buyer/Farmer/Vendor landed straight on the walkthrough's
      // text-size step with no Preferences/Interests step ever shown,
      // confirmed as the exact symptom reported live. Navigating FIRST
      // (while still on this screen, so the redirect's own
      // onOnboarding/onWalkthrough check matches the real target) and
      // refreshing the cached user only afterward closes the race --
      // the destination screen still ends up with the refreshed user
      // moments later via the same Riverpod state update, just no
      // longer able to pre-empt getting there at all.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(widget.nextRoute);
      }
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final result =
          await ref.read(authRepositoryProvider).resendEmailVerification();
      if (!mounted) return;
      setState(() {
        // REAL BUG FOUND AND FIXED: the backend's OTP_DEMO_FALLBACK
        // (live-confirmed active in production -- Resend's sandbox
        // restriction blocks real delivery to any address but the
        // account owner's own) returns the actual code as
        // demo_otp_code specifically so a tester isn't stuck with no
        // way to ever receive one; this screen used to discard that
        // field entirely and show only the generic message, leaving
        // "enter the code" with no code anywhere to enter. Shown here
        // and pre-filled into the field below so Verify works with no
        // other action needed.
        _infoMessage = result.demoOtpCode != null
            ? '${result.message}\n\nYour verification code: ${result.demoOtpCode}'
            : result.message;
        if (result.demoOtpCode != null) {
          _otpController.text = result.demoOtpCode!;
        }
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Your Email')),
      body: SafeArea(
        // Same real bug class as login_screen.dart (caught on a real
        // device at a larger text size): a bare Padding+Column here
        // would overflow instead of scrolling once content exceeds the
        // viewport.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                user?.email != null
                    ? 'Enter the 6-digit code we sent to ${user!.email}.'
                    : 'Enter the 6-digit code we emailed you.',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: AppColors.statusCancelledBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(_errorMessage!,
                      style:
                          const TextStyle(color: AppColors.statusCancelledFg)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_infoMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: AppColors.statusSuccessBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(_infoMessage!,
                      style:
                          const TextStyle(color: AppColors.statusSuccessFg)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Verification Code'),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _submitting ? null : _verify,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accent))
                    : const Text('Verify'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _resending ? null : _resend,
                child: Text(_resending ? 'Sending...' : 'Resend Code'),
              ),
              // Never a hard block on browsing -- requireVerified only
              // gates transacting actions server-side (listing,
              // ordering, agreements), same "optional, skippable for
              // now" precedent as onboarding's own "Set Up Later".
              TextButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(widget.nextRoute),
                child: const Text('Skip for Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}
