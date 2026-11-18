// lib/features/account_recovery/presentation/account_recovery_screen.dart
//
// Closes a real gap: UW 2.5's Locked-Out Account Recovery had a full,
// working 3-step backend (routes/accountRecovery.js) and zero mobile
// UI at all -- reachable only by someone editing requests by hand.
// One wizard screen carries the short-lived token the backend hands
// back between steps (nothing is persisted server-side until the
// final submit), rather than three separately-routed screens passing
// a JWT through query params.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/utils/image_picking.dart';
import '../../kyc/domain/kyc_models.dart';
import '../../kyc/domain/liveness_challenge.dart';
import '../../kyc/presentation/screen_flash_challenge_screen.dart';
import '../data/account_recovery_repository.dart';
import '../domain/recovery_models.dart';

final accountRecoveryRepositoryProvider = Provider<AccountRecoveryRepository>(
    (ref) => AccountRecoveryRepository(ref.watch(apiClientProvider)));

class AccountRecoveryScreen extends ConsumerStatefulWidget {
  const AccountRecoveryScreen({super.key});
  @override
  ConsumerState<AccountRecoveryScreen> createState() =>
      _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends ConsumerState<AccountRecoveryScreen> {
  int _step = 0; // 0 identity, 1 id-check, 2 reason+submit, 3 done
  bool _submitting = false;
  String? _errorMessage;

  // Step 0 state
  final _fullNameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _dontKnowIdentifier = false;
  bool _skipPassword = false;
  String? _token;
  bool? _accountNeverVerified;

  // Step 1 state
  KycIdType _idType = KycIdType.passport;
  bool _differentIdType = false;
  String? _idFrontPath;
  String? _idBackPath;
  LivenessCaptureResult? _liveness;
  bool _didOpenVerificationUrl = false;

  // Step 2 state
  String? _reasonCode;
  final _reasonOtherController = TextEditingController();
  final _contactController = TextEditingController();

  // Step 3 state
  String? _requestNumber;

  List<IdTypeConfig>? _idTypeConfigs;

  @override
  void initState() {
    super.initState();
    // UW 10.1: same live Route table as KycSubmissionScreen's own
    // fetch -- an Admin's edit must change what THIS screen's Step 2
    // asks for too, not just the regular KYC submission form.
    // REAL BUG FOUND AND FIXED: this used to call
    // kycRepositoryProvider (GET /kyc/id-types), which requires an
    // authenticated session -- always a 401 for this screen's actual,
    // locked-out-and-can't-log-in audience, confirmed live. The
    // failure was swallowed by .catchError, so _idTypeConfigs just
    // silently stayed null forever and every real recovery attempt
    // fell back to the static client-side defaults, never the Admin's
    // live edits. Now calls the dedicated, unauthenticated
    // accountRecoveryRepositoryProvider.getIdTypes() instead (same
    // backend data, see accountRecovery.js's own new /id-types route).
    ref.read(accountRecoveryRepositoryProvider).getIdTypes().then((configs) {
      if (mounted) setState(() => _idTypeConfigs = configs);
    }).catchError((_) {});
  }

  IdTypeConfig? get _liveConfig {
    final configs = _idTypeConfigs;
    if (configs == null) return null;
    for (final c in configs) {
      if (c.idType == _idType.apiValue) return c;
    }
    return null;
  }

  String get _effectiveRoute => _liveConfig?.route ?? _idType.route;
  bool get _effectiveRequiresBack =>
      _liveConfig?.backRequired ?? _idType.requiresBack;

  bool get _identifierIsEmail => _identifierController.text.contains('@');

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(DateTime.now().year - 25),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  int get _age {
    if (_dateOfBirth == null) return 0;
    final today = DateTime.now();
    var age = today.year - _dateOfBirth!.year;
    if (today.month < _dateOfBirth!.month ||
        (today.month == _dateOfBirth!.month && today.day < _dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  Future<void> _submitStep0() async {
    if (_fullNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Full name is required.');
      return;
    }
    if (_dateOfBirth == null) {
      setState(() => _errorMessage = 'Please enter a valid date of birth.');
      return;
    }
    if (!_dontKnowIdentifier && _identifierController.text.trim().isEmpty) {
      setState(() => _errorMessage =
          'Enter the email address or phone number the account was registered with.');
      return;
    }
    if (!_skipPassword && _passwordController.text.isEmpty) {
      setState(() => _errorMessage =
          'Enter your password, or select "I don\'t remember my password."');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final result =
          await ref.read(accountRecoveryRepositoryProvider).verifyIdentity(
                fullName: _fullNameController.text.trim(),
                dateOfBirth: _dateOfBirth!,
                age: _age,
                email: !_dontKnowIdentifier && _identifierIsEmail
                    ? _identifierController.text.trim()
                    : null,
                phoneNumber: !_dontKnowIdentifier && !_identifierIsEmail
                    ? _identifierController.text.trim()
                    : null,
                dontKnowIdentifier: _dontKnowIdentifier,
                password: _passwordController.text,
                skipPassword: _skipPassword,
              );
      if (!mounted) return;
      setState(() {
        _token = result.token;
        _accountNeverVerified = result.accountNeverVerified;
        _step = 1;
      });
    } on RecoveryException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openVerificationUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) setState(() => _didOpenVerificationUrl = true);
  }

  Future<void> _startLivenessCheck() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScreenFlashChallengeScreen(
          fetchChallenge: () => ref
              .read(accountRecoveryRepositoryProvider)
              .fetchLivenessChallenge(_token!),
          onCompleted: (result) {
            if (!mounted) return;
            setState(() => _liveness = result);
          },
        ),
      ),
    );
  }

