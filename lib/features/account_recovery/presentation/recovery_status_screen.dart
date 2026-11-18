// lib/features/account_recovery/presentation/recovery_status_screen.dart
//
// Closes the other half of the Account Recovery gap: GET
// /account-recovery/check (request number + date of birth, no login)
// had no mobile screen either, despite being the only way for someone
// mid-recovery to see whether their request was approved, rejected,
// or needs more info.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/account_recovery_repository.dart';
import '../domain/recovery_models.dart';
import 'account_recovery_screen.dart' show accountRecoveryRepositoryProvider;
import 'recovery_respond_screen.dart';

class RecoveryStatusScreen extends ConsumerStatefulWidget {
  const RecoveryStatusScreen({super.key});
  @override
  ConsumerState<RecoveryStatusScreen> createState() =>
      _RecoveryStatusScreenState();
}

class _RecoveryStatusScreenState extends ConsumerState<RecoveryStatusScreen> {
  final _requestNumberController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _checking = false;
  String? _errorMessage;
  RecoveryCheckResult? _result;

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: DateTime(DateTime.now().year - 25),
        firstDate: DateTime(1900),
        lastDate: DateTime.now());
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _check() async {
    if (_requestNumberController.text.trim().isEmpty || _dateOfBirth == null) {
      setState(
          () => _errorMessage = 'Enter your request number and date of birth.');
      return;
    }
    setState(() {
      _checking = true;
      _errorMessage = null;
      _result = null;
    });
    try {
      final result =
          await ref.read(accountRecoveryRepositoryProvider).checkStatus(
                requestNumber: _requestNumberController.text.trim(),
                dateOfBirth: _dateOfBirth!,
              );
      if (mounted) setState(() => _result = result);
    } on RecoveryException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _statusLabel(RecoveryRequestStatus s) => switch (s) {
        RecoveryRequestStatus.awaitingReview => 'Awaiting review',
        RecoveryRequestStatus.moreInfoNeeded => 'More information needed',
        RecoveryRequestStatus.approved => 'Approved',
        RecoveryRequestStatus.rejected => 'Rejected',
        RecoveryRequestStatus.cancelled => 'Cancelled',
        RecoveryRequestStatus.expired => 'Expired',
        RecoveryRequestStatus.unknown => 'Unknown',
      };

  Color _statusColor(RecoveryRequestStatus s) => switch (s) {
        RecoveryRequestStatus.approved => AppColors.statusSuccessFg,
        RecoveryRequestStatus.rejected ||
        RecoveryRequestStatus.cancelled ||
        RecoveryRequestStatus.expired =>
          AppColors.statusCancelledFg,
        RecoveryRequestStatus.moreInfoNeeded => AppColors.accentDark,
        _ => AppColors.statusPendingFg,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check Recovery Request')),
      body: SafeArea(
        // Same real bug class as login_screen.dart (caught on a real
        // device at a larger text size): a bare Padding+Column here
        // would overflow instead of scrolling once content exceeds the
        // viewport. Applied preventively across every other screen with
        // this same Scaffold>SafeArea>Padding>Column shape, not just
        // the one caught live.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
                      style:
                          const TextStyle(color: AppColors.statusCancelledFg)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextFormField(
                  controller: _requestNumberController,
                  decoration: const InputDecoration(
                      labelText: 'Request Number (e.g. REC-123456)')),
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
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _checking ? null : _check,
                child: _checking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accent))
                    : const Text('Check Status'),
              ),
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_result!.requestNumber, style: AppTypography.h3),
                      const SizedBox(height: AppSpacing.xs),
                      Text(_statusLabel(_result!.status),
                          style: AppTypography.body.copyWith(
                              color: _statusColor(_result!.status),
                              fontWeight: FontWeight.w700)),
                      if (_result!.rejectionReason != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Reason: ${_result!.rejectionReason}',
                            style: AppTypography.bodySmall),
                      ],
                      if (_result!.moreInfoRequested != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Needed: ${_result!.moreInfoRequested}',
                            style: AppTypography.bodySmall),
                      ],
                      if (_result!.status ==
                          RecoveryRequestStatus.moreInfoNeeded) ...[
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => RecoveryRespondScreen(
                                requestNumber: _result!.requestNumber,
                                dateOfBirth: _dateOfBirth!,
                                moreInfoItems: _result!.moreInfoItems,
                                moreInfoRequested: _result!.moreInfoRequested,
                                idType: _result!.idType,
                                backRequired: _result!.backRequired,
                              ),
                            ));
                          },
                          child: const Text('Respond'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _requestNumberController.dispose();
    super.dispose();
  }
}
