// lib/admin_web/presentation/settings/admin_settings_screen.dart
//
// UW 21.10: "Admin accounts have Profile, Account & Security,
// Language, and Accessibility & Display only; Payment Details,
// Preferences & Interests, and delivery notification switches do not
// apply. Admin Settings are used on the web Admin Dashboard only."
// Reuses ProfileRepository/AuthRepository's real endpoints directly
// (the consumer app's own AccountSettingsScreen/
// AccessibilitySettingsScreen/EditProfileScreen aren't reused as
// widgets since each calls the consumer authControllerProvider
// directly to refresh the cached user -- this screen is the same
// backend contract, wired to adminAuthControllerProvider instead).
//
// REAL GAP FOUND AND FIXED: the stale comment this replaced claimed
// password change and 2FA had no repository method anywhere in the
// app -- true when it was written, but account_security_screen.dart
// (the consumer app's own UW 21.2 screen) has called
// AuthRepository.changePassword/disableTwoFactor/
// requestEnableTwoFactor/confirmEnableTwoFactor for a while now. Those
// methods were just never wired into THIS screen, so "Account &
// Security" here stayed stuck at email/phone only -- but UW 21.10
// says Admin gets the full Account & Security group (21.2), not a
// trimmed one, so Password and Two-Factor Authentication were a real,
// standing gap, not an intentional admin restriction (21.10's own
// restriction list names Payment Details/Preferences/delivery
// switches, never Password or 2FA).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/utils/image_picking.dart';
import '../../../core/validation/password_requirements.dart';
import '../../../features/authentication/application/auth_controller.dart'
    show authRepositoryProvider;
import '../../../features/authentication/data/auth_repository.dart';
import '../../../features/profile/data/profile_repository.dart';
import '../../../features/profile/domain/profile_details.dart';
import '../../application/admin_auth_controller.dart';

final _profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(apiClientProvider)));

