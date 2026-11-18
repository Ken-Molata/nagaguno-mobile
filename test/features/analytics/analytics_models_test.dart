// test/features/analytics/analytics_models_test.dart
//
// UW 16. Model-parsing tests against real GET /analytics/sales and
// GET /analytics/transactions response shapes (routes/analytics.js),
// same discipline as test/domain/model_parsing_test.dart for the
// Agreement/Order/CropPlan models.
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/analytics/domain/analytics_models.dart';

void main() {
  group('ProductSalesRow.fromJson', () {
    test('parses a real product row exactly', () {
      final row = ProductSalesRow.fromJson({
        'product_name': 'Kamatis',
        'quantity': 12,
        'price_per_unit': 25.5,
        'subtotal': 306.0,
      });
      expect(row.productName, 'Kamatis');
      expect(row.quantity, 12.0);
      expect(row.pricePerUnit, 25.5);
      expect(row.subtotal, 306.0);
    });
  });

  group('SalesAnalytics.fromJson', () {
    Map<String, dynamic> baseJson(
            {String roleScope = 'sales',
            String? firstActivityMonth = '2026-08'}) =>
        {
          'period': 'week',
          'period_start': '2026-10-12',
          'period_end': '2026-10-18',
          'role_scope': roleScope,
          'products': [
            {
              'product_name': 'Kamatis',
              'quantity': 12,
              'price_per_unit': 25.5,
              'subtotal': 306.0
            },
            {
              'product_name': 'Sitaw',
              'quantity': 5,
              'price_per_unit': 40.0,
              'subtotal': 200.0
            },
          ],
          'period_total': 506.0,
          'first_activity_month': firstActivityMonth,
        };

    test('parses period bounds, role scope, and a ranked product list', () {
      final analytics = SalesAnalytics.fromJson(baseJson());
      expect(analytics.period, AnalyticsPeriod.week);
      expect(analytics.periodStart, DateTime(2026, 10, 12));
      expect(analytics.periodEnd, DateTime(2026, 10, 18));
      expect(analytics.roleScope, 'sales');
      expect(analytics.products, hasLength(2));
      expect(analytics.products.first.productName, 'Kamatis');
      expect(analytics.periodTotal, 506.0);
      expect(analytics.firstActivityMonth, '2026-08');
    });

    test(
        '"month" period string maps to AnalyticsPeriod.month, anything else defaults to week',
        () {
      final monthJson = {...baseJson(), 'period': 'month'};
      expect(SalesAnalytics.fromJson(monthJson).period, AnalyticsPeriod.month);
    });

    test(
        'role_scope "purchases" (UW 16.5: Buyer or Farmer/Vendor in buyer mode) parses through unchanged',
        () {
      final analytics =
          SalesAnalytics.fromJson(baseJson(roleScope: 'purchases'));
      expect(analytics.roleScope, 'purchases');
    });

    test(
        'a null first_activity_month (no transactions yet) parses to null, not a crash -- UW 16.6 empty state',
        () {
      final analytics =
          SalesAnalytics.fromJson(baseJson(firstActivityMonth: null));
      expect(analytics.firstActivityMonth, isNull);
    });

    test(
        'an empty products list (UW 16.6 empty state) parses to an empty list, not an error',
        () {
      final json = {...baseJson(), 'products': [], 'period_total': 0.0};
      final analytics = SalesAnalytics.fromJson(json);
      expect(analytics.products, isEmpty);
      expect(analytics.periodTotal, 0.0);
    });
  });

  group('TransactionHistoryEntry.fromJson', () {
    Map<String, dynamic> orderJson(
            {String? settlementStatus,
            String? settledAt,
            bool isTestSettlement = false}) =>
        {
          'id': 'o1',
          'source': 'order',
          'counterparty_name': 'Juan Dela Cruz',
          'product_names': 'Kamatis, Sitaw',
          'quantity': 7,
          'amount': 506.0,
          'payment_method': 'online',
          'payment_channel': 'gateway',
          'fulfillment_method': 'pickup',
          'final_status': 'fulfilled',
          'finalized_at': '2026-10-15T08:00:00.000Z',
          'settlement_status': settlementStatus,
          'settled_at': settledAt,
          'is_test_settlement': isTestSettlement,
        };

    test('parses a fulfilled Gateway order, unsettled', () {
      final entry = TransactionHistoryEntry.fromJson(
          orderJson(settlementStatus: 'unsettled'));
      expect(entry.source, 'order');
      expect(entry.finalStatus, 'fulfilled');
      expect(entry.paymentChannel, 'gateway');
      expect(entry.fulfillmentMethod, 'pickup');
      expect(entry.settlementStatus, 'unsettled');
      expect(entry.settledAt, isNull);
    });

    test(
        'parses a settled Gateway order with its settlement date -- UW 16.7 "Settled on [date]"',
        () {
      final entry = TransactionHistoryEntry.fromJson(orderJson(
          settlementStatus: 'settled', settledAt: '2026-10-20T00:00:00.000Z'));
      expect(entry.settlementStatus, 'settled');
      expect(entry.settledAt, DateTime.utc(2026, 10, 20));
    });

    test(
        'UW 6.4 test mode: is_test_settlement surfaces so the UI can label it "Test settlement"',
        () {
      final entry = TransactionHistoryEntry.fromJson(orderJson(
          settlementStatus: 'settled',
          settledAt: '2026-10-20T00:00:00.000Z',
          isTestSettlement: true));
      expect(entry.isTestSettlement, isTrue);
    });

    test(
        'an agreement that never became an order (Rejected/Expired/Cancelled) has no payment/fulfillment fields and no settlement status',
        () {
      final entry = TransactionHistoryEntry.fromJson({
        'id': 'a1',
        'source': 'agreement',
        'counterparty_name': 'Maria Santos',
        'product_names': 'Mangga',
        'quantity': 10,
        'amount': 500.0,
        'payment_method': null,
        'payment_channel': null,
        'fulfillment_method': null,
        'final_status': 'expired',
        'finalized_at': '2026-09-01T00:00:00.000Z',
        'settlement_status': null,
        'settled_at': null,
        'is_test_settlement': false,
      });
      expect(entry.source, 'agreement');
      expect(entry.finalStatus, 'expired');
      expect(entry.paymentMethod, isNull);
      expect(entry.settlementStatus, isNull);
    });

    test(
        'a buyer-side entry (settlement never applies to the buyer) parses with settlement_status null',
        () {
      final entry =
          TransactionHistoryEntry.fromJson(orderJson(settlementStatus: null));
      expect(entry.settlementStatus, isNull);
    });
  });

  group('SettlementSummary.fromJson', () {
    test(
        'parses the pending-settlement summary line -- UW 16.7 "[amount] pending settlement from [N] orders."',
        () {
      final summary = SettlementSummary.fromJson(
          {'pending_order_count': 3, 'pending_amount': 1250.5});
      expect(summary.pendingOrderCount, 3);
      expect(summary.pendingAmount, 1250.5);
    });
  });
}
