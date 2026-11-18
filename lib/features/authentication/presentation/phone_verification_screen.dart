// lib/features/authentication/presentation/phone_verification_screen.dart
//
// Phone-channel counterpart of email_verification_screen.dart (see that
// file's own header for the full history) -- for a phone-registered
// account (auth_provider = 'phone', no email on file). Registration now
// lets the user pick either channel to register with (register_screen
// .dart's toggle), and whichever one they pick is also the one real
// activation step their account has: middleware/auth.js's
// requireVerified checks is_phone_verified instead of is_email_verified
// for this auth_provider, and authController.js's confirmPhoneVerification
// is the only place that ever flips a phone-registered Buyer's
// account_status from 'pending_verification' to 'active'.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

class PhoneVerificationScreen extends ConsumerStatefulWidget {
  const PhoneVerificationScreen({super.key, this.nextRoute = '/home'});

  /// Same role as EmailVerificationScreen.nextRoute -- see that file's
  /// own doc comment.
  final String nextRoute;

  @override
  ConsumerState<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState
    extends ConsumerState<PhoneVerificationScreen> {
  final _otpController = TextEditingController();
  bool _submitting = false;
  bool _resending = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    // Same fix as EmailVerificationScreen's own initState -- send once,
    // unconditionally, on open, so this screen's "we sent a code"
    // claim is actually true whether reached fresh from registration
    // or later from Settings.
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
          .confirmPhoneVerification(otp: _otpController.text.trim());
      if (!mounted) return;
      // REAL, SEVERE BUG FOUND AND FIXED: same race as
      // EmailVerificationScreen's own _verify() -- see that file's
      // header comment for the full mechanism. Navigating to
      // widget.nextRoute (/onboarding, reached fresh from
      // registration) BEFORE refreshUser() keeps app_router.dart's
      // walkthrough redirect from firing against this screen's old
      // route first and disposing it before the navigation below ever
      // ran, which is what let a brand new phone-registered account
      // skip straight past Preferences/Interests into the walkthrough.
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
          await ref.read(authRepositoryProvider).requestPhoneVerification();
      if (!mounted) return;
      setState(() {
        // Same demo-fallback display fix as EmailVerificationScreen's
        // own _resend() -- the backend's SMS demo fallback returns the
        // real code as demo_otp_code specifically so a tester isn't
        // stuck with no way to ever receive one.
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
      appBar: AppBar(title: const Text('Verify Your Phone Number')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                user?.phoneNumber != null
                    ? 'Enter the 6-digit code we sent by SMS to ${user!.phoneNumber}.'
                    : 'Enter the 6-digit code we sent by SMS.',
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
              // now" precedent as EmailVerificationScreen's own skip.
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
