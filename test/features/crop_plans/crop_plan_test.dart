// test/features/crop_plans/crop_plan_test.dart
//
// The "remaining unlisted quantity" ledger: CropPlan.fromJson's
// parsing of remaining_quantity, the new field GET /production now
// returns (routes/cropPlans.js, mirroring routes/products.js's
// remainingPlanQuantity formula in SQL).
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/crop_plans/domain/crop_plan.dart';

Map<String, dynamic> _baseJson() => {
      'id': 'plan-1',
      'crop_name': 'Kamatis',
      'category': 'Vegetables',
      'quantity_kg': '100',
      'unit': 'kg',
      'price_per_unit': '50',
      'field_location': 'North Field',
      'planting_date': '2026-06-01',
      'expected_harvest': '2026-09-01',
      'stage': 'growing',
    };

void main() {
  group('CropPlan.fromJson -- remainingQuantity', () {
    test('is null when absent -- a raw INSERT/UPDATE RETURNING row, not the GET / list query', () {
      final plan = CropPlan.fromJson(_baseJson());
      expect(plan.remainingQuantity, isNull);
    });

    test('parses the real GET /production list query\'s remaining_quantity', () {
      final plan = CropPlan.fromJson({..._baseJson(), 'remaining_quantity': '40'});
      expect(plan.remainingQuantity, 40.0);
    });

    test('parses a fully-exhausted plan\'s remaining_quantity of 0', () {
      final plan = CropPlan.fromJson({..._baseJson(), 'remaining_quantity': '0'});
      expect(plan.remainingQuantity, 0.0);
    });
  });

  group('CropPlan.fromJson -- stage', () {
    test('falls back to planted for an unrecognized stage rather than throwing', () {
      final plan = CropPlan.fromJson({..._baseJson(), 'stage': 'bogus'});
      expect(plan.stage, CropStage.planted);
    });

    test('parses each real stage value', () {
      for (final stage in CropStage.values) {
        final plan = CropPlan.fromJson({..._baseJson(), 'stage': stage.name});
        expect(plan.stage, stage);
      }
    });
  });
}
