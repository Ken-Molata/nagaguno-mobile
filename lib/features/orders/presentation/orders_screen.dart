// lib/features/orders/presentation/orders_screen.dart
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/localization/app_strings.dart';
import '../../authentication/application/auth_controller.dart';
import '../../buyer_mode/application/buyer_mode_controller.dart';
import '../../buyer_mode/presentation/widgets/buyer_mode_label.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../data/orders_repository.dart';
import '../domain/order.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>(
    (ref) => OrdersRepository(ref.watch(apiClientProvider)));

final _statusFilterProvider = StateProvider<String>((ref) => 'all');

// Client-side, not a new backend query param -- a single user's order
// list is always a small, already-fully-fetched set (no pagination
// exists on GET /orders), so filtering what's already in memory is
// simpler and just as fast as a round trip for this screen specifically.
final _historySearchProvider = StateProvider<String>((ref) => '');

/// true = "selling/sales" direction, false = "buying/sourcing" —
/// only meaningful for farmer/vendor, who can be both. Buyers never
/// see this toggle at all (see OrdersScreen.build below).
final _sellingDirectionProvider = StateProvider<bool>((ref) => true);

final ordersListProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final status = ref.watch(_statusFilterProvider);
  final repo = ref.watch(ordersRepositoryProvider);
  final role = ref.watch(authControllerProvider).user?.role;
  final isSelling = ref.watch(_sellingDirectionProvider);

  // Re-verified against the real routes/orders.js this session: there
  // is no "role" query param at all, just the same plain view=buyer
  // convention used in recommendation.js/agreement.js. The
  // farmer_seller/farmer_buyer/vendor_seller/vendor_buyer values this
  // sent before were silently ignored by the server the whole time —
  // the Selling/Buying toggle never actually changed which orders
  // came back. A plain buyer account has no direction choice.
  final view =
      ((role == 'farmer' || role == 'vendor') && !isSelling) ? 'buyer' : null;

  return repo.getOrders(status: status, view: view);
});

const _statusFilters = [
  'all',
  'pending',
  'confirmed',
  'preparing',
  'dispatched',
  'delivered',
  'cancelled'
];

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStatus = ref.watch(_statusFilterProvider);
    final ordersAsync = ref.watch(ordersListProvider);
    final role = ref.watch(authControllerProvider).user?.role;
    final showDirectionToggle = role == 'farmer' || role == 'vendor';
    final isSelling = ref.watch(_sellingDirectionProvider);
    final searchQuery = ref.watch(_historySearchProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.ordersTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: TextField(
              onChanged: (value) =>
                  ref.read(_historySearchProvider.notifier).state = value,
              decoration: InputDecoration(
                hintText: s.searchOrderHistoryHint,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          if (showDirectionToggle)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                      value: true,
                      label:
                          Text(role == 'farmer' ? s.sellingLabel : s.salesLabel)),
                  ButtonSegment(
                      value: false,
                      label: Text(
                          role == 'farmer' ? s.buyingLabel : s.sourcingLabel)),
                ],
                selected: {isSelling},
                onSelectionChanged: (v) => ref
                    .read(_sellingDirectionProvider.notifier)
                    .state = v.first,
              ),
            ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) {
                final statusKey = _statusFilters[i];
                return ChoiceChip(
                  label: Text(statusKey == 'all'
                      ? s.allLabel
                      : s.orderStatusLabel(statusKey)),
                  selected: selectedStatus == statusKey,
                  onSelected: (_) => ref.read(_statusFilterProvider.notifier).state =
                      statusKey,
                );
              },
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              // REAL BUG FOUND AND FIXED: the actual error was discarded
              // entirely (`error: (_, __) => ...`) in favor of one
              // generic "Couldn't load your orders." regardless of
              // cause -- a real backend validation message, an expired
              // session, or just a slow connection all looked
              // identical and gave no way to tell which.
              error: (err, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(friendlyErrorMessage(err)),
                    const SizedBox(height: AppSpacing.sm),
                    ElevatedButton(
                        onPressed: () => ref.invalidate(ordersListProvider),
                        child: Text(s.retry)),
                  ],
                ),
              ),
              data: (allOrders) {
                final userId = ref.watch(authControllerProvider).user?.id;
                final query = searchQuery.trim().toLowerCase();
                final orders = query.isEmpty
                    ? allOrders
                    : allOrders
                        .where((o) =>
                            o
                                .counterpartyName(userId)
                                .toLowerCase()
                                .contains(query) ||
                            o.items.any((item) =>
                                item.productName.toLowerCase().contains(query)))
                        .toList();

                if (orders.isEmpty) {
                  // Distinguishes "genuinely no orders at all" from
                  // "no orders matching the active filter" -- these
                  // previously showed the identical generic message,
                  // which is actively misleading when a filter (e.g.
                  // "Cancelled") is active and the user does have
                  // orders, just none in that specific status.
                  final message = query.isNotEmpty
                      ? s.noOrdersMatchSearch(searchQuery)
                      : selectedStatus == 'all'
                          ? s.noOrdersYetMessage
                          : s.noOrdersWithStatus(
                              s.orderStatusLabel(selectedStatus));
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(message, textAlign: TextAlign.center),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(ordersListProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _OrderCard(order: orders[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});
  final Order order;

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return AppColors.statusPendingFg;
      case OrderStatus.confirmed:
      case OrderStatus.delivered:
        return AppColors.statusSuccessFg;
      case OrderStatus.preparing:
        return AppColors.statusPreparingFg;
      case OrderStatus.dispatched:
        return AppColors.statusDispatchedFg;
      case OrderStatus.cancelled:
        return AppColors.statusCancelledFg;
    }
  }

  Color _statusBg(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return AppColors.statusPendingBg;
      case OrderStatus.confirmed:
      case OrderStatus.delivered:
        return AppColors.statusSuccessBg;
      case OrderStatus.preparing:
        return AppColors.statusPreparingBg;
      case OrderStatus.dispatched:
        return AppColors.statusDispatchedBg;
      case OrderStatus.cancelled:
        return AppColors.statusCancelledBg;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final userId = user?.id;
    final showBuyerModeLabel = isBuyerModeRecord(
        viewerRole: user?.role, viewerId: userId, recordBuyerId: order.buyerId);
    final s = ref.watch(appStringsProvider);
    return InkWell(
      onTap: () => context.push('/orders/${order.id}'),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Row(children: [
                  Flexible(
                      child: Text(order.counterpartyName(userId),
                          style: AppTypography.h3.copyWith(fontSize: 15),
                          overflow: TextOverflow.ellipsis)),
                  if (showBuyerModeLabel) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const BuyerModeLabel(),
                  ],
                ])),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _statusBg(order.status),
                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(s.orderStatusLabel(order.status.name).toUpperCase(),
                      style: TextStyle(
                          color: _statusColor(order.status),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'DMSans')),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
                '${order.items.length} item${order.items.length == 1 ? '' : 's'} · ₱${order.totalAmount.toStringAsFixed(2)}',
                style: AppTypography.bodySmall),
            const SizedBox(height: 4),
            Text(
                '${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}-${order.createdAt.day.toString().padLeft(2, '0')}',
                style: AppTypography.label),
          ],
        ),
      ),
    );
  }
}
