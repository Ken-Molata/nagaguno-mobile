// lib/admin_web/presentation/corrections/admin_corrections_screen.dart
// UW 21.1: "Request a correction" for a verified account's name/DOB.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;
import '../../../features/admin/domain/admin_models.dart';
import '../widgets/admin_queue_scaffold.dart';
import '../widgets/admin_decision_dialogs.dart';

final _correctionQueueProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getCorrectionQueue());

const _correctionRejectReasons = {
  'document_mismatch': 'Document does not show the requested details',
  'unreadable_or_low_quality': 'Document unreadable or of insufficient image quality',
  'document_altered_or_fraudulent': 'Document appears altered or fraudulent',
  'document_expired': 'Document is expired',
  'dob_under_18': 'Requested date of birth gives an age under 18',
  'other': 'Other',
};

class AdminCorrectionsScreen extends ConsumerWidget {
  const AdminCorrectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(_correctionQueueProvider);

    return AdminQueueScaffold<CorrectionQueueItem>(
      title: 'Profile Corrections',
      subtitle: 'Requests to fix a verified account\'s name or date of birth.',
      asyncItems: queueAsync,
      onRetry: () => ref.invalidate(_correctionQueueProvider),
      emptyLabel: 'No correction requests awaiting review.',
      columns: const ['User', 'Role', 'Detail', 'Reason', 'Filed'],
      rowCells: (item) => [
        Text(item.userName),
        Text(item.role),
        Text(item.detail.replaceAll('_', ' ')),
        Text(item.reasonCode.replaceAll('_', ' ')),
        Text(_fmt(item.createdAt)),
      ],
      onOpen: (item) => showDialog(
        context: context,
        builder: (_) => _CorrectionDetailDialog(
          id: item.id,
          onDecided: () => ref.invalidate(_correctionQueueProvider),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _CorrectionDetailDialog extends ConsumerStatefulWidget {
  const _CorrectionDetailDialog({required this.id, required this.onDecided});
  final String id;
  final VoidCallback onDecided;
  @override
  ConsumerState<_CorrectionDetailDialog> createState() =>
      _CorrectionDetailDialogState();
}

class _CorrectionDetailDialogState extends ConsumerState<_CorrectionDetailDialog> {
  CorrectionDetail? _detail;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(adminRepositoryProvider).getCorrectionDetail(widget.id);
      if (mounted) {
        setState(() {
          _detail = d;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Couldn\'t load this request.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _decide(String decision, {String? rejectionReason, String? note}) async {
    setState(() => _submitting = true);
    try {
      await ref.read(adminRepositoryProvider).submitCorrectionDecision(widget.id,
          decision: decision, rejectionReason: rejectionReason, note: note);
      if (!mounted) return;
      widget.onDecided();
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn\'t record that decision.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _detail == null
                  ? Center(child: Text(_error ?? 'Not found.'))
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final d = _detail!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(child: Text('Correction Request', style: AppTypography.h2)),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Current full name', d.currentFullName),
                _row('Current date of birth', _fmt(d.currentDateOfBirth)),
                if (d.requestedFullName != null)
                  _row('Requested full name', d.requestedFullName!),
                if (d.requestedDateOfBirth != null)
                  _row('Requested date of birth', _fmt(d.requestedDateOfBirth)),
                _row('Reason', d.reasonCode.replaceAll('_', ' ')),
                if (d.reasonOther != null) _row('Explanation', d.reasonOther!),
                const SizedBox(height: AppSpacing.sm),
                if (d.documentUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.network(d.documentUrl!, height: 200, fit: BoxFit.contain),
                  ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: AppSpacing.md),
        // UW 19: "Submitting shows 'Submitting decision...'"
        if (_submitting) ...[
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: AppSpacing.sm),
              Text('Submitting decision...', style: AppTypography.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _submitting
                  ? null
                  : () async {
                      final result = await showReasonDialog(
                          context: context,
                          title: 'Reject Correction Request',
                          reasons: _correctionRejectReasons);
                      if (result != null) {
                        await _decide('rejected',
                            rejectionReason: result.$1, note: result.$2);
                      }
                    },
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ElevatedButton(
              onPressed: _submitting ? null : () => _decide('approved'),
              child: const Text('Approve'),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 180, child: Text(label, style: AppTypography.bodySmall)),
          Expanded(child: Text(value, style: AppTypography.body)),
        ]),
      );

  String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
