// lib/features/dashboard/application/greeting.dart
//
// Pure function, not a widget -- testable directly, no clock
// dependency injection needed beyond passing the DateTime in (same
// "inject rather than call DateTime.now() internally" reasoning
// already used for BlinkStateMachine's clock).
//
// Three tiers, a common convention: Morning 5:00-11:59, Afternoon
// 12:00-16:59, Evening everything else (17:00-4:59) -- late night
// stays "Good evening" rather than a jarring "Good night, {name}!"
// on a dashboard greeting.
//
// [language] defaults to 'en' so every existing call site and
// greeting_test.dart's own assertions (all written against the plain
// English strings) stay exactly as they were -- UW 21.5 translation
// support is additive here, not a breaking change to this already-
// tested pure function.
String timeBasedGreeting(DateTime now, {String language = 'en'}) {
  final hour = now.hour;
  final tl = language == 'tl';
  if (hour >= 5 && hour < 12) return tl ? 'Magandang umaga' : 'Good morning';
  if (hour >= 12 && hour < 17) return tl ? 'Magandang hapon' : 'Good afternoon';
  return tl ? 'Magandang gabi' : 'Good evening';
}
