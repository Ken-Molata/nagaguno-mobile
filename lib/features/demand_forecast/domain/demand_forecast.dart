// lib/features/demand_forecast/domain/demand_forecast.dart
//
// Full rewrite against the real GET /api/demand/forecast?category=
// (routes/demand.js), replacing a model that no longer exists on the
// backend at all. The old CropDemandForecast (crop_name/date/
// predicted_demand_kg/predicted_price_php/demand_level, ranking all 10
// crops via POST /demand/predict/batch against a synthetic-CSV-trained
// Flask model) matched a contract the backend's own header comment
// says was deliberately replaced: "the same synthetic-CSV-trained
// model the handover's own honesty rules warn about... do not repeat
// it." The real model is per-category (one of this session's own
// productCategories), computed from THIS seller's own real order
// history, not a ranked list across crops.

enum ForecastTrend { rising, falling, steady }

enum ForecastConfidence { high, moderate, low }

class ForecastWeekPoint {
  const ForecastWeekPoint(
      {required this.week, required this.projectedQuantity});
  final int week;
  final double projectedQuantity;

  factory ForecastWeekPoint.fromJson(Map<String, dynamic> json) =>
      ForecastWeekPoint(
        week: json['week'] as int,
        projectedQuantity:
            double.tryParse(json['projected_quantity'].toString()) ?? 0,
      );
}

class HistoryWeekPoint {
  const HistoryWeekPoint({required this.weekStart, required this.quantity});
  final DateTime weekStart;
  final double quantity;

  factory HistoryWeekPoint.fromJson(Map<String, dynamic> json) =>
      HistoryWeekPoint(
        weekStart: DateTime.parse(json['week_start']),
        quantity: double.tryParse(json['quantity'].toString()) ?? 0,
      );
}

enum CropDemandLevel { high, moderate, low }

/// REAL GAP FOUND AND FIXED: the model (and this whole feature) only
/// ever forecast at the CATEGORY level, pooled across every one of a
/// seller's own listings in it -- this screen showed one blended
/// number for, say, "Vegetables" as a whole, with no way to see which
/// specific crop/product that implies more or less demand for.
/// per_crop (routes/demand.js's own buildPerCropBreakdown) allocates
/// that one real forecast across the seller's own live products in
/// the category, proportional to each product's historical share of
/// this seller's order volume -- a disclosed allocation heuristic,
/// not a second trained model (see that function's own header for
/// exactly what it is and isn't).
class CropDemandRow {
  const CropDemandRow({
    required this.productId,
    required this.productName,
    required this.pricePhp,
    required this.unit,
    required this.availableAmount,
    required this.projectedWeekly,
    required this.projectedDaily,
    required this.demandLevel,
    required this.isListed,
    this.priceSource,
    this.recommendedPricePhp,
    this.demandBasis,
  });

  final String? productId;
  final String productName;
  final double? pricePhp;
  // Disclosed provenance for pricePhp on an unlisted (isListed == false)
  // row -- either real platform-wide data from other sellers, or a PSA
  // government reference figure (routes/demand.js's crop_price_reference
  // fallback). Null for a listed row, since that price is just the
  // seller's own real listing -- nothing to disclose.
  final String? priceSource;
  final String? unit;
  final double? availableAmount;
  final double? projectedWeekly;
  final double? projectedDaily;
  final CropDemandLevel? demandLevel;

  /// Disclosed provenance for [projectedWeekly]/[projectedDaily] on an
  /// unlisted row -- either real platform-wide sales data from other
  /// sellers, or (by explicit product decision, not a default) an even
  /// split of this seller's own category-level forecast across every
  /// reference crop with no real per-crop sales data anywhere. Null for
  /// a listed row (that figure is this seller's own real allocation,
  /// nothing to disclose) and for an unlisted row from before this was
  /// added.
  final String? demandBasis;

  /// True only for the disclosed category-level split estimate, never
  /// for a real platform-wide figure -- see [demandBasis]'s own
  /// wording (the backend controls both ends of this string).
  bool get isEstimatedDemand => demandBasis?.startsWith('Estimated') ?? false;

  /// A disclosed RULE-BASED nudge off [demandLevel] (+10% High, -10%
  /// Low, unchanged Moderate) -- not a trained price prediction. There
  /// is no real historical price-vs-demand dataset to fit one on (see
  /// routes/demand.js's own comment on why crop_price_reference stays
  /// narrow rather than a fitted curve). Null for an unlisted row --
  /// nothing for this seller to actually reprice.
  final double? recommendedPricePhp;

  /// REAL GAP FOUND AND FIXED: this row used to only ever exist for
  /// one of the seller's own live listings. It now also covers every
  /// crop in crop_shelf_life_reference (routes/products.js -- the
  /// real per-crop baseline already used to set a new listing's own
  /// shelf life) for this category that the seller doesn't currently
  /// list, so they can see which producible crops they're not
  /// offering at all -- [isListed] is false for those, and every
  /// price/stock/demand field above is null rather than a fabricated
  /// number, since there's no real order history for a crop this
  /// seller has never sold.
  final bool isListed;

