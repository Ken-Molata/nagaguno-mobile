// lib/features/analytics/domain/analytics_models.dart
//
// UW 16. Fields verified against the real GET /analytics/sales and
// GET /analytics/transactions responses (routes/analytics.js).

class ProductSalesRow {
  const ProductSalesRow({
    required this.productName,
    required this.quantity,
    required this.pricePerUnit,
    required this.subtotal,
  });

  final String productName;
  final double quantity;
  final double pricePerUnit;
  final double subtotal;

  factory ProductSalesRow.fromJson(Map<String, dynamic> json) =>
      ProductSalesRow(
        productName: json['product_name'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        pricePerUnit: (json['price_per_unit'] as num).toDouble(),
        subtotal: (json['subtotal'] as num).toDouble(),
      );
}

enum AnalyticsPeriod { week, month }

class SalesAnalytics {
  const SalesAnalytics({
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.roleScope,
    required this.products,
    required this.periodTotal,
    this.firstActivityMonth,
  });

  final AnalyticsPeriod period;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String roleScope; // 'sales' | 'purchases'
  final List<ProductSalesRow> products;
  final double periodTotal;

  /// 'YYYY-MM' of the user's first confirmed transaction, or null if
  /// they have none yet -- bounds the month picker per UW 16.3 ("The
  /// earliest selectable month is the user's first month with a
  /// recorded sale; no prior option is available.").
  final String? firstActivityMonth;

  factory SalesAnalytics.fromJson(Map<String, dynamic> json) => SalesAnalytics(
        period: json['period'] == 'month'
            ? AnalyticsPeriod.month
            : AnalyticsPeriod.week,
        periodStart: DateTime.parse(json['period_start']),
        periodEnd: DateTime.parse(json['period_end']),
        roleScope: json['role_scope'] as String,
        products: (json['products'] as List)
            .map((j) => ProductSalesRow.fromJson(j))
            .toList(),
        periodTotal: (json['period_total'] as num).toDouble(),
        firstActivityMonth: json['first_activity_month'] as String?,
      );
}

class TransactionHistoryEntry {
  const TransactionHistoryEntry({
    required this.id,
    required this.source,
    required this.counterpartyName,
    required this.amount,
    required this.finalStatus,
    required this.finalizedAt,
    this.productNames,
    this.quantity,
    this.paymentMethod,
    this.paymentChannel,
    this.fulfillmentMethod,
    this.settlementStatus,
    this.settledAt,
    this.isTestSettlement = false,
  });

  final String id;
  final String source; // 'order' | 'agreement'
  final String counterpartyName;
  final String? productNames;
  final double? quantity;
  final double amount;
  final String? paymentMethod;
  final String? paymentChannel;
  final String? fulfillmentMethod;
  final String
      finalStatus; // 'fulfilled' | 'cancelled' | 'rejected' | 'expired'
  final DateTime finalizedAt;
  final String? settlementStatus; // 'settled' | 'unsettled' | null
  final DateTime? settledAt;
  final bool isTestSettlement;

  factory TransactionHistoryEntry.fromJson(Map<String, dynamic> json) =>
      TransactionHistoryEntry(
        id: json['id'] as String,
        source: json['source'] as String,
        counterpartyName: json['counterparty_name'] as String,
        productNames: json['product_names'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble(),
        amount: (json['amount'] as num).toDouble(),
        paymentMethod: json['payment_method'] as String?,
        paymentChannel: json['payment_channel'] as String?,
        fulfillmentMethod: json['fulfillment_method'] as String?,
        finalStatus: json['final_status'] as String,
        finalizedAt: DateTime.parse(json['finalized_at']),
        settlementStatus: json['settlement_status'] as String?,
        settledAt: json['settled_at'] != null
            ? DateTime.parse(json['settled_at'])
            : null,
        isTestSettlement: json['is_test_settlement'] as bool? ?? false,
      );
}

class SettlementSummary {
  const SettlementSummary(
      {required this.pendingOrderCount, required this.pendingAmount});
  final int pendingOrderCount;
  final double pendingAmount;

  factory SettlementSummary.fromJson(Map<String, dynamic> json) =>
      SettlementSummary(
        pendingOrderCount: json['pending_order_count'] as int,
        pendingAmount: (json['pending_amount'] as num).toDouble(),
      );
}

class TransactionHistoryPage {
  const TransactionHistoryPage({required this.entries, this.settlementSummary});
  final List<TransactionHistoryEntry> entries;
  final SettlementSummary? settlementSummary;
}
