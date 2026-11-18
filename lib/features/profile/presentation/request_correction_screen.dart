// lib/features/profile/presentation/request_correction_screen.dart
//
// UW 21.1's "Request a correction" -- the real replacement for the
// direct name/DOB edit this app deliberately removed (see
// routes/profile.js's own header comment: a verified account's name
// and date of birth can't be changed freely, since they're what's
// checked against the user's KYC ID and against a locked-out account
// recovery, Section 2.5). Only reachable for a Verified account; an
// unverified one is pointed to Section 10.5's resubmission screen
// instead, which is the only place IT can fix a wrong detail.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/utils/image_picking.dart';
import '../data/profile_repository.dart';
import '../domain/correction_request.dart';

final _profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(apiClientProvider)));

class RequestCorrectionScreen extends ConsumerStatefulWidget {
  const RequestCorrectionScreen({super.key});
  @override
  ConsumerState<RequestCorrectionScreen> createState() =>
      _RequestCorrectionScreenState();
}

class _RequestCorrectionScreenState
    extends ConsumerState<RequestCorrectionScreen> {
  bool _loadingStatus = true;
  MyCorrectionRequest? _pending;

  String _detail = CorrectionDetail.fullName;
  final _newFullNameController = TextEditingController();
  DateTime? _newDateOfBirth;
  String _reasonCode = 'spelling_mistake';
  final _reasonOtherController = TextEditingController();
  String? _documentPath;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final requests =
          await ref.read(_profileRepositoryProvider).getMyCorrectionRequests();
      final pendingMatches = requests.where((r) => r.isPending);
      if (mounted) {
        setState(() {
          _pending = pendingMatches.isEmpty ? null : pendingMatches.first;
          _loadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(DateTime.now().year - 25),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _newDateOfBirth = picked);
  }

  Future<void> _pickDocument() async {
    final file = await pickAndCompressImage();
    if (file != null) setState(() => _documentPath = file.path);
  }

  bool get _needsFullName =>
      _detail == CorrectionDetail.fullName || _detail == CorrectionDetail.both;
  bool get _needsDateOfBirth =>
      _detail == CorrectionDetail.dateOfBirth ||
      _detail == CorrectionDetail.both;

  Future<void> _submit() async {
    if (_needsFullName && _newFullNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Enter the correct full name.');
      return;
    }
    if (_needsDateOfBirth && _newDateOfBirth == null) {
      setState(() => _errorMessage = 'Select the correct date of birth.');
      return;
    }
    if (_reasonCode == 'other' && _reasonOtherController.text.trim().isEmpty) {
      setState(
          () => _errorMessage = 'Describe the reason for this correction.');
      return;
    }
    if (_documentPath == null) {
      setState(() => _errorMessage =
          'A photo of an ID or official document showing the correct value is required.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final message =
          await ref.read(_profileRepositoryProvider).submitCorrectionRequest(
                detail: _detail,
                reasonCode: _reasonCode,
                documentPath: _documentPath!,
                requestedFullName:
                    _needsFullName ? _newFullNameController.text.trim() : null,
                requestedDateOfBirth: _needsDateOfBirth
                    ? _newDateOfBirth!.toIso8601String().split('T').first
                    : null,
                reasonOther: _reasonCode == 'other'
                    ? _reasonOtherController.text.trim()
                    : null,
              );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    } on CorrectionRequestException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingStatus) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Request a Correction')),
      body: SafeArea(
        child: _pending != null ? _buildPendingStatus(_pending!) : _buildForm(),
      ),
    );
  }

  Widget _buildPendingStatus(MyCorrectionRequest pending) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_outlined,
              size: 40, color: AppColors.accentDark),
          const SizedBox(height: AppSpacing.md),
          const Text('You already have a correction request under review.',
              style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Submitted ${pending.createdAt.toLocal()}'.split('.').first,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
              'Your current details stay until it is reviewed. You\'ll be notified of the outcome.',
              style: AppTypography.body),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
              'This is a request to Customer Service for a genuine mistake (for example, a spelling error or a legal name change). Your current details stay until it is reviewed.',
              style: AppTypography.body),
          const SizedBox(height: AppSpacing.lg),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                  color: AppColors.statusCancelledBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Text(_errorMessage!,
                  style: const TextStyle(color: AppColors.statusCancelledFg)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const Text('Which detail is wrong?', style: AppTypography.h3),
          RadioGroup<String>(
            groupValue: _detail,
            onChanged: (v) => setState(() => _detail = v ?? _detail),
            child: const Column(children: [
              RadioListTile<String>(
                  title: Text('Full name'),
                  value: CorrectionDetail.fullName,
                  contentPadding: EdgeInsets.zero),
              RadioListTile<String>(
                  title: Text('Date of birth'),
                  value: CorrectionDetail.dateOfBirth,
                  contentPadding: EdgeInsets.zero),
              RadioListTile<String>(
                  title: Text('Both'),
                  value: CorrectionDetail.both,
                  contentPadding: EdgeInsets.zero),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_needsFullName) ...[
            TextFormField(
              controller: _newFullNameController,
              decoration: const InputDecoration(labelText: 'Correct Full Name'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_needsDateOfBirth) ...[
            InkWell(
              onTap: _pickDateOfBirth,
              child: InputDecorator(
                decoration:
                    const InputDecoration(labelText: 'Correct Date of Birth'),
                child: Text(_newDateOfBirth == null
                    ? 'Select date'
                    : _newDateOfBirth!.toIso8601String().split('T').first),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const Text('Why is this wrong?', style: AppTypography.h3),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _reasonCode,
            items: correctionReasons.entries
                .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _reasonCode = v ?? _reasonCode),
          ),
          if (_reasonCode == 'other') ...[
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _reasonOtherController,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Explain the reason'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Text('Supporting Document', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
              'A photo of an ID or official document showing the correct value.',
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: _pickDocument,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: _documentPath == null
                  ? const Center(
                      child: Icon(Icons.add_a_photo_outlined, size: 32))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.file(File(_documentPath!),
                          fit: BoxFit.cover, width: double.infinity),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent))
                : const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _newFullNameController.dispose();
    _reasonOtherController.dispose();
    super.dispose();
  }
}
