// lib/features/authentication/presentation/cancel_email_change_screen.dart
//
// UW 21.2: "A notice is sent to the current address: 'A request was
// made to change the email on your NagaGuno account to [new email].
// If this wasn't you, select This wasn't me.' That link cancels the
// request and prompts a password change." REAL, CONCRETE GAP FOUND AND
// FIXED this pass: the backend has always generated, emailed, and
// handled this link (authController.js's cancelEmailChangeByLink,
// reachable at CLIENT_URL/settings/cancel-email-change?token=...,
// deliberately unauthenticated since the device opening it may have no
// session) -- but nothing in the app ever rendered a screen at that
// path, so clicking the real link from an email would have hit
// whatever the web build's 404/catch-all is, or silently redirected to
// login on mobile. Registered as a public route in app_router.dart,
// outside the auth-redirect gate, same as /login and /register.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

class CancelEmailChangeScreen extends ConsumerStatefulWidget {
  const CancelEmailChangeScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<CancelEmailChangeScreen> createState() =>
      _CancelEmailChangeScreenState();
}

class _CancelEmailChangeScreenState
    extends ConsumerState<CancelEmailChangeScreen> {
  bool _loading = true;
  String? _resultMessage;
  bool _succeeded = false;

  @override
  void initState() {
    super.initState();
    _cancel();
  }

  Future<void> _cancel() async {
    try {
      final message = await ref
          .read(authRepositoryProvider)
          .cancelEmailChangeByLink(widget.token);
      if (mounted) {
        setState(() {
          _resultMessage = message;
          _succeeded = true;
          _loading = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _resultMessage = e.message;
          _succeeded = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading)
                  const CircularProgressIndicator()
                else ...[
                  Icon(
                    _succeeded ? Icons.check_circle : Icons.error_outline,
                    size: 48,
                    color: _succeeded
                        ? AppColors.statusSuccessFg
                        : AppColors.statusCancelledFg,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _resultMessage ?? '',
                    textAlign: TextAlign.center,
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // UW 21.2's "prompts a password change" -- this link
                  // is reachable with no session, so the only thing
                  // that can actually be offered here is the path back
                  // into one: login, then Account & Security's own
                  // Password section.
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Log In'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
