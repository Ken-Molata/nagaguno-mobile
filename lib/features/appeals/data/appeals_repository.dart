// lib/features/appeals/data/appeals_repository.dart
//
// Matches the real routes/appeals.js exactly. Which violation a
// submission actually targets is derived server-side from the
// account's current state -- the client only ever says WHICH kind of
// penalty it's appealing (target_type), never a specific violation id.

import 'package:dio/dio.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/appeal.dart';

class AppealException implements Exception {
  AppealException(this.message);
  final String message;
}

class AppealsRepository {
  AppealsRepository(this._client);
  final ApiClient _client;

  /// Either [essay] or at least one of [photoPaths] is required
  /// (matches the real backend's own rule). A 409 means a
  /// not-yet-appealed violation of this type couldn't be found --
  /// most commonly because this exact penalty was already appealed.
  Future<String> submitAppeal({
    required AppealTargetType targetType,
    String? essay,
    List<String> photoPaths = const [],
  }) async {
    if ((essay == null || essay.trim().isEmpty) && photoPaths.isEmpty) {
      throw AppealException('Provide a description and/or at least one photo.');
    }
    try {
      final formData = FormData.fromMap({
        'target_type': targetType.apiValue,
        if (essay != null && essay.trim().isNotEmpty) 'essay': essay.trim(),
        for (final path in photoPaths)
          'photos': await MultipartFile.fromFile(path),
      });
      final response =
          await _client.dio.post(ApiEndpoints.appeals, data: formData);
      return response.data['data']['id'] as String;
    } on DioException catch (e) {
      final message = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      throw AppealException(message ?? 'Failed to submit appeal.');
    }
  }

  Future<List<Appeal>> getMyAppeals() async {
    final response = await _client.dio.get(ApiEndpoints.appealsMine);
    return (response.data['data'] as List)
        .map((j) => Appeal.fromJson(j))
        .toList();
  }

  /// UW 17.5: whether pressing "Appeal This" for each target type would
  /// actually succeed right now -- false for a penalty with no active
  /// instance, or one whose active instance was already appealed.
  Future<Map<AppealTargetType, bool>> getEligibility() async {
    final response = await _client.dio.get(ApiEndpoints.appealsEligibility);
    final data = response.data['data'] as Map<String, dynamic>;
    return {
      AppealTargetType.ban: data['ban'] as bool? ?? false,
      AppealTargetType.suspension: data['suspension'] as bool? ?? false,
      AppealTargetType.codRestriction:
          data['cod_restriction'] as bool? ?? false,
    };
  }
}
