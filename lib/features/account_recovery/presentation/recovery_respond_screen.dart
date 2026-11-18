// lib/features/account_recovery/presentation/recovery_respond_screen.dart
//
// Answers the gap RecoveryStatusScreen could only ever describe: an
// Admin's "Request More Information" decision. Reached from that
// screen once it sees status moreInfoNeeded, carrying the same
// request number + date of birth (no login -- this flow's whole
// reason to exist is someone who can't log in) plus the structured
// moreInfoItems that say which of these fields actually apply.
// Mirrors KycSubmissionScreen's own upload-tile/liveness-check pattern
// (ScreenFlashChallengeScreen is already shared between KYC and this
// feature) rather than inventing a second one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_picking.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../../kyc/domain/liveness_challenge.dart';
import '../../kyc/presentation/screen_flash_challenge_screen.dart';
import '../data/account_recovery_repository.dart';
import 'account_recovery_screen.dart' show accountRecoveryRepositoryProvider;

class RecoveryRespondScreen extends ConsumerStatefulWidget {
  const RecoveryRespondScreen({
    super.key,
    required this.requestNumber,
    required this.dateOfBirth,
    required this.moreInfoItems,
    this.moreInfoRequested,
    this.idType,
    this.backRequired = false,
  });

  final String requestNumber;
  final DateTime dateOfBirth;
  final List<String> moreInfoItems;
  final String? moreInfoRequested;
  final String? idType;
  final bool backRequired;

  @override
  ConsumerState<RecoveryRespondScreen> createState() =>
      _RecoveryRespondScreenState();
}

class _RecoveryRespondScreenState
    extends ConsumerState<RecoveryRespondScreen> {
  final _contactController = TextEditingController();
  final _otherController = TextEditingController();
  String? _idFrontPath;
  String? _idBackPath;
  LivenessCaptureResult? _liveness;
  bool _submitting = false;
  bool _done = false;
  String? _errorMessage;

  bool Function(String) get _needs => widget.moreInfoItems.contains;

  Future<void> _pickImage(void Function(String path) onPicked) async {
    final file = await pickAndCompressImage();
    if (file != null) setState(() => onPicked(file.path));
  }

  Future<void> _startLivenessCheck() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScreenFlashChallengeScreen(
          fetchChallenge: () => ref
              .read(accountRecoveryRepositoryProvider)
              .fetchLivenessChallengeForRespond(
                requestNumber: widget.requestNumber,
                dateOfBirth: widget.dateOfBirth,
              ),
          onCompleted: (result) {
            if (!mounted) return;
            setState(() => _liveness = result);
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_needs('retake_id_photo') && _idFrontPath == null) {
      setState(() => _errorMessage = 'Please upload a new front image of your ID.');
      return;
    }
    if (_needs('retake_id_photo') && widget.backRequired && _idBackPath == null) {
      setState(() => _errorMessage = 'Please upload a new back image of your ID.');
      return;
    }
    if (_needs('repeat_selfie') && _liveness == null) {
      setState(() => _errorMessage = 'Please complete the liveness check.');
      return;
    }
    if (_needs('contact') && _contactController.text.trim().isEmpty) {
      setState(() => _errorMessage =
          'Please enter the email or phone number the account was registered with.');
      return;
    }
    if (_needs('other') && _otherController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a response.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(accountRecoveryRepositoryProvider).respond(
            requestNumber: widget.requestNumber,
            dateOfBirth: widget.dateOfBirth,
            idFrontPath: _needs('retake_id_photo') ? _idFrontPath : null,
            idBackPath: _needs('retake_id_photo') ? _idBackPath : null,
            liveness: _needs('repeat_selfie') ? _liveness : null,
            contact: _needs('contact') ? _contactController.text.trim() : null,
            otherResponse:
                _needs('other') ? _otherController.text.trim() : null,
          );
      if (mounted) setState(() => _done = true);
    } on RecoveryException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        appBar: AppBar(title: const Text('Response Submitted')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Your response has been submitted and your request is back under review.',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Respond to Request')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.moreInfoRequested != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: AppColors.backgroundStart,
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text('Needed: ${widget.moreInfoRequested}',
                      style: AppTypography.bodySmall),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
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
              if (_needs('retake_id_photo')) ...[
                _buildUploadTile(
                  label: 'ID Front Photo',
                  path: _idFrontPath,
                  onTap: () => _pickImage((p) => _idFrontPath = p),
                ),
                if (widget.backRequired) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildUploadTile(
                    label: 'ID Back Photo',
                    path: _idBackPath,
                    onTap: () => _pickImage((p) => _idBackPath = p),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
              if (_needs('repeat_selfie')) ...[
                _buildUploadTile(
                  label: 'Liveness Check',
                  path: _liveness == null
                      ? null
                      : (_liveness!.optedOut ? 'skipped' : _liveness!.neutralPath),
                  doneLabelOverride:
                      _liveness?.optedOut == true ? 'Liveness check skipped' : null,
                  onTap: _startLivenessCheck,
                  icon: Icons.remove_red_eye_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_needs('contact')) ...[
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                      labelText: 'Email or phone number on the account'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_needs('other')) ...[
                TextFormField(
                  controller: _otherController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Your response'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accent))
                    : const Text('Submit Response'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadTile({
    required String label,
    required String? path,
    required VoidCallback onTap,
    String? doneLabelOverride,
    IconData icon = Icons.upload_file,
  }) {
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
                child: Text(done ? (doneLabelOverride ?? 'Added — $label') : label,
                    style: AppTypography.body)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contactController.dispose();
    _otherController.dispose();
    super.dispose();
  }
}
