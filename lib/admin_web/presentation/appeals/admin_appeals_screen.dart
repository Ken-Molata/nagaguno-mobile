// lib/admin_web/presentation/appeals/admin_appeals_screen.dart
// UW 17.5: appeals against a suspension or ban.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;
import '../../../features/admin/domain/admin_models.dart';
import '../widgets/admin_queue_scaffold.dart';
import '../widgets/admin_decision_dialogs.dart';

final _appealQueueProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getAppealQueue());

class AdminAppealsScreen extends ConsumerWidget {
  const AdminAppealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(_appealQueueProvider);

    return AdminQueueScaffold<AppealQueueItem>(
      title: 'Appeals',
      subtitle: 'One appeal per penalty, against a suspension or ban.',
      asyncItems: queueAsync,
      onRetry: () => ref.invalidate(_appealQueueProvider),
      emptyLabel: 'No appeals awaiting review.',
      columns: const ['User', 'Role', 'Penalty', 'Filed'],
      rowCells: (item) => [
        Text(item.userName),
        Text(item.role),
        Text(item.targetType),
        Text(_fmt(item.createdAt)),
      ],
      onOpen: (item) => showDialog(
        context: context,
        builder: (_) => _AppealDetailDialog(
          id: item.id,
          onDecided: () => ref.invalidate(_appealQueueProvider),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _AppealDetailDialog extends ConsumerStatefulWidget {
  const _AppealDetailDialog({required this.id, required this.onDecided});
  final String id;
  final VoidCallback onDecided;
  @override
  ConsumerState<_AppealDetailDialog> createState() => _AppealDetailDialogState();
}

class _AppealDetailDialogState extends ConsumerState<_AppealDetailDialog> {
  AppealDetail? _detail;
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
      final d = await ref.read(adminRepositoryProvider).getAppealDetail(widget.id);
      if (mounted) {
        setState(() {
          _detail = d;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Couldn\'t load this appeal.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _decide(String decision, {String? note}) async {
    setState(() => _submitting = true);
    try {
      await ref.read(adminRepositoryProvider).submitAppealDecision(widget.id,
          decision: decision, note: note);
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
          Expanded(child: Text('Appeal: ${d.userName}', style: AppTypography.h2)),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Penalty: ${d.targetType} (${d.violationCategory})',
                    style: AppTypography.body),
                Text('Reason given at the time: ${d.violationReason}',
                    style: AppTypography.bodySmall),
                Text('Source: ${d.violationSource}', style: AppTypography.bodySmall),
                const SizedBox(height: AppSpacing.md),
                if (d.originalReportEssay != null) ...[
                  const Text('Original report', style: AppTypography.label),
                  Text(d.originalReportEssay!, style: AppTypography.body),
                  const SizedBox(height: AppSpacing.md),
                ],
                const Text('Appellant\'s counter-evidence', style: AppTypography.label),
                Text(d.counterEvidence ?? '—', style: AppTypography.body),
                if (d.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
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
                      final note = await showNoteDialog(
                          context: context,
                          title: 'Reject Appeal',
                          label: 'Notes (optional)');
                      await _decide('rejected', note: note);
                    },
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ElevatedButton(
              onPressed: _submitting ? null : () => _decide('approved'),
              child: const Text('Approve (Reverse Penalty)'),
            ),
          ),
        ]),
      ],
    );
  }
}
