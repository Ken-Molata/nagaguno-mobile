// lib/features/kyc/presentation/kyc_submission_screen.dart
//
// Ties together the KycRepository (real multipart shape verified
// against routes/kyc.js) and ScreenFlashChallengeScreen (UW 10.2).
// Form validation matches the real backend's actual required/optional
// rules per ID type -- route/back-image requirement now comes from the
// live Route table (UW 10.1, Admin-editable), not just KycIdType's own
// compile-time fields; see _effectiveRoute/_effectiveRequiresBack.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.
// KycIdType's own `.label` values (ID type names) are left in English,
// same reasoning as onboarding's category labels -- they also render
// in the admin web app's KYC review queue, not yet covered by this pass.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/naga_city_barangays.dart';
import '../../../core/utils/image_picking.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../authentication/application/auth_controller.dart';
import '../application/kyc_status_provider.dart';
import '../data/kyc_repository.dart';
import '../domain/kyc_models.dart';
import '../domain/liveness_challenge.dart';
import 'screen_flash_challenge_screen.dart';

/// Mirrors routes/kyc.js's own calculateAge() exactly -- used here only
/// to show the user a read-only confirmation of what their date of
/// birth works out to; the real, authoritative age the backend stores
/// is always computed server-side the same way, never trusted from the
/// client (see this screen's own header note on the removed Age field).
int _calculateAge(DateTime dob) {
  final today = DateTime.now();
  var age = today.year - dob.year;
  final hadBirthdayThisYear = today.month > dob.month ||
      (today.month == dob.month && today.day >= dob.day);
  if (!hadBirthdayThisYear) age -= 1;
  return age;
}

class KycSubmissionScreen extends ConsumerStatefulWidget {
  const KycSubmissionScreen({
    super.key,
    this.rejectionReason,
    this.resubmissionFields = const [],
    this.priorDateOfBirth,
    this.priorCompleteAddress,
    this.priorContactNumber,
    this.priorIdType,
  });
  final String? rejectionReason;

  /// UW 10.5: when non-empty, the Admin flagged only these specific
  /// document(s) for resubmission -- "only the document(s) flagged are
  /// presented for re-capture; the ID type, any document not flagged,
  /// and the supporting documents remain as submitted." The document-
  /// specific sections below (ID type, ID photos, supporting doc,
  /// liveness) are hidden/locked unless their own key is in this list;
  /// the always-required fields (DOB, address, contact) are always
  /// shown but pre-filled from [priorDateOfBirth] etc. (or, absent a
  /// prior KYC value, from the registered account itself -- see this
  /// screen's own initState) rather than left blank, since the backend
  /// requires them on every submission regardless of what's flagged.
  final List<String> resubmissionFields;
  final DateTime? priorDateOfBirth;
  final String? priorCompleteAddress;
  final String? priorContactNumber;
  final String? priorIdType;
  @override
  ConsumerState<KycSubmissionScreen> createState() =>
      _KycSubmissionScreenState();
}