  Future<void> _submitStep1() async {
    final isRouteB = _effectiveRoute == 'B';
    if (isRouteB) {
      if (_idFrontPath == null) {
        setState(
            () => _errorMessage = 'A front image of a valid ID is required.');
        return;
      }
      if (_effectiveRequiresBack && _idBackPath == null) {
        setState(
            () => _errorMessage = 'A back image of this ID type is required.');
        return;
      }
      if (_liveness == null) {
        setState(
            () => _errorMessage = 'A liveness check (selfie) is required.');
        return;
      }
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final result = await ref.read(accountRecoveryRepositoryProvider).idCheck(
            token: _token!,
            idType: _idType.apiValue,
            differentIdType: _differentIdType,
            idFrontPath: isRouteB ? _idFrontPath : null,
            idBackPath: isRouteB ? _idBackPath : null,
            liveness: isRouteB ? _liveness : null,
          );
      if (!mounted) return;
      setState(() {
        _token = result.token;
      });
      if (result.route == 'A' && result.verificationUrl != null) {
        await _openVerificationUrl(result.verificationUrl!);
        // Didit's hosted capture happens off-site; the user returns
        // here and moves on manually once done (same pattern as the
        // PayMongo gateway checkout redirect elsewhere in this app).
        if (!mounted) return;
        setState(() => _submitting = false);
        return;
      }
      setState(() => _step = 2);
    } on RecoveryException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitStep2() async {
    if (_reasonCode == null) {
      setState(() => _errorMessage = 'Select a reason for this request.');
      return;
    }
    if (_reasonCode == 'other' && _reasonOtherController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please explain your reason.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final result = await ref.read(accountRecoveryRepositoryProvider).submit(
            token: _token!,
            reasonCode: _reasonCode!,
            reasonOther: _reasonOtherController.text.trim(),
            contactForUpdates: _contactController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _requestNumber = result.requestNumber;
        _step = 3;
      });
    } on RecoveryException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Recovery')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepIndicator(step: _step),
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
              if (_step == 0) _buildStep0(),
              if (_step == 1) _buildStep1(),
              if (_step == 2) _buildStep2(),
              if (_step == 3) _buildStep3(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Let\'s confirm this is really your account.',
            style: AppTypography.body),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
                labelText: 'Full Name (as on the account)')),
        const SizedBox(height: AppSpacing.md),
        InkWell(
          onTap: _pickDob,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date of Birth'),
            child: Text(_dateOfBirth == null
                ? 'Select date'
                : '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!_dontKnowIdentifier)
          TextFormField(
            controller: _identifierController,
            decoration: const InputDecoration(
                labelText: 'Email or Phone Number on the Account'),
          ),
        CheckboxListTile(
          value: _dontKnowIdentifier,
          contentPadding: EdgeInsets.zero,
          title: const Text(
              'I don\'t know the email or phone number on the account'),
          onChanged: (v) => setState(() => _dontKnowIdentifier = v ?? false),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!_skipPassword)
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
        CheckboxListTile(
          value: _skipPassword,
          contentPadding: EdgeInsets.zero,
          title: const Text('I don\'t remember my password'),
          onChanged: (v) => setState(() => _skipPassword = v ?? false),
        ),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(
          onPressed: _submitting ? null : _submitStep0,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent))
              : const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    final isRouteB = _effectiveRoute == 'B';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_accountNeverVerified == true)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
                'This account has no prior verification on file to compare against — our team will review this manually.',
                style: AppTypography.bodySmall),
          ),
        DropdownButtonFormField<KycIdType>(
          isExpanded: true,
          initialValue: _idType,
          decoration: const InputDecoration(labelText: 'ID Type'),
          items: KycIdType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
              .toList(),
          onChanged: (v) => setState(() => _idType = v!),
        ),
        CheckboxListTile(
          value: _differentIdType,
          contentPadding: EdgeInsets.zero,
          title: const Text('This is a different ID than the one on file'),
          onChanged: (v) => setState(() => _differentIdType = v ?? false),
        ),
        const SizedBox(height: AppSpacing.md),
        if (isRouteB) ...[
          OutlinedButton.icon(
            onPressed: () async {
              final file = await pickAndCompressImage();
              if (file != null) setState(() => _idFrontPath = file.path);
            },
            icon: const Icon(Icons.badge_outlined),
            label: Text(
                _idFrontPath == null ? 'Upload ID Front' : 'ID Front Added'),
          ),
          if (_effectiveRequiresBack) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () async {
                final file = await pickAndCompressImage();
                if (file != null) setState(() => _idBackPath = file.path);
              },
              icon: const Icon(Icons.badge_outlined),
              label: Text(
                  _idBackPath == null ? 'Upload ID Back' : 'ID Back Added'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _startLivenessCheck,
            icon: const Icon(Icons.face_outlined),
            label: Text(_liveness == null
                ? 'Liveness Check'
                : (_liveness!.optedOut
                    ? 'Liveness Check — Skipped'
                    : 'Liveness Check — Added')),
          ),
        ] else ...[
          Text(
            _didOpenVerificationUrl
                ? 'Finished verifying? Continue below.'
                : 'This ID type uses automatic verification. Tap below to complete it, then come back here.',
            style: AppTypography.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(
          onPressed: _submitting ? null : _submitStep1,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent))
              : Text(!isRouteB && _didOpenVerificationUrl
                  ? 'Continue'
                  : (isRouteB ? 'Continue' : 'Start Verification')),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final needsContact = _skipPassword;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Why do you need to recover this account?',
            style: AppTypography.body),
        const SizedBox(height: AppSpacing.md),
        RadioGroup<String>(
          groupValue: _reasonCode,
          onChanged: (v) => setState(() => _reasonCode = v),
          child: Column(
            children: recoveryReasons.entries
                .map((e) => RadioListTile<String>(
                      title: Text(e.value),
                      value: e.key,
                      contentPadding: EdgeInsets.zero,
                    ))
                .toList(),
          ),
        ),
        if (_reasonCode == 'other') ...[
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
              controller: _reasonOtherController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Please explain')),
        ],
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _contactController,
          decoration: InputDecoration(
            labelText: needsContact
                ? 'Email or Phone for Updates (required)'
                : 'Email or Phone for Updates (optional)',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(
          onPressed: _submitting ? null : _submitStep2,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent))
              : const Text('Submit Request'),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline,
            color: AppColors.statusSuccessFg, size: 48),
        const SizedBox(height: AppSpacing.md),
        const Text('Request received.',
            style: AppTypography.h2, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        const Text('Your request number is',
            style: AppTypography.body, textAlign: TextAlign.center),
        Text(_requestNumber ?? '',
            style: AppTypography.display, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.md),
        const Text(
            'Please write this down — you\'ll need it with your date of birth to check your request status.',
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Login')),
      ],
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _reasonOtherController.dispose();
    _contactController.dispose();
    super.dispose();
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;
  static const _labels = ['Identity', 'ID Check', 'Reason', 'Done'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (i) {
        final active = i <= step;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                  radius: 12,
                  backgroundColor:
                      active ? AppColors.primary : AppColors.border,
                  child: Text('${i + 1}',
                      style:
                          AppTypography.label.copyWith(color: Colors.white))),
              const SizedBox(height: 2),
              Text(_labels[i],
                  style: AppTypography.label.copyWith(
                      color: active
                          ? AppColors.textPrimary
                          : AppColors.textMuted)),
            ],
          ),
        );
      }),
    );
  }
}
