// lib/features/analytics/data/analytics_repository.dart
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/analytics_models.dart';

class AnalyticsRepository {
  AnalyticsRepository(this._client);
  final ApiClient _client;

  Future<SalesAnalytics> getSalesAnalytics({
    required AnalyticsPeriod period,
    required DateTime date,
    bool viewAsBuyer = false,
  }) async {
    final response =
        await _client.dio.get(ApiEndpoints.analyticsSales, queryParameters: {
      'period': period == AnalyticsPeriod.month ? 'month' : 'week',
      'date': date.toIso8601String().substring(0, 10),
      if (viewAsBuyer) 'view': 'buyer',
    });
    return SalesAnalytics.fromJson(response.data['data']);
  }

  Future<TransactionHistoryPage> getTransactionHistory({
    bool viewAsBuyer = false,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? counterparty,
    String? product,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.dio
        .get(ApiEndpoints.analyticsTransactions, queryParameters: {
      if (viewAsBuyer) 'view': 'buyer',
      if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
      if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
      if (counterparty != null && counterparty.isNotEmpty)
        'counterparty': counterparty,
      if (product != null && product.isNotEmpty) 'product': product,
      'limit': limit,
      'offset': offset,
    });
    final entries = (response.data['data'] as List)
        .map((j) => TransactionHistoryEntry.fromJson(j))
        .toList();
    final summaryJson = response.data['settlement_summary'];
    return TransactionHistoryPage(
      entries: entries,
      settlementSummary:
          summaryJson != null ? SettlementSummary.fromJson(summaryJson) : null,
    );
  }
}