class _KycSubmissionScreenState extends ConsumerState<KycSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressDetailController = TextEditingController();
  final _contactController = TextEditingController();
  final _fullNameController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _barangay;
  KycIdType _idType = KycIdType.philsysNationalId;
  String? _idFrontPath;
  String? _idBackPath;
  String? _supportingDocPath;
  LivenessCaptureResult? _liveness;
  bool _submitting = false;
  String? _errorMessage;
  Map<String, String>? _fieldErrors;
  List<IdTypeConfig>? _idTypeConfigs;

  @override
  void initState() {
    super.initState();
    // UW 10.1: the Route table is Admin-editable now -- fetched once
    // per visit to this screen rather than trusted from KycIdType's
    // own compile-time route/requiresBack fields alone. A fetch
    // failure (or still-loading) silently falls back to those
    // compile-time values via _effectiveRoute/_effectiveRequiresBack
    // below, never blocking the form.
    ref.read(kycRepositoryProvider).getIdTypes().then((configs) {
      if (mounted) setState(() => _idTypeConfigs = configs);
    }).catchError((_) {});

    // UW 10.5: "Previously submitted information is retained and
    // pre-filled rather than cleared." Only meaningful on a
    // resubmission -- a fresh, first-time submission has no prior KYC
    // values at all, but DOES already have a registered account with
    // its own date of birth and (optionally) phone number on file.
    //
    // REAL GAP FOUND AND FIXED: a fresh submission used to leave date
    // of birth and contact number both blank, asking the user to
    // retype information collected at registration moments earlier
    // (RegisterScreen already requires full_name/date_of_birth, and
    // optionally phone_number). Pre-filled from the session user here
    // whenever there's no prior KYC value to prefer instead.
    final user = ref.read(authControllerProvider).user;
    _dateOfBirth = widget.priorDateOfBirth ?? user?.dateOfBirth;
    if (widget.priorCompleteAddress != null) {
      // Address isn't one of UW 10.5's flaggable per-field resubmission
      // fields (date_of_birth/complete_address/contact_number are
      // always required fresh on every submission, per routes/kyc.js's
      // own comment) -- the prior free-text value can't be reliably
      // split back into a barangay + the rest, so it's offered as a
      // starting point in the open-ended detail field and the barangay
      // dropdown is left for the user to reselect.
      _addressDetailController.text = widget.priorCompleteAddress!;
    }
    _contactController.text = widget.priorContactNumber ?? user?.phoneNumber ?? '';
    if (widget.priorIdType != null) {
      _idType = KycIdType.values.firstWhere(
          (t) => t.apiValue == widget.priorIdType,
          orElse: () => _idType);
    }
  }

  /// UW 10.5: whether this is a partial resubmission (Admin flagged
  /// specific field(s)) as opposed to a fresh submission or a legacy/
  /// free-text-only rejection with nothing flagged -- the latter two
  /// fall back to showing the full form, same as before this pass.
  bool get _isPartialResubmission => widget.resubmissionFields.isNotEmpty;
  bool _isFlagged(String field) =>
      !_isPartialResubmission || widget.resubmissionFields.contains(field);

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
  bool get _accountDetailsFlagged =>
      widget.resubmissionFields.contains('account_details');

  Future<void> _pickImage(void Function(String path) onPicked) async {
    final file = await pickAndCompressImage();
    if (file != null) setState(() => onPicked(file.path));
  }

  Future<void> _startLivenessCheck() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScreenFlashChallengeScreen(
          fetchChallenge: () =>
              ref.read(kycRepositoryProvider).fetchLivenessChallenge(),
          onCompleted: (result) {
            if (!mounted) return;
            setState(() => _liveness = result);
          },
        ),
      ),
    );
  }

  bool get _isRouteB => _effectiveRoute == 'B';

  Future<void> _submit() async {
    final s = ref.read(appStringsProvider);
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      setState(() => _errorMessage = s.pleaseSelectDateOfBirthError);
      return;
    }
    if (_barangay == null) {
      setState(() => _errorMessage = s.pleaseSelectBarangayError);
      return;
    }
    // UW 10.6: Route A (this ID type's automatic Didit verification)
    // uploads nothing here at all -- only Route B needs these. UW 10.5:
    // further narrowed to only whatever field(s) are actually flagged
    // on a partial resubmission -- a field that's hidden (not flagged)
    // was never collected, so it can't be required here either.
    if (_isRouteB) {
      if (_isFlagged('id_front') && _idFrontPath == null) {
        setState(() => _errorMessage = s.pleaseUploadIdFrontError);
        return;
      }
      if (_effectiveRequiresBack &&
          _isFlagged('id_back') &&
          _idBackPath == null) {
        setState(() => _errorMessage = s.idTypeRequiresBackUploadError);
        return;
      }
      if (_isFlagged('liveness') && _liveness == null) {
        setState(() => _errorMessage = s.pleaseCompleteLivenessCheckError);
        return;
      }
    }
    // REAL BUG FOUND AND FIXED: this used to hard-require a Vendor to
    // upload a "Business Permit" photo here as a bare KYC supporting
    // document before KYC could even submit (blocking Route A's Didit
    // redirect too) -- live-confirmed to block submission even with
    // every other field correctly filled in. The dedicated vendor
    // business-permit system (routes/vendorPermits.js, reached from
    // onboarding/Profile, not this screen) now handles business-
    // legitimacy verification far more thoroughly and is deliberately
    // independent of KYC (personal identity). See routes/kyc.js's own
    // matching fix for the full reasoning -- this field is optional
    // for every role now, same as it always was for a Farmer.

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _fieldErrors = null;
    });

    try {
      // Naga City barangay now comes from a fixed dropdown (see this
      // screen's own header note) rather than free text, concatenated
      // with the open-ended house/lot/street/zone detail into the one
      // complete_address string the backend actually stores.
      final completeAddress =
          '${_addressDetailController.text.trim()}, Barangay $_barangay, Naga City';
      final result = await ref.read(kycRepositoryProvider).submit(
            dateOfBirth: _dateOfBirth!,
            completeAddress: completeAddress,
            contactNumber: _contactController.text.trim(),
            idType: _idType,
            idFrontPath: _isRouteB ? _idFrontPath : null,
            idBackPath: _isRouteB ? _idBackPath : null,
            // UW 10: "Supporting documents are uploaded to NagaGuno
            // directly under both routes" -- REAL GAP FOUND AND FIXED:
            // this used to be discarded for Route A exactly like the
            // Route-B-only id_front/id_back/liveness fields above it,
            // even though it isn't one of those -- a Route A Vendor or
            // Farmer had no way to ever submit it at all.
            supportingDocPath: _supportingDocPath,
            fullName: _accountDetailsFlagged
                ? _fullNameController.text.trim()
                : null,
            liveness: _isRouteB ? _liveness : null,
            resubmissionFields: widget.resubmissionFields,
          );
      ref.invalidate(
          kycStatusProvider); // refresh the app-wide gating state everywhere it's used
      if (!mounted) return;

      if (result.verificationUrl != null) {
        // Route A: Didit's own hosted page does the actual scan/
        // liveness check -- hand off to it now, same pattern as the
        // PayMongo/account-recovery external redirects elsewhere in
        // this app. The result resolves automatically afterward
        // (GET /kyc/me lazily polls Didit once the user checks back).
        //
        // REAL BUG FOUND AND FIXED: canLaunchUrl() silently returned
        // false here on Android 11+ -- AndroidManifest.xml had no
        // <queries> block declaring this app's intent to view https
        // links, which Android's package-visibility rules (API 30+)
        // require before any app can even detect a browser can handle
        // one, regardless of whether one is installed. The screen then
        // popped as if the hand-off had worked, leaving the user on
        // the "pending Didit" status message with nothing having
        // opened at all. Fixed at the root (the manifest now declares
        // it) -- this surfaces a clear error instead of silently doing
        // nothing if it ever fails again for any other reason.
        final uri = Uri.parse(result.verificationUrl!);
        bool launched = false;
        try {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          launched = false;
        }
        if (!launched) {
          if (mounted) {
            setState(() => _errorMessage = s.couldntOpenVerificationLinkError);
          }
          return;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on KycValidationException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _fieldErrors = e.fieldErrors;
        });
      }
    } catch (e) {
      // UW 19: a connectivity-detected failure gets its own exact
      // wording, not the same generic message as a genuine server/logic
      // error -- this previously always showed the generic string
      // regardless of cause, the one real gap found checking this
      // screen against Section 19.
      if (mounted) {
        setState(() => _errorMessage = friendlyErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    // No Scaffold/AppBar here: this widget is always embedded directly
    // in KycScreen's body (lib/features/kyc/presentation/kyc_screen.dart),
    // which already provides the single "Verification" app bar. Wrapping
    // another Scaffold+AppBar around this content produced two stacked
    // app bars (and two back buttons) on screen -- confirmed live.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                if (widget.rejectionReason != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.statusCancelledBg,
                      border: Border.all(color: AppColors.statusCancelledFg),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            widget.resubmissionFields.isNotEmpty
                                ? s.resubmissionRequiredLabel
                                : s.previousSubmissionNotApproved,
                            style: AppTypography.h3.copyWith(
                                color: AppColors.statusCancelledFg,
                                fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(widget.rejectionReason!,
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.statusCancelledFg)),
                        // UW 10.5: the form below already shows only
                        // these flagged field(s) -- this line is a
                        // plain-language summary alongside that, not a
                        // substitute for it.
                        if (widget.resubmissionFields.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                              s.pleaseUpdateFieldsLabel(widget
                                  .resubmissionFields
                                  .map((f) => s.resubmissionFieldLabel(f))
                                  .join(', ')),
                              style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.statusCancelledFg,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
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
                // UW 10.5's one carve-out: full name/date of birth are
                // normally locked (set at registration, matched against
                // the ID) -- this is the only place they become editable,
                // and only when the Admin specifically flagged
                // 'account_details' as the reason resubmission is needed.
                if (_accountDetailsFlagged) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                        labelText: s.fullName,
                        errorText: _fieldErrors?['full_name']),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? s.fullNameRequired
                        : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now()
                          .subtract(const Duration(days: 365 * 25)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _dateOfBirth = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: s.dateOfBirth),
                    child: Text(_dateOfBirth == null
                        ? s.selectDateLabel
                        : '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}'),
                  ),
                ),
                // REAL GAP FOUND AND FIXED: this screen used to also
                // have a separate, manually-typed "Age" field the real
                // backend never even reads (routes/kyc.js computes age
                // itself from date_of_birth and ignores req.body.age
                // entirely) -- removed; age is shown here purely as a
                // read-only confirmation of what the date of birth
                // above works out to, the same "calculated, never
                // typed in" rule UW 1 already applies at registration.
                if (_dateOfBirth != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(s.ageFromDateOfBirth(_calculateAge(_dateOfBirth!)),
                      style: AppTypography.bodySmall),
                ],
                const SizedBox(height: AppSpacing.md),
                // REAL GAP FOUND AND FIXED: complete_address used to be
                // one free-text field with no structure at all. Naga
                // City is the only city NagaGuno operates in, so its
                // barangay is now a fixed dropdown (naga_city_
                // barangays.dart) rather than typed freehand -- the
                // rest of the address (house/lot no., street, zone)
                // stays open-ended text, since that part genuinely
                // varies per household and has no fixed list.
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _barangay,
                  decoration: InputDecoration(labelText: s.barangayLabel),
                  items: nagaCityBarangays
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setState(() => _barangay = v),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _addressDetailController,
                  decoration: InputDecoration(
                      labelText: s.addressDetailLabel,
                      hintText: s.addressDetailHint,
                      errorText: _fieldErrors?['complete_address']),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? s.addressRequiredError
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: s.contactNumberLabel,
                    hintText: s.contactNumberHint,
                    errorText: _fieldErrors?['contact_number'],
                  ),
                  validator: (v) {
                    final trimmed = v?.trim() ?? '';
                    if (trimmed.isEmpty) return s.contactNumberRequiredError;
                    if (!phPhoneRegex.hasMatch(trimmed)) {
                      return s.enterValidPhMobileNumberError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                // UW 10.5: "the ID type... remain[s] as submitted" when
                // not itself flagged -- shown locked rather than as an
                // editable dropdown, so there's no way to change it by
                // accident during an otherwise narrow resubmission.
                if (_isFlagged('id_type'))
                  DropdownButtonFormField<KycIdType>(
                    isExpanded: true,
                    initialValue: _idType,
                    decoration: InputDecoration(labelText: s.idTypeLabel),
                    items: KycIdType.values
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t.label)))
                        .toList(),
                    onChanged: (v) => setState(() => _idType = v!),
                  )
                else
                  InputDecorator(
                    decoration: InputDecoration(labelText: s.idTypeLabel),
                    child: Text(_idType.label),
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (_isRouteB) ...[
                  if (_isFlagged('id_front'))
                    _buildUploadTile(
                      s,
                      label: s.idFrontPhotoLabel,
                      path: _idFrontPath,
                      onTap: () => _pickImage((p) => _idFrontPath = p),
                    ),
                  if (_effectiveRequiresBack && _isFlagged('id_back')) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _buildUploadTile(
                      s,
                      label: s.idBackPhotoLabel,
                      path: _idBackPath,
                      onTap: () => _pickImage((p) => _idBackPath = p),
                    ),
                  ],
                  if (_isFlagged('liveness')) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _buildUploadTile(
                      s,
                      label: s.livenessCheckLabel,
                      path: _liveness == null
                          ? null
                          : (_liveness!.optedOut ? 'skipped' : _liveness!.neutralPath),
                      doneLabelOverride: _liveness?.optedOut == true
                          ? s.livenessCheckSkippedLabel
                          : null,
                      onTap: _startLivenessCheck,
                      icon: Icons.remove_red_eye_outlined,
                    ),
                  ],
                ] else
                  // UW 10.6: this ID type is verified automatically by
                  // Didit on its own secure page, not uploaded here.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                        color: AppColors.backgroundStart,
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Row(children: [
                      const Icon(Icons.flash_on, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          s.idTypeVerifiedAutomaticallyNote,
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    ]),
                  ),
                // UW 10: "Supporting documents are uploaded to NagaGuno
                // directly under both routes... reviewed by the Admin
                // only." Shown regardless of route. Optional for every
                // role, including Vendor -- see this screen's own
                // header comment on why the old Vendor-specific
                // "Business Permit required here too" requirement was
                // removed (the dedicated vendor-permit system now
                // owns that, entirely separately from KYC).
                if (_isFlagged('supporting_doc')) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildUploadTile(
                    s,
                    label: s.supportingDocumentOptionalLabel,
                    path: _supportingDocPath,
                    onTap: () => _pickImage((p) => _supportingDocPath = p),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent))
                      : Text(s.submitForVerificationLabel),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildUploadTile(AppStrings s,
      {required String label,
      required String? path,
      required VoidCallback onTap,
      String? doneLabelOverride,
      IconData icon = Icons.upload_file}) {
    final done = path != null;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: done ? AppColors.statusSuccessBg : AppColors.surface,
          border: Border.all(
              color: done ? AppColors.statusSuccessFg : AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle : icon,
                color: done ? AppColors.statusSuccessFg : AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: Text(
                    done
                        ? (doneLabelOverride ?? s.addedSuffixLabel(label))
                        : label,
                    style: AppTypography.body)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _addressDetailController.dispose();
    _contactController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }
}
