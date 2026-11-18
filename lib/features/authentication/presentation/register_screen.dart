// lib/features/authentication/presentation/register_screen.dart
//
// Validation rules verified against middleware/auth.js's
// validateRegistration schema exactly — including the real password
// pattern and the real phone-number pattern for THIS endpoint
// specifically (registration's phone rule — 11 digits, no country
// code prefix — differs from KYC's own phone rule; each screen
// validates against its own endpoint's actual rule, not a shared
// assumption).
//
// REAL, SEVERE BUG FOUND AND FIXED this pass: this screen had NO date
// of birth field at all, despite middleware/auth.js's
// validateRegistration Joi schema requiring `date_of_birth` on every
// POST /auth/register with no default (`.required()`, confirmed
// directly against that file). Every registration attempt through
// this screen was therefore rejected outright with "Please enter a
// valid date of birth." -- the single most basic flow in the app,
// completely non-functional. Every account used for testing elsewhere
// this session came from direct SQL seed data, which is presumably
// why this was never caught by exercising the app itself. UW 1 is
// explicit about the UI shape: "three drop-down lists (Month, Day,
// Year)... so that it works the same way on every device, including
// low-end phones" -- not a native date picker.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/naga_city_barangays.dart';
import '../../../core/validation/validators.dart';
import '../../../core/validation/date_of_birth.dart';
import '../../../core/validation/password_requirements.dart';
import '../../../core/validation/password_requirements_checklist.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_toggle_button.dart';
import '../../../shared/widgets/legal_links.dart';
import '../../../shared/widgets/nagaguno_badge.dart';
import '../application/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  // REAL BUG FOUND AND FIXED: barangay used to be an optional,
  // open-ended free-text field -- the same real gap already found and
  // fixed for KYC's own address (kyc_submission_screen.dart: a fixed
  // Naga City barangay dropdown, required, since this app only
  // operates in Naga City and a freehand value can't be reliably
  // matched against anything). Now required and selected from the
  // same real 27-barangay list.
  String? _barangay;
  final _passwordController = TextEditingController();
  String _role = 'buyer';
  // REAL GAP FOUND AND FIXED: registration used to require an email
  // unconditionally (both this screen's own validator and the real
  // backend's, verified directly against the old middleware/auth.js
  // validateRegistration Joi schema) even though phone_number was
  // already otherwise fully usable as the account's sole contact
  // method -- auth_controller.dart's register()/login() and
  // authController.js's own `auth_provider: email ? 'email' : 'phone'`
  // already assumed a phone-only account was possible. The backend
  // validator now actually allows it; this toggle is what lets the
  // user pick which one to register with, matching whichever channel
  // the OTP they verify next is sent to (/verify-email or
  // /verify-phone).
  String _registerVia = 'email'; // 'email' | 'phone'
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorMessage;
  Map<String, String>? _fieldErrors;

  int? _birthMonth;
  int? _birthDay;
  int? _birthYear;

  /// UW 1: "The Day list adjusts to the month and year chosen (for
  /// example, February shows 28 or 29)." A non-leap year (28 days) is
  /// assumed until a year is actually picked, matching the Year list
  /// defaulting to nothing selected rather than guessing a birth year.
  int _daysInSelectedMonth() =>
      daysInMonth(_birthYear ?? 2001, _birthMonth ?? 1);

  /// UW 1: "The Year list starts at the current year and runs
  /// backwards." No explicit lower bound given -- 100 years covers
  /// every realistic account holder without an unbounded list.
  List<int> get _birthYearOptions {
    final currentYear = DateTime.now().year;
    return List.generate(101, (i) => currentYear - i);
  }

  String? _dobErrorMessage;

  Future<void> _submit() async {
    final dobResult = validateDateOfBirth(
        month: _birthMonth, day: _birthDay, year: _birthYear);
    final s = ref.read(appStringsProvider);
    _dobErrorMessage = switch (dobResult.errorCode) {
      DateOfBirthError.invalidDate => s.pleaseEnterValidDateOfBirth,
      DateOfBirthError.tooYoung => s.mustBeAtLeast18,
      null => null,
    };
    final dateOfBirth = dobResult.isoDate;
    if (!_formKey.currentState!.validate() || dateOfBirth == null) {
      setState(() {}); // surface _dobErrorMessage
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
      _fieldErrors = null;
    });

    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final error = await ref.read(authControllerProvider.notifier).register(
          fullName: _fullNameController.text.trim(),
          email: email.isEmpty ? null : email,
          password: _passwordController.text,
          role: _role,
          dateOfBirth: dateOfBirth,
          phoneNumber: phone.isEmpty ? null : phone,
          barangay: _barangay,
        );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      setState(() {
        _errorMessage = error.message;
        _fieldErrors = error.fieldErrors;
      });
      return;
    }
    // Deliberately different from login's behavior: a brand-new
    // registration goes to onboarding first, not straight to /home —
    // explicit navigation here rather than relying on the router's
    // generic auth-redirect (which sends any authenticated user away
    // from /login or /register to /home), since that generic redirect
    // has no way to distinguish "just registered" from "just logged
    // in" and shouldn't be made to.
    //
    // UW 1.3: registration's own success message says to verify
    // whichever channel was just registered with -- so that channel's
    // own verification screen comes first, before onboarding.
    if (!mounted) return;
    if (_registerVia == 'email') {
      context.go('/verify-email?next=/onboarding');
    } else {
      context.go('/verify-phone?next=/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    // Same green-header + cream-curtain layout as login_screen.dart --
    // see that file's own comment for why it's reused rather than
    // reinvented. Replaces the plain AppBar with a header carrying the
    // same badge/language toggle/title treatment.
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // UW 21.9: "the toggle in the header of the ...
                  // registration screens."
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      NagaGunoBadge(),
                      SizedBox(width: AppSpacing.sm),
                      LanguageToggleButton(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(s.createAccount,
                      style:
                          AppTypography.display.copyWith(color: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.backgroundStart,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    topRight: Radius.circular(AppRadius.xl),
                  ),
                ),
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
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm)),
                            child: Text(_errorMessage!,
                                style: const TextStyle(
                                    color: AppColors.statusCancelledFg)),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        Text(s.iAmA, style: AppTypography.label),
                        const SizedBox(height: AppSpacing.xs),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(value: 'buyer', label: Text(s.buyer)),
                            ButtonSegment(
                                value: 'farmer', label: Text(s.farmer)),
                            ButtonSegment(
                                value: 'vendor', label: Text(s.vendor)),
                          ],
                          selected: {_role},
                          onSelectionChanged: (sel) =>
                              setState(() => _role = sel.first),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                              labelText: s.fullName,
                              // UW 1: "A hint under the name field reads:
                              // 'Enter your name exactly as it appears on
                              // your government ID.'"
                              helperText: s.enterNameAsOnGovernmentId,
                              helperMaxLines: 2,
                              errorText: _fieldErrors?['full_name']),
                          validator: (v) {
                            final trimmed = v?.trim() ?? '';
                            if (trimmed.isEmpty) return s.fullNameRequired;
                            if (trimmed.length < 2) return s.fullNameTooShort;
                            if (trimmed.length > 50) return s.fullNameTooLong;
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // UW 1: "The date of birth is chosen with three
                        // drop-down lists (Month, Day, Year) rather than
                        // typed, so that it works the same way on every
                        // device, including low-end phones."
                        Text(s.dateOfBirth, style: AppTypography.label),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                initialValue: _birthMonth,
                                // isExpanded: true -- without it, DropdownButton
                                // sizes itself to its WIDEST item's intrinsic
                                // width (here, the longest month name, e.g.
                                // "September") rather than the Expanded parent's
                                // actual constraint, overflowing this flex:3 slot
                                // by a few pixels (real bug, caught live -- not
                                // just at a larger accessibility text scale,
                                // though scale made it worse: 31px overflow at
                                // Large vs. 10px at Standard).
                                isExpanded: true,
                                decoration: InputDecoration(labelText: s.month),
                                items: List.generate(
                                    12,
                                    (i) => DropdownMenuItem(
                                        value: i + 1,
                                        child: Text(s.monthNames[i]))),
                                onChanged: (v) => setState(() {
                                  _birthMonth = v;
                                  final maxDay = _daysInSelectedMonth();
                                  if (_birthDay != null &&
                                      _birthDay! > maxDay) {
                                    _birthDay = maxDay;
                                  }
                                }),
                                validator: (v) =>
                                    v == null ? s.required_ : null,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<int>(
                                initialValue: _birthDay,
                                isExpanded: true,
                                decoration: InputDecoration(labelText: s.day),
                                items: List.generate(
                                    _daysInSelectedMonth(),
                                    (i) => DropdownMenuItem(
                                        value: i + 1, child: Text('${i + 1}'))),
                                onChanged: (v) => setState(() => _birthDay = v),
                                validator: (v) =>
                                    v == null ? s.required_ : null,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                initialValue: _birthYear,
                                isExpanded: true,
                                decoration: InputDecoration(labelText: s.year),
                                items: _birthYearOptions
                                    .map((y) => DropdownMenuItem(
                                        value: y, child: Text('$y')))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _birthYear = v;
                                  final maxDay = _daysInSelectedMonth();
                                  if (_birthDay != null &&
                                      _birthDay! > maxDay) {
                                    _birthDay = maxDay;
                                  }
                                }),
                                validator: (v) =>
                                    v == null ? s.required_ : null,
                              ),
                            ),
                          ],
                        ),
                        if (_dobErrorMessage != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(_dobErrorMessage!,
                              style: const TextStyle(color: AppColors.error)),
                        ],
                        if (_fieldErrors?['date_of_birth'] != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(_fieldErrors!['date_of_birth']!,
                              style: const TextStyle(color: AppColors.error)),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        // UW 1: "A notice beneath the two fields reads: 'Your
                        // name and date of birth are used to verify your
                        // identity. You will not be able to edit them after
                        // you register, so please check that they are
                        // correct.'"
                        Text(s.nameAndDobVerifyIdentityNotice,
                            style: AppTypography.bodySmall),
                        const SizedBox(height: AppSpacing.md),
                        Text(s.registerVia, style: AppTypography.label),
                        const SizedBox(height: AppSpacing.xs),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                                value: 'email',
                                label: Text(s.registerWithEmail)),
                            ButtonSegment(
                                value: 'phone',
                                label: Text(s.registerWithPhone)),
                          ],
                          selected: {_registerVia},
                          onSelectionChanged: (sel) =>
                              setState(() => _registerVia = sel.first),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                              labelText: _registerVia == 'email'
                                  ? s.emailAddress
                                  : s.emailAddressOptional,
                              errorText: _fieldErrors?['email']),
                          validator: (v) {
                            final trimmed = v?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              // Required only when this is the chosen
                              // registration channel; otherwise it's a
                              // genuinely optional secondary contact
                              // (same as the real backend's Joi schema).
                              return _registerVia == 'email'
                                  ? s.emailAddressRequired
                                  : null;
                            }
                            if (!trimmed.contains('@') ||
                                !trimmed.contains('.')) {
                              return s.enterValidEmailAddress;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: _registerVia == 'phone'
                                ? s.mobileNumber
                                : s.mobileNumberOptional,
                            hintText: '09123456789',
                            errorText: _fieldErrors?['phone_number'],
                          ),
                          validator: (v) {
                            final trimmed = v?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return _registerVia == 'phone'
                                  ? s.mobileNumberRequired
                                  : null; // optional
                            }
                            if (!registrationPhonePattern.hasMatch(trimmed)) {
                              return s.phoneNumberMustBe11Digits;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _barangay,
                          decoration: InputDecoration(
                              labelText: s.barangayLabel,
                              errorText: _fieldErrors?['barangay']),
                          items: nagaCityBarangays
                              .map((b) =>
                                  DropdownMenuItem(value: b, child: Text(b)))
                              .toList(),
                          onChanged: (v) => setState(() => _barangay = v),
                          validator: (v) =>
                              v == null ? s.pleaseSelectBarangayError : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: s.password,
                            errorText: _fieldErrors?['password'],
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          // UW 1: "A password field that still has any red
                          // requirement cannot be submitted; attempting to
                          // submit with one shows which specific
                          // requirement is still unmet... rather than a
                          // generic rejection." -- returns the first
                          // unmet requirement's own label rather than
                          // passwordRequirementsNotMet's bundled message.
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return s.passwordRequiredDot;
                            }
                            for (final r in passwordRequirements(s)) {
                              if (!r.test(v)) return r.label;
                            }
                            return null;
                          },
                        ),
                        PasswordRequirementsChecklist(
                            controller: _passwordController, strings: s),
                        const SizedBox(height: AppSpacing.lg),
                        const LegalConsentLine(
                            actionVerb: 'registering',
                            actionVerbTl: 'rehistro'),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.accent))
                              : Text(s.createAccount),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.alreadyHaveAnAccount,
                                style: AppTypography.bodySmall),
                            TextButton(
                                onPressed: () => context.go('/login'),
                                child: Text(s.logIn)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
