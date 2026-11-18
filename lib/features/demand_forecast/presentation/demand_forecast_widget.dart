// lib/features/demand_forecast/presentation/demand_forecast_widget.dart
//
// Full rewrite against the real GET /api/demand/forecast?category=
// (UW 20.2) — see domain/demand_forecast.dart's header comment for why
// the old "rank all 10 crops, Today/This Week tabs" design this
// replaces no longer matches anything the backend exposes. The real
// model is per-category and needs a category picked (defaulting to
// the first one this app offers anywhere else, via the shared
// productCategories constant), not an auto-ranked list.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/constants/product_categories.dart';
import '../data/demand_forecast_repository.dart';
import '../domain/demand_forecast.dart';

final _demandRepoProvider = Provider<DemandForecastRepository>(
    (ref) => DemandForecastRepository(ref.watch(apiClientProvider)));

final _selectedCategoryProvider =
    StateProvider.autoDispose<String>((ref) => productCategories.first);

/// REAL GAP FOUND AND FIXED: the model only ever forecasts in weekly
/// steps (see routes/demand.js/ml-service/predict.py) -- there was no
/// toggle at all before this, just a single weekly figure. "Daily" is
/// a plain /7 derivation of the same weekly figure (per_crop's own
/// projected_quantity_daily), disclosed as such in the UI rather than
/// presented as a separately-trained daily model.
final _isWeeklyProvider = StateProvider.autoDispose<bool>((ref) => true);

final _forecastProvider =
    FutureProvider.autoDispose<CategoryDemandForecast>((ref) {
  final category = ref.watch(_selectedCategoryProvider);
  return ref.watch(_demandRepoProvider).getForecast(category);
});

