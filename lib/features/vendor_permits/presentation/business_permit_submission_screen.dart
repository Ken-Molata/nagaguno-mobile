// lib/features/vendor_permits/presentation/business_permit_submission_screen.dart
//
// The Vendor-only business-permit submission form -- see
// routes/vendorPermits.js's own header for why this exists separately
// from KYC. Reached from onboarding_flow_screen.dart for a new Vendor
// account, and reusable as a standalone route for resubmission after a
// rejection.
//
// Fields beyond business name/permit type/permit number/photo (TIN,
// business address, issuing authority, date issued, expiry date) were
// added after checking what real PH business-verification flows
// actually collect -- migrations/058_vendor_business_permit_record_
// fields.sql's own header has the sourcing (GCash for Business
// requires a TIN for every entity type and that business details
// match across documents; every real DTI/Mayor's/BIR/SEC document
// itself names an issuing office, an issue date, and -- except BIR's
// Form 2303 -- an expiry date).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_picking.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../application/vendor_permits_provider.dart';
import 'dart:io';

class BusinessPermitSubmissionScreen extends ConsumerStatefulWidget {
  const BusinessPermitSubmissionScreen(
      {super.key, this.onDone, this.allowSkip = true, this.rejectionReason});

  /// Called after a successful submission. When null, the screen pops
  /// itself (standalone-route usage); the onboarding flow instead
  /// passes a callback that advances its own step.
  final VoidCallback? onDone;

  /// REAL GAP FOUND AND FIXED: the admin's rejection reason was only
  /// ever sent as a notification (routes/vendorPermits.js's own
  /// decide endpoint) -- nothing showed it on THIS screen, so a vendor
  /// resubmitting had no idea what to actually fix unless they still
  /// had the notification open. business_permit_status_screen.dart
  /// passes the latest rejected submission's reason through here, same
  /// as KycSubmissionScreen already does for its own rejectionReason.
  final String? rejectionReason;

  /// Onboarding passes false: a Vendor account cannot reach the rest
  /// of the app (and therefore cannot list products or request bulk
  /// agreements -- the two things an approved permit actually gates,
  /// same restriction KYC already enforces alongside this one) without
  /// at least SUBMITTING a permit first. Not waiting for admin approval
  /// at this exact screen -- just not letting them skip past submitting
  /// at all. The standalone /business-permit route (reached from
  /// Profile, for a first submission after skipping was still possible
  /// before this, or any later resubmission) keeps the default true --
  /// a vendor already past onboarding can always navigate away and
  /// come back without being forced to submit on every visit.
  final bool allowSkip;

  @override
  ConsumerState<BusinessPermitSubmissionScreen> createState() =>
      _BusinessPermitSubmissionScreenState();
}

class _BusinessPermitSubmissionScreenState
    extends ConsumerState<BusinessPermitSubmissionScreen> {
  final _businessNameController = TextEditingController();
  final _permitNumberController = TextEditingController();
  final _tinController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _issuingAuthorityController = TextEditingController();
  String? _permitType;
  DateTime? _dateIssued;
  DateTime? _expiryDate;
  String? _photoPath;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _businessNameController.dispose();
    _permitNumberController.dispose();
    _tinController.dispose();
    _businessAddressController.dispose();
    _issuingAuthorityController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await pickAndCompressImage(source: ImageSource.camera);
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _pickFromGallery() async {
    final file = await pickAndCompressImage();
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _pickDateIssued() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateIssued ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateIssued = picked);
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  bool get _canSubmit =>
      !_submitting &&
      _businessNameController.text.trim().isNotEmpty &&
      _permitNumberController.text.trim().isNotEmpty &&
      _tinController.text.trim().isNotEmpty &&
      _businessAddressController.text.trim().isNotEmpty &&
      _issuingAuthorityController.text.trim().isNotEmpty &&
      _permitType != null &&
      _dateIssued != null &&
      _photoPath != null;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(vendorPermitsRepositoryProvider).submit(
            permitType: _permitType!,
            permitNumber: _permitNumberController.text.trim(),
            businessName: _businessNameController.text.trim(),
            tin: _tinController.text.trim(),
            businessAddress: _businessAddressController.text.trim(),
            issuingAuthority: _issuingAuthorityController.text.trim(),
            dateIssued: _dateIssued!,
            expiryDate: _expiryDate,
            documentPath: _photoPath!,
          );
      if (!mounted) return;
      ref.invalidate(myVendorPermitSubmissionsProvider);
      if (widget.onDone != null) {
        widget.onDone!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final permitTypesAsync = ref.watch(businessPermitTypesProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      appBar: AppBar(
        title: const Text('Business Permit Verification'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (widget.rejectionReason != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.error),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your previous submission was not approved',
                        style: AppTypography.label.copyWith(color: AppColors.error)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(widget.rejectionReason!, style: AppTypography.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              'Vendors resell produce rather than selling what they grow '
              'themselves, so we ask for proof of a real registered '
              'business. An admin reviews every submission -- this is '
              'not automatic.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Business / Shop Name', style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _businessNameController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'e.g. Naga Fresh Produce Trading',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Permit Type', style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            permitTypesAsync.when(
              data: (types) => DropdownButtonFormField<String>(
                initialValue: _permitType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: types
                    .map((t) => DropdownMenuItem(
                          value: t.permitType,
                          child: Text(t.label),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _permitType = v),
                hint: const Text('Select permit type'),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(
                "Couldn't load permit types. Check your connection.",
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Permit / Registration Number', style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _permitNumberController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'As printed on the document',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // GCash for Business requires a TIN for every entity type,
            // regardless of permit_type -- migrations/058's own header.
            Text('BIR Tax Identification Number (TIN)', style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _tinController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                hintText: 'e.g. 123-456-789',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // GCash for Business: "name and business details must
            // match across all documents and your application."
            Text('Registered Business Address', style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _businessAddressController,
              onChanged: (_) => setState(() {}),
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Exactly as printed on the document',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Issuing Office', style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _issuingAuthorityController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: "e.g. DTI Naga City Field Office, Naga City Mayor's Office, BIR RDO 067",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date Issued', style: AppTypography.label),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton(
                        onPressed: _pickDateIssued,
                        child: Text(_dateIssued == null
                            ? 'Select date'
                            : _fmt(_dateIssued!)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expiry Date (if any)', style: AppTypography.label),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _pickExpiryDate,
                              child: Text(_expiryDate == null
                                  ? 'Select date'
                                  : _fmt(_expiryDate!)),
                            ),
                          ),
                          if (_expiryDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _expiryDate = null),
                              tooltip: 'Clear',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Leave Expiry Date blank if the document itself shows none '
                '(a BIR Certificate of Registration typically doesn\'t).',
                style: AppTypography.bodySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Photo of the Document', style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            if (_photoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.file(File(_photoPath!),
                    height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Upload'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent))
                  : const Text('Submit for Review'),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (widget.onDone != null && widget.allowSkip)
              TextButton(
                onPressed: _submitting ? null : widget.onDone,
                child: const Text("I'll do this later"),
              ),
          ],
        ),
      ),
    );
  }
}
