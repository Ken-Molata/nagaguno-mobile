// lib/core/validation/password_requirements.dart
//
// UW 1: "These are checked live as the user types, not only at
// submission. A checklist of the four requirements above is shown
// beneath the password field, each line starting with a red indicator;
// as each requirement is met, that line's indicator turns green and
// stays green even if the user keeps typing further characters, it
// only turns back to red if an edit removes what had satisfied it...
// Once all four are green, a message replaces the checklist: 'Password
// accepted.'" Reused verbatim for Forgot Password's new-password step
// (UW 2.1: "the same requirements as registration, with the same live
// red/green checklist and 'Password accepted' confirmation").
//
// UW 1's own bullet list names only four requirements (8+ characters,
// uppercase, number, special character) -- it never names lowercase as
// its own bullet. The real backend rule this must never contradict
// (registrationPasswordPattern, mirroring middleware/auth.js's
// validateRegistration regex exactly) also requires a lowercase letter.
// Showing only the spec's four named bullets would let this checklist
// say "Password accepted" for a password the backend still rejects --
// so a fifth, lowercase line is included despite not being separately
// named in the spec text, since the checklist's real job is to never
// lie about what submission will accept.

import '../localization/app_strings.dart';
import 'validators.dart';

class PasswordRequirement {
  const PasswordRequirement(this.label, this.test);
  final String label;
  final bool Function(String) test;
}

List<PasswordRequirement> passwordRequirements(AppStrings s) => [
      PasswordRequirement(s.passwordReqLength, (p) => p.length >= 8),
      PasswordRequirement(
          s.passwordReqUppercase, (p) => p.contains(RegExp(r'[A-Z]'))),
      PasswordRequirement(
          s.passwordReqLowercase, (p) => p.contains(RegExp(r'[a-z]'))),
      PasswordRequirement(s.passwordReqNumber, (p) => p.contains(RegExp(r'\d'))),
      PasswordRequirement(
          s.passwordReqSpecial, (p) => p.contains(RegExp(r'[@$!%*?&.]'))),
    ];

/// True only once every requirement is met -- equivalent to
/// [registrationPasswordPattern] matching, kept as a single source of
/// truth check here since the pattern-vs-checklist equivalence is what
/// makes the "Password accepted" message trustworthy.
bool passwordMeetsAllRequirements(String password) =>
    registrationPasswordPattern.hasMatch(password);
