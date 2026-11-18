// lib/features/authentication/data/auth_repository.dart
//
// Request/response shapes verified directly against the real backend
// (controllers/authController.js + middleware/auth.js's Joi validation
// schemas) this session.

import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../domain/nagaguno_user.dart';
import '../domain/device.dart';

class AuthResult {
  AuthResult({required this.user, required this.message});
  final NagagunoUser user;
  final String message;
}

class AuthException implements Exception {
  AuthException(this.message, {this.fieldErrors});
  final String message;

  /// Field-level validation errors, matching the real backend's Joi
  /// error shape (e.g. { "email": "must be a valid email" }).
  final Map<String, String>? fieldErrors;
}

/// POST /auth/verify-email/resend's response. [demoOtpCode] is only
/// present when the backend's OTP_DEMO_FALLBACK is active and real
/// email delivery failed (Resend's sandbox restriction, live-confirmed
/// this session) -- the code is otherwise never sent back to a client.
class EmailOtpSendResult {
  EmailOtpSendResult({required this.message, this.demoOtpCode});
  final String message;
  final String? demoOtpCode;
}

/// POST /auth/forgot-password's response. [demoOtpCode] is only present
/// when OTP_DEMO_FALLBACK is active and real delivery failed -- same
/// contract as [EmailOtpSendResult].
class ForgotPasswordResult {
  ForgotPasswordResult({required this.userId, this.demoOtpCode});
  final String? userId;
  final String? demoOtpCode;
}

/// Thrown specifically when a Google sign-in attempt (with no role
/// provided) turns out to be for a genuinely new account -- the real
/// backend requires a role in that case, verified against
/// controllers/authController.js this session.
class GoogleAuthNeedsRoleException implements Exception {}

/// Thrown by [AuthRepository.login] when the account has 2FA on (UW
/// 2.2): the real backend returns {requires2FA: true, userId} instead
/// of tokens at this point -- no tokens exist yet. The caller must
/// collect the OTP sent to the account's phone and call
/// [AuthRepository.verifyLogin2FA] with [userId] to actually finish
/// logging in. Before this, login() had no handling for this response
/// shape at all and would throw a raw type-cast error trying to read
/// a non-existent access_token.
class TwoFactorRequiredException implements Exception {
  TwoFactorRequiredException(this.userId);
  final String userId;
}

class AuthRepository {
  AuthRepository(this._client);
  final ApiClient _client;

