// lib/features/kyc/data/kyc_repository.dart
//
// Matches routes/kyc.js's POST /submit exactly: for a Route B ID
// type, id_front and liveness_photo are required, id_back required
// unless id_type has requiresBack=false, supporting_doc optional. A
// Route A ID type sends none of those -- see submit()'s own comment.

import 'package:dio/dio.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/kyc_models.dart';
import '../domain/liveness_challenge.dart';

class KycValidationException implements Exception {
  KycValidationException(this.fieldErrors, this.message);
  final Map<String, String> fieldErrors;
  final String message;
}

class KycRepository {
  KycRepository(this._client);
  final ApiClient _client;

  Future<KycSubmissionStatus> getMyStatus() async {
    final response = await _client.dio.get(ApiEndpoints.kycMe);
    return KycSubmissionStatus.fromJson(response.data['data']);
  }

  /// UW 10.1's Route table, live from the server (see IdTypeConfig's
  /// own doc comment for why this matters now that it's Admin-editable).
  Future<List<IdTypeConfig>> getIdTypes() async {
    final response = await _client.dio.get(ApiEndpoints.kycIdTypes);
    return (response.data['data'] as List)
        .map((j) => IdTypeConfig.fromJson(j))
        .toList();
  }

  /// UW 10.2: fetched fresh at the start of each capture attempt
  /// (including a "Try Again" retry), never reused.
  Future<LivenessChallenge> fetchLivenessChallenge() async {
    final response =
        await _client.dio.post(ApiEndpoints.kycLivenessChallenge);
    return LivenessChallenge.fromJson(response.data['data']);
  }

  /// Re-verified against the real POST /kyc/submit this session: Route
  /// A (idType.route == 'A' -- Passport, PhilSys National ID, Driver's
  /// License, UMID) uploads NOTHING here at all. UW 10.6's automatic
  /// scan/liveness check happens on Didit's own hosted page, which the
  /// backend returns a verification_url for instead. Only Route B
  /// (every other ID type) needs [idFrontPath] (+ [idBackPath] when
  /// that type requires one) plus the Screen Flash Challenge capture
  /// in [liveness] -- unless the user opted out of the check entirely
  /// (LivenessCaptureResult.optedOut()), which needs none of it.
  /// REAL GAP FOUND AND FIXED: this used to also require an [age]
  /// parameter, filled in by a separate manual "Age" field on the
  /// submission screen -- verified directly against routes/kyc.js's
  /// POST /submit handler that it never reads req.body.age at all; the
  /// server computes age itself from date_of_birth
  /// (`calculateAge(date_of_birth)`) and ignores whatever the client
  /// sends. UW 1's own rule ("the user's age is never typed in...
  /// calculated... not stored as a separate value") already applied to
  /// registration; this screen was the one place still asking for it
  /// redundantly, on top of a date of birth the account already has on
  /// file from registration.
  Future<KycSubmitResult> submit({
    required DateTime dateOfBirth,
    required String completeAddress,
    required String contactNumber,
    required KycIdType idType,
    String? idFrontPath,
    String? idBackPath,
    String? supportingDocPath,
    LivenessCaptureResult? liveness,
    /// UW 10.5's one carve-out: only meaningful (and only ever shown by
    /// the UI) when the Admin flagged 'account_details' for
    /// resubmission -- "the only place where an unverified user can
    /// change the name or date of birth."
    String? fullName,
    /// UW 10.5: when non-empty, only these document field(s) are
    /// actually required/sent -- everything else "remain[s] as
    /// submitted" server-side, so this client-side check (and which
    /// files actually get attached below) must narrow the same way the
    /// submission screen's own field visibility does, not require
    /// every Route B field unconditionally.
    List<String> resubmissionFields = const [],
  }) async {
    final isRouteB = idType.route == 'B';
    bool isFlagged(String field) =>
        resubmissionFields.isEmpty || resubmissionFields.contains(field);

    if (isRouteB && isFlagged('id_front') && idFrontPath == null) {
      throw KycValidationException(
          {'id_front': 'A front image of a valid ID is required.'},
          'Please provide the required documents.');
    }
    if (isRouteB &&
        idType.requiresBack &&
        isFlagged('id_back') &&
        idBackPath == null) {
      throw KycValidationException(
          {'id_back': 'A back image is required for this ID type.'},
          'Please provide the required documents.');
    }
    if (isRouteB && isFlagged('liveness') && liveness == null) {
      throw KycValidationException(
          {'liveness_photo': 'A liveness check is required.'},
          'Please provide the required documents.');
    }
    final optedOut = liveness?.optedOut ?? false;

    final formData = FormData.fromMap({
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'complete_address': completeAddress,
      'contact_number': contactNumber,
      'id_type': idType.apiValue,
      if (fullName != null) 'full_name': fullName,
      if (isRouteB) ...{
        // Each of these is only attached when actually present -- a
        // field the resubmission screen hid (not flagged) was never
        // collected, so nothing is sent for it and the backend keeps
        // whatever was already on file.
        if (idFrontPath != null)
          'id_front': await MultipartFile.fromFile(idFrontPath),
        if (idBackPath != null)
          'id_back': await MultipartFile.fromFile(idBackPath),
        if (supportingDocPath != null)
          'supporting_doc': await MultipartFile.fromFile(supportingDocPath),
        if (liveness != null) ...{
          'liveness_opted_out': optedOut.toString(),
          if (!optedOut) ...{
            'challenge_code': liveness.challengeCode!,
            'neutral_photo': await MultipartFile.fromFile(liveness.neutralPath!),
            'color_photo_1': await MultipartFile.fromFile(liveness.colorPaths[0]),
            'color_photo_2': await MultipartFile.fromFile(liveness.colorPaths[1]),
            'color_photo_3': await MultipartFile.fromFile(liveness.colorPaths[2]),
            'head_turn_skipped': liveness.headTurnSkipped.toString(),
            if (liveness.headTurnPath != null)
              'head_turn_photo': await MultipartFile.fromFile(liveness.headTurnPath!),
          },
        },
      },
    });

    try {
      final response =
          await _client.dio.post(ApiEndpoints.kycSubmit, data: formData);
      return KycSubmitResult.fromJson(response.data);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['errors'] is Map) {
        throw KycValidationException(
          Map<String, String>.from(responseData['errors']),
          responseData['message'] as String? ??
              'Please check the highlighted fields.',
        );
      }
      rethrow;
    }
  }
}
