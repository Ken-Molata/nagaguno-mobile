// lib/admin_web/presentation/reports_disputes/admin_reports_disputes_screen.dart
// UW 9.1/9.2: Reports & Disputes admin review queue.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;
import '../../../features/admin/domain/admin_models.dart';
import '../widgets/admin_queue_scaffold.dart';
import '../widgets/admin_decision_dialogs.dart';

final _reportQueueProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getReportQueue());

const _dismissReasons = {
  'insufficient_evidence': 'Insufficient evidence to confirm the claim',
  'no_violation_found': 'No violation found upon review',
  'already_resolved': 'Issue already resolved between the parties',
  'other': 'Other',
};

class AdminReportsDisputesScreen extends ConsumerWidget {
  const AdminReportsDisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(_reportQueueProvider);

    return AdminQueueScaffold<ReportQueueItem>(
      title: 'Reports & Disputes',
      subtitle: 'Filed reports against users, listings, orders, and agreements.',
      asyncItems: queueAsync,
      onRetry: () => ref.invalidate(_reportQueueProvider),
      emptyLabel: 'No reports awaiting review.',
      columns: const ['Filed by', 'Against', 'Type', 'Violation', 'Filed'],
      rowCells: (item) => [
        Text(item.filerName),
        Text('${item.reportedName} (${item.reportedRole})'),
        Text(item.violationGroup.replaceAll('_', ' ')),
        Text(item.violationType.replaceAll('_', ' ')),
        Text(_fmt(item.createdAt)),
      ],
      onOpen: (item) => showDialog(
        context: context,
        builder: (_) => _ReportDetailDialog(
          id: item.id,
          onDecided: () => ref.invalidate(_reportQueueProvider),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _ReportDetailDialog extends ConsumerStatefulWidget {
  const _ReportDetailDialog({required this.id, required this.onDecided});
  final String id;
  final VoidCallback onDecided;
  @override
  ConsumerState<_ReportDetailDialog> createState() => _ReportDetailDialogState();
}

class _ReportDetailDialogState extends ConsumerState<_ReportDetailDialog> {
  ReportDetail? _detail;
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
      final d = await ref.read(adminRepositoryProvider).getReportDetail(widget.id);
      if (mounted) {
        setState(() {
          _detail = d;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Couldn\'t load this report.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _decide(String decision, {String? reasonCode, String? note}) async {
    setState(() => _submitting = true);
    try {
      await ref.read(adminRepositoryProvider).submitReportDecision(widget.id,
          decision: decision, reasonCode: reasonCode, note: note);
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
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
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
          const Expanded(child: Text('Report', style: AppTypography.h2)),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filed by ${d.filerName} against ${d.reportedName} (${d.reportedRole})',
                    style: AppTypography.body),
                // UW 21.8: "A report keeps the reported person's
                // name/picture as they were when filed, shown beside
                // current ones -- renaming/re-picturing can never
                // erase evidence." d.reportedName above is live
                // (joined fresh); this is the frozen snapshot, shown
                // only when it differs from the current name -- a
                // report that's never had the account renamed since
                // has nothing extra worth showing.
                if (d.reportedNameAtFiling != null &&
                    d.reportedNameAtFiling != d.reportedName) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text('Named "${d.reportedNameAtFiling}" when this report was filed',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text('${d.violationGroup.replaceAll('_', ' ')} — ${d.violationType.replaceAll('_', ' ')}',
                    style: AppTypography.bodySmall),
                if (d.transactionId != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text('Related record: ${d.transactionId}', style: AppTypography.bodySmall),
                ],
                const SizedBox(height: AppSpacing.md),
                if (d.essay != null) ...[
                  const Text('Filer\'s account', style: AppTypography.label),
                  Text(d.essay!, style: AppTypography.body),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (d.photoUrls.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: d.photoUrls
                        .map((u) => ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: Image.network(u, height: 120, width: 120, fit: BoxFit.cover),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                // UW 9.1's headline mechanism: the original content
                // itself, pulled automatically and shown separately
                // from the filer's own account above -- "the admin
                // sees three things side by side." Absent when this
                // report has nothing to auto-capture (a direct
                // user-conduct report with no content pre-link).
                if (d.originalContentSnapshot != null ||
                    d.originalContentImageUrls.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                        color: AppColors.backgroundStart,
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            d.originalContentAuthorName != null
                                ? 'Original content — posted by ${d.originalContentAuthorName}'
                                : 'Original content',
                            style: AppTypography.label),
                        if (d.originalContentSnapshot != null) ...[
                          const SizedBox(height: 4),
                          Text(d.originalContentSnapshot!,
                              style: AppTypography.body),
                        ],
                        if (d.originalContentImageUrls.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: d.originalContentImageUrls
                                .map((u) => ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                      child: Image.network(u,
                                          height: 120,
                                          width: 120,
                                          fit: BoxFit.cover),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: AppSpacing.md),
        // UW 19: "Submitting shows 'Submitting decision...'" -- these
        // three buttons already disabled themselves while submitting
        // (preventing a double-submit) but showed no visible indicator
        // at all, just their normal label sitting inert.
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
                          title: 'Dismiss Report',
                          reasons: _dismissReasons);
                      if (result != null) {
                        await _decide('dismissed', reasonCode: result.$1, note: result.$2);
                      }
                    },
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.textMuted),
              child: const Text('Dismiss'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: OutlinedButton(
              onPressed: _submitting
                  ? null
                  : () async {
                      final note = await showNoteDialog(
                          context: context,
                          title: 'Request More Evidence',
                          label: 'What additional evidence is needed?');
                      if (note != null) {
                        await _decide('more_info_requested', note: note);
                      }
                    },
              child: const Text('Request More Info'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ElevatedButton(
              onPressed: _submitting ? null : () => _decide('verified'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Verify Violation'),
            ),
          ),
        ]),
      ],
    );
  }
}
