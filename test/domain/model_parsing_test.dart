// test/domain/model_parsing_test.dart
//
// Tests the JSON-parsing enum mappings on Agreement, Order, and
// CropPlan — each uses a firstWhere(...orElse: fallback) pattern that
// silently defaults on an unrecognized backend value rather than
// throwing. That's a real, deliberate design choice worth verifying
// explicitly (a malformed/unexpected status shouldn't crash the app),
// but it also means a genuine backend typo or an added-but-unhandled
// new status value would silently masquerade as the fallback rather
// than surface as an error — these tests document that behavior
// precisely rather than leave it implicit.

import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/agreements/domain/agreement.dart';
import 'package:nagaguno_mobile/features/orders/domain/order.dart';
import 'package:nagaguno_mobile/features/crop_plans/domain/crop_plan.dart';

Map<String, dynamic> _baseAgreementJson({String? status}) => {
      'id': 'a1',
      'buyer_id': 'b1',
      'seller_id': 's1',
      'status': status,
      'product_name': 'Kamatis',
      'quantity': '10',
      'unit': 'kg',
      'price_per_unit': '25.0',
      'total_price': '250.0',
      'buyer_name': 'Juan',
      'seller_name': 'Maria',
      'seller_role': 'farmer',
      'created_at': '2026-01-01T00:00:00.000Z',
    };

Map<String, dynamic> _baseOrderJson({String? status, String? proofStatus}) => {
      'id': 'o1',
      'buyer_id': 'b1',
      'seller_id': 's1',
      'status': status,
      'proof_status': proofStatus,
      'total_amount': '100.0',
      'buyer_name': 'Juan',
      'seller_name': 'Maria',
      'seller_role': 'farmer',
      'items': [],
      'created_at': '2026-01-01T00:00:00.000Z',
    };

Map<String, dynamic> _baseCropPlanJson({String? stage}) => {
      'id': 'c1',
      'crop_name': 'Kamatis',
      'category': 'Vegetables',
      'quantity_kg': '50',
      'unit': 'kg',
      'field_location': 'North Field',
      'planting_date': '2026-01-01',
      'expected_harvest': '2026-04-01',
      'stage': stage,
    };

void main() {
  group('Agreement.fromJson — status mapping', () {
    test('maps every real backend status value correctly', () {
      expect(Agreement.fromJson(_baseAgreementJson(status: 'pending')).status,
          AgreementStatus.pending);
      expect(Agreement.fromJson(_baseAgreementJson(status: 'active')).status,
          AgreementStatus.active);
      expect(Agreement.fromJson(_baseAgreementJson(status: 'fulfilled')).status,
          AgreementStatus.fulfilled);
      expect(Agreement.fromJson(_baseAgreementJson(status: 'cancelled')).status,
          AgreementStatus.cancelled);
    });

    test(
        'an unrecognized status string silently falls back to pending, per the real firstWhere(orElse:) design',
        () {
      final a = Agreement.fromJson(
          _baseAgreementJson(status: 'some_future_status_not_yet_handled'));
      expect(a.status, AgreementStatus.pending,
          reason:
              'this documents the real fallback behavior -- not asserting it is ideal, only that it is what the code actually does');
    });

    test('a null status also falls back to pending', () {
      expect(Agreement.fromJson(_baseAgreementJson(status: null)).status,
          AgreementStatus.pending);
    });
  });

  group('Order.fromJson — proofStatus mapping', () {
    // Moved here from Agreement per agreement.dart's own header comment:
    // payment proof no longer lives on the agreement at all, it lives on
    // the order created by POST /:id/accept (agreements.order_id) --
    // this test group was still asserting against Agreement.proofStatus,
    // a field that doesn't exist any more, caught by a real `flutter
    // analyze` run. Same coverage, correct model.
    test('maps every real backend proof_status value correctly', () {
      expect(Order.fromJson(_baseOrderJson(proofStatus: 'pending')).proofStatus,
          ProofStatus.pending);
      expect(
          Order.fromJson(_baseOrderJson(proofStatus: 'verified')).proofStatus,
          ProofStatus.verified);
      expect(
          Order.fromJson(_baseOrderJson(proofStatus: 'rejected')).proofStatus,
          ProofStatus.rejected);
    });

    test('null proof_status (no proof uploaded yet) maps to none, not a crash',
        () {
      expect(Order.fromJson(_baseOrderJson(proofStatus: null)).proofStatus,
          ProofStatus.none);
    });
  });

  group('Order.fromJson — status mapping', () {
    test('maps every real backend status value correctly', () {
      for (final s in [
        'pending',
        'confirmed',
        'preparing',
        'dispatched',
        'delivered',
        'cancelled'
      ]) {
        final expected = OrderStatus.values.firstWhere((e) => e.name == s);
        expect(Order.fromJson(_baseOrderJson(status: s)).status, expected,
            reason: 'status "$s" should map to itself');
      }
    });

    test('an unrecognized status string falls back to pending', () {
      expect(Order.fromJson(_baseOrderJson(status: 'not_a_real_status')).status,
          OrderStatus.pending);
    });
  });

  group('Order.fromJson — items list edge case', () {
    test(
        'a null-object entry in the items array (a possible json_agg-over-LEFT-JOIN artifact) is filtered out, not crashed on',
        () {
      final json = _baseOrderJson(status: 'pending');
      json['items'] = [
        {
          'id': null
        }, // the exact shape json_agg can produce when an order has zero real items
      ];
      final order = Order.fromJson(json);
      expect(order.items, isEmpty,
          reason:
              'the null-id guard should filter this out rather than throw on missing required fields');
    });
  });

  group('CropPlan.fromJson — stage mapping', () {
    test('maps every real backend stage value correctly', () {
      expect(CropPlan.fromJson(_baseCropPlanJson(stage: 'planted')).stage,
          CropStage.planted);
      expect(CropPlan.fromJson(_baseCropPlanJson(stage: 'growing')).stage,
          CropStage.growing);
      expect(CropPlan.fromJson(_baseCropPlanJson(stage: 'harvesting')).stage,
          CropStage.harvesting);
      expect(CropPlan.fromJson(_baseCropPlanJson(stage: 'done')).stage,
          CropStage.done);
    });

    test('an unrecognized stage string falls back to planted', () {
      expect(CropPlan.fromJson(_baseCropPlanJson(stage: 'unknown_stage')).stage,
          CropStage.planted);
    });
  });
}
