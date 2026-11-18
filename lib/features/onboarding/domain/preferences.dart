// lib/features/onboarding/domain/preferences.dart
//
// Fields verified against the real GET/PATCH /profiles/preferences
// endpoints added to the backend this session (migration 004).

class UserPreferences {
  const UserPreferences({
    required this.onboardingCompleted,
    required this.selectedCategories,
    this.pricePreference,
    this.recommendationPriorities = const [],
  });

  final bool onboardingCompleted;
  final List<String> selectedCategories;

  /// Buyer-only field — null for farmer/vendor, matching the real
  /// backend's own table structure (only buyer_profiles has these
  /// two columns, verified against migration 004).
  final String? pricePreference;

  /// UW 21.4: "Shopping preferences: Proximity, Freshness,
  /// Affordability. All optional; the user may clear every one."
  /// REAL BUG FOUND AND FIXED: this field used to be a single
  /// `String?` sent as a bare string to recommendation_priority, a
  /// live `text[]` column (confirmed via information_schema this
  /// session) -- Postgres's array_in() rejects an unbracketed string
  /// outright ("malformed array literal"), live-reproduced this
  /// session, so the real PATCH /profiles/preferences 500'd on every
  /// submission that included a priority, rolling back the whole
  /// update (selected_categories and price_preference bundled in the
  /// same single-row UPDATE). Even a successful save would never have
  /// mattered anyway: the old 5-option vocabulary ("Near me", "Lowest
  /// price", "Freshest products", "Popular products", "New listings")
  /// doesn't overlap the exact lowercase keys
  /// routes/recommendation.js's own scoring actually checks
  /// (`.includes('proximity')` etc.) -- see shoppingPreferenceOptions
  /// below, now the single source of truth for both ends.
  final List<String> recommendationPriorities;

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        onboardingCompleted: json['preference_onboarding_completed'] as bool,
        selectedCategories:
            (json['selected_categories'] as List? ?? []).cast<String>(),
        pricePreference: json['price_preference'] as String?,
        recommendationPriorities:
            (json['recommendation_priority'] as List? ?? []).cast<String>(),
      );
}

// Same category vocabulary used everywhere else in the app (products,
// crop plans, marketplace filters) -- not a second taxonomy.

const pricePreferenceOptions = ['Budget', 'Standard', 'Premium', 'Any'];

/// UW 21.4's exact three named shopping preferences. Keys match
/// routes/recommendation.js's TAGS/weighting checks verbatim
/// (`priorities.includes('proximity')` etc.) -- values are the exact
/// spec-named display labels.
const shoppingPreferenceOptions = {
  'proximity': 'Proximity',
  'freshness': 'Freshness',
  'affordability': 'Affordability',
};
