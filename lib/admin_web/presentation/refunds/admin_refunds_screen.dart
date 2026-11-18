// lib/admin_web/presentation/refunds/admin_refunds_screen.dart
// UW 9.4: escalated refund requests (seller declined, buyer escalated).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;
import '../../../features/admin/domain/admin_models.dart';
import '../widgets/admin_queue_scaffold.dart';
import '../widgets/admin_decision_dialogs.dart';

final _refundQueueProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getRefundQueue());

const _refundDismissReasons = {
  'insufficient_evidence': 'Insufficient evidence',
  'sellers_response_reasonable': "Seller's response was reasonable",
  'other': 'Other',
};

class AdminRefundsScreen extends ConsumerWidget {
  const AdminRefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(_refundQueueProvider);

    return AdminQueueScaffold<RefundQueueItem>(
      title: 'Refund Escalations',
      subtitle: 'Refund claims the seller declined and the buyer escalated.',
      asyncItems: queueAsync,
      onRetry: () => ref.invalidate(_refundQueueProvider),
      emptyLabel: 'No escalated refund requests.',
      columns: const ['Buyer', 'Seller', 'Reason', 'Escalated'],
      rowCells: (item) => [
        Text(item.buyerName),
        Text(item.sellerName),
        Text(item.reasonCode.replaceAll('_', ' ')),
        Text(item.escalatedAt != null ? _fmt(item.escalatedAt!) : '—'),
      ],
      onOpen: (item) async {
        final action = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('${item.buyerName} vs ${item.sellerName}'),
            content: Text(
                'Reason given: ${item.reasonCode.replaceAll('_', ' ')}'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop('dismiss'),
                  child: const Text('Dismiss')),
              ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop('verify'),
                  child: const Text('Verify Claim')),
            ],
          ),
        );
        if (action == null || !context.mounted) return;
        if (action == 'verify') {
          await runAdminDecision(
              context,
              () => ref
                  .read(adminRepositoryProvider)
                  .submitRefundDecision(item.id, decision: 'verified'));
          ref.invalidate(_refundQueueProvider);
          return;
        }
        final result = await showReasonDialog(
            context: context,
            title: 'Dismiss Refund Claim',
            reasons: _refundDismissReasons);
        if (result == null) return;
        if (!context.mounted) return;
        await runAdminDecision(
            context,
            () => ref.read(adminRepositoryProvider).submitRefundDecision(
                item.id,
                decision: 'dismissed',
                reasonCode: result.$1,
                note: result.$2));
        ref.invalidate(_refundQueueProvider);
      },
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
