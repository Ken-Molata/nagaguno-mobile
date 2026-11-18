// lib/features/authentication/presentation/login_2fa_screen.dart
//
// Closes a real gap: UW 2.2's second login step for a 2FA-enabled
// account had no screen at all. Before this, login() would throw a
// raw type-cast error the moment such an account's credentials were
// correct (the backend returns {requires2FA: true, userId} instead of
// tokens, which nothing here understood), crashing the app rather than
// showing this step.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

class Login2FAScreen extends ConsumerStatefulWidget {
  const Login2FAScreen({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<Login2FAScreen> createState() => _Login2FAScreenState();
}

class _Login2FAScreenState extends ConsumerState<Login2FAScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _submitting = false;
  bool _resending = false;
  String? _errorMessage;
  String? _infoMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final error =
        await ref.read(authControllerProvider.notifier).verifyLogin2FA(
              userId: widget.userId,
              otp: _otpController.text.trim(),
            );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      setState(() => _errorMessage = error.message);
    }
    // On success, authControllerProvider's state change triggers the
    // router's redirect to /home automatically, same as regular login.
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resendLogin2FA(userId: widget.userId);
      if (mounted) {
        setState(
            () => _infoMessage = 'A new code has been sent to your phone.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify It\'s You')),
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
                    'Enter the 6-digit code sent to your phone to finish logging in.',
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
                  decoration: const InputDecoration(labelText: 'Login Code'),
                  validator: (v) => (v == null || v.trim().length != 6)
                      ? 'Enter the 6-digit code.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent))
                      : const Text('Verify & Log In'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: _resending ? null : _resend,
                  child: _resending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Resend Code'),
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
    super.dispose();
  }
}
