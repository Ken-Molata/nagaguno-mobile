// lib/features/authentication/presentation/contact_change_screen.dart
//
// Closes a real gap: UW 21.2's change-email and change-phone flows had
// working backend endpoints (requestEmailChange/confirmEmailChange,
// requestPhoneChange/confirmPhoneChange in controllers/authController.js)
// and no mobile screen at all. One shared screen for both channels --
// the two flows are identical in shape (password + new value -> OTP
// sent -> confirm -> forced re-login), differing only in which field
// and which endpoints, so a single parametrized screen avoids a
// near-exact duplicate rather than genuinely different logic.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/validators.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import '../domain/nagaguno_user.dart';

enum ContactChannel { email, phone }

class ContactChangeScreen extends ConsumerStatefulWidget {
  const ContactChangeScreen({super.key, required this.channel});
  final ContactChannel channel;

  @override
  ConsumerState<ContactChangeScreen> createState() =>
      _ContactChangeScreenState();
}

class _ContactChangeScreenState extends ConsumerState<ContactChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _newValueController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpStep = false;
  bool _submitting = false;
  String? _errorMessage;
  String? _infoMessage;

  bool get _isEmail => widget.channel == ContactChannel.email;
  String get _label => _isEmail ? 'email address' : 'phone number';

  // REAL GAP FOUND AND FIXED: this screen is reached for BOTH "add one
  // from scratch" (a phone-registered account has no email yet, or
  // vice versa -- profile_screen.dart's own tile already supports
  // this) and "change an existing one", but every label here
  // hardcoded the "change" wording and never showed what the current
  // value even was, so an account adding its first phone number saw
  // "Change Phone Number" / "New Phone Number" with nothing to
  // actually be changing FROM.
  String? _currentValue(NagagunoUser? user) =>
      _isEmail ? user?.email : user?.phoneNumber;
  bool _isAdding(NagagunoUser? user) => _currentValue(user) == null;

  @override
  void initState() {
    super.initState();
    // REAL GAP FOUND AND FIXED: UW 21.2 -- "Until the new address is
    // verified ... Settings shows 'Waiting for verification of [new
    // email]' with Resend link and Cancel change." A user who already
    // requested a change and left this screen (or the app) before
    // entering the code used to land back on the plain password+new-
    // value form with no sign a change was even pending -- re-entering
    // everything would just re-request it from scratch. Now this reads
    // the already-cached pending value (NagagunoUser.pendingEmail/
    // pendingPhoneNumber, from the same getMe response the rest of the
    // app's session user comes from) and jumps straight to the waiting
    // state.
    final user = ref.read(authControllerProvider).user;
    final pending =
        _isEmail ? user?.pendingEmail : user?.pendingPhoneNumber;
    if (pending != null) {
      _otpStep = true;
      _infoMessage = 'Waiting for verification of $pending.';
    }
  }

  Future<void> _resend() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_isEmail) {
        await repo.resendEmailChange();
      } else {
        await repo.resendPhoneChange();
      }
      if (mounted) {
        setState(() =>
            _infoMessage = 'A confirmation code was sent to your new $_label.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestChange() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_isEmail) {
        await repo.requestEmailChange(
            password: _passwordController.text,
            newEmail: _newValueController.text.trim());
      } else {
        await repo.requestPhoneChange(
            password: _passwordController.text,
            newPhoneNumber: _newValueController.text.trim());
      }
      if (mounted) {
        setState(() {
          _otpStep = true;
          _infoMessage = 'A confirmation code was sent to your new $_label.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmChange() async {
    if (_otpController.text.trim().length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_isEmail) {
        await repo.confirmEmailChange(otp: _otpController.text.trim());
      } else {
        await repo.confirmPhoneChange(otp: _otpController.text.trim());
      }
      if (!mounted) return;
      // REAL BUG FOUND AND FIXED: this used to force a client-side
      // logout() here to match the backend revoking every refresh
      // token including the caller's own -- but UW 21.2 only calls
      // for an email change to log out OTHER devices (nothing at all
      // for phone), never the one making the change. Now that
      // authController.js's confirmEmailChange/confirmPhoneChange
      // both preserve the current session server-side, forcing a
      // logout here would just needlessly discard a session the
      // backend intentionally kept valid. The cached session user still
      // needs a refresh, though, since the account's email/phone
      // genuinely did change and nothing else re-fetches it now.
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_isEmail ? 'Email updated.' : 'Phone number updated.')),
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelPending() async {
    setState(() => _submitting = true);
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_isEmail) {
        await repo.cancelEmailChange();
      } else {
        await repo.cancelPhoneChange();
      }
      if (mounted) {
        setState(() {
          _otpStep = false;
          _infoMessage = null;
          _errorMessage = null;
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final currentValue = _currentValue(user);
    final isAdding = _isAdding(user);
    final channelNoun = _isEmail ? 'Email' : 'Phone Number';
    return Scaffold(
      appBar: AppBar(
          title: Text(isAdding ? 'Add $channelNoun' : 'Change $channelNoun')),
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
                if (!_otpStep) ...[
                  Text(
                      isAdding
                          ? 'Confirm your password and enter your $_label.'
                          : 'Confirm your password and enter your new $_label.',
                      style: AppTypography.body),
                  if (!isAdding) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                          color: AppColors.backgroundStart,
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Text('Current $channelNoun: $currentValue',
                          style: AppTypography.body
                              .copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Current Password'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _newValueController,
                    keyboardType: _isEmail
                        ? TextInputType.emailAddress
                        : TextInputType.phone,
                    decoration: InputDecoration(
                        labelText: isAdding
                            ? (_isEmail ? 'Email Address' : 'Phone Number')
                            : (_isEmail
                                ? 'New Email Address'
                                : 'New Phone Number')),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (_isEmail) {
                        if (!v.contains('@')) {
                          return 'Enter a valid email address.';
                        }
                      } else if (!phPhoneRegex.hasMatch(v.trim())) {
                        return 'Enter a valid Philippine mobile number.';
                      }
                      // REAL GAP FOUND AND FIXED: nothing stopped
                      // "changing" to the exact same value already on
                      // file -- the backend would send an OTP to
                      // confirm a no-op change. Only applies when
                      // there IS a current value to compare against;
                      // adding one from scratch has nothing to collide
                      // with.
                      if (currentValue != null) {
                        final sameValue = _isEmail
                            ? v.trim().toLowerCase() ==
                                currentValue.toLowerCase()
                            : v.trim() == currentValue;
                        if (sameValue) {
                          return _isEmail
                              ? 'Must be a new email address.'
                              : 'Must be a new number.';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton(
                    onPressed: _submitting ? null : _requestChange,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.accent))
                        : const Text('Send Confirmation Code'),
                  ),
                ] else ...[
                  Text('Enter the 6-digit code sent to your new $_label.',
                      style: AppTypography.body),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Confirmation Code'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: _submitting ? null : _confirmChange,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.accent))
                        : const Text('Confirm'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                          onPressed: _submitting ? null : _resend,
                          child: const Text('Resend')),
                      TextButton(
                          onPressed: _submitting ? null : _cancelPending,
                          child: const Text('Cancel')),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _newValueController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
