// lib/features/onboarding/data/preferences_repository.dart

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/preferences.dart';

class PreferencesRepository {
  PreferencesRepository(this._client);
  final ApiClient _client;

  Future<UserPreferences> getPreferences() async {
    final response = await _client.dio.get(ApiEndpoints.preferences);
    return UserPreferences.fromJson(response.data['data']);
  }

  /// [recommendationPriorities] is always sent as a list, even when
  /// empty -- matching recommendation_priority's real `text[]` column
  /// type (see UserPreferences's own comment on the bug this fixes).
  /// A null/omitted value previously left the OLD stored array
  /// untouched, but UW 21.4 explicitly allows "the user may clear
  /// every one," so sending `[]` must actually clear it, not be
  /// skipped like the optional string fields above it.
  Future<UserPreferences> submitPreferences({
    required List<String> selectedCategories,
    String? pricePreference,
    List<String> recommendationPriorities = const [],
  }) async {
    final response = await _client.dio.patch(ApiEndpoints.preferences, data: {
      'selected_categories': selectedCategories,
      if (pricePreference != null) 'price_preference': pricePreference,
      'recommendation_priority': recommendationPriorities,
    });
    return UserPreferences.fromJson(response.data['data']);
  }
}
