// lib/features/analytics/presentation/transaction_history_screen.dart
//
// UW 16.7. Reachable from the home dashboard alongside "Inventory &
// Sales" (UW 16.1), not nested inside it -- a separate view over
// closed/final transactions specifically (see routes/analytics.js's
// own header comment for exactly which two sources feed it and why).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../authentication/application/auth_controller.dart';
import '../../buyer_mode/application/buyer_mode_controller.dart';
import '../../buyer_mode/presentation/widgets/buyer_mode_label.dart';
import 'sales_analytics_screen.dart'
    show analyticsRepositoryProvider, resolveViewAsBuyer;
import '../domain/analytics_models.dart';

final _dateFromProvider = StateProvider.autoDispose<DateTime?>((ref) => null);
final _dateToProvider = StateProvider.autoDispose<DateTime?>((ref) => null);
final _counterpartyFilterProvider =
    StateProvider.autoDispose<String>((ref) => '');
final _productFilterProvider = StateProvider.autoDispose<String>((ref) => '');

final _transactionHistoryProvider =
    FutureProvider.autoDispose<TransactionHistoryPage>((ref) {
  final viewAsBuyer = resolveViewAsBuyer(
      user: ref.watch(authControllerProvider).user,
      buyerModeOn: ref.watch(buyerModeProvider));
  return ref.watch(analyticsRepositoryProvider).getTransactionHistory(
        viewAsBuyer: viewAsBuyer,
        dateFrom: ref.watch(_dateFromProvider),
        dateTo: ref.watch(_dateToProvider),
        counterparty: ref.watch(_counterpartyFilterProvider),
        product: ref.watch(_productFilterProvider),
      );
});

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_transactionHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterSheet(context, ref))
        ],
      ),
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Couldn\'t load transaction history.'),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                  onPressed: () => ref.invalidate(_transactionHistoryProvider),
                  child: const Text('Retry')),
            ]),
          ),
          data: (page) {
            if (page.entries.isEmpty) {
              return const Center(child: Text('No transactions yet.'));
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (page.settlementSummary != null &&
                    page.settlementSummary!.pendingOrderCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                        color: AppColors.statusPendingBg,
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Text(
                      '₱${page.settlementSummary!.pendingAmount.toStringAsFixed(2)} pending settlement from ${page.settlementSummary!.pendingOrderCount} order${page.settlementSummary!.pendingOrderCount == 1 ? '' : 's'}.',
                      style: const TextStyle(
                          color: AppColors.statusPendingFg,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                ...page.entries.map((e) => _TransactionTile(entry: e)),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    final counterpartyController =
        TextEditingController(text: ref.read(_counterpartyFilterProvider));
    final productController =
        TextEditingController(text: ref.read(_productFilterProvider));
    DateTime? dateFrom = ref.read(_dateFromProvider);
    DateTime? dateTo = ref.read(_dateToProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom:
                AppSpacing.lg + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Filter Transactions', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.md),
              TextField(
                  controller: counterpartyController,
                  decoration:
                      const InputDecoration(labelText: 'Counterparty name')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: productController,
                  decoration: const InputDecoration(labelText: 'Product name')),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: dateFrom ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now());
                      if (picked != null) {
                        setSheetState(() => dateFrom = picked);
                      }
                    },
                    child: Text(dateFrom == null
                        ? 'From date'
                        : '${dateFrom!.year}-${dateFrom!.month.toString().padLeft(2, '0')}-${dateFrom!.day.toString().padLeft(2, '0')}'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: dateTo ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now());
                      if (picked != null) setSheetState(() => dateTo = picked);
                    },
                    child: Text(dateTo == null
                        ? 'To date'
                        : '${dateTo!.year}-${dateTo!.month.toString().padLeft(2, '0')}-${dateTo!.day.toString().padLeft(2, '0')}'),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(_counterpartyFilterProvider.notifier).state = '';
                      ref.read(_productFilterProvider.notifier).state = '';
                      ref.read(_dateFromProvider.notifier).state = null;
                      ref.read(_dateToProvider.notifier).state = null;
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(_counterpartyFilterProvider.notifier).state =
                          counterpartyController.text.trim();
                      ref.read(_productFilterProvider.notifier).state =
                          productController.text.trim();
                      ref.read(_dateFromProvider.notifier).state = dateFrom;
                      ref.read(_dateToProvider.notifier).state = dateTo;
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.entry});
  final TransactionHistoryEntry entry;

  Color _statusColor(String status) {
    switch (status) {
      case 'fulfilled':
        return AppColors.statusSuccessFg;
      case 'cancelled':
      case 'rejected':
        return AppColors.statusCancelledFg;
      case 'expired':
        return AppColors.textMuted;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authControllerProvider).user;
    final viewAsBuyer = resolveViewAsBuyer(
        user: currentUser, buyerModeOn: ref.watch(buyerModeProvider));

    return InkWell(
      onTap: () => context.push(entry.source == 'order'
          ? '/orders/${entry.id}'
          : '/agreements/${entry.id}'),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(entry.counterpartyName,
                      style: AppTypography.h3.copyWith(fontSize: 15))),
              if (viewAsBuyer &&
                  (currentUser?.isFarmer == true ||
                      currentUser?.isVendor == true)) ...[
                const BuyerModeLabel(),
                const SizedBox(width: AppSpacing.xs),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color:
                        _statusColor(entry.finalStatus).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(entry.finalStatus.toUpperCase(),
                    style: TextStyle(
                        color: _statusColor(entry.finalStatus),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'DMSans')),
              ),
            ]),
            const SizedBox(height: 4),
            if (entry.productNames != null)
              Text(entry.productNames!,
                  style: AppTypography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('₱${entry.amount.toStringAsFixed(2)}',
                style:
                    AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(_detailsLine(entry), style: AppTypography.label),
            if (entry.settlementStatus != null) ...[
              const SizedBox(height: 4),
              Text(
                entry.settlementStatus == 'settled'
                    ? '${entry.isTestSettlement ? 'Test settlement' : 'Settled'} on ${entry.settledAt!.year}-${entry.settledAt!.month.toString().padLeft(2, '0')}-${entry.settledAt!.day.toString().padLeft(2, '0')}'
                    : 'Unsettled',
                style: AppTypography.label.copyWith(
                  color: entry.settlementStatus == 'settled'
                      ? AppColors.statusSuccessFg
                      : AppColors.statusPendingFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _detailsLine(TransactionHistoryEntry e) {
    final parts = <String>[
      '${e.finalizedAt.year}-${e.finalizedAt.month.toString().padLeft(2, '0')}-${e.finalizedAt.day.toString().padLeft(2, '0')}',
    ];
    if (e.paymentMethod != null) {
      parts.add(e.paymentMethod == 'cod'
          ? 'COD'
          : (e.paymentChannel == 'manual_transfer'
              ? 'Manual Transfer'
              : 'GCash'));
    }
    if (e.fulfillmentMethod != null) {
      parts.add(e.fulfillmentMethod == 'pickup' ? 'Pickup' : 'Delivery');
    }
    return parts.join(' · ');
  }
}
