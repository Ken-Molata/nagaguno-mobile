// lib/features/account_recovery/data/account_recovery_repository.dart
//
// Matches the real routes/accountRecovery.js exactly. Every call here
// is unauthenticated by design (the whole point of this feature is a
// user who's locked out and can't log in) -- same reasoning as
// resetPassword's own unauthenticated flow.

import 'package:dio/dio.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../../kyc/domain/kyc_models.dart';
import '../../kyc/domain/liveness_challenge.dart';
import '../domain/recovery_models.dart';

class RecoveryException implements Exception {
  RecoveryException(this.message);
  final String message;
}

class AccountRecoveryRepository {
  AccountRecoveryRepository(this._client);
  final ApiClient _client;

  /// UW 10.1's live, Admin-editable Route table -- see
  /// ApiEndpoints.recoveryIdTypes's own doc comment for why this
  /// can't reuse KycRepository.getIdTypes() (that one requires login).
  Future<List<IdTypeConfig>> getIdTypes() async {
    final response = await _client.dio.get(ApiEndpoints.recoveryIdTypes);
    return (response.data['data'] as List)
        .map((j) => IdTypeConfig.fromJson(j))
        .toList();
  }

  /// Step 1. Either ([email] or [phoneNumber]) or [dontKnowIdentifier]
  /// must be set. [password] is required unless [skipPassword] is
  /// true ("I don't remember my password"). Every mismatch (enumeration-
  /// safe by design) surfaces as the same generic [RecoveryException]
  /// message -- never which specific field was wrong.
  Future<IdentityCheckResult> verifyIdentity({
    required String fullName,
    required DateTime dateOfBirth,
    required int age,
    String? email,
    String? phoneNumber,
    bool dontKnowIdentifier = false,
    String? password,
    bool skipPassword = false,
  }) async {
    try {
      final response =
          await _client.dio.post(ApiEndpoints.recoveryVerifyIdentity, data: {
        'full_name': fullName,
        'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        'age': age,
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        'dont_know_identifier': dontKnowIdentifier,
        if (!skipPassword && password != null) 'password': password,
        'skip_password': skipPassword,
      });
      return IdentityCheckResult.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// UW 2.5 Step 2 / UW 10.2: fetched fresh at the start of each
  /// capture attempt, exactly like KycRepository.fetchLivenessChallenge
  /// -- same challenge shape, gated by the Step 1 [token] instead of
  /// an authenticated session, since this flow runs unauthenticated.
  Future<LivenessChallenge> fetchLivenessChallenge(String token) async {
    final response = await _client.dio
        .post(ApiEndpoints.recoveryLivenessChallenge, data: {'token': token});
    return LivenessChallenge.fromJson(response.data['data']);
  }

  /// Same endpoint, but for RecoveryRespondScreen's repeat_selfie ask --
  /// days after Step 1/2, whose token has long since expired
  /// (RECOVERY_TOKEN_TTL is 60m; more_info_deadline is 7 days out).
  /// Re-verifies identity the same request_number + date_of_birth way
  /// as [checkStatus]/[respond] instead.
  Future<LivenessChallenge> fetchLivenessChallengeForRespond({
    required String requestNumber,
    required DateTime dateOfBirth,
  }) async {
    final response =
        await _client.dio.post(ApiEndpoints.recoveryLivenessChallenge, data: {
      'request_number': requestNumber,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
    });
    return LivenessChallenge.fromJson(response.data['data']);
  }

  /// Step 2. [idType] must be one of KycIdType's apiValues (same ID
  /// type set as KYC, config/kycRoutes.js). Route B (manual upload)
  /// needs [idFrontPath] (+ [idBackPath] when that ID type requires a
  /// back image) plus the Screen Flash Challenge capture in
  /// [liveness] -- same contract as KycRepository.submit. Route A
  /// needs none of those -- the backend creates a Didit-hosted session
  /// instead and returns a verification_url to open.
  Future<IdCheckResult> idCheck({
    required String token,
    required String idType,
    bool differentIdType = false,
    String? idFrontPath,
    String? idBackPath,
    LivenessCaptureResult? liveness,
  }) async {
    try {
      final optedOut = liveness?.optedOut ?? false;
      final formData = FormData.fromMap({
        'token': token,
        'id_type': idType,
        'different_id_type': differentIdType.toString(),
        if (idFrontPath != null)
          'id_front': await MultipartFile.fromFile(idFrontPath),
        if (idBackPath != null)
          'id_back': await MultipartFile.fromFile(idBackPath),
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
      });
      final response =
          await _client.dio.post(ApiEndpoints.recoveryIdCheck, data: formData);
      return IdCheckResult.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Step 3 -- the only step that actually creates a recovery_requests
  /// row. [reasonCode] must be one of recoveryReasons' keys; 'other'
  /// requires [reasonOther]. [contactForUpdates] is required when the
  /// password wasn't confirmed in Step 1 (the backend has no other way
  /// to reach the requester about this request).
  Future<RecoverySubmitResult> submit({
    required String token,
    required String reasonCode,
    String? reasonOther,
    String? contactForUpdates,
  }) async {
    try {
      final response =
          await _client.dio.post(ApiEndpoints.recoverySubmit, data: {
        'token': token,
        'reason': reasonCode,
        if (reasonOther != null && reasonOther.isNotEmpty)
          'reason_other': reasonOther,
        if (contactForUpdates != null && contactForUpdates.isNotEmpty)
          'contact_for_updates': contactForUpdates,
      });
      return RecoverySubmitResult.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Answers an Admin's "Request More Information" decision
  /// (RecoveryCheckResult.moreInfoItems says which of these apply).
  /// [idFrontPath]/[idBackPath] for a retake_id_photo ask, [liveness]
  /// for a repeat_selfie ask (same contract as [idCheck]'s own, opt-out
  /// included), [contact] for a contact ask, [otherResponse] for an
  /// 'other' ask. Re-verifies identity via [requestNumber] +
  /// [dateOfBirth] -- no login, no token (the original Step 1 one is
  /// long expired by now).
  Future<void> respond({
    required String requestNumber,
    required DateTime dateOfBirth,
    String? idFrontPath,
    String? idBackPath,
    LivenessCaptureResult? liveness,
    String? contact,
    String? otherResponse,
  }) async {
    try {
      final optedOut = liveness?.optedOut ?? false;
      final formData = FormData.fromMap({
        'request_number': requestNumber,
        'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        if (idFrontPath != null)
          'id_front': await MultipartFile.fromFile(idFrontPath),
        if (idBackPath != null)
          'id_back': await MultipartFile.fromFile(idBackPath),
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
        if (contact != null) 'contact': contact,
        if (otherResponse != null) 'other': otherResponse,
      });
      await _client.dio.post(ApiEndpoints.recoveryRespond, data: formData);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<RecoveryCheckResult> checkStatus(
      {required String requestNumber, required DateTime dateOfBirth}) async {
    try {
      final response =
          await _client.dio.get(ApiEndpoints.recoveryCheck, queryParameters: {
        'request_number': requestNumber,
        'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      });
      return RecoveryCheckResult.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  RecoveryException _mapError(DioException e) {
    final message = (e.response?.data is Map
        ? e.response?.data['message']
        : null) as String?;
    return RecoveryException(
        message ?? 'Something went wrong. Please try again.');
  }
}
