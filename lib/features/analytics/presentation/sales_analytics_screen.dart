// lib/features/analytics/presentation/sales_analytics_screen.dart
//
// UW 16.1-16.6: the "Inventory & Sales" view reached from the home
// dashboard. Role scope follows the global Buyer Mode toggle (UW 1.5)
// rather than a second, separate toggle on this screen -- a plain
// Buyer account always sees purchases; a Farmer/Vendor sees their own
// sales by default, or their purchases while Buyer Mode is active
// (UW 16.5: "Vendors acting as buyers in buyer mode... are provided
// an analogous view of their own purchases, using the same control").
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../authentication/application/auth_controller.dart';
import '../../buyer_mode/application/buyer_mode_controller.dart';
import '../../authentication/domain/nagaguno_user.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
    (ref) => AnalyticsRepository(ref.watch(apiClientProvider)));

final _periodProvider =
    StateProvider.autoDispose<AnalyticsPeriod>((ref) => AnalyticsPeriod.week);
final _anchorDateProvider =
    StateProvider.autoDispose<DateTime>((ref) => DateTime.now());

/// Pure function (not a ref-based helper) so it works identically from
/// both a widget's WidgetRef and a provider's own Ref -- those are two
/// separate, unrelated interfaces in this riverpod version, neither a
/// subtype of the other.
bool resolveViewAsBuyer(
    {required NagagunoUser? user, required bool buyerModeOn}) {
  if (user == null) return false;
  if (user.isBuyer) return true;
  return (user.isFarmer || user.isVendor) && buyerModeOn;
}

final _salesAnalyticsProvider =
    FutureProvider.autoDispose<SalesAnalytics>((ref) {
  final period = ref.watch(_periodProvider);
  final date = ref.watch(_anchorDateProvider);
  final viewAsBuyer = resolveViewAsBuyer(
      user: ref.watch(authControllerProvider).user,
      buyerModeOn: ref.watch(buyerModeProvider));
  return ref
      .watch(analyticsRepositoryProvider)
      .getSalesAnalytics(period: period, date: date, viewAsBuyer: viewAsBuyer);
});

class SalesAnalyticsScreen extends ConsumerWidget {
  const SalesAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(_periodProvider);
    final anchorDate = ref.watch(_anchorDateProvider);
    final analyticsAsync = ref.watch(_salesAnalyticsProvider);
    final viewAsBuyer = resolveViewAsBuyer(
        user: ref.watch(authControllerProvider).user,
        buyerModeOn: ref.watch(buyerModeProvider));