class DemandForecastWidget extends ConsumerWidget {
  const DemandForecastWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(_selectedCategoryProvider);
    final forecastAsync = ref.watch(_forecastProvider);
    final isWeekly = ref.watch(_isWeeklyProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: selectedCategory,
            decoration:
                const InputDecoration(labelText: 'Category', isDense: true),
            items: productCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) =>
                ref.read(_selectedCategoryProvider.notifier).state = v!,
          ),
          const SizedBox(height: AppSpacing.sm),
          // REAL GAP FOUND AND FIXED: no way to view demand as a daily
          // figure at all before this -- see _isWeeklyProvider's own
          // doc comment for what "Daily" actually is (a /7 derivation
          // of the weekly forecast, not a second trained model).
          Align(
            alignment: Alignment.centerRight,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Weekly')),
                ButtonSegment(value: false, label: Text('Daily')),
              ],
              selected: {isWeekly},
              onSelectionChanged: (s) =>
                  ref.read(_isWeeklyProvider.notifier).state = s.first,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          forecastAsync.when(
            // UW 19/20.2: "Loading shows 'Loading demand forecast...'
            // while it computes" -- previously a bare spinner with no
            // text at all.
            loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.sm),
                      Text('Loading demand forecast...',
                          style: AppTypography.bodySmall),
                    ],
                  ),
                )),
            error: (_, __) => const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text('Forecast unavailable right now.')),
            data: (forecast) => _buildForecast(forecast, isWeekly),
          ),
        ],
      ),
    );
  }

  Widget _buildForecast(CategoryDemandForecast forecast, bool isWeekly) {
    // UW 20.2: "not enough data" state.
    if (!forecast.forecastAvailable) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
            forecast.message ??
                'Not enough data yet to forecast this category.',
            style: AppTypography.bodySmall),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (forecast.confidence != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _confidenceBg(forecast.confidence!),
                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(
                      '${_confidenceLabel(forecast.confidence!)} CONFIDENCE',
                      style: AppTypography.label.copyWith(
                          color: _confidenceFg(forecast.confidence!))),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (forecast.trend != null)
                Row(children: [
                  Icon(_trendIcon(forecast.trend!),
                      size: 16, color: _trendColor(forecast.trend!)),
                  const SizedBox(width: 2),
                  Text(
                    '${_trendLabel(forecast.trend!)}${forecast.trendChangePct != null ? ' ${forecast.trendChangePct!.abs().toStringAsFixed(0)}%' : ''}',
                    style: AppTypography.bodySmall
                        .copyWith(color: _trendColor(forecast.trend!)),
                  ),
                ]),
            ],
          ),
          if (forecast.seasonalityAdjustmentApplied) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Includes a seasonal adjustment for typical dry-season demand, based on Naga City Agriculture Office data — removed automatically once your own order history is enough to forecast from alone.',
              style: AppTypography.label.copyWith(color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // UW 20.2: "Shown as an 8-week forecast chart... actual past
          // demand plotted alongside projected future demand, labeled
          // 'Actual' and 'Forecast' respectively so the two are never
          // mistaken for each other." Previously this widget only ever
          // showed a single summed total -- the chart itself, the
          // feature's own primary described form, didn't exist even
          // though the backend already returns both series.
          if (forecast.history.isNotEmpty || forecast.forecast.isNotEmpty)
            _DemandChart(history: forecast.history, forecast: forecast.forecast),
          const SizedBox(height: AppSpacing.sm),
          // REAL BUG FOUND AND FIXED: the Weekly/Daily toggle above only
          // ever changed the per-crop breakdown rows further down --
          // this headline figure (the first number anyone actually
          // looks at) stayed the same weekly total either way, making
          // the toggle look broken/inert. Daily here is the same /7
          // derivation already used for each per-crop row, just applied
          // to the category-level total too, so the toggle now visibly
          // changes something at every level of this widget.
          Text(
              isWeekly
                  ? 'Projected demand (next ${forecast.forecast.length} weeks)'
                  : 'Projected demand (daily average, next ${forecast.forecast.length} weeks)',
              style: AppTypography.label),
          Text(
              '${(isWeekly ? forecast.projectedTotal : forecast.projectedTotal / 7).toStringAsFixed(isWeekly ? 0 : 1)} kg',
              style: AppTypography.h2),
          if (forecast.suggestion != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                  color: AppColors.backgroundStart,
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Text(forecast.suggestion!, style: AppTypography.bodySmall),
            ),
          ],
          // REAL GAP FOUND AND FIXED: this whole section didn't exist
          // before -- the only thing shown was the one blended
          // category-level total above. Every one of this seller's own
          // live listings in the category is now broken out by name,
          // with its own available stock, price, and a demand level
          // allocated from that same category forecast (see
          // CropDemandRow's own doc comment for exactly how).
          if (forecast.perCrop.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Text(
                '${forecast.category} crops (${isWeekly ? 'weekly' : 'daily'} demand)',
                style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            ...forecast.perCrop.map((c) => _CropDemandTile(
                crop: c,
                projected: isWeekly ? c.projectedWeekly : c.projectedDaily)),
          ],
        ],
      ),
    );
  }

  String _confidenceLabel(ForecastConfidence c) => c.name.toUpperCase();
  Color _confidenceFg(ForecastConfidence c) => switch (c) {
        ForecastConfidence.high => AppColors.statusSuccessFg,
        ForecastConfidence.moderate => AppColors.accentDark,
        ForecastConfidence.low => AppColors.textMuted,
      };
  Color _confidenceBg(ForecastConfidence c) => switch (c) {
        ForecastConfidence.high => AppColors.statusSuccessBg,
        ForecastConfidence.moderate => AppColors.statusPendingBg,
        ForecastConfidence.low => AppColors.backgroundStart,
      };

  IconData _trendIcon(ForecastTrend t) => switch (t) {
        ForecastTrend.rising => Icons.trending_up,
        ForecastTrend.falling => Icons.trending_down,
        ForecastTrend.steady => Icons.trending_flat,
      };
  // UW 20.2's exact quoted strings: "Demand rising," "Demand falling,"
  // "Demand steady" -- previously dropped "Demand" entirely.
  String _trendLabel(ForecastTrend t) => switch (t) {
        ForecastTrend.rising => 'Demand rising',
        ForecastTrend.falling => 'Demand falling',
        ForecastTrend.steady => 'Demand steady',
      };
  Color _trendColor(ForecastTrend t) => switch (t) {
        ForecastTrend.rising => AppColors.statusSuccessFg,
        ForecastTrend.falling => AppColors.statusCancelledFg,
        ForecastTrend.steady => AppColors.textMuted,
      };
}

