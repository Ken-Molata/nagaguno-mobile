// lib/features/dashboard/presentation/home_screen.dart
//
// Farmer hierarchy matches the earlier-established canonical order
// (Greeting -> Verification banner -> Upcoming harvest -> Quick
// actions -> Orders needing attention -> Recent activity) exactly,
// not a generic dashboard layout.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/localization/app_strings.dart';
import '../../../shared/widgets/verification_banner.dart';
import '../../../shared/widgets/nagaguno_badge.dart';
import '../../authentication/application/auth_controller.dart';
import '../../buyer_mode/presentation/widgets/buyer_mode_banner.dart';
import '../../buyer_mode/presentation/widgets/buyer_mode_pill.dart';
import '../../conversations/presentation/widgets/messages_icon_button.dart';
import '../../demand_forecast/presentation/demand_forecast_widget.dart';
import '../../analytics/presentation/sales_analytics_screen.dart';
import '../../analytics/presentation/transaction_history_screen.dart';
import '../application/greeting.dart';
import '../data/dashboard_repository.dart';
import '../data/weather_repository.dart';
import '../domain/dashboard_models.dart';
import '../domain/weather_snapshot.dart';

final _dashboardRepoProvider = Provider<DashboardRepository>(
    (ref) => DashboardRepository(ref.watch(apiClientProvider)));

final _buyerDashboardProvider = FutureProvider.autoDispose<BuyerDashboard>(
    (ref) => ref.watch(_dashboardRepoProvider).getBuyerDashboard());
final _farmerDashboardProvider = FutureProvider.autoDispose<FarmerDashboard>(
    (ref) => ref.watch(_dashboardRepoProvider).getFarmerDashboard());
final _vendorDashboardProvider = FutureProvider.autoDispose<VendorDashboard>(
    (ref) => ref.watch(_dashboardRepoProvider).getVendorDashboard());

final _weatherRepoProvider =
    Provider<WeatherRepository>((ref) => WeatherRepository());
