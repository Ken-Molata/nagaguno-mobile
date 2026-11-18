// lib/features/profile/presentation/account_security_screen.dart
//
// UW 21.2 "Account & Security": Password, Two-factor authentication,
// and Logged-in devices -- the three pieces of this section with no
// mobile screen (and, for Password-while-logged-in and the devices
// list/logout, no backend endpoint either) before this. Email and
// phone number are handled by contact_change_screen.dart already;
// this screen is reached alongside it from the same Settings area.
//
// "Confirming it is the user": UW 21.2's own top rule -- "Before
// changing the email, phone number, password, two-factor
// authentication, or payment details, the user is asked 'Confirm your
// password to continue'... lasts until the user leaves Settings." This
// screen follows the established per-action pattern from
// contact_change_screen.dart/payment_methods_screen.dart instead
// (asking password inline on each action) rather than introducing a
// new settings-session-scoped confirmation mechanism -- a disclosed,
// consistent simplification already made everywhere else this exact
// rule applies, not a new, lower bar introduced just here.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/password_requirements.dart';
import '../../../core/validation/password_requirements_checklist.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../../../core/localization/app_strings.dart';
import '../../authentication/application/auth_controller.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/device.dart';

final _devicesProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(authRepositoryProvider).getDevices());

class AccountSecurityScreen extends ConsumerWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final s = ref.watch(appStringsProvider);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: Text(s.accountAndSecurityTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(s.password, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            const _PasswordForm(),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text(s.twoFactorAuthenticationTitle, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            _TwoFactorSection(enabled: user.twoFactorEnabled),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text(s.loggedInDevicesTitle, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            const _DevicesSection(),
          ],
        ),
      ),
    );
  }
}

class _PasswordForm extends ConsumerStatefulWidget {
  const _PasswordForm();
  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).changePassword(
          currentPassword: _currentController.text,
          newPassword: _newController.text);
      _currentController.clear();
      _newController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(ref.read(appStringsProvider).passwordChangedMessage)));
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Form(
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
                  style: const TextStyle(color: AppColors.statusCancelledFg)),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          TextFormField(
            controller: _currentController,
            obscureText: true,
            decoration: InputDecoration(labelText: s.currentPasswordLabel),
            validator: (v) => (v == null || v.isEmpty) ? s.required_ : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _newController,
            obscureText: true,
            decoration: InputDecoration(labelText: s.newPasswordLabel),
            // UW 21.2: "the user enters the current password and a new
            // one, with the live red and green checklist and 'Password
            // accepted' confirmation of Section 1" -- same first-unmet-
            // requirement message as registration/reset-password,
            // replacing the old bundled passwordRequirementsNotMet text.
            validator: (v) {
              if (v == null || v.isEmpty) return s.required_;
              for (final r in passwordRequirements(s)) {
                if (!r.test(v)) return r.label;
              }
              return null;
            },
          ),
          PasswordRequirementsChecklist(
              controller: _newController, strings: s),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent))
                  : Text(s.changePasswordButton),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }
}

class _TwoFactorSection extends ConsumerStatefulWidget {
  const _TwoFactorSection({required this.enabled});
  final bool enabled;
  @override
  ConsumerState<_TwoFactorSection> createState() => _TwoFactorSectionState();
}

class _TwoFactorSectionState extends ConsumerState<_TwoFactorSection> {
  bool _submitting = false;
  bool _awaitingOtp = false;
  final _otpController = TextEditingController();
  String? _errorMessage;

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    final s = ref.read(appStringsProvider);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.confirmYourPasswordTitle),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: s.password),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(s.cancel)),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(s.continueLabel)),
        ],
      ),
    );
  }

  Future<void> _disable() async {
    final password = await _askPassword();
    if (password == null || password.isEmpty) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).disableTwoFactor(password: password);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                ref.read(appStringsProvider).twoFactorDisabledMessage)));
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestEnable() async {
    final password = await _askPassword();
    if (password == null || password.isEmpty) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestEnableTwoFactor(password: password);
      if (mounted) setState(() => _awaitingOtp = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmEnable() async {
    if (_otpController.text.trim().length != 6) {
      setState(() =>
          _errorMessage = ref.read(appStringsProvider).enterSixDigitCodeError);
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .confirmEnableTwoFactor(otp: _otpController.text.trim());
      await ref.read(authControllerProvider.notifier).refreshUser();
      _otpController.clear();
      if (mounted) {
        setState(() => _awaitingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(ref.read(appStringsProvider).twoFactorEnabledMessage)));
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
                color: AppColors.statusCancelledBg,
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text(_errorMessage!,
                style: const TextStyle(color: AppColors.statusCancelledFg)),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (_awaitingOtp) ...[
          Text(s.enterSixDigitCodeToConfirmPhone,
              style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: s.confirmationCodeLabel),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            ElevatedButton(
              onPressed: _submitting ? null : _confirmEnable,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent))
                  : Text(s.confirmLabel),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                          _awaitingOtp = false;
                          _errorMessage = null;
                        }),
                child: Text(s.cancel)),
          ]),
        ] else
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.twoFactorAuthenticationTitle),
            subtitle: Text(widget.enabled
                ? s.twoFactorOnSubtitle
                : s.twoFactorOffSubtitle),
            value: widget.enabled,
            onChanged: _submitting
                ? null
                : (v) => v ? _requestEnable() : _disable(),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}

class _DevicesSection extends ConsumerWidget {
  const _DevicesSection();

  String _fmt(DateTime d, AppStrings s) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return s.justNowLabel;
    if (diff.inHours < 1) return '${diff.inMinutes}${s.minutesAgo}';
    if (diff.inDays < 1) return '${diff.inHours}${s.hoursAgo}';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _logoutDevice(BuildContext context, WidgetRef ref, Device d) async {
    try {
      await ref.read(authRepositoryProvider).logoutDevice(d.id);
      ref.invalidate(_devicesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  Future<void> _logoutAllOthers(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).logoutAllOtherDevices();
      ref.invalidate(_devicesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                ref.read(appStringsProvider).allOtherDevicesLoggedOut)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(_devicesProvider);
    final s = ref.watch(appStringsProvider);

    return devicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.couldntLoadDevices, style: AppTypography.bodySmall),
          TextButton(
              onPressed: () => ref.invalidate(_devicesProvider),
              child: Text(s.retry)),
        ],
      ),
      data: (devices) {
        final hasOthers = devices.any((d) => !d.isCurrent);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...devices.map((d) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.devices_outlined),
                  title: Text(d.deviceInfo ?? s.unknownDevice),
                  subtitle: Text(d.isCurrent
                      ? s.thisDeviceLabel
                      : '${s.lastActivePrefix}${_fmt(d.createdAt, s)}'),
                  trailing: d.isCurrent
                      ? null
                      : TextButton(
                          onPressed: () => _logoutDevice(context, ref, d),
                          child: Text(s.logOut),
                        ),
                )),
            if (hasOthers) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => _logoutAllOthers(context, ref),
                child: Text(s.logOutAllOtherDevices),
              ),
            ],
          ],
        );
      },
    );
  }
}
