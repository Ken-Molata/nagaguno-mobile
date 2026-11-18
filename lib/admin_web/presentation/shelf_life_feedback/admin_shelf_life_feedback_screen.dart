// lib/admin_web/presentation/shelf_life_feedback/admin_shelf_life_feedback_screen.dart
//
// UW 3.3 "Farmer feedback": "Next to a listing's shelf-life display,
// the farmer or vendor can select 'Shelf life seems wrong?'... The
// Admin reviews it and either accepts it (the row is updated) or
// declines it with a reason." Also the Section 18 cross-cutting
// example ("Shelf-life feedback declined") this screen was built to
// close -- the whole farmer-feedback loop was previously entirely
// unbuilt (only the read-only reference lookup existed).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;
import '../../../features/admin/domain/admin_models.dart';
import '../widgets/admin_queue_scaffold.dart';
import '../widgets/admin_decision_dialogs.dart';

final _shelfLifeFeedbackQueueProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getShelfLifeFeedbackQueue());

// Matches SHELF_LIFE_DECLINE_REASONS in routes/admin.js exactly.
const _declineReasons = {
  'matches_reference': 'Figure matches the reference sources',
  'insufficient_info': 'Not enough information to change it',
  'seller_specific': 'Applies only to this seller\'s storage conditions',
  'other': 'Other',
};

class AdminShelfLifeFeedbackScreen extends ConsumerWidget {
  const AdminShelfLifeFeedbackScreen({super.key});

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _decide(BuildContext context, WidgetRef ref,
      ShelfLifeFeedbackItem item, String decision,
      {String? reasonCode, String? note}) async {
    try {
      await runAdminDecision(
          context,
          () => ref
              .read(adminRepositoryProvider)
              .submitShelfLifeFeedbackDecision(item.id,
                  decision: decision, reasonCode: reasonCode, note: note));
      ref.invalidate(_shelfLifeFeedbackQueueProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(adminErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(_shelfLifeFeedbackQueueProvider);

    return AdminQueueScaffold<ShelfLifeFeedbackItem>(
      title: 'Shelf Life Feedback',
      subtitle:
          'Farmer/vendor-reported corrections to a crop\'s shelf-life reference figure.',
      asyncItems: queueAsync,
      onRetry: () => ref.invalidate(_shelfLifeFeedbackQueueProvider),
      emptyLabel: 'No shelf-life feedback awaiting review.',
      columns: const [
        'Crop',
        'Reported by',
        'Observed',
        'Current reference',
        'Filed'
      ],
      rowCells: (item) {
        final currentDays = item.storageCondition == 'refrigerated'
            ? item.currentDaysRefrigerated
            : item.currentDaysRoomTemp;
        return [
          Text(item.cropName),
          Text(item.farmerName),
          Text(
              '${item.observedDays} days (${item.direction == 'longer' ? 'lasts longer' : 'spoils sooner'})'),
          Text(currentDays != null ? '$currentDays days' : 'No reference yet'),
          Text(_fmt(item.createdAt)),
        ];
      },
      onOpen: (item) => showDialog(
        context: context,
        builder: (_) => _FeedbackDetailDialog(item: item, onDecide: _decide),
      ),
    );
  }
}

class _FeedbackDetailDialog extends StatelessWidget {
  const _FeedbackDetailDialog({required this.item, required this.onDecide});
  final ShelfLifeFeedbackItem item;
  final Future<void> Function(BuildContext, WidgetRef, ShelfLifeFeedbackItem,
      String, {String? reasonCode, String? note}) onDecide;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final currentDays = item.storageCondition == 'refrigerated'
            ? item.currentDaysRefrigerated
            : item.currentDaysRoomTemp;
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('${item.cropName} (${item.category})',
                            style: AppTypography.h2)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop()),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                      'Reported by ${item.farmerName}: their crop ${item.direction == 'longer' ? 'lasts longer than shown' : 'spoils sooner than shown'} -- observed ${item.observedDays} days (${item.storageCondition.replaceAll('_', ' ')}). Current reference: ${currentDays != null ? '$currentDays days' : 'none yet'}.',
                      style: AppTypography.body),
                  if (item.note != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Note: ${item.note}', style: AppTypography.bodySmall),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final result = await showReasonDialog(
                              context: context,
                              title: 'Decline Feedback',
                              reasons: _declineReasons);
                          if (result != null && context.mounted) {
                            await onDecide(context, ref, item, 'declined',
                                reasonCode: result.$1, note: result.$2);
                            if (context.mounted) Navigator.of(context).pop();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textMuted),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await onDecide(context, ref, item, 'accepted');
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text('Accept'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