// autoDispose deliberately omitted -- this should NOT refetch every
// time the user navigates away from and back to Home within the same
// app session; a dashboard weather chip doesn't need that freshness,
// and Open-Meteo is a free public API worth being a reasonably light
// consumer of rather than re-polling on every tab switch.
final _weatherProvider = FutureProvider<WeatherSnapshot?>(
    (ref) => ref.watch(_weatherRepoProvider).getCurrentWeather());

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const SizedBox
          .shrink(); // router guard guarantees this shouldn't happen, but fail safely rather than crash
    }

    final s = ref.watch(appStringsProvider);
    final greeting = timeBasedGreeting(DateTime.now(), language: s.language);
    final weatherAsync = ref.watch(_weatherProvider);

    // Humanized-dashboard redesign, part 2: a contrast layout borrowed
    // from the "colored header + rounded white sheet draped over it"
    // pattern common to delivery-app checkouts -- NOT their color
    // palette (this stays entirely within the app's own green/gold
    // brand tokens, per explicit instruction not to use e.g. McDo's
    // red/yellow). The greeting sits directly on a solid brand-green
    // header; everything else lives on a cream "curtain" card whose
    // top corners round over that header, giving the page a second
    // visual layer instead of one flat cream field top to bottom.
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '$greeting, ${user.fullName.split(' ').first}!',
                            style: AppTypography.display.copyWith(
                                fontSize: 26, color: Colors.white)),
                        // Weather chip -- a nice-to-have, never blocking:
                        // simply absent (not an error message, not a
                        // loading spinner that lingers) if the fetch
                        // fails or hasn't resolved yet.
                        weatherAsync.maybeWhen(
                          data: (weather) => weather == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '${weather.icon} ${weather.description} · ${weather.temperatureC.round()}°C in Naga City',
                                    style: AppTypography.bodySmall.copyWith(
                                        color: Colors.white70),
                                  ),
                                ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  // REAL GAP FOUND AND FIXED: the only way to reach
                  // the conversations list (UW 13's Messenger-style
                  // thread collection) was buried in Profile -- added
                  // here too for quick access straight from Home,
                  // same unread-badge pattern CartIconButton already
                  // uses elsewhere.
                  const MessagesIconButton(color: Colors.white),
                  // Sized to roughly span the greeting block's own
                  // height (title + weather line) rather than the
                  // smaller fixed badge used elsewhere (Login/Register/
                  // Checkout headers, where it sits beside a single
                  // short line) -- vertically centered against it via
                  // the Row's own crossAxisAlignment above.
                  const NagaGunoBadge(size: 64),
                  // UW 1.5: visible only to Farmer/Vendor accounts --
                  // Buyers have nothing to switch between.
                  if (user.isFarmer || user.isVendor) ...[
                    const SizedBox(width: AppSpacing.sm),
                    BuyerModePill(
                        ownRoleLabel: user.isFarmer ? s.farmer : s.vendor),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.backgroundStart,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    topRight: Radius.circular(AppRadius.xl),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    const BuyerModeBanner(),
                    const VerificationBanner(),
                    // UW 16.1: "The home dashboard presents an
                    // 'Inventory & Sales' control... Analytics are not
                    // displayed by default; selecting the control
                    // expands the analytics view." UW 16.7's
                    // Transaction History sits "alongside" it, reached
                    // from the same row, not nested inside it.
                    //
                    // Humanized-dashboard redesign: these were the one
                    // remaining pair of bordered "bento" boxes on this
                    // screen, sitting directly above the stat cluster
                    // that already had this same treatment removed --
                    // same unbounded-tap, icon-tinted-with-the-app's-
                    // own-warm-palette language as _StatCell below,
                    // instead of a drawn outline.
                    Row(children: [
                      Expanded(
                        child: _QuickLink(
                          icon: Icons.bar_chart_outlined,
                          label: user.isBuyer
                              ? s.orderAnalytics
                              : s.inventoryAndSales,
                          color: AppColors.accentDark,
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const SalesAnalyticsScreen())),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: _QuickLink(
                          icon: Icons.receipt_long_outlined,
                          label: s.history,
                          color: AppColors.secondary,
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const TransactionHistoryScreen())),
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    if (user.isFarmer) _FarmerHome(),
                    if (user.isVendor) _VendorHome(),
                    if (user.isBuyer) _BuyerHome(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FarmerHome extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_farmerDashboardProvider);
    final s = ref.watch(appStringsProvider);
    return dashAsync.when(
      loading: () => const Center(
          child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator())),
      error: (_, __) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(s.couldntLoadDashboard)),
      data: (dash) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          // Same "Unbounded Data" treatment _StatsRow/_StatCell below
          // already establish for this screen's other stats -- no
          // bordered/colored box, plain DMSans instead of the curvy
          // Fraunces display face. This card was added separately and
          // still had the old bento-box styling the rest of this
          // screen was already redesigned away from.
          Text(s.nextHarvest, style: AppTypography.label),
          const SizedBox(height: 2),
          Text(dash.nextHarvest,
              style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentDark)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                  child: _QuickAction(
                      icon: Icons.add_circle_outline,
                      label: s.addCrop,
                      onTap: () => context.push('/crop-plans/new'))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: _QuickAction(
                      icon: Icons.add_a_photo_outlined,
                      label: s.addProduct,
                      onTap: () => context.push('/my-products'))),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (dash.incomingOrders.isNotEmpty) ...[
            Text(s.ordersNeedingAttention, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            ...dash.incomingOrders.map((o) => _MiniOrderTile(order: o)),
            const SizedBox(height: AppSpacing.md),
          ],
          _StatsRow(stats: [
            (s.activeAgreements, '${dash.activeAgreements}'),
            (s.orders, '${dash.totalOrders}'),
            (s.thisMonth, '₱${dash.thisMonth.toStringAsFixed(0)}'),
          ], onTaps: [
            () => context.push('/agreements'),
            () => context.push('/orders'),
            () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SalesAnalyticsScreen())),
          ]),
          const SizedBox(height: AppSpacing.md),
          Text(s.demandForecast, style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          const DemandForecastWidget(),
        ],
      ),
    );
  }
}

