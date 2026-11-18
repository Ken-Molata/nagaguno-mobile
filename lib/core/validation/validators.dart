// lib/core/validation/validators.dart
//
// Shared, public validation patterns — pulled out of register_screen.dart
// specifically so they're both reusable and independently unit-testable
// (a private, underscore-prefixed pattern defined inside a screen file
// is genuinely inaccessible from a test file in Dart, not just
// inconvenient — this is the real fix, not a test-only workaround).
// Every pattern here is verified against the exact real backend
// validation rule it corresponds to.

/// Matches middleware/auth.js's validateRegistration schema exactly:
/// 8+ chars, at least one lowercase, one uppercase, one digit, one of
/// @$!%*?&.
final RegExp registrationPasswordPattern = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&.])[A-Za-z\d@$!%*?&.]{8,}$');

/// Matches middleware/auth.js's validateRegistration schema exactly
/// for THIS endpoint specifically: exactly 11 digits, no country-code
/// prefix accepted. Deliberately different from phPhoneRegex below —
/// two different endpoints, two different real backend regexes, not
/// a shared rule.
final RegExp registrationPhonePattern = RegExp(r'^[0-9]{11}$');

/// Matches routes/kyc.js's PH_PHONE_REGEX exactly: accepts either a
/// +63 or a leading-0 prefix, then 9, then 9 more digits.
final RegExp phPhoneRegex = RegExp(r'^(\+63|0)9\d{9}$');
