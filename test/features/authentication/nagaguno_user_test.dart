// test/features/authentication/nagaguno_user_test.dart
//
// UW 1.4/21.5 (Language) and UW 21.7 (Notification Preferences):
// NagagunoUser.fromJson's defaulting behavior for the three new
// fields, which only ever appear on the real GET /me response and are
// absent from login/register/adminLogin/googleAuth payloads.
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/authentication/domain/nagaguno_user.dart';

Map<String, dynamic> _baseJson() => {
      'id': 'user-1',
      'full_name': 'Juan Dela Cruz',
      'role': 'buyer',
      'account_status': 'active',
    };

void main() {
  group('NagagunoUser.fromJson -- language/notification defaults', () {
    test('defaults to English and both channels on when the fields are absent -- login/register response shape', () {
      final user = NagagunoUser.fromJson(_baseJson());

      expect(user.language, 'en');
      expect(user.smsDeliveryUpdates, true);
      expect(user.emailDeliveryUpdates, true);
    });

    test('reads the real saved values when present -- GET /me response shape', () {
      final user = NagagunoUser.fromJson({
        ..._baseJson(),
        'language': 'tl',
        'sms_delivery_updates': false,
        'email_delivery_updates': false,
      });

      expect(user.language, 'tl');
      expect(user.smsDeliveryUpdates, false);
      expect(user.emailDeliveryUpdates, false);
    });

    test('a null language/switch value falls back to the same default as a missing field', () {
      final user = NagagunoUser.fromJson({
        ..._baseJson(),
        'language': null,
        'sms_delivery_updates': null,
      });

      expect(user.language, 'en');
      expect(user.smsDeliveryUpdates, true);
    });
  });

  group('NagagunoUser.fromJson -- UW 21.1 verified details (dateOfBirth/age)', () {
    test('both are null when absent -- login/register response shape', () {
      final user = NagagunoUser.fromJson(_baseJson());

      expect(user.dateOfBirth, isNull);
      expect(user.age, isNull);
    });

    test('reads date_of_birth and the server-computed age from /auth/me', () {
      final user = NagagunoUser.fromJson({
        ..._baseJson(),
        'date_of_birth': '2000-05-15',
        'age': 26,
      });

      expect(user.dateOfBirth, DateTime(2000, 5, 15));
      expect(user.age, 26);
    });
  });

  group('NagagunoUser.fromJson -- UW 21.6 accessibility settings', () {
    test('defaults to standard text size and every toggle off when absent', () {
      final user = NagagunoUser.fromJson(_baseJson());

      expect(user.textSize, 'standard');
      expect(user.highContrast, false);
      expect(user.boldText, false);
      expect(user.reduceMotion, false);
    });

    test('reads the real saved values when present -- /auth/me response shape', () {
      final user = NagagunoUser.fromJson({
        ..._baseJson(),
        'text_size': 'extra_large',
        'high_contrast': true,
        'bold_text': true,
        'reduce_motion': true,
      });

      expect(user.textSize, 'extra_large');
      expect(user.highContrast, true);
      expect(user.boldText, true);
      expect(user.reduceMotion, true);
    });
  });

  group('NagagunoUser.fromJson -- UW 2.3 hasSeenWalkthrough', () {
    test('defaults to false when absent', () {
      expect(NagagunoUser.fromJson(_baseJson()).hasSeenWalkthrough, false);
    });

    test('reads true once the backend reports it -- login/register/googleAuth all now include this field', () {
      final user = NagagunoUser.fromJson({..._baseJson(), 'has_seen_walkthrough': true});
      expect(user.hasSeenWalkthrough, true);
    });
  });
}
