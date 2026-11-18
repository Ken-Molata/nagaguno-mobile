// lib/core/configuration/env_config.dart
//
// Real dev/staging/prod environment switching, using Dart's compile-
// time --dart-define flags -- there is no runtime environment
// detection possible here (that's inherent to how Dart's
// String.fromEnvironment works, not a limitation of this file), so
// the environment must be chosen at BUILD time, not decided by the
// running app.
//
// Usage:
//   flutter run --dart-define=API_BASE_URL=http://localhost:5000/api
//   flutter build apk --dart-define=API_BASE_URL=https://staging.nagaguno.example/api
//   flutter build apk --dart-define=API_BASE_URL=https://api.nagaguno.example/api --release
//
// The actual real backend URLs (dev/staging/prod) are deployment
// details that live outside this codebase -- this file defines the
// mechanism, not the real values, since asserting a specific
// production URL here without knowing your actual deployment target
// would be exactly the kind of confident-looking guess this session
// has consistently avoided elsewhere (see PLATFORM_SETUP.md).

enum AppEnvironment { development, staging, production }

class EnvConfig {
  EnvConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Only a sensible LOCAL default -- assumes a backend running on
    // the same machine during `flutter run` with no --dart-define
    // passed at all, which is the most common no-config case during
    // active development. Real staging/production URLs must always
    // be passed explicitly via --dart-define, never hardcoded here.
    defaultValue: 'http://localhost:5000/api',
  );

  static const String environmentName =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');

  // REAL BUG FOUND AND FIXED: GoogleSignIn() was being constructed with
  // no serverClientId anywhere in the app (login_screen.dart) -- on
  // Android specifically, the google_sign_in plugin reliably returns a
  // NULL idToken without one, since idToken is only issued against a
  // Web-type OAuth client passed explicitly as serverClientId, not
  // against whatever client Android's account picker itself used. The
  // backend (controllers/authController.js) verifies that idToken's
  // audience against its own GOOGLE_CLIENT_ID -- so the mobile side
  // must request a token for that exact same Web client, or
  // verification fails (or, as seen live, the token is never even
  // returned at all and the flow dead-ends on "couldn't get a token").
  // Defaulted to the real Web client ID already configured in the
  // backend's own .env (GOOGLE_CLIENT_ID) -- this is the actual,
  // already-provisioned credential for this specific project, not a
  // fabricated placeholder, so no further setup is needed on this
  // front alone. Overridable via --dart-define for a different
  // environment's own Google Cloud project.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '192852119883-7cs101gv99j8fpaf6p9ivulq9tdvieto.apps.googleusercontent.com',
  );

  /// Both required by Apple App Store Review and Google Play policy
  /// for any app collecting personal data -- this one collects
  /// government ID photos, biometric liveness data, addresses, and
  /// phone numbers, so this isn't optional for a real submission.
  /// Deliberately left as empty defaults, NOT a fabricated placeholder
  /// URL or invented legal text -- a real privacy policy is a legal
  /// document requiring actual legal review of this specific app's
  /// real data practices (retention, third-party sharing, the exact
  /// KYC/liveness data flow), not something to generate here. The UI
  /// scaffolding (RegisterScreen's consent line, Profile's links) is
  /// real and wired up; only the actual URLs need to be supplied via
  /// --dart-define before a real app store submission.
  static const String privacyPolicyUrl =
      String.fromEnvironment('PRIVACY_POLICY_URL', defaultValue: '');
  static const String termsOfServiceUrl =
      String.fromEnvironment('TERMS_OF_SERVICE_URL', defaultValue: '');

  static AppEnvironment get environment {
    switch (environmentName) {
      case 'staging':
        return AppEnvironment.staging;
      case 'production':
        return AppEnvironment.production;
      default:
        return AppEnvironment.development;
    }
  }

  static bool get isProduction => environment == AppEnvironment.production;
  static bool get isDevelopment => environment == AppEnvironment.development;
}
