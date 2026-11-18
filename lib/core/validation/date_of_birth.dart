// lib/core/validation/date_of_birth.dart
//
// UW 1's date-of-birth rules: three Month/Day/Year dropdowns composed
// into one ISO date, a minimum age of 18, and two exact messages.
// Extracted out of register_screen.dart so this logic is unit-testable
// on its own rather than only reachable through a widget test.

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Mirrors controllers/authController.js's own calculateAge exactly
/// (UTC, birthday-aware) so this client-side check never disagrees
/// with the server's.
int calculateAge(DateTime birth, {DateTime? now}) {
  final today = (now ?? DateTime.now()).toUtc();
  final b = DateTime.utc(birth.year, birth.month, birth.day);
  var age = today.year - b.year;
  final hadBirthdayThisYear = today.month > b.month ||
      (today.month == b.month && today.day >= b.day);
  if (!hadBirthdayThisYear) age -= 1;
  return age;
}

/// UW 21.5: lets a caller pick a translated message instead of the
/// hardcoded English [DateOfBirthResult.errorMessage] below, without
/// changing that field's existing contract (date_of_birth_test.dart
/// asserts its exact English text).
enum DateOfBirthError { invalidDate, tooYoung }

class DateOfBirthResult {
  const DateOfBirthResult.ok(String this.isoDate)
      : errorMessage = null,
        errorCode = null;
  const DateOfBirthResult.error(String this.errorMessage, this.errorCode)
      : isoDate = null;
  final String? isoDate;
  final String? errorMessage;
  final DateOfBirthError? errorCode;
}

/// UW 1's two exact messages: "Please enter a valid date of birth."
/// (missing or impossible date) and "You must be at least 18 years
/// old to create a NagaGuno account." (a real date, just too young).
DateOfBirthResult validateDateOfBirth({
  required int? month,
  required int? day,
  required int? year,
  DateTime? now,
}) {
  if (month == null || day == null || year == null) {
    return const DateOfBirthResult.error(
        'Please enter a valid date of birth.', DateOfBirthError.invalidDate);
  }
  final birth = DateTime(year, month, day);
  // DateTime silently rolls an impossible day over (e.g. Feb 30 -> Mar
  // 2) instead of throwing -- caught here the same way the backend's
  // own Joi schema catches it, even though the Day dropdown is itself
  // kept in range of the selected month/year.
  if (birth.year != year || birth.month != month || birth.day != day) {
    return const DateOfBirthResult.error(
        'Please enter a valid date of birth.', DateOfBirthError.invalidDate);
  }
  if (calculateAge(birth, now: now) < 18) {
    return const DateOfBirthResult.error(
        'You must be at least 18 years old to create a NagaGuno account.',
        DateOfBirthError.tooYoung);
  }
  final mm = month.toString().padLeft(2, '0');
  final dd = day.toString().padLeft(2, '0');
  return DateOfBirthResult.ok('$year-$mm-$dd');
}
