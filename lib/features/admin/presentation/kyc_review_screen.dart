// lib/features/admin/presentation/kyc_review_screen.dart
//
// The single most "needs to happen quickly, on the go" admin task —
// prioritized for mobile per the earlier UX plan's note that Admin
// overall is web-primary but doesn't need to be all-or-nothing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../kyc/domain/kyc_models.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';

final kycQueueProvider = FutureProvider.autoDispose<List<KycQueueItem>>(
    (ref) => ref.watch(adminRepositoryProvider).getKycQueue());

class KycReviewScreen extends ConsumerWidget {
  const KycReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(kycQueueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verification Queue')),
      body: queueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Couldn\'t load the queue.'),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
                onPressed: () => ref.invalidate(kycQueueProvider),
                child: const Text('Retry')),
          ]),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No pending verifications.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(kycQueueProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final item = items[i];
                return ListTile(
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      side: const BorderSide(color: AppColors.border)),
                  title: Text(item.fullName,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${item.role[0].toUpperCase()}${item.role.substring(1)}${item.barangay != null ? ' · ${item.barangay}' : ''}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            KycReviewDetailScreen(submissionId: item.id)));
                    ref.invalidate(kycQueueProvider);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

final _kycDetailProvider = FutureProvider.autoDispose.family(
  (ref, String id) => ref.watch(adminRepositoryProvider).getKycDetail(id),
);

class KycReviewDetailScreen extends ConsumerStatefulWidget {
  const KycReviewDetailScreen({super.key, required this.submissionId});
  final String submissionId;
  @override
  ConsumerState<KycReviewDetailScreen> createState() =>
      _KycReviewDetailScreenState();
}