  /// [dateOfBirth] is an ISO `yyyy-MM-dd` string, composed client-side
  /// from the three Month/Day/Year dropdowns UW 1 specifies --
  /// REAL, SEVERE BUG FOUND AND FIXED this pass: this parameter (and
  /// the whole date-of-birth UI it depends on) didn't exist at all,
  /// despite middleware/auth.js's validateRegistration Joi schema
  /// requiring `date_of_birth` on every POST /auth/register with no
  /// default -- meaning every registration attempt through this app
  /// was rejected outright with "Please enter a valid date of birth."
  /// This was the single most basic flow in the entire app and had
  /// never actually been exercised through the real screen; every
  /// account used for testing elsewhere this session came from direct
  /// SQL seed data instead.
  ///
  /// Returns the real backend's own message, NOT an [AuthResult] --
  /// REAL, SEVERE BUG FOUND AND FIXED, compounding the one above: this
  /// used to call [_handleAuthSuccess], which force-casts
  /// `data['access_token'] as String`. The real POST /auth/register
  /// response (verified directly against controllers/authController.js)
  /// has no access_token/refresh_token at all -- only
  /// `data: { user: {...} } }` -- by design (its own comment: "the
  /// client logs in afterward," since UW 1.3's literal "an unverified
  /// account cannot log in" was deliberately not implemented that way).
  /// That cast would have thrown "type 'Null' is not a subtype of type
  /// 'String'" on every single successful registration, meaning
  /// registration was still completely broken even with the date-of-
  /// birth fix in place. AuthController.register() now logs in
  /// immediately afterward with the same credentials to actually
  /// establish a session, matching that design comment literally.
  /// REAL GAP FOUND AND FIXED: [email] used to be required here,
  /// matching the real backend's Joi validator at the time -- but that
  /// validator itself was out of step with this file's own earlier
  /// comment ("email and phone_number are both nullable since the
  /// backend allows registering with either one, not both") and with
  /// register()'s own `auth_provider: email ? 'email' : 'phone'` logic,
  /// which already assumed a phone-only signup was possible. The
  /// backend validator now actually allows it (requires at least one
  /// of email/phone_number, not email specifically) -- the caller
  /// (register_screen.dart's channel toggle) supplies whichever one the
  /// user chose to register with.
  Future<String> register({
    required String fullName,
    required String password,
    required String role, // 'buyer' | 'farmer' | 'vendor'
    required String dateOfBirth,
    String? email,
    String? phoneNumber,
    String? barangay,
  }) async {
    try {
      final response = await _client.dio.post(ApiEndpoints.register, data: {
        'full_name': fullName,
        'password': password,
        'role': role,
        'date_of_birth': dateOfBirth,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
        if (barangay != null && barangay.isNotEmpty) 'barangay': barangay,
      });
      return response.data['message'] as String? ?? 'Account created.';
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// UW 1.3. Authenticated (POST /auth/verify-email) -- "login no
  /// longer blocks on email verification," per authController.js's own
  /// comment, so this is reached from within the app, not a pre-login
  /// step. Returns the real backend's own message ("Email verified!").
  Future<String> verifyEmail({required String otp}) async {
    try {
      final response =
          await _client.dio.post(ApiEndpoints.verifyEmail, data: {'otp': otp});
      return response.data['message'] as String;
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<EmailOtpSendResult> resendEmailVerification() async {
    try {
      final response = await _client.dio.post(ApiEndpoints.verifyEmailResend);
      return EmailOtpSendResult(
        // NOTE: unlike /auth/register (which nests demo_otp_code under
        // `data`), this endpoint's controller puts it top-level on the
        // response body alongside `message` -- verified directly
        // against authController.js's resendEmailVerification.
        message: response.data['message'] as String,
        demoOtpCode: response.data['demo_otp_code'] as String?,
      );
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Phone-channel counterpart of resendEmailVerification above, for a
  /// phone-registered account -- same response shape (message +
  /// top-level demo_otp_code when the backend's SMS demo fallback is
  /// active), verified directly against authController.js's
  /// requestPhoneVerification.
  Future<EmailOtpSendResult> requestPhoneVerification() async {
    try {
      final response = await _client.dio.post(ApiEndpoints.verifyPhoneRequest);
      return EmailOtpSendResult(
        message: response.data['message'] as String,
        demoOtpCode: response.data['demo_otp_code'] as String?,
      );
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Phone-channel counterpart of verifyEmail above.
  Future<String> confirmPhoneVerification({required String otp}) async {
    try {
      final response = await _client.dio
          .post(ApiEndpoints.verifyPhoneConfirm, data: {'otp': otp});
      return response.data['message'] as String;
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Throws [TwoFactorRequiredException] rather than returning
  /// anything when the account has 2FA on -- there are no tokens to
  /// return yet at that point.
  Future<AuthResult> login(
      {String? email, String? phoneNumber, required String password}) async {
    try {
      final response = await _client.dio.post(ApiEndpoints.login, data: {
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        'password': password,
      });
      if (response.data['data']?['requires2FA'] == true) {
        throw TwoFactorRequiredException(
            response.data['data']['userId'] as String);
      }
      return _handleAuthSuccess(response);
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// UW 2.6: "Admin accounts sign in on the NagaGuno website" -- a
  /// deliberately separate endpoint from [login], which itself
  /// rejects an admin account outright (controllers/authController.js's
  /// login() has its own explicit admin-rejection branch). Only ever
  /// called from the web admin app's own login screen, never the
  /// consumer app. No 2FA branch -- the real POST /auth/admin/login
  /// has none.
  Future<AuthResult> adminLogin(
      {required String email, required String password}) async {
    try {
      final response = await _client.dio.post(ApiEndpoints.adminLogin, data: {
        'email': email,
        'password': password,
      });
      return _handleAuthSuccess(response);
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<AuthResult> verifyLogin2FA(
      {required String userId, required String otp}) async {
    try {
      final response =
          await _client.dio.post(ApiEndpoints.loginVerify2FA, data: {
        'userId': userId,
        'otp': otp,
      });
      return _handleAuthSuccess(response);
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> resendLogin2FA({required String userId}) async {
    try {
      await _client.dio
          .post(ApiEndpoints.loginResend2FA, data: {'userId': userId});
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// [role] should be omitted on the first attempt -- the real
  /// backend only requires it for a genuinely new account (a
  /// business rule beyond what its own Joi schema captures, which
  /// marks role as optional at the validation layer). An existing
  /// Google-linked account ignores role entirely. Throws
  /// GoogleAuthNeedsRoleException specifically when the backend's
  /// real "Invalid role selection." rejection fires, so the caller
  /// can prompt for a role and retry with it included.
  Future<AuthResult> googleAuth({required String idToken, String? role}) async {
    try {
      final response = await _client.dio.post(ApiEndpoints.googleAuth, data: {
        'id_token': idToken,
        if (role != null) 'role': role,
      });
      return _handleAuthSuccess(response);
    } on DioException catch (e) {
      final message = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      if (role == null && message == 'Invalid role selection.') {
        throw GoogleAuthNeedsRoleException();
      }
      throw _mapAuthError(e);
    }
  }

  Future<NagagunoUser> getMe() async {
    final response = await _client.dio.get(ApiEndpoints.me);
    // Real backend wraps this as { data: { user: {...} } }, one level
    // deeper than login/register's { data: { user, access_token,
    // refresh_token } } — same key name, same nesting depth actually,
    // this was genuinely just missed on first pass, not a differently-
    // shaped endpoint. Verified directly against authController.js's
    // exports.getMe this session.
    return NagagunoUser.fromJson(response.data['data']['user']);
  }

  Future<void> logout() async {
    try {
      await _client.dio.post(ApiEndpoints.logout);
    } finally {
      // Clear local state regardless of whether the server call
      // succeeded — a failed logout request shouldn't leave the user
      // stuck unable to sign out on their own device.
      AuthTokenHolder.instance.clear();
      await SecureStorage.instance.clearRefreshToken();
      // Real gap this session: a user who signed in via Google had
      // no way to actually clear that cached Google session on
      // logout -- GoogleSignIn caches the last account, and without
      // this, tapping "Sign in with Google" again would silently
      // re-authenticate the same account with no picker shown,
      // rather than let them confirm or switch accounts. Wrapped in
      // its own try/catch: a user who never signed in via Google at
      // all shouldn't have their logout fail because of this.
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
  }

  /// Returns null if no data.user_id came back — this happens by
  /// design on the real backend's anti-enumeration path (verified
  /// against controllers/authController.js this session: the "account
  /// not found" branch returns the exact same generic success message
  /// but with NO data field at all, specifically so this response
  /// can't be used to probe which emails/numbers are registered). The
  /// UI must show the same generic message either way, and simply
  /// can't proceed to the reset-code screen when this is null, since
  /// there's no real account to reset.
  /// [channel] is 'email' or 'phone' -- UW 2.1: "The user is then asked
  /// to choose how to receive the OTP, from two options, always both
  /// offered regardless of which identifier they entered." REAL GAP
  /// FOUND AND FIXED: the real backend has always accepted this
  /// (controllers/authController.js's own `sendVia = channel || ...`
  /// fallback), but nothing on this client ever sent it, so the
  /// channel was silently whatever field happened to be typed as the
  /// identifier -- never an independent choice. Also what "Try another
  /// way" resends with: the same [email]/[phoneNumber] identifier,
  /// just a different [channel], which re-looks-up the same account
  /// without asking the user to re-enter anything (ForgotPasswordScreen
  /// stays alive underneath ResetPasswordScreen on the nav stack for
  /// exactly this).
  // REAL BUG FOUND AND FIXED: this never wrapped its DioException in
  // _mapAuthError like every other call here does, so the real
  // backend message -- the OTP cooldown's exact wait-time text, and
  // now the send-failure message added alongside requestEmailChange's
  // own fix -- never reached the caller. ForgotPasswordScreen's bare
  // `catch (_)` then had nothing to show but a generic "Something went
  // wrong," confirmed live: a genuine 502 send failure surfaced as
  // that generic text instead of the real "We couldn't send your
  // reset code" message the server actually returned.
  //
  // REAL BUG FOUND AND FIXED: this also discarded the response's
  // demo_otp_code entirely, unlike every other OTP-send call in this
  // file (resendEmailVerification, requestPhoneVerification, etc).
  // With the backend's OTP_DEMO_FALLBACK active in production (real
  // SMS/email delivery blocked, see controllers/authController.js's
  // own header comment), the forgot-password flow has no other way to
  // ever get the reset code to the user -- ResetPasswordScreen's OTP
  // field was simply left blank with nothing to enter. Now returned
  // alongside the user id so the caller can pre-fill it the same way
  // the other verification screens already do.
  Future<ForgotPasswordResult> forgotPassword(
      {String? email, String? phoneNumber, String? channel}) async {
    try {
      final response = await _client.dio.post(ApiEndpoints.forgotPassword, data: {
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (channel != null) 'channel': channel,
      });
      final data = response.data['data'];
      return ForgotPasswordResult(
        userId: data != null ? data['user_id'] as String? : null,
        demoOtpCode: data != null ? data['demo_otp_code'] as String? : null,
      );
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> resetPassword(
      {required String userId,
      required String otp,
      required String newPassword}) async {
    try {
      await _client.dio.post(ApiEndpoints.resetPassword, data: {
        'user_id': userId,
        'otp': otp,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      final message = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      throw AuthException(message ?? friendlyErrorMessage(e));
    }
  }

  Future<AuthResult> _handleAuthSuccess(Response response) async {
    final data = response.data['data'];
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;

    AuthTokenHolder.instance.setAccessToken(accessToken);
    await SecureStorage.instance.saveRefreshToken(refreshToken);

    return AuthResult(
      user: NagagunoUser.fromJson(data['user']),
      message: response.data['message'] as String? ?? '',
    );
  }

  /// UW 21.2. Requires the current password; sends a confirmation
  /// code to [newEmail] and, if the account already has an email on
  /// file, a "this wasn't me" security notice to the OLD address.
  Future<void> requestEmailChange(
      {required String password, required String newEmail}) async {
    try {
      await _client.dio.post(ApiEndpoints.changeEmailRequest,
          data: {'password': password, 'new_email': newEmail});
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// REAL BUG FOUND AND FIXED, doc comment stale until now: this used
  /// to say the backend revokes every refresh token including the
  /// caller's own -- that was true of an EARLIER version of
  /// confirmEmailChange, but authController.js's own comment on that
  /// handler documents the fix (only OTHER devices are revoked now,
  /// matching UW 21.2 exactly). The caller does NOT need to force a
  /// logout here; see ContactChangeScreen's own comment on why it
  /// calls refreshUser() instead.
  Future<void> confirmEmailChange({required String otp}) async {
    try {
      await _client.dio
          .post(ApiEndpoints.changeEmailConfirm, data: {'otp': otp});
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> cancelEmailChange() async {
    try {
      await _client.dio.post(ApiEndpoints.changeEmailCancel);
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// UW 21.2's "Resend link" on the "Waiting for verification of [new
  /// email]" state -- re-sends a fresh code to the already-pending
  /// address without re-taking the password/new address.
  Future<void> resendEmailChange() async {
    try {
      await _client.dio.post(ApiEndpoints.changeEmailResend);
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// UW 21.2's "This wasn't me" link -- deliberately unauthenticated
  /// server-side (see api_endpoints.dart's own comment), since the
  /// device clicking it may have no session at all. Returns the real
  /// backend's own message ("This email change has been cancelled.
  /// Please change your password now.") so the screen can show the
  /// exact spec text, not a client-side guess.
  Future<String> cancelEmailChangeByLink(String token) async {
    try {
      final response = await _client.dio
          .post(ApiEndpoints.changeEmailCancelByLink, data: {'token': token});
      return response.data['message'] as String;
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Same shape as [requestEmailChange]. UW 21.2 only documents a
  /// post-change FYI to the old number for phone (no pre-change
  /// cancel-by-link, unlike email) -- nothing to build here for that.
  Future<void> requestPhoneChange(
      {required String password, required String newPhoneNumber}) async {
    try {
      await _client.dio.post(ApiEndpoints.changePhoneRequest,
          data: {'password': password, 'new_phone_number': newPhoneNumber});
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Same forced-logout caveat as [confirmEmailChange].
  Future<void> confirmPhoneChange({required String otp}) async {
    try {
      await _client.dio
          .post(ApiEndpoints.changePhoneConfirm, data: {'otp': otp});
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> cancelPhoneChange() async {
    try {
      await _client.dio.post(ApiEndpoints.changePhoneCancel);
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Same resend gap as [resendEmailChange], for the phone channel.
  Future<void> resendPhoneChange() async {
    try {
      await _client.dio.post(ApiEndpoints.changePhoneResend);
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// UW 21.2 "Password": while logged in, proven via the current
  /// password itself rather than an OTP. Unlike confirmEmailChange/
  /// confirmPhoneChange above, this does NOT force a logout -- the
  /// real backend keeps this session's own refresh token valid and
  /// only revokes other devices (see changePassword's own comment).
  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {
    try {
      await _client.dio.post(ApiEndpoints.changePassword, data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<List<Device>> getDevices() async {
    try {
      final response = await _client.dio.get(ApiEndpoints.authDevices);
      return (response.data['data'] as List)
          .map((j) => Device.fromJson(j))
          .toList();
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> logoutDevice(String id) async {
    try {
      await _client.dio.post(ApiEndpoints.authDeviceLogout(id));
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> logoutAllOtherDevices() async {
    try {
      await _client.dio.post(ApiEndpoints.authDevicesLogoutAllOthers);
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// UW 21.2 "Two-factor authentication": disabling is one
  /// password-confirmed step.
  Future<void> disableTwoFactor({required String password}) async {
    try {
      await _client.dio.post(ApiEndpoints.twoFactorToggle,
          data: {'password': password, 'enabled': false});
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// First step of enabling: sends an OTP to the phone on file to
  /// prove it's reachable -- 2FA isn't actually on until
  /// [confirmEnableTwoFactor] succeeds.
  Future<void> requestEnableTwoFactor({required String password}) async {
    try {
      await _client.dio
          .post(ApiEndpoints.twoFactorEnableRequest, data: {'password': password});
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> confirmEnableTwoFactor({required String otp}) async {
    try {
      await _client.dio
          .post(ApiEndpoints.twoFactorEnableConfirm, data: {'otp': otp});
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  AuthException _mapAuthError(DioException e) {
    final responseData = e.response?.data;
    if (responseData is Map && responseData['errors'] is Map) {
      // Matches the real backend's Joi validation error shape.
      final fieldErrors = Map<String, String>.from(responseData['errors']);
      return AuthException('Please check the highlighted fields.',
          fieldErrors: fieldErrors);
    }
    // Delegates to the shared helper for the timeout/connection-error
    // distinction — previously, a timeout during login/register showed
    // the exact same generic "Something went wrong" as any other
    // failure, which is a real, worth-fixing gap specifically because
    // this is the very first screen anyone sees in a demo, on
    // whatever venue wifi happens to be available.
    return AuthException(friendlyErrorMessage(e));
  }
}
