// lib/admin_web/presentation/settlements/admin_settlements_screen.dart
// UW 6.1: Gateway settlement -- unsettled Gateway orders grouped by
// seller, with the "send total, upload proof, mark settled" action.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_picking.dart';
import '../../../features/admin/data/admin_repository.dart';
import '../../../features/admin/domain/admin_models.dart';
import '../widgets/admin_queue_scaffold.dart';
import '../widgets/admin_decision_dialogs.dart'
    show adminErrorMessage, runAdminDecision;

final _settlementsProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getSettlements());

class AdminSettlementsScreen extends ConsumerWidget {
  const AdminSettlementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(_settlementsProvider);

    return AdminQueueScaffold<SettlementQueueItem>(
      title: 'Gateway Settlement',
      subtitle:
          'Gateway (PayMongo) sales pooled on the platform account, owed out to each seller.',
      asyncItems: queueAsync,
      onRetry: () => ref.invalidate(_settlementsProvider),
      emptyLabel: 'Nothing unsettled right now.',
      columns: const ['Seller', 'Role', 'Orders', 'Total Owed', 'Linked Account'],
      rowCells: (item) => [
        Text(item.sellerName),
        Text(item.sellerRole),
        Text('${item.orderCount}'),
        Text('₱${item.totalOwed.toStringAsFixed(2)}'),
        Text(item.hasLinkedAccount ? 'On file' : 'Not on file',
            style: item.hasLinkedAccount
                ? null
                : const TextStyle(color: AppColors.error)),
      ],
      onOpen: (item) async {
        if (!item.hasLinkedAccount) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('No Linked Account'),
              content: Text(
                  '${item.sellerName} has no payment account on file yet. Their ₱${item.totalOwed.toStringAsFixed(2)} stays held until they add one -- nothing is lost.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK')),
              ],
            ),
          );
          return;
        }

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Settle ${item.sellerName}'),
            content: Text(
                'This marks all ${item.orderCount} unsettled order(s), totaling ₱${item.totalOwed.toStringAsFixed(2)}, as settled. You\'ll be asked for proof the transfer was sent.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Continue')),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;

        final file = await pickAndCompressImage();
        if (file == null || !context.mounted) return;

        try {
          // UW 19: "Submitting shows 'Submitting decision...'" -- this
          // previously awaited the upload with no visible indicator at
          // all.
          await runAdminDecision(
              context,
              () => ref
                  .read(adminRepositoryProvider)
                  .recordSettlement(item.sellerId, proofPath: file.path));
          ref.invalidate(_settlementsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settlement recorded.')));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(adminErrorMessage(e, fallback: 'Couldn\'t record this settlement.'))));
          }
        }
      },
    );
  }
}
