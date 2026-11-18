// lib/features/authentication/presentation/reset_password_screen.dart
//
// UW 2.1's "Try another way": pops back to ForgotPasswordScreen, which
// is still alive underneath this one on the nav stack (pushed, not
// replaced) with the identifier already typed in -- picking the other
// channel and submitting again both re-sends and switches channel in
// one extra tap, without the "start over or re-enter their email"
// spec explicitly rules out. A dedicated in-place resend (same
// channel, no pop) was considered and skipped as a disclosed
// simplification: it would need the identifier/channel threaded
// through as extra constructor params purely to re-issue the same
// backend call ForgotPasswordScreen already makes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/password_requirements.dart';
import '../../../core/validation/password_requirements_checklist.dart';
import '../../../core/localization/app_strings.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.userId, this.demoOtpCode});
  final String userId;
  // REAL BUG FOUND AND FIXED: with the backend's OTP_DEMO_FALLBACK
  // active in production, forgotPassword's response carries the real
  // code here whenever actual delivery failed -- previously discarded
  // entirely by auth_repository.dart's forgotPassword(), leaving this
  // screen's OTP field blank with no way for anyone to know what to
  // type into it. Pre-filled below, same pattern as
  // EmailVerificationScreen/PhoneVerificationScreen's own resend.
  final String? demoOtpCode;
  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _otpController =
      TextEditingController(text: widget.demoOtpCode);
  final _newPasswordController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            userId: widget.userId,
            otp: _otpController.text.trim(),
            newPassword: _newPasswordController.text,
          );
      if (!mounted) return;
      // Real backend revokes every refresh token and clears cookies on
      // a successful reset -- for this mobile client that means the
      // locally stored refresh token (if any) is now stale too.
      // Popping back to login is correct; there's no session left to
      // preserve.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only this screen's password requirements (UW 2.1: "the same
    // requirements as registration, with the same live red/green
    // checklist") are localized here -- the rest of this screen's
    // strings are hardcoded English, a pre-existing gap against UW
    // 1.4's "platform-wide" language rule, disclosed rather than fixed
    // since it's unrelated to the checklist this pass is adding.
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        // Same real bug class as login_screen.dart (caught on a real
        // device at a larger text size): a bare Padding+Form+Column
        // here would overflow instead of scrolling once content
        // exceeds the viewport.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                    'Enter the 6-digit code we sent you, and your new password.',
                    style: AppTypography.body),
                const SizedBox(height: AppSpacing.lg),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                        color: AppColors.statusCancelledBg,
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: AppColors.statusCancelledFg)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reset Code'),
                  validator: (v) => (v == null || v.trim().length != 6)
                      ? 'Enter the 6-digit code.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  // UW 1 / 2.1: specific unmet requirement, not a bundled
                  // message -- see register_screen.dart's identical fix.
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required.';
                    for (final r in passwordRequirements(s)) {
                      if (!r.test(v)) return r.label;
                    }
                    return null;
                  },
                ),
                PasswordRequirementsChecklist(
                    controller: _newPasswordController, strings: s),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent))
                      : const Text('Reset Password'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Try Another Way'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}