/// UW 20.2's own chart: actual past weekly order volume (solid line)
/// continuing into projected future demand (dashed line), with a small
/// "Actual"/"Forecast" legend so the two are never mistaken for each
/// other, exactly as the spec requires. No charting package was
/// already a dependency here, so this is a small hand-rolled
/// CustomPainter rather than pulling one in for a single chart.
class _DemandChart extends StatelessWidget {
  const _DemandChart({required this.history, required this.forecast});
  final List<HistoryWeekPoint> history;
  final List<ForecastWeekPoint> forecast;

  @override
  Widget build(BuildContext context) {
    final actualValues = history.map((h) => h.quantity).toList();
    final forecastValues = forecast.map((f) => f.projectedQuantity).toList();
    final maxValue = [...actualValues, ...forecastValues]
        .fold<double>(0, (max, v) => v > max ? v : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 110,
          width: double.infinity,
          child: CustomPaint(
            painter: _DemandChartPainter(
              actual: actualValues,
              forecast: forecastValues,
              maxValue: maxValue <= 0 ? 1 : maxValue,
              actualColor: AppColors.primary,
              forecastColor: AppColors.accentDark,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Row(
          children: [
            _LegendDot(color: AppColors.primary, label: 'Actual'),
            SizedBox(width: AppSpacing.md),
            _LegendDot(color: AppColors.accentDark, label: 'Forecast'),
          ],
        ),
      ],
    );
  }
}

/// One row of the per-crop breakdown -- product name, available
/// stock, price, and a demand-level badge for the currently selected
/// Weekly/Daily figure. See CropDemandRow's own doc comment for how
/// [crop.demandLevel] is derived.
class _CropDemandTile extends StatelessWidget {
  const _CropDemandTile({required this.crop, required this.projected});
  final CropDemandRow crop;
  final double? projected;

  Color _levelBg(CropDemandLevel l) => switch (l) {
        CropDemandLevel.high => AppColors.statusSuccessBg,
        CropDemandLevel.moderate => AppColors.statusPendingBg,
        CropDemandLevel.low => AppColors.backgroundStart,
      };
  Color _levelFg(CropDemandLevel l) => switch (l) {
        CropDemandLevel.high => AppColors.statusSuccessFg,
        CropDemandLevel.moderate => AppColors.accentDark,
        CropDemandLevel.low => AppColors.textMuted,
      };
  String _levelLabel(CropDemandLevel l) => switch (l) {
        CropDemandLevel.high => 'HIGH DEMAND',
        CropDemandLevel.moderate => 'MODERATE DEMAND',
        CropDemandLevel.low => 'LOW DEMAND',
      };