    return Scaffold(
      appBar: AppBar(
          title: Text(viewAsBuyer ? 'My Purchases' : 'Inventory & Sales')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SegmentedButton<AnalyticsPeriod>(
                segments: const [
                  ButtonSegment(
                      value: AnalyticsPeriod.week, label: Text('Weekly')),
                  ButtonSegment(
                      value: AnalyticsPeriod.month, label: Text('Monthly')),
                ],
                selected: {period},
                onSelectionChanged: (s) =>
                    ref.read(_periodProvider.notifier).state = s.first,
              ),
            ),
            analyticsAsync.maybeWhen(
              data: (analytics) => _PeriodNavigator(
                  period: period,
                  anchorDate: anchorDate,
                  firstActivityMonth: analytics.firstActivityMonth),
              orElse: () => _PeriodNavigator(
                  period: period,
                  anchorDate: anchorDate,
                  firstActivityMonth: null),
            ),
            const Divider(height: 1),
            Expanded(
              child: analyticsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Couldn\'t load analytics.'),
                    const SizedBox(height: AppSpacing.sm),
                    ElevatedButton(
                        onPressed: () =>
                            ref.invalidate(_salesAnalyticsProvider),
                        child: const Text('Retry')),
                  ]),
                ),
                data: (analytics) {
                  if (analytics.products.isEmpty) {
                    return Center(
                      child: Text(
                        viewAsBuyer
                            ? 'No purchases in this period.'
                            : 'No sales in this period.',
                        style: AppTypography.body,
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      // UW 16.2: card styled in NagaGuno's primary brand
                      // green -- AppColors.primary is that exact token
                      // (#123D26), not a guessed/approximate color.
                      Container(
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.lg)),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm),
                              child: Row(children: [
                                Expanded(
                                    child: Text('Product',
                                        style: AppTypography.label
                                            .copyWith(color: Colors.white70))),
                                Text('Qty',
                                    style: AppTypography.label
                                        .copyWith(color: Colors.white70)),
                                const SizedBox(width: AppSpacing.md),
                                SizedBox(
                                    width: 70,
                                    child: Text(
                                        viewAsBuyer ? 'Total' : 'Earned',
                                        textAlign: TextAlign.right,
                                        style: AppTypography.label
                                            .copyWith(color: Colors.white70))),
                              ]),
                            ),
                            const Divider(height: 1, color: Colors.white24),
                            ...analytics.products.map((p) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.xs),
                                  child: Row(children: [
                                    Expanded(
                                        child: Text(p.productName,
                                            style: const TextStyle(
                                                color: Colors.white),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                    Text(p.quantity.toStringAsFixed(0),
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    const SizedBox(width: AppSpacing.md),
                                    SizedBox(
                                        width: 70,
                                        child: Text(
                                            '₱${p.subtotal.toStringAsFixed(0)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                                color: AppColors.accent,
                                                fontWeight: FontWeight.w700))),
                                  ]),
                                )),
                            const Divider(height: 1, color: Colors.white24),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm),
                              child: Row(children: [
                                Text('Total',
                                    style: AppTypography.h3
                                        .copyWith(color: Colors.white)),
                                const Spacer(),
                                Text(
                                    '₱${analytics.periodTotal.toStringAsFixed(2)}',
                                    style: AppTypography.h3
                                        .copyWith(color: AppColors.accent)),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodNavigator extends ConsumerWidget {
  const _PeriodNavigator(
      {required this.period,
      required this.anchorDate,
      required this.firstActivityMonth});
  final AnalyticsPeriod period;
  final DateTime anchorDate;
  final String? firstActivityMonth;

  DateTime get _firstActivityDate {
    if (firstActivityMonth == null) return DateTime(2020, 1, 1);
    final parts = firstActivityMonth!.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (period == AnalyticsPeriod.week) {
      final weekday = anchorDate.weekday; // 1=Mon..7=Sun
      final monday = anchorDate.subtract(Duration(days: weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final canGoEarlier = monday.isAfter(_firstActivityDate) ||
          monday.isAtSameMomentAs(_firstActivityDate);
      return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: canGoEarlier
                ? () => ref.read(_anchorDateProvider.notifier).state =
                    anchorDate.subtract(const Duration(days: 7))
                : null,
          ),
          Expanded(
            child: Text(
              '${_fmt(monday)} — ${_fmt(sunday)}',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(_anchorDateProvider.notifier).state =
                anchorDate.add(const Duration(days: 7)),
          ),
        ]),
      );
    }

    // Monthly: a month/year dropdown bounded by firstActivityMonth,
    // per UW 16.3 ("no prior option is available").
    final months = <DateTime>[];
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, 1);
    final earliest = _firstActivityDate;
    while (!cursor.isBefore(DateTime(earliest.year, earliest.month, 1))) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month - 1, 1);
    }
    final selected = DateTime(anchorDate.year, anchorDate.month, 1);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: DropdownButtonFormField<DateTime>(
        isExpanded: true,
        initialValue: months.any(
                (m) => m.year == selected.year && m.month == selected.month)
            ? selected
            : months.first,
        items: months
            .map((m) => DropdownMenuItem(
                value: m, child: Text('${_monthName(m.month)} ${m.year}')))
            .toList(),
        onChanged: (v) {
          if (v != null) ref.read(_anchorDateProvider.notifier).state = v;
        },
      ),
    );
  }

  String _fmt(DateTime d) => '${_monthName(d.month)} ${d.day}';
  String _monthName(int m) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][m - 1];
}