class _VendorHome extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_vendorDashboardProvider);
    final s = ref.watch(appStringsProvider);
    return dashAsync.when(
      loading: () => const Center(
          child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator())),
      error: (_, __) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(s.couldntLoadDashboard)),
      data: (dash) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          _StatsRow(stats: [
            (s.activeListings, '${dash.activeListings}'),
            (s.totalRevenue, '₱${dash.totalRevenue.toStringAsFixed(0)}'),
            (s.thisMonth, '₱${dash.thisMonth.toStringAsFixed(0)}'),
          ], onTaps: [
            () => context.push('/my-products'),
            () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SalesAnalyticsScreen())),
            () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SalesAnalyticsScreen())),
          ]),
          const SizedBox(height: AppSpacing.md),
          if (dash.recentOrders.isNotEmpty) ...[
            Text(s.recentOrders, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            ...dash.recentOrders.map((o) => _MiniOrderTile(order: o)),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(s.demandForecast, style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          const DemandForecastWidget(),
        ],
      ),
    );
  }
}

class _BuyerHome extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_buyerDashboardProvider);
    final s = ref.watch(appStringsProvider);
    return dashAsync.when(
      loading: () => const Center(
          child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator())),
      error: (_, __) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(s.couldntLoadDashboard)),
      data: (dash) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          _StatsRow(stats: [
            (s.activeAgreements, '${dash.activeAgreements}'),
            (s.totalOrders, '${dash.totalOrders}'),
            (s.savedFarmers, '${dash.savedFarmers}'),
          ], onTaps: [
            () => context.push('/agreements'),
            () => context.push('/orders'),
            null,
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/farmers/saved'),
              child: Text(s.viewSavedFarmers),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // REAL GAP FOUND AND FIXED: dash.recentAgreements was already
          // being fetched (BuyerDashboard.fromJson parses it, and
          // routes/dashboard.js's GET /buyer already returns it) but
          // never rendered anywhere on this screen -- the "Active
          // Agreements" stat above had a number with nothing backing
          // it up. Same tile treatment as Recent Orders just below.
          if (dash.recentAgreements.isNotEmpty) ...[
            Text(s.activeAgreements, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            ...dash.recentAgreements
                .map((a) => _MiniAgreementTile(agreement: a)),
            const SizedBox(height: AppSpacing.md),
          ],
          if (dash.recentOrders.isNotEmpty) ...[
            Text(s.recentOrders, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            ...dash.recentOrders.map((o) => _MiniOrderTile(order: o)),
          ],
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.label)
        ]),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
                child: Text(label,
                    style: AppTypography.button.copyWith(color: color),
                    maxLines: 2)),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, this.onTaps});
  final List<(String, String)> stats;

  /// Same length as [stats] when provided; a null entry leaves that
  /// one stat non-interactive. Previously every stat here was inert --
  /// confirmed live that a farmer had no way at all to reach the real
  /// Agreements/Orders lists from Home, this being one of the places
  /// that needed a real destination.
  final List<VoidCallback?>? onTaps;

  // Humanized-dashboard redesign, scoped deliberately to just this one
  // stat cluster (the "bento" grid of bordered boxes) and nothing else
  // on this screen or elsewhere in the app. Principles applied:
  // "Unbounded Data" -- no card/border/background tile at all, each
  // number sits directly on the page's own canvas; "Asymmetrical
  // Negative Space" -- varied gaps and a larger lead stat instead of
  // three forced-equal columns; "Contextual Grouping" -- related
  // numbers read as a group via alignment and proximity, not a drawn
  // box; "Warm... natural palette" -- reusing this app's own existing
  // warm-toned tokens (the amber accent, the sage-green secondary, the
  // soft mid-green) rather than inventing new colors that would drift
  // from the rest of the app's palette.
  static const _accents = [
    AppColors.accentDark,
    AppColors.secondary,
    AppColors.lightGreen,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0)
            SizedBox(width: i.isOdd ? AppSpacing.xl : AppSpacing.lg),
          Expanded(
            // Asymmetrical: the lead stat gets more room and a larger
            // number, rather than three identical thirds.
            flex: i == 0 ? 4 : 3,
            child: _StatCell(
              value: stats[i].$2,
              label: stats[i].$1,
              valueFontSize: i == 0 ? 30 : 23,
              color: _accents[i % _accents.length],
              onTap: onTaps != null && i < onTaps!.length ? onTaps![i] : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell(
      {required this.value,
      required this.label,
      required this.valueFontSize,
      required this.color,
      this.onTap});
  final String value;
  final String label;
  final double valueFontSize;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Plain DMSans, not the Fraunces display face used for page
        // headings elsewhere -- a dashboard stat number reads better
        // as a crisp sans figure than a curvy serif one, and this
        // keeps it visually distinct from headline text.
        Text(value,
            style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: valueFontSize,
                fontWeight: FontWeight.w800,
                color: color)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.label, maxLines: 2),
      ],
    );
    if (onTap == null) return content;
    return InkWell(borderRadius: BorderRadius.circular(AppRadius.sm), onTap: onTap, child: content);
  }
}