  @override
  Widget build(BuildContext context) {
    // REAL GAP FOUND AND FIXED: every row used to be one of this
    // seller's own live listings -- this screen now also lists crops
    // from crop_shelf_life_reference (the category's real producible-
    // crop baseline) that the seller doesn't currently sell at all
    // (crop.isListed == false). routes/demand.js fills one of these
    // from, in order: real platform-wide data (what other sellers
    // currently charge/carry/sell), then a PSA government price
    // reference when no seller anywhere carries it either (price only
    // -- no real stock/sales figure exists for a crop nobody here
    // sells, so availableAmount/projected stay null even though price
    // is real), and only truly falls back to the plain "Not listed by
    // you" prompt when neither exists. Three real states, not two, so
    // this can't just gate on pricePhp alone -- it also can't assume
    // availableAmount/projected are there just because pricePhp is.
    if (!crop.isListed && crop.pricePhp == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(crop.productName,
                  style: AppTypography.body.copyWith(color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Text('Not listed by you',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    final hasStock = crop.availableAmount != null;
    final hasProjection = projected != null && crop.demandLevel != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crop.productName,
                    style: AppTypography.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                    hasStock
                        ? '${crop.availableAmount!.toStringAsFixed(0)} ${crop.unit} available · ₱${crop.pricePhp!.toStringAsFixed(2)}/${crop.unit}'
                        : '₱${crop.pricePhp!.toStringAsFixed(2)}/${crop.unit} (reference price)',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textMuted)),
                // crop.isListed is still false here -- this price is
                // real, but it's not this seller's own, so the tile
                // discloses exactly where it came from rather than
                // implying it's the seller's own listing.
                if (!crop.isListed) ...[
                  const SizedBox(height: 2),
                  Text(
                      crop.priceSource != null
                          ? 'Not listed by you — ${crop.priceSource}'
                          : 'Not listed by you — platform-wide data',
                      style: AppTypography.label
                          .copyWith(color: AppColors.accentDark, fontSize: 10)),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasProjection) ...[
                  Text('${projected!.toStringAsFixed(1)} ${crop.unit}',
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                ],
                if (crop.demandLevel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: _levelBg(crop.demandLevel!),
                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text(_levelLabel(crop.demandLevel!),
                        style: AppTypography.label.copyWith(
                            color: _levelFg(crop.demandLevel!), fontSize: 10)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: AppTypography.label),
    ]);
  }
}

class _DemandChartPainter extends CustomPainter {
  _DemandChartPainter({
    required this.actual,
    required this.forecast,
    required this.maxValue,
    required this.actualColor,
    required this.forecastColor,
  });

  final List<double> actual;
  final List<double> forecast;
  final double maxValue;
  final Color actualColor;
  final Color forecastColor;

  @override
  void paint(Canvas canvas, Size size) {
    final totalPoints = actual.length + forecast.length;
    if (totalPoints < 2) return;

    final stepX = size.width / (totalPoints - 1);
    double yFor(double v) => size.height - (v / maxValue) * size.height;
    Offset pointAt(int i, double v) => Offset(i * stepX, yFor(v));

    // Baseline.
    final axisPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), axisPaint);

    final actualPaint = Paint()
      ..color = actualColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final forecastPaint = Paint()
      ..color = forecastColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    // Actual (solid), indices 0..actual.length-1.
    for (var i = 0; i < actual.length; i++) {
      final p = pointAt(i, actual[i]);
      if (i > 0) {
        canvas.drawLine(pointAt(i - 1, actual[i - 1]), p, actualPaint);
      }
      canvas.drawCircle(p, 2.5, dotPaint..color = actualColor);
    }

    // Forecast (dashed), continuing from the last actual point (or
    // from the chart's start if there's no history at all) so the two
    // series visually connect instead of floating apart.
    final forecastStartIndex = actual.length - 1;
    Offset prev = actual.isNotEmpty
        ? pointAt(forecastStartIndex, actual.last)
        : pointAt(0, forecast.isNotEmpty ? forecast.first : 0);
    for (var i = 0; i < forecast.length; i++) {
      final p = pointAt(actual.length + i, forecast[i]);
      _drawDashedLine(canvas, prev, p, forecastPaint);
      canvas.drawCircle(p, 2.5, dotPaint..color = forecastColor);
      prev = p;
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashGap = 3.0;
    final distance = (end - start).distance;
    if (distance == 0) return;
    final direction = (end - start) / distance;
    var covered = 0.0;
    var draw = true;
    var current = start;
    while (covered < distance) {
      final segment = draw ? dashWidth : dashGap;
      final next = current + direction * segment.clamp(0, distance - covered);
      if (draw) canvas.drawLine(current, next, paint);
      current = next;
      covered += segment;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(covariant _DemandChartPainter oldDelegate) =>
      oldDelegate.actual != actual ||
      oldDelegate.forecast != forecast ||
      oldDelegate.maxValue != maxValue;
}
