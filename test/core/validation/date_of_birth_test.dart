// test/core/validation/date_of_birth_test.dart
//
// Covers the pure logic register_screen.dart's three Month/Day/Year
// dropdowns depend on (UW 1) -- extracted into date_of_birth.dart
// specifically so it's unit-testable here rather than only reachable
// through a widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/core/validation/date_of_birth.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 6, 15);

  group('calculateAge', () {
    test('birthday already passed this year counts the year just turned', () {
      expect(calculateAge(DateTime.utc(2000, 1, 1), now: fixedNow), 26);
    });

    test('birthday is today counts the year just turned', () {
      expect(calculateAge(DateTime.utc(2000, 6, 15), now: fixedNow), 26);
    });

    test('birthday not yet reached this year does not count it', () {
      expect(calculateAge(DateTime.utc(2000, 12, 31), now: fixedNow), 25);
    });
  });

  group('validateDateOfBirth', () {
    test('a real date exactly 18 years old today is accepted', () {
      final result = validateDateOfBirth(
          month: 6, day: 15, year: 2008, now: fixedNow);
      expect(result.isoDate, '2008-06-15');
      expect(result.errorMessage, isNull);
    });

    test('turning 18 tomorrow is rejected -- "You must be at least 18"', () {
      final result = validateDateOfBirth(
          month: 6, day: 16, year: 2008, now: fixedNow);
      expect(result.isoDate, isNull);
      expect(result.errorMessage,
          'You must be at least 18 years old to create a NagaGuno account.');
    });

    test('a missing field is rejected -- "Please enter a valid date"', () {
      final result =
          validateDateOfBirth(month: 6, day: null, year: 2000, now: fixedNow);
      expect(result.isoDate, isNull);
      expect(result.errorMessage, 'Please enter a valid date of birth.');
    });

    test('Feb 29 on a leap year is accepted', () {
      final result = validateDateOfBirth(
          month: 2, day: 29, year: 2000, now: fixedNow);
      expect(result.isoDate, '2000-02-29');
    });

    test('Feb 30 (impossible, defensively caught) is rejected', () {
      final result = validateDateOfBirth(
          month: 2, day: 30, year: 2000, now: fixedNow);
      expect(result.isoDate, isNull);
      expect(result.errorMessage, 'Please enter a valid date of birth.');
    });

    test('composes a zero-padded ISO yyyy-MM-dd string', () {
      final result =
          validateDateOfBirth(month: 3, day: 5, year: 1990, now: fixedNow);
      expect(result.isoDate, '1990-03-05');
    });
  });

  group('daysInMonth', () {
    test('February has 29 days on a leap year', () {
      expect(daysInMonth(2000, 2), 29);
    });

    test('February has 28 days on a non-leap year', () {
      expect(daysInMonth(2001, 2), 28);
    });

    test('April has 30 days', () {
      expect(daysInMonth(2026, 4), 30);
    });
  });
}