class _MiniOrderTile extends StatelessWidget {
  const _MiniOrderTile({required this.order});
  final OrderSummary order;
  @override
  Widget build(BuildContext context) {
    // Leads with the product (name/picture/price) rather than the
    // counterparty -- that's what a buyer or seller scanning a recent-
    // orders list actually wants to recognize at a glance; the
    // counterparty name moves to the subhead alongside the quantity,
    // same demotion the marketplace's own product cards already give
    // the seller row relative to the product name.
    // Previously inert (no onTap at all) -- a buyer or seller scanning
    // this preview had no way to actually open the order it summarizes,
    // confirmed live alongside the matching gap on _MiniAgreementTile.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('/orders/${order.id}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: order.productImageUrl != null
                      ? Image.network(order.productImageUrl!,
                          fit: BoxFit.cover)
                      : Container(
                          color: AppColors.backgroundStart,
                          child: const Icon(Icons.image_outlined,
                              size: 20, color: AppColors.textMuted)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(order.productName ?? order.counterpartyName,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                        order.itemQuantity != null
                            ? '${order.counterpartyName} · ${order.itemQuantity!.toStringAsFixed(0)} ${order.itemUnit ?? ''}'
                            : order.counterpartyName,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('₱${order.totalAmount.toStringAsFixed(0)}',
                  style:
                      AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAgreementTile extends StatelessWidget {
  const _MiniAgreementTile({required this.agreement});
  final AgreementSummary agreement;
  @override
  Widget build(BuildContext context) {
    // Same lead-with-the-product treatment as _MiniOrderTile just
    // above, for the same reason -- the one difference is the
    // subhead's quantity comes straight off the agreement row itself
    // (agreements.quantity/unit), not a joined order_items row.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('/agreements/${agreement.id}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: agreement.productImageUrl != null
                      ? Image.network(agreement.productImageUrl!,
                          fit: BoxFit.cover)
                      : Container(
                          color: AppColors.backgroundStart,
                          child: const Icon(Icons.image_outlined,
                              size: 20, color: AppColors.textMuted)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(agreement.productName,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                        agreement.quantity != null
                            ? '${agreement.sellerName} · ${agreement.quantity!.toStringAsFixed(0)} ${agreement.unit ?? ''}'
                            : agreement.sellerName,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('₱${agreement.totalPrice.toStringAsFixed(0)}',
                  style:
                      AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
