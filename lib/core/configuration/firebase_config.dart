// lib/core/configuration/firebase_config.dart
//
// UW 15's proposed push channel (FCM). Same --dart-define mechanism
// and same "mechanism is real, values are not" discipline as
// env_config.dart's API_BASE_URL/PRIVACY_POLICY_URL -- these four
// values come from your own Firebase project's Android app config
// (Firebase Console > Project Settings > Your apps > Android app,
// package name com.nagaguno.mobile) and genuinely cannot be fabricated
// here. Passed as explicit FirebaseOptions in main.dart rather than
// via the Google Services Gradle plugin + google-services.json route
// -- see android/settings.gradle's own comment for why: it needs no
// native build file changes at all, so there's zero risk of this
// breaking the build the way an incomplete Gradle-plugin wiring could.
// Empty defaults mean Firebase.initializeApp() throws at startup,
// which main.dart catches -- the app still runs fully; only push
// notifications (never the only way a chat message is delivered --
// UW 13.1's 5-second poll always works) silently don't fire.
class FirebaseConfig {
  FirebaseConfig._();

  static const String apiKey =
      String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
  static const String appId =
      String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
  static const String messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
  static const String projectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;
}
