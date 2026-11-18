// lib/features/authentication/presentation/forgot_password_screen.dart
//
// Closes a real gap: "Forgot password?" on LoginScreen had an empty
// onPressed handler — a visibly broken button, worse than not having
// one at all, since it teaches a user the app doesn't work.
//
// UW 2.1: "The user is then asked to choose how to receive the OTP,
// from two options, always both offered regardless of which
// identifier they entered." REAL GAP FOUND AND FIXED: this used to
// infer the channel purely from whether the typed identifier looked
// like an email, with no way to choose the other one even when the
// account has both on file -- never offering a real choice at all,
// despite the real backend (middleware/auth.js's own `channel` Joi
// field) having always supported it. Stays alive underneath
// ResetPasswordScreen on the nav stack (a push, not a replace) so
// "Try another way" can pop back here with the identifier already
// typed in, matching UW 2.1's "without starting over or re-entering
// their email."

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart' show AuthException;
import 'reset_password_screen.dart';
import '../../account_recovery/presentation/account_recovery_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _identifierController = TextEditingController();
  bool _submitting = false;
  String? _statusMessage;
  String _channel = 'email';
  bool _channelTouched = false;

  bool get _isEmail => _identifierController.text.contains('@');

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _statusMessage = null;
    });
    try {
      final result = await ref.read(authRepositoryProvider).forgotPassword(
            email: _isEmail ? _identifierController.text.trim() : null,
            phoneNumber: !_isEmail ? _identifierController.text.trim() : null,
            channel: _channel,
          );
      if (!mounted) return;
      if (result.userId != null) {
        // Only advance when a real account was found -- the backend's
        // anti-enumeration message is the same either way, but this
        // client genuinely cannot proceed to the reset step without
        // a real user_id (see the repository's own note on this).
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
                userId: result.userId!, demoOtpCode: result.demoOtpCode)));
      } else {
        setState(() => _statusMessage =
            'If this account exists, you will receive a reset code shortly.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _statusMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _statusMessage = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
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
              const Text(
                  'Enter your email or mobile number and we\'ll send you a reset code.',
                  style: AppTypography.body),
              const SizedBox(height: AppSpacing.lg),
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: AppColors.backgroundStart,
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(_statusMessage!, style: AppTypography.bodySmall),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextField(
                controller: _identifierController,
                decoration:
                    const InputDecoration(labelText: 'Email or Mobile Number'),
                onChanged: (_) {
                  // Defaults the channel to match what's being typed,
                  // but only until the user actually picks one
                  // themselves -- after that, their explicit choice
                  // (UW 2.1's "always both offered") is never
                  // silently overridden by further typing.
                  if (_channelTouched) return;
                  setState(() => _channel = _isEmail ? 'email' : 'phone');
                },
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Receive the code via', style: AppTypography.label),
              RadioGroup<String>(
                groupValue: _channel,
                onChanged: (v) => setState(() {
                  _channelTouched = true;
                  if (v != null) _channel = v;
                }),
                child: const Column(children: [
                  RadioListTile<String>(
                      title: Text('Email'),
                      value: 'email',
                      contentPadding: EdgeInsets.zero),
                  RadioListTile<String>(
                      title: Text('Phone Number'),
                      value: 'phone',
                      contentPadding: EdgeInsets.zero),
                ]),
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
                    : const Text('Send Reset Code'),
              ),
              const SizedBox(height: AppSpacing.sm),
              // UW 2.1's closing line: "If neither the email nor the
              // phone number can receive the OTP, the user selects 'I
              // can't access my email or phone number'... which opens
              // the recovery process in Section 2.5."
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AccountRecoveryScreen())),
                  child: const Text('I can\'t access my email or phone number'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }
}