  static CropDemandLevel? _levelFrom(String? s) => switch (s) {
        'High' => CropDemandLevel.high,
        'Moderate' => CropDemandLevel.moderate,
        'Low' => CropDemandLevel.low,
        _ => null,
      };

  factory CropDemandRow.fromJson(Map<String, dynamic> json) => CropDemandRow(
        productId: json['product_id'] as String?,
        productName: json['product_name'] as String,
        pricePhp: json['price_php'] != null
            ? double.tryParse(json['price_php'].toString())
            : null,
        priceSource: json['price_source'] as String?,
        unit: json['unit'] as String?,
        availableAmount: json['available_amount'] != null
            ? double.tryParse(json['available_amount'].toString())
            : null,
        isListed: json['is_listed'] as bool? ?? true,
        projectedWeekly: json['projected_quantity_weekly'] != null
            ? double.tryParse(json['projected_quantity_weekly'].toString())
            : null,
        projectedDaily: json['projected_quantity_daily'] != null
            ? double.tryParse(json['projected_quantity_daily'].toString())
            : null,
        demandLevel: _levelFrom(json['demand_level'] as String?),
        recommendedPricePhp: json['recommended_price_php'] != null
            ? double.tryParse(json['recommended_price_php'].toString())
            : null,
        demandBasis: json['demand_basis'] as String?,
      );
}

class CategoryDemandForecast {
  const CategoryDemandForecast({
    required this.category,
    required this.forecastAvailable,
    this.message,
    this.confidence,
    this.trend,
    this.trendChangePct,
    this.history = const [],
    this.forecast = const [],
    this.suggestion,
    this.seasonalityAdjustmentApplied = false,
    this.seasonalitySource,
    this.perCrop = const [],
  });

  final String category;

  /// UW 20.2's "not enough data" state — when false, only [message] is set.
  final bool forecastAvailable;
  final String? message;
  final ForecastConfidence? confidence;
  final ForecastTrend? trend;
  final double? trendChangePct;
  final List<HistoryWeekPoint> history;
  final List<ForecastWeekPoint> forecast;
  final String? suggestion;

  /// True only when the real model's own confidence for this category is
  /// "Low" AND the external CAgO seasonality prior (ml-service/
  /// seasonality_prior.py) actually covers this category -- see that
  /// file's header for exactly what it is and isn't. Disclosed here
  /// rather than left as an invisible adjustment baked into [forecast]'s
  /// numbers, since real transaction data always wins once there's
  /// enough of it (this flips back to false on its own as confidence
  /// rises past "Low").
  final bool seasonalityAdjustmentApplied;
  final String? seasonalitySource;

  /// Per-product breakdown within this category -- see CropDemandRow's
  /// own header comment. Empty when the seller has no live listings in
  /// this category yet, same as an empty category view elsewhere.
  final List<CropDemandRow> perCrop;

  double get projectedTotal =>
      forecast.fold(0, (sum, f) => sum + f.projectedQuantity);

  static ForecastConfidence? _confidenceFrom(String? s) => switch (s) {
        'High' => ForecastConfidence.high,
        'Moderate' => ForecastConfidence.moderate,
        'Low' => ForecastConfidence.low,
        _ => null,
      };

  static ForecastTrend? _trendFrom(String? s) => switch (s) {
        'rising' => ForecastTrend.rising,
        'falling' => ForecastTrend.falling,
        'steady' => ForecastTrend.steady,
        _ => null,
      };

  factory CategoryDemandForecast.fromJson(Map<String, dynamic> json) =>
      CategoryDemandForecast(
        category: json['category'] as String,
        forecastAvailable: json['forecast_available'] as bool,
        message: json['message'] as String?,
        confidence: _confidenceFrom(json['confidence'] as String?),
        trend: _trendFrom(json['trend'] as String?),
        trendChangePct: json['trend_change_pct'] != null
            ? double.tryParse(json['trend_change_pct'].toString())
            : null,
        history: (json['history'] as List? ?? [])
            .map((h) => HistoryWeekPoint.fromJson(h))
            .toList(),
        forecast: (json['forecast'] as List? ?? [])
            .map((f) => ForecastWeekPoint.fromJson(f))
            .toList(),
        suggestion: json['suggestion'] as String?,
        seasonalityAdjustmentApplied:
            json['seasonality_adjustment_applied'] as bool? ?? false,
        seasonalitySource: json['seasonality_source'] as String?,
        perCrop: (json['per_crop'] as List? ?? [])
            .map((c) => CropDemandRow.fromJson(c))
            .toList(),
      );
}
