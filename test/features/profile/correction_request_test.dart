// test/features/profile/correction_request_test.dart
//
// UW 21.1 "Request a correction". MyCorrectionRequest.fromJson against
// the real routes/profileCorrections.js response shape, and
// correctionReasons matching the server's REASON_TEXT map exactly --
// same discipline as the reports feature's violationTypes copy.
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/profile/domain/correction_request.dart';

Map<String, dynamic> _baseJson({String status = 'pending'}) => {
      'id': 'req-1',
      'detail': 'full_name',
      'reason_code': 'spelling_mistake',
      'status': status,
      'created_at': '2026-10-01T00:00:00.000Z',
    };

void main() {
  group('MyCorrectionRequest.fromJson', () {
    test('parses a pending full_name request with no decision yet', () {
      final request = MyCorrectionRequest.fromJson(_baseJson());

      expect(request.id, 'req-1');
      expect(request.detail, CorrectionDetail.fullName);
      expect(request.isPending, isTrue);
      expect(request.decidedAt, isNull);
      expect(request.requestedDateOfBirth, isNull);
    });

    test('parses requested_date_of_birth and decidedAt when present', () {
      final request = MyCorrectionRequest.fromJson({
        ..._baseJson(status: 'approved'),
        'detail': 'both',
        'requested_full_name': 'Juan Dela Cruz',
        'requested_date_of_birth': '2000-05-15',
        'decided_at': '2026-10-05T00:00:00.000Z',
        'admin_notes': null,
      });

      expect(request.detail, CorrectionDetail.both);
      expect(request.requestedFullName, 'Juan Dela Cruz');
      expect(request.requestedDateOfBirth, DateTime(2000, 5, 15));
      expect(request.isPending, isFalse);
      expect(request.decidedAt, isNotNull);
    });

    test('isPending is false for both approved and rejected', () {
      expect(MyCorrectionRequest.fromJson(_baseJson(status: 'approved')).isPending,
          isFalse);
      expect(MyCorrectionRequest.fromJson(_baseJson(status: 'rejected')).isPending,
          isFalse);
    });
  });

  group('correctionReasons', () {
    test('matches the server\'s four reason codes exactly', () {
      expect(correctionReasons.keys.toSet(), {
        'spelling_mistake',
        'name_changed',
        'wrong_dob',
        'other',
      });
    });

    test('every reason has non-empty display text', () {
      for (final text in correctionReasons.values) {
        expect(text, isNotEmpty);
      }
    });
  });
}
