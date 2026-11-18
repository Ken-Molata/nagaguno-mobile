// test/features/reports/report_models_test.dart
//
// UW 9/7.6/17.6/17.7. Mirrors routes/reports.js's own VIOLATION_TYPES
// and role-gating logic -- these tests exist to catch this client-side
// copy drifting out of sync with the real backend map it's meant to
// match exactly.
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/reports/domain/report_models.dart';

void main() {
  group('violationTypes', () {
    test('every real violation group from the backend is present', () {
      expect(
          violationTypes.keys,
          containsAll([
            ViolationGroup.transaction,
            ViolationGroup.nonArrival,
            ViolationGroup.buyerConduct,
            ViolationGroup.sellerConduct,
          ]));
    });

    test(
        'every group includes an "other" option requiring a written explanation',
        () {
      for (final types in violationTypes.values) {
        expect(types.containsKey('other'), isTrue);
      }
    });

    test('non_arrival carries UW 7.6\'s exact three named reasons plus Other',
        () {
      expect(violationTypes[ViolationGroup.nonArrival]!.keys, {
        'delivery_date_passed',
        'dispatched_but_never_arrived',
        'seller_unreachable',
        'other',
      });
    });
  });

  group('conductGroupFor', () {
    // Matches routes/reports.js's own check exactly: "buyer_conduct
    // reports can only be filed against a Buyer" / "seller_conduct...
    // only... against a Farmer or Vendor".
    test('a buyer role resolves to buyerConduct', () {
      expect(conductGroupFor('buyer'), ViolationGroup.buyerConduct);
    });

    test('a farmer role resolves to sellerConduct', () {
      expect(conductGroupFor('farmer'), ViolationGroup.sellerConduct);
    });

    test('a vendor role resolves to sellerConduct', () {
      expect(conductGroupFor('vendor'), ViolationGroup.sellerConduct);
    });
  });

  group('MyReport.fromJson', () {
    test('parses a pending report', () {
      final report = MyReport.fromJson({
        'id': 'r1',
        'violation_group': ViolationGroup.nonArrival,
        'violation_type': 'delivery_date_passed',
        'status': 'pending',
        'admin_reason': null,
        'created_at': '2026-10-15T08:00:00.000Z',
        'decided_at': null,
      });
      expect(report.status, 'pending');
      expect(report.decidedAt, isNull);
      expect(report.violationLabel,
          'Estimated delivery date has passed with no update');
    });

    test('parses a dismissed report with its admin reason', () {
      final report = MyReport.fromJson({
        'id': 'r2',
        'violation_group': ViolationGroup.transaction,
        'violation_type': 'product_quality_issue',
        'status': 'dismissed',
        'admin_reason': 'Insufficient evidence to confirm the claim',
        'created_at': '2026-10-10T00:00:00.000Z',
        'decided_at': '2026-10-12T00:00:00.000Z',
      });
      expect(report.status, 'dismissed');
      expect(report.adminReason, 'Insufficient evidence to confirm the claim');
      expect(report.decidedAt, DateTime.utc(2026, 10, 12));
    });

    test(
        'an unrecognized violation_type still parses, falling back to the raw code as its label',
        () {
      final report = MyReport.fromJson({
        'id': 'r3',
        'violation_group': 'transaction',
        'violation_type': 'some_future_type',
        'status': 'pending',
        'admin_reason': null,
        'created_at': '2026-10-15T08:00:00.000Z',
        'decided_at': null,
      });
      expect(report.violationLabel, 'some_future_type');
    });
  });
}
