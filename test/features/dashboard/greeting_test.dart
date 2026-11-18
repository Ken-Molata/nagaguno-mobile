// test/features/dashboard/greeting_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/dashboard/application/greeting.dart';

DateTime _at(int hour) => DateTime(2026, 10, 31, hour);

void main() {
  group('timeBasedGreeting', () {
    test('early morning (5:00) is "Good morning"', () {
      expect(timeBasedGreeting(_at(5)), 'Good morning');
    });

    test('late morning (11:59) is still "Good morning"', () {
      expect(timeBasedGreeting(DateTime(2026, 10, 31, 11, 59)), 'Good morning');
    });

    test('noon (12:00) switches to "Good afternoon"', () {
      expect(timeBasedGreeting(_at(12)), 'Good afternoon');
    });

    test('late afternoon (16:59) is still "Good afternoon"', () {
      expect(
          timeBasedGreeting(DateTime(2026, 10, 31, 16, 59)), 'Good afternoon');
    });

    test('5pm (17:00) switches to "Good evening"', () {
      expect(timeBasedGreeting(_at(17)), 'Good evening');
    });

    test(
        'late night (23:00) is still "Good evening", not a jarring "Good night"',
        () {
      expect(timeBasedGreeting(_at(23)), 'Good evening');
    });

    test(
        'just before sunrise (4:59) is still "Good evening" -- the overnight tier',
        () {
      expect(timeBasedGreeting(DateTime(2026, 10, 31, 4, 59)), 'Good evening');
    });

    test('midnight (0:00) is "Good evening"', () {
      expect(timeBasedGreeting(_at(0)), 'Good evening');
    });
  });
}
