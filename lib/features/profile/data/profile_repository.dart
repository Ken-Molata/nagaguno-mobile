// lib/features/profile/data/profile_repository.dart

import 'package:dio/dio.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/profile_details.dart';
import '../domain/correction_request.dart';
import '../domain/violation_indicator.dart';

class CorrectionRequestException implements Exception {
  CorrectionRequestException(this.message);
  final String message;
}

class ProfileRepository {
  ProfileRepository(this._client);
  final ApiClient _client;

  /// UW 17.3's "red indicator" -- "visible only to the account holder,
  /// on their own profile, and to Admin." Returns null only on a
  /// malformed response; a user with no violations at all still gets a
  /// real object back with indicator: null (see hasIndicator).
  Future<ViolationIndicator?> getViolationStatus() async {
    final response = await _client.dio.get(ApiEndpoints.violationStatus);
    final data = response.data['data'];
    return data == null ? null : ViolationIndicator.fromJson(data);
  }

  Future<ProfileDetails> getMyProfile() async {
    final response = await _client.dio.get(ApiEndpoints.profileMe);
    return ProfileDetails.fromJson(response.data['data']);
  }

  /// Field behavior verified against the real backend exactly: every
  /// field except [aboutMe] uses COALESCE server-side, meaning an
  /// omitted/null value here leaves the existing value UNCHANGED —
  /// there's no way to clear full_name/phone_number/barangay/
  /// farm_name/etc. to empty via this endpoint, only to update them
  /// to a new non-empty value. [aboutMe] is the one exception (a null
  /// check only, server-side), so passing an empty string for it
  /// genuinely clears it — not a bug in this client, a real asymmetry
  /// in the backend itself.
  ///
  /// Returns void, not a ProfileDetails, because the real backend's
  /// response here is only { success, message } — no data payload at
  /// all (verified directly, not assumed to match GET's shape). The
  /// caller should call getMyProfile() again afterward if it needs
  /// the fresh values displayed.
  Future<void> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? barangay,
    String? aboutMe,
    String? farmName,
    String? farmAddress,
    String? aboutFarm,
    String? businessName,
    String? businessAddress,
    String? aboutBusiness,
  }) async {
    await _client.dio.patch(ApiEndpoints.profileMe, data: {
      if (fullName != null) 'full_name': fullName,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (barangay != null) 'barangay': barangay,
      if (aboutMe != null) 'about_me': aboutMe,
      if (farmName != null) 'farm_name': farmName,
      if (farmAddress != null) 'farm_address': farmAddress,
      if (aboutFarm != null) 'about_farm': aboutFarm,
      if (businessName != null) 'business_name': businessName,
      if (businessAddress != null) 'business_address': businessAddress,
      if (aboutBusiness != null) 'about_business': aboutBusiness,
    });
  }

  Future<String> uploadPhoto(String filePath) async {
    final formData =
        FormData.fromMap({'photo': await MultipartFile.fromFile(filePath)});
    final response =
        await _client.dio.post(ApiEndpoints.profilePhoto, data: formData);
    return response.data['data']['url'] as String;
  }

  /// UW 21.1: "Remove photo" -- previously had no backend endpoint to
  /// call at all.
  Future<void> removePhoto() async {
    await _client.dio.delete(ApiEndpoints.profilePhoto);
  }

  /// UW 21.5/21.7/21.6. Returns the real backend's own success message
  /// (already phrased in the account's newly-saved language when
  /// [language] is part of this call, or naming the tier/on-off state
  /// for an accessibility field -- see routes/profile.js's own
  /// resolveAccountSettingsMessage), not a client-side guess at what
  /// to say. Only one field is ever expected to be set per call in
  /// practice -- every accessibility control "takes effect the moment
  /// it's chosen, with no separate Save step" (UW 21.6).
  Future<String> updateAccountSettings({
    String? language,
    bool? smsDeliveryUpdates,
    bool? emailDeliveryUpdates,
    String? textSize,
    bool? highContrast,
    bool? boldText,
    bool? reduceMotion,
    bool? readAloudEnabled,
    bool? easyModeEnabled,
  }) async {
    final response =
        await _client.dio.patch(ApiEndpoints.accountSettings, data: {
      if (language != null) 'language': language,
      if (smsDeliveryUpdates != null)
        'sms_delivery_updates': smsDeliveryUpdates,
      if (emailDeliveryUpdates != null)
        'email_delivery_updates': emailDeliveryUpdates,
      if (textSize != null) 'text_size': textSize,
      if (highContrast != null) 'high_contrast': highContrast,
      if (boldText != null) 'bold_text': boldText,
      if (reduceMotion != null) 'reduce_motion': reduceMotion,
      if (readAloudEnabled != null) 'read_aloud_enabled': readAloudEnabled,
      if (easyModeEnabled != null) 'easy_mode_enabled': easyModeEnabled,
    });
    return response.data['message'] as String;
  }

  /// UW 21.1. [requestedFullName]/[requestedDateOfBirth] (ISO
  /// yyyy-MM-dd) are required only for the detail(s) being corrected --
  /// the server's own validateCorrectionRequestInput enforces this the
  /// same way, this is just avoiding sending fields that don't apply.
  Future<String> submitCorrectionRequest({
    required String detail,
    required String reasonCode,
    required String documentPath,
    String? requestedFullName,
    String? requestedDateOfBirth,
    String? reasonOther,
  }) async {
    try {
      final formData = FormData.fromMap({
        'detail': detail,
        'reason_code': reasonCode,
        if (requestedFullName != null) 'requested_full_name': requestedFullName,
        if (requestedDateOfBirth != null)
          'requested_date_of_birth': requestedDateOfBirth,
        if (reasonOther != null) 'reason_other': reasonOther,
        'document': await MultipartFile.fromFile(documentPath),
      });
      final response = await _client.dio
          .post(ApiEndpoints.profileCorrections, data: formData);
      return response.data['message'] as String;
    } on DioException catch (e) {
      final message = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      throw CorrectionRequestException(
          message ?? 'Failed to submit correction request.');
    }
  }

  Future<List<MyCorrectionRequest>> getMyCorrectionRequests() async {
    final response = await _client.dio.get(ApiEndpoints.profileCorrectionsMine);
    return (response.data['data'] as List)
        .map((j) => MyCorrectionRequest.fromJson(j))
        .toList();
  }

  /// UW 2.3: marks the First-Time Walkthrough as seen. A one-way flag,
  /// never meant to be un-set by the client -- see
  /// routes/profile.js's own comment on the endpoint this calls.
  Future<void> markWalkthroughSeen() async {
    await _client.dio.post(ApiEndpoints.walkthroughSeen);
  }
}
