// test/core/redacting_log_interceptor_test.dart
//
// Real tests for the redaction logic specifically -- this is
// security-relevant (the original spec explicitly required never
// logging passwords/tokens/KYC data), so it gets the same test
// discipline as everything else, not just "it compiles."

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/core/networking/redacting_log_interceptor.dart';

void main() {
  group('redactSensitiveData — plain maps', () {
    test('redacts a password field', () {
      final result =
          redactSensitiveData({'email': 'a@b.com', 'password': 'Secret123!'});
      expect(result['password'], '<redacted>');
      expect(result['email'], 'a@b.com',
          reason: 'non-sensitive fields should pass through unchanged');
    });

    test('redacts every real sensitive field this app actually sends', () {
      final input = {
        'access_token': 'abc',
        'refresh_token': 'def',
        'otp': '123456',
        'age': 25,
        'date_of_birth': '2000-01-01',
        'complete_address': '123 Main St',
        'contact_number': '09123456789',
      };
      final result = redactSensitiveData(input);
      for (final key in input.keys) {
        expect(result[key], '<redacted>', reason: '"$key" should be redacted');
      }
    });

    test('redaction is case-insensitive on key names', () {
      final result =
          redactSensitiveData({'PASSWORD': 'x', 'Access_Token': 'y'});
      expect(result['PASSWORD'], '<redacted>');
      expect(result['Access_Token'], '<redacted>');
    });

    test('redacts nested maps recursively', () {
      final result = redactSensitiveData({
        'data': {
          'user': {'password': 'x'}
        }
      });
      expect(result['data']['user']['password'], '<redacted>');
    });

    test('redacts sensitive values inside a list of maps', () {
      final result = redactSensitiveData([
        {'password': 'a'},
        {'password': 'b'},
        {'email': 'c'}
      ]);
      expect(result[0]['password'], '<redacted>');
      expect(result[1]['password'], '<redacted>');
      expect(result[2]['email'], 'c');
    });

    test('a non-map, non-list, non-FormData value passes through unchanged',
        () {
      expect(redactSensitiveData('plain string'), 'plain string');
      expect(redactSensitiveData(42), 42);
      expect(redactSensitiveData(null), null);
    });
  });

  group('redactSensitiveData — FormData (multipart uploads)', () {
    test('redacts sensitive text fields within FormData', () async {
      final formData = FormData.fromMap({
        'age': '25',
        'complete_address': '123 Main St',
        'id_type': 'passport', // not sensitive -- should pass through
      });
      final result = redactSensitiveData(formData);
      expect(result['fields']['age'], '<redacted>');
      expect(result['fields']['complete_address'], '<redacted>');
      expect(result['fields']['id_type'], 'passport');
    });

    test('lists file field names without exposing file content', () async {
      // A minimal in-memory "file" is enough here -- this test only
      // verifies the file's FIELD NAME appears, and that no file
      // bytes/content ever reach the output, not the specifics of
      // MultipartFile construction itself.
      final formData = FormData.fromMap({
        'photo': MultipartFile.fromBytes([1, 2, 3], filename: 'test.jpg'),
      });
      final result = redactSensitiveData(formData);
      expect(result['files (name only)'], contains('photo'));
      // The critical property: nothing in the output is the raw byte
      // list [1, 2, 3] or any string derived from it.
      expect(result.toString().contains('1, 2, 3'), isFalse);
    });
  });
}
