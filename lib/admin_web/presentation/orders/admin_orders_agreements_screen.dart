// lib/admin_web/presentation/orders/admin_orders_agreements_screen.dart
// UW 2.6 "full platform oversight": every order and agreement,
// read-only (each one's own real decision actions stay with the
// buyer/seller/the specific review queue they belong to -- this is
// the admin's cross-account visibility, not a second action surface).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;
import '../../../features/admin/domain/admin_models.dart';

final _ordersProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getAllOrders());
final _agreementsProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getAllAgreements());

class AdminOrdersAgreementsScreen extends ConsumerStatefulWidget {
  const AdminOrdersAgreementsScreen({super.key});
  @override
  ConsumerState<AdminOrdersAgreementsScreen> createState() =>
      _AdminOrdersAgreementsScreenState();
}

class _AdminOrdersAgreementsScreenState
    extends ConsumerState<AdminOrdersAgreementsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Orders & Agreements', style: AppTypography.h1),
          const SizedBox(height: AppSpacing.sm),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            tabs: const [Tab(text: 'Orders'), Tab(text: 'Agreements')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_OrdersTab(), _AgreementsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOrders = ref.watch(_ordersProvider);
    return asyncOrders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Couldn\'t load orders.')),
      data: (orders) => _Table<AdminOrderListItem>(
        items: orders,
        columns: const ['Buyer', 'Seller', 'Status', 'Total', 'Placed'],
        cells: (o) => [
          Text(o.buyerName),
          Text(o.sellerName),
          Text(o.status),
          Text('₱${o.totalAmount.toStringAsFixed(2)}'),
          Text(_fmt(o.createdAt)),
        ],
      ),
    );
  }
}

class _AgreementsTab extends ConsumerWidget {
  const _AgreementsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAgreements = ref.watch(_agreementsProvider);
    return asyncAgreements.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Couldn\'t load agreements.')),
      data: (agreements) => _Table<AdminAgreementListItem>(
        items: agreements,
        columns: const ['Buyer', 'Seller', 'Product', 'Status', 'Total', 'Placed'],
        cells: (a) => [
          Text(a.buyerName),
          Text(a.sellerName),
          Text(a.productName),
          Text(a.status),
          Text('₱${a.totalPrice.toStringAsFixed(2)}'),
          Text(_fmt(a.createdAt)),
        ],
      ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _Table<T> extends StatelessWidget {
  const _Table({required this.items, required this.columns, required this.cells});
  final List<T> items;
  final List<String> columns;
  final List<Widget> Function(T item) cells;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Nothing here yet.'));
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: columns
                    .map((c) => Expanded(child: Text(c, style: AppTypography.label)))
                    .toList(),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Row(
                    children:
                        cells(items[i]).map((w) => Expanded(child: w)).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