class _KycReviewDetailScreenState extends ConsumerState<KycReviewDetailScreen> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .submitKycDecision(widget.submissionId, decision: 'approved');
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Something went wrong.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Submission'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason (required)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(reasonController.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    // Matches the real backend's own validation exactly: a rejection
    // without a reason is a 400 error, so this is enforced client-side
    // too, before even attempting the request.
    if (reason == null || reason.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).submitKycDecision(
          widget.submissionId,
          decision: 'rejected',
          rejectionReason: reason);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Something went wrong.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Mirrors RESUBMISSION_FIELD_LABELS in routes/kyc.js exactly.
  static const _fieldLabels = {
    'id_front': 'Front of ID',
    'id_back': 'Back of ID',
    'supporting_doc': 'Supporting document',
    'liveness': 'Liveness / selfie check',
    'id_type': 'Selected ID type',
    'account_details': 'Full name or date of birth',
  };

  Future<void> _requestResubmission() async {
    // UW 15.3: "a document side not required for that ID type is never
    // referenced" -- id_back must not even be offered as a resubmission
    // option for an ID type with no back page (Passport, PhilSys
    // ePhilID, Voter's Certification/ID, Barangay ID with Certification),
    // otherwise an Admin could flag it and the resulting notification
    // would wrongly ask the user for a document side that type doesn't
    // have. KycIdType mirrors the real Route table's requiresBack value
    // per type (kept in sync -- see that enum's own doc comment).
    final idType = ref.read(_kycDetailProvider(widget.submissionId)).value?.idType;
    final requiresBack = idType == null ||
        KycIdType.values
            .firstWhere((t) => t.apiValue == idType,
                orElse: () => KycIdType.values.first)
            .requiresBack;
    final fieldLabels = requiresBack
        ? _fieldLabels
        : (Map<String, String>.from(_fieldLabels)..remove('id_back'));

    final reasonController = TextEditingController();
    final selected = <String>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Request Resubmission'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason (required)'),
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Which document(s) need resubmission?',
                    style: AppTypography.label),
                // UW 10.4: "Admin flags the specific document(s)
                // requiring resubmission using the same reason set as
                // Reject" -- at least one is required, enforced below.
                ...fieldLabels.entries.map((e) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.value),
                      value: selected.contains(e.key),
                      onChanged: (v) => setDialogState(() {
                        if (v == true) {
                          selected.add(e.key);
                        } else {
                          selected.remove(e.key);
                        }
                      }),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty || selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A reason and at least one document are required.')));
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).submitKycDecision(
          widget.submissionId,
          decision: 'resubmission_required',
          rejectionReason: reason,
          resubmissionFields: selected.toList());
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Something went wrong.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(_kycDetailProvider(widget.submissionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Review Submission')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Couldn\'t load this submission.')),
        data: (d) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(d.fullName, style: AppTypography.h1),
              Text(
                  '${d.role[0].toUpperCase()}${d.role.substring(1)} · Age ${d.age}',
                  style: AppTypography.bodySmall),
              const SizedBox(height: AppSpacing.md),
              _DetailRow(label: 'Address', value: d.completeAddress),
              _DetailRow(label: 'Contact', value: d.contactNumber),
              _DetailRow(
                  label: 'ID Type', value: d.idType.replaceAll('_', ' ')),
              const SizedBox(height: AppSpacing.lg),
              const Text('ID Front', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.xs),
              if (d.idFrontUrl != null)
                ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.network(d.idFrontUrl!,
                        height: 180, fit: BoxFit.cover)),
              if (d.idBackUrl != null) ...[
                const SizedBox(height: AppSpacing.md),
                const Text('ID Back', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.network(d.idBackUrl!,
                        height: 180, fit: BoxFit.cover)),
              ],
              // REAL GAP FOUND AND FIXED: supportingDocUrl was parsed
              // from the API response and even has its own label in
              // the Request Resubmission field picker below ('Supporting
              // document') -- but nothing ever rendered it here, so the
              // Admin could flag it for resubmission without ever
              // having been able to see it, including the Business
              // Permit this session made mandatory for Vendors.
              if (d.supportingDocUrl != null) ...[
                const SizedBox(height: AppSpacing.md),
                const Text('Supporting Document', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.network(d.supportingDocUrl!,
                        height: 180, fit: BoxFit.cover)),
              ],
              // UW 10.2's Screen Flash Challenge: shown alongside the
              // ID photo so the Admin can visually compare the two —
              // the automated checks below are explicitly advisory
              // ("the Admin decides"), not a substitute for that.
              if (d.livenessOptedOut) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: AppColors.backgroundStart,
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: const Text(
                      'Liveness check: Not performed (user choice).',
                      style: AppTypography.bodySmall),
                ),
              ] else if (d.routeBCaptureUrls != null) ...[
                const SizedBox(height: AppSpacing.md),
                const Text('Liveness Check Photos', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                _LivenessResultBadge(result: d.livenessResult),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _capturePhoto('Neutral', d.routeBCaptureUrls!['neutral']),
                    _capturePhoto('Color 1', d.routeBCaptureUrls!['color_1']),
                    _capturePhoto('Color 2', d.routeBCaptureUrls!['color_2']),
                    _capturePhoto('Color 3', d.routeBCaptureUrls!['color_3']),
                    if (d.headTurnSkipped)
                      _captureSkippedTile('Head Turn — Skipped')
                    else
                      _capturePhoto('Head Turn', d.routeBCaptureUrls!['head_turn']),
                  ],
                ),
                if (d.livenessChecks != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _LivenessChecksTable(checks: d.livenessChecks!),
                ],
              ] else if (d.livenessPhotoUrl != null) ...[
                const SizedBox(height: AppSpacing.md),
                const Text('Liveness Check Photo', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.network(d.livenessPhotoUrl!,
                        height: 180, fit: BoxFit.cover)),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // UW 10.4: the third decision -- distinct from Reject,
                // flags specific document(s) for a narrower resubmission
                // rather than requiring the user start over.
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _requestResubmission,
                    child: const Text('Resubmission'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _approve,
                    child: const Text('Approve'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _capturePhoto(String label, String? url) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: url != null
                ? Image.network(url, height: 110, width: 110, fit: BoxFit.cover)
                : Container(
                    height: 110,
                    width: 110,
                    color: AppColors.backgroundStart,
                    child: const Icon(Icons.image_not_supported_outlined,
                        color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _captureSkippedTile(String label) {
    return SizedBox(
      width: 110,
      height: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: 2),
          Container(
            height: 110,
            width: 110,
            decoration: BoxDecoration(
                color: AppColors.backgroundStart,
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            child:
                const Icon(Icons.not_interested, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: AppTypography.bodySmall)),
        Expanded(
            flex: 2,
            child: Text(value,
                style: AppTypography.body, textAlign: TextAlign.end)),
      ]),
    );
  }
}

/// UW 10.2: "Result recorded as Liveness: Passed, Failed, or
/// Inconclusive."
class _LivenessResultBadge extends StatelessWidget {
  const _LivenessResultBadge({required this.result});
  final String? result;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (result) {
      'passed' => (AppColors.statusSuccessBg, AppColors.statusSuccessFg, 'Liveness: Passed'),
      'failed' => (AppColors.statusCancelledBg, AppColors.statusCancelledFg, 'Liveness: Failed'),
      'inconclusive' => (AppColors.statusPendingBg, AppColors.statusPendingFg, 'Liveness: Inconclusive'),
      _ => (AppColors.backgroundStart, AppColors.textMuted, 'Liveness: Unknown'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(label, style: AppTypography.label.copyWith(color: fg)),
    );
  }
}

/// UW 10.2's four-factor breakdown: same person, light response,
/// sequence match, head turn. Advisory -- the Admin decides -- so this
/// is informational only, same as the rest of this review screen.
class _LivenessChecksTable extends StatelessWidget {
  const _LivenessChecksTable({required this.checks});
  final Map<String, dynamic> checks;

  static const _rowLabels = {
    'same_person': 'Same person',
    'light_response': 'Light response',
    'sequence_match': 'Sequence match',
    'head_turn': 'Head turn',
  };

  String _displayValue(dynamic v) {
    if (v is bool) return v ? 'Matched' : 'Did not match';
    return switch (v) {
      'passed' => 'Passed',
      'failed' => 'Failed',
      'partial' => 'Partial',
      'not_available' => 'Not available',
      'skipped' => 'Skipped',
      _ => v?.toString() ?? '—',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        children: _rowLabels.entries
            .map((e) => _DetailRow(
                label: e.value, value: _displayValue(checks[e.key])))
            .toList(),
      ),
    );
  }
}
