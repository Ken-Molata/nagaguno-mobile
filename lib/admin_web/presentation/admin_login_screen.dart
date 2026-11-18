// lib/admin_web/presentation/admin_login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../features/account_recovery/presentation/account_recovery_screen.dart';
import '../application/admin_auth_controller.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final error = await ref.read(adminAuthControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _errorMessage = error?.message;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            margin: const EdgeInsets.all(AppSpacing.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('NagaGuno Admin', style: AppTypography.h1),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('Sign in to the Admin Dashboard',
                        style: AppTypography.bodySmall),
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
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Email is required.'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Password is required.'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
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
                          : const Text('Sign In'),
                    ),
                    // UW 2.5: same entry point as the consumer login
                    // screen's own "Can't access your email or phone?"
                    // link (features/authentication/presentation/
                    // login_screen.dart), reusing AccountRecoveryScreen
                    // as-is -- it's self-contained (no consumer-router
                    // or consumer-auth-controller coupling) and works
                    // for an Admin account's own lockout exactly like
                    // any other role's, since POST /account-recovery/
                    // verify-identity never filtered by role. Pushed
                    // imperatively, not a named route, for the same
                    // reason login_screen.dart's own comment gives: a
                    // go_router route here would be bounced straight
                    // back to /login by the unauthenticated redirect
                    // guard before the user ever saw it.
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AccountRecoveryScreen())),
                        child: const Text('Can\'t access your account?'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
