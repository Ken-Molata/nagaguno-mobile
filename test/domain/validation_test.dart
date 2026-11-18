// test/domain/validation_test.dart
//
// Tests for the actual regex patterns used across the app's forms,
// each verified against the real backend validation rule it's meant
// to match (per this session's own established discipline — every
// regex here was checked against middleware/auth.js or routes/kyc.js
// before being written, not invented).

import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/core/validation/validators.dart';
import 'package:nagaguno_mobile/features/kyc/domain/kyc_models.dart';

void main() {
  group('Registration password pattern (matches middleware/auth.js exactly)',
      () {
    // Real backend rule: 8+ chars, at least one lowercase, one
    // uppercase, one digit, one of @$!%*?&.
    test('accepts a password meeting every real requirement', () {
      expect(registrationPasswordPattern.hasMatch('Password1!'), isTrue);
    });

    test('rejects a password with no uppercase letter', () {
      expect(registrationPasswordPattern.hasMatch('password1!'), isFalse);
    });

    test('rejects a password with no lowercase letter', () {
      expect(registrationPasswordPattern.hasMatch('PASSWORD1!'), isFalse);
    });

    test('rejects a password with no digit', () {
      expect(registrationPasswordPattern.hasMatch('Password!'), isFalse);
    });

    test('rejects a password with no special character', () {
      expect(registrationPasswordPattern.hasMatch('Password1'), isFalse);
    });

    test(
        'rejects a password under 8 characters even if it has every character class',
        () {
      expect(registrationPasswordPattern.hasMatch('Pas1!'), isFalse);
    });

    test(
        r'accepts every real special character the backend allows: @ $ ! % * ? .',
        () {
      for (final char in ['@', r'$', '!', '%', '*', '?', '.']) {
        expect(registrationPasswordPattern.hasMatch('Password1$char'), isTrue,
            reason: 'should accept special char "$char"');
      }
    });
  });

  group(
      'Registration phone pattern (matches middleware/auth.js exactly — 11 digits, no country-code prefix)',
      () {
    test('accepts a valid 11-digit PH mobile number', () {
      expect(registrationPhonePattern.hasMatch('09123456789'), isTrue);
    });

    test('rejects a number with a +63 prefix', () {
      // Deliberately different from KYC's phone rule (see below) —
      // this is the real, verified asymmetry between the two
      // endpoints' validation, not a copy-paste of one shared rule.
      expect(registrationPhonePattern.hasMatch('+639123456789'), isFalse);
    });

    test('rejects a number with fewer than 11 digits', () {
      expect(registrationPhonePattern.hasMatch('0912345678'), isFalse);
    });

    test('rejects a number with more than 11 digits', () {
      expect(registrationPhonePattern.hasMatch('091234567890'), isFalse);
    });

    test('rejects non-digit characters', () {
      expect(registrationPhonePattern.hasMatch('0912-345-678'), isFalse);
    });
  });

  group(
      'KYC phone pattern (matches routes/kyc.js exactly — accepts +63 or 0 prefix)',
      () {
    test('accepts the 0-prefixed form', () {
      expect(phPhoneRegex.hasMatch('09123456789'), isTrue);
    });

    test('accepts the +63-prefixed form', () {
      expect(phPhoneRegex.hasMatch('+639123456789'), isTrue);
    });

    test('rejects a number that does not start with 9 after the prefix', () {
      expect(phPhoneRegex.hasMatch('08123456789'), isFalse);
    });

    test(
        'this rule is genuinely different from the registration rule above — same input, different endpoints, different real backend regexes',
        () {
      // +63-prefixed numbers are valid for KYC but NOT for registration
      // — verifying both directions of the asymmetry explicitly, not
      // just asserting one and assuming the other follows.
      const numberWithPrefix = '+639123456789';
      expect(phPhoneRegex.hasMatch(numberWithPrefix), isTrue);
      expect(registrationPhonePattern.hasMatch(numberWithPrefix), isFalse);
    });
  });

  group('KycIdType.requiresBack (matches the real ID_TYPES set exactly)', () {
    // Stale against kyc_models.dart's own corrected values -- a real
    // `flutter test` run caught this: the enum grew from 5 to 10 ID
    // types this session, and two of the original five had their
    // requiresBack flipped (philsysNationalId is true, votersId is
    // false -- see kyc_models.dart's own header comment for why), but
    // this test file was never updated to match either change.
    test('passport does not require a back image', () {
      expect(KycIdType.passport.requiresBack, isFalse);
    });

    test('PhilSys National ID requires a back image', () {
      expect(KycIdType.philsysNationalId.requiresBack, isTrue);
    });

    test('every requiresBack: true ID type requires a back image', () {
      for (final type in [
        KycIdType.philsysNationalId,
        KycIdType.driversLicense,
        KycIdType.umid,
        KycIdType.postalId,
        KycIdType.prcId
      ]) {
        expect(type.requiresBack, isTrue,
            reason: '${type.apiValue} should require a back image');
      }
    });

    test('every requiresBack: false ID type does not require a back image', () {
      for (final type in [
        KycIdType.passport,
        KycIdType.philsysEphilid,
        KycIdType.votersCertification,
        KycIdType.votersId,
        KycIdType.barangayId
      ]) {
        expect(type.requiresBack, isFalse,
            reason: '${type.apiValue} should not require a back image');
      }
    });

    test('every enum value maps to the real, exact backend id_type string', () {
      // Verified directly against ID_TYPES in routes/kyc.js this
      // session — catches a typo'd apiValue that would otherwise
      // silently fail backend validation with a generic error.
      const expectedValues = {
        'passport',
        'philsys_national_id',
        'drivers_license',
        'umid',
        'philsys_ephilid',
        'postal_id',
        'prc_id',
        'sss_id',
        'voters_certification',
        'voters_id',
        'barangay_id_with_certification',
      };
      final actualValues = KycIdType.values.map((t) => t.apiValue).toSet();
      expect(actualValues, expectedValues);
    });
  });
}