const _textSizeLabels = {
  'standard': 'Standard',
  'large': 'Large',
  'extra_large': 'Extra Large',
  'maximum': 'Maximum',
};

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});
  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  ProfileDetails? _profile;
  bool _loading = true;
  bool _saving = false;
  final _aboutController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(_profileRepositoryProvider).getMyProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _aboutController.text = profile.aboutMe ?? '';
      _addressController.text = profile.barangay ?? '';
      _loading = false;
    });
  }

  Future<void> _snack(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await ref.read(_profileRepositoryProvider).updateProfile(
          aboutMe: _aboutController.text, barangay: _addressController.text);
      await _load();
      await _snack('Profile updated.');
    } catch (_) {
      await _snack('We couldn\'t save your changes. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadPhoto() async {
    final file = await pickAndCompressImage();
    if (file == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(_profileRepositoryProvider).uploadPhoto(file.path);
      await _load();
    } catch (_) {
      await _snack('Couldn\'t upload that photo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSetting(Future<String> Function() call) async {
    setState(() => _saving = true);
    try {
      final message = await call();
      await ref.read(adminAuthControllerProvider.notifier).refreshUser();
      await _snack(message);
    } catch (_) {
      await _snack('We couldn\'t save this setting. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(adminAuthControllerProvider).user;
    final accessibility = user == null
        ? null
        : (
            textSize: user.textSize,
            highContrast: user.highContrast,
            boldText: user.boldText,
            reduceMotion: user.reduceMotion,
          );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Settings', style: AppTypography.h1),
                    const SizedBox(height: AppSpacing.lg),

                    _Section(title: 'Profile', children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.backgroundStart,
                          backgroundImage: _profile?.avatarUrl != null
                              ? NetworkImage(_profile!.avatarUrl!)
                              : null,
                          child: _profile?.avatarUrl == null
                              ? const Icon(Icons.person, color: AppColors.primary)
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // Bare in a Row: the theme's minimumSize is
                        // Size.fromHeight(48) (infinite width), which a
                        // Row's unbounded child constraints turn into
                        // "BoxConstraints forces an infinite width".
                        OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44)),
                            onPressed: _saving ? null : _uploadPhoto,
                            child: const Text('Upload Photo')),
                      ]),
                      const SizedBox(height: AppSpacing.md),
                      _ReadOnlyField(
                          label: 'Full name',
                          value: _profile?.fullName ?? '',
                          note: 'Used to verify your identity; cannot be edited here.'),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _aboutController,
                        decoration: const InputDecoration(labelText: 'About'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                            onPressed: _saving ? null : _saveProfile,
                            child: const Text('Save')),
                      ),
                    ]),

                    _Section(title: 'Account & Security', children: [
                      _ReadOnlyField(label: 'Email', value: user?.email ?? ''),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton(
                        onPressed: () => _showChangeEmailDialog(),
                        child: const Text('Change Email'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ReadOnlyField(
                          label: 'Phone', value: _profile?.phoneNumber ?? '—'),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton(
                        onPressed: () => _showChangePhoneDialog(),
                        child: const Text('Change Phone'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                        onPressed: () => _showChangePasswordDialog(),
                        child: const Text('Change Password'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Two-Factor Authentication'),
                        subtitle: Text(user?.twoFactorEnabled == true
                            ? 'A code is sent to your phone each time you log in.'
                            : "Off -- turning this on sends a code to the phone on file to confirm it's reachable."),
                        value: user?.twoFactorEnabled ?? false,
                        onChanged: _saving
                            ? null
                            : (v) => v
                                ? _enableTwoFactor()
                                : _disableTwoFactor(),
                      ),
                    ]),

                    _Section(title: 'Language', children: [
                      DropdownButton<String>(
                        value: user?.language ?? 'en',
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'tl', child: Text('Tagalog')),
                        ],
                        onChanged: _saving
                            ? null
                            : (v) {
                                if (v != null) {
                                  _saveSetting(() => ref
                                      .read(_profileRepositoryProvider)
                                      .updateAccountSettings(language: v));
                                }
                              },
                      ),
                    ]),

                    if (accessibility != null)
                      _Section(title: 'Accessibility & Display', children: [
                        const Text('Text size', style: AppTypography.label),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: _textSizeLabels.entries
                              .map((e) => ChoiceChip(
                                    label: Text(e.value),
                                    selected: accessibility.textSize == e.key,
                                    onSelected: _saving
                                        ? null
                                        : (_) => _saveSetting(() => ref
                                            .read(_profileRepositoryProvider)
                                            .updateAccountSettings(
                                                textSize: e.key)),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SwitchListTile(
                          title: const Text('High contrast'),
                          value: accessibility.highContrast,
                          onChanged: _saving
                              ? null
                              : (v) => _saveSetting(() => ref
                                  .read(_profileRepositoryProvider)
                                  .updateAccountSettings(highContrast: v)),
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          title: const Text('Bold text'),
                          value: accessibility.boldText,
                          onChanged: _saving
                              ? null
                              : (v) => _saveSetting(() => ref
                                  .read(_profileRepositoryProvider)
                                  .updateAccountSettings(boldText: v)),
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          title: const Text('Reduce motion'),
                          value: accessibility.reduceMotion,
                          onChanged: _saving
                              ? null
                              : (v) => _saveSetting(() => ref
                                  .read(_profileRepositoryProvider)
                                  .updateAccountSettings(reduceMotion: v)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ]),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _showChangeEmailDialog() async {
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'New email')),
            TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Send Confirmation')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authRepositoryProvider).requestEmailChange(
          password: passwordController.text, newEmail: emailController.text.trim());
      await _snack('Check your new email for a confirmation code.');
    } on AuthException catch (e) {
      await _snack(e.message);
    }
  }

  Future<void> _showChangePhoneDialog() async {
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'New phone number')),
            TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Send Code')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authRepositoryProvider).requestPhoneChange(
          password: passwordController.text,
          newPhoneNumber: phoneController.text.trim());
      await _snack('Check your new number for a confirmation code.');
    } on AuthException catch (e) {
      await _snack(e.message);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password')),
            TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Change Password')),
        ],
      ),
    );
    if (confirmed != true) return;
    // UW 1/21.2's live checklist is the consumer app's own
    // _PasswordForm UI, built on AppStrings labels this all-English
    // admin screen doesn't use -- the real backend rule
    // (passwordMeetsAllRequirements) is still enforced here so this
    // never submits a password the server would reject anyway.
    if (!passwordMeetsAllRequirements(newController.text)) {
      await _snack(
          'Password must be 8+ characters with upper/lowercase, a number, and a special character.');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentController.text,
          newPassword: newController.text);
      await _snack('Password changed.');
    } on AuthException catch (e) {
      await _snack(e.message);
    }
  }

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm your password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Continue')),
        ],
      ),
    );
  }

  Future<void> _disableTwoFactor() async {
    final password = await _askPassword();
    if (password == null || password.isEmpty) return;
    try {
      await ref.read(authRepositoryProvider).disableTwoFactor(password: password);
      await ref.read(adminAuthControllerProvider.notifier).refreshUser();
      await _snack('Two-factor authentication is off.');
    } on AuthException catch (e) {
      await _snack(e.message);
    }
  }

  Future<void> _enableTwoFactor() async {
    final password = await _askPassword();
    if (password == null || password.isEmpty) return;
    try {
      await ref.read(authRepositoryProvider).requestEnableTwoFactor(password: password);
    } on AuthException catch (e) {
      await _snack(e.message);
      return;
    }
    if (!mounted) return;
    final otpController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter confirmation code'),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: '6-digit code sent to your phone'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(authRepositoryProvider)
          .confirmEnableTwoFactor(otp: otpController.text.trim());
      await ref.read(adminAuthControllerProvider.notifier).refreshUser();
      await _snack('Two-factor authentication is on.');
    } on AuthException catch (e) {
      await _snack(e.message);
    }
  }

  @override
  void dispose() {
    _aboutController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value, this.note});
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label),
        Text(value, style: AppTypography.body),
        if (note != null)
          Text(note!, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
      ],
    );
  }
}
