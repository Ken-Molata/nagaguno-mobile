// lib/features/admin/data/admin_repository.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/admin_models.dart';

/// Moved here from kyc_review_screen.dart (where it originally lived,
/// the one mobile admin screen this app had before the web admin app)
/// -- every repository provider in this codebase lives alongside its
/// repository class, same as kycRepositoryProvider/authRepositoryProvider;
/// a presentation file was never the right home, it just worked by
/// accident for the one other screen that happened to import it.
final adminRepositoryProvider = Provider<AdminRepository>(
    (ref) => AdminRepository(ref.watch(apiClientProvider)));

class AdminRepository {
  AdminRepository(this._client);
  final ApiClient _client;

  Future<AdminAnalytics> getAnalytics() async {
    final response = await _client.dio.get(ApiEndpoints.adminAnalytics);
    return AdminAnalytics.fromJson(response.data['data']);
  }

  Future<List<KycQueueItem>> getKycQueue({String status = 'pending'}) async {
    final response = await _client.dio
        .get(ApiEndpoints.kycQueue, queryParameters: {'status': status});
    return (response.data['data'] as List)
        .map((j) => KycQueueItem.fromJson(j))
        .toList();
  }

  Future<KycSubmissionDetail> getKycDetail(String id) async {
    final response = await _client.dio.get(ApiEndpoints.kycDetail(id));
    return KycSubmissionDetail.fromJson(response.data['data']);
  }

  /// [rejectionReason] required when [decision] is 'rejected' or
  /// 'resubmission_required' — matching the real backend's exact
  /// validation. [resubmissionFields] is required (non-empty) for
  /// 'resubmission_required' (UW 10.4: "Admin flags the specific
  /// document(s)"); optional for 'rejected', where the backend falls
  /// back to a reason-implied default set if omitted.
  Future<void> submitKycDecision(String id,
      {required String decision,
      String? rejectionReason,
      List<String>? resubmissionFields}) async {
    await _client.dio.post(ApiEndpoints.kycDecision(id), data: {
      'decision': decision,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (resubmissionFields != null) 'resubmissionFields': resubmissionFields,
    });
  }

  /// Matches GET /admin/users exactly (routes/admin.js): role/status
  /// are exact-match filters, search does an ILIKE against full_name
  /// OR email server-side.
  Future<List<AdminUserListItem>> getUsers(
      {String? role, String? status, String? search}) async {
    final response =
        await _client.dio.get(ApiEndpoints.adminUsers, queryParameters: {
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (response.data['data'] as List)
        .map((j) => AdminUserListItem.fromJson(j))
        .toList();
  }

  Future<AdminUserDetail> getUserDetail(String id) async {
    final response = await _client.dio.get(ApiEndpoints.adminUserDetail(id));
    return AdminUserDetail.fromJson(response.data['data']);
  }

  /// [reason] required whenever [accountStatus] isn't 'active' —
  /// matching the real backend's exact validation (routes/admin.js).
  Future<void> updateUserStatus(String id,
      {required String accountStatus, String? reason}) async {
    await _client.dio.patch(ApiEndpoints.adminUserDetail(id), data: {
      'account_status': accountStatus,
      if (reason != null) 'reason': reason,
    });
  }

  // ── UW 9.1/9.2: Reports & Disputes ──
  Future<List<ReportQueueItem>> getReportQueue() async {
    final response = await _client.dio.get(ApiEndpoints.reportsAdminQueue);
    return (response.data['data'] as List)
        .map((j) => ReportQueueItem.fromJson(j))
        .toList();
  }

  Future<ReportDetail> getReportDetail(String id) async {
    final response =
        await _client.dio.get(ApiEndpoints.reportsAdminDetail(id));
    return ReportDetail.fromJson(response.data['data']);
  }

  /// [decision] is 'verified' | 'dismissed' | 'more_info_requested'.
  /// [reasonCode] (from DISMISS_REASONS, or 'other' with [note])
  /// required when dismissing; [note] required (the evidence ask) when
  /// requesting more info.
  Future<void> submitReportDecision(String id,
      {required String decision, String? reasonCode, String? note}) async {
    await _client.dio.post(ApiEndpoints.reportsAdminDecision(id), data: {
      'decision': decision,
      if (reasonCode != null) 'reasonCode': reasonCode,
      if (note != null) 'note': note,
    });
  }

  // ── UW 9.4: Refund escalations ──
  Future<List<RefundQueueItem>> getRefundQueue() async {
    final response = await _client.dio.get(ApiEndpoints.refundsAdminQueue);
    return (response.data['data'] as List)
        .map((j) => RefundQueueItem.fromJson(j))
        .toList();
  }

  /// [decision] is 'verified' | 'dismissed'; [reasonCode] (from
  /// ADMIN_DISMISS_REASONS, or 'other' with [note]) required when
  /// dismissing.
  Future<void> submitRefundDecision(String id,
      {required String decision, String? reasonCode, String? note}) async {
    await _client.dio.post(ApiEndpoints.refundsAdminDecision(id), data: {
      'decision': decision,
      if (reasonCode != null) 'reasonCode': reasonCode,
      if (note != null) 'note': note,
    });
  }

  // ── UW 17.5: Appeals ──
  Future<List<AppealQueueItem>> getAppealQueue() async {
    final response = await _client.dio.get(ApiEndpoints.appealsAdminQueue);
    return (response.data['data'] as List)
        .map((j) => AppealQueueItem.fromJson(j))
        .toList();
  }

  Future<AppealDetail> getAppealDetail(String id) async {
    final response =
        await _client.dio.get(ApiEndpoints.appealsAdminDetail(id));
    return AppealDetail.fromJson(response.data['data']);
  }

  Future<void> submitAppealDecision(String id,
      {required String decision, String? note}) async {
    await _client.dio.post(ApiEndpoints.appealsAdminDecision(id), data: {
      'decision': decision,
      if (note != null) 'note': note,
    });
  }

  // ── UW 21.1: Profile correction requests ──
  Future<List<CorrectionQueueItem>> getCorrectionQueue() async {
    final response =
        await _client.dio.get(ApiEndpoints.correctionsAdminQueue);
    return (response.data['data'] as List)
        .map((j) => CorrectionQueueItem.fromJson(j))
        .toList();
  }

  Future<CorrectionDetail> getCorrectionDetail(String id) async {
    final response =
        await _client.dio.get(ApiEndpoints.correctionsAdminDetail(id));
    return CorrectionDetail.fromJson(response.data['data']);
  }

  /// [rejectionReason] (one of REJECTION_REASONS' keys) required when
  /// rejecting; 'other' additionally requires [note].
  Future<void> submitCorrectionDecision(String id,
      {required String decision, String? rejectionReason, String? note}) async {
    await _client.dio.post(ApiEndpoints.correctionsAdminDecision(id), data: {
      'decision': decision,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (note != null) 'note': note,
    });
  }

  // ── UW 3.3 "Farmer feedback" on shelf life ──
  Future<List<ShelfLifeFeedbackItem>> getShelfLifeFeedbackQueue() async {
    final response =
        await _client.dio.get(ApiEndpoints.adminShelfLifeFeedbackQueue);
    return (response.data['data'] as List)
        .map((j) => ShelfLifeFeedbackItem.fromJson(j))
        .toList();
  }

  /// [reasonCode] (+ [note] for 'other') required when [decision] is
  /// 'declined' -- matches the real backend's own validation.
  Future<void> submitShelfLifeFeedbackDecision(String id,
      {required String decision, String? reasonCode, String? note}) async {
    await _client.dio
        .post(ApiEndpoints.adminShelfLifeFeedbackDecision(id), data: {
      'decision': decision,
      if (reasonCode != null) 'reasonCode': reasonCode,
      if (note != null) 'note': note,
    });
  }

  // ── UW 2.5 Step 4: Account Recovery ──
  Future<List<RecoveryQueueItem>> getRecoveryQueue() async {
    final response = await _client.dio.get(ApiEndpoints.recoveryAdminQueue);
    return (response.data['data'] as List)
        .map((j) => RecoveryQueueItem.fromJson(j))
        .toList();
  }

  Future<RecoveryDetail> getRecoveryDetail(String id) async {
    final response =
        await _client.dio.get(ApiEndpoints.recoveryAdminDetail(id));
    return response.data['data'] as Map<String, dynamic>;
  }

  /// UW 2.5 Step 1's "Account not identified by user" case: links a
  /// request with no user_id to the account the Admin found by
  /// name/date-of-birth search, required before it can be approved.
  Future<void> linkRecoveryAccount(String id, {required String userId}) async {
    await _client.dio
        .post(ApiEndpoints.recoveryAdminLinkAccount(id), data: {'userId': userId});
  }

  /// [decision] is 'approved' | 'more_info_needed' | 'rejected'.
  /// Rejecting needs [reasonCode] (+ [note] for 'other'); needing more
  /// info needs [items] (MORE_INFO_LABELS keys) (+ [other] text when
  /// items includes 'other').
  Future<void> submitRecoveryDecision(
    String id, {
    required String decision,
    String? reasonCode,
    String? note,
    List<String>? items,
    String? other,
  }) async {
    await _client.dio.post(ApiEndpoints.recoveryAdminDecision(id), data: {
      'decision': decision,
      if (reasonCode != null) 'reasonCode': reasonCode,
      if (note != null) 'note': note,
      if (items != null) 'items': items,
      if (other != null) 'other': other,
    });
  }

  // ── UW 3.3/3.4: Spoilage monitoring ──
  Future<SpoilageDashboard> getSpoilageDashboard() async {
    final response = await _client.dio.get(ApiEndpoints.spoilageDashboard);
    return SpoilageDashboard.fromJson(response.data['data']);
  }

  // ── UW 2.6 "full platform oversight": orders, agreements, listings ──
  Future<List<AdminOrderListItem>> getAllOrders({String? status}) async {
    final response = await _client.dio.get(ApiEndpoints.adminOrders,
        queryParameters: {if (status != null) 'status': status});
    return (response.data['data'] as List)
        .map((j) => AdminOrderListItem.fromJson(j))
        .toList();
  }

  Future<List<AdminAgreementListItem>> getAllAgreements({String? status}) async {
    final response = await _client.dio.get(ApiEndpoints.adminAgreements,
        queryParameters: {if (status != null) 'status': status});
    return (response.data['data'] as List)
        .map((j) => AdminAgreementListItem.fromJson(j))
        .toList();
  }

  Future<List<AdminListingItem>> getAllListings(
      {String? status, String? category, String? search}) async {
    final response = await _client.dio.get(ApiEndpoints.adminListings,
        queryParameters: {
          if (status != null) 'status': status,
          if (category != null) 'category': category,
          if (search != null && search.isNotEmpty) 'search': search,
        });
    return (response.data['data'] as List)
        .map((j) => AdminListingItem.fromJson(j))
        .toList();
  }

  /// [status] is 'live' | 'hidden'; [reason] required when hiding.
  Future<void> updateListingStatus(String id,
      {required String status, String? reason}) async {
    await _client.dio.patch(ApiEndpoints.adminListingDetail(id), data: {
      'status': status,
      if (reason != null) 'reason': reason,
    });
  }

  // ── UW 10.1: KYC Route table (read side lives on KycRepository.
  // getIdTypes() -- every authenticated user needs that same list, not
  // just Admin; this is only the write side admin.js/kyc.js reserves
  // to authorize('admin')) ──
  Future<void> updateIdTypeRoute(String idType,
      {String? route, bool? backRequired, String? label}) async {
    await _client.dio.patch(ApiEndpoints.kycIdTypeDetail(idType), data: {
      if (route != null) 'route': route,
      if (backRequired != null) 'backRequired': backRequired,
      if (label != null) 'label': label,
    });
  }

  // ── UW 6.1: Gateway settlement ──
  Future<List<SettlementQueueItem>> getSettlements() async {
    final response = await _client.dio.get(ApiEndpoints.adminSettlements);
    return (response.data['data'] as List)
        .map((j) => SettlementQueueItem.fromJson(j))
        .toList();
  }

  /// Marks every currently-unsettled Gateway order for this seller as
  /// settled in one batch, with [proofPath] as evidence the transfer
  /// was actually sent (UW 6.1: "before this can be marked complete,
  /// the seller must first upload proof" -- same shape, Admin side).
  Future<void> recordSettlement(String sellerId, {required String proofPath}) async {
    final formData = FormData.fromMap(
        {'proof': await MultipartFile.fromFile(proofPath)});
    await _client.dio
        .post(ApiEndpoints.adminSettlementDetail(sellerId), data: formData);
  }

  // ── UW 14.4: platform feedback ──
  Future<List<PlatformFeedbackItem>> getPlatformFeedback() async {
    final response = await _client.dio.get(ApiEndpoints.adminFeedback);
    return (response.data['data'] as List)
        .map((j) => PlatformFeedbackItem.fromJson(j))
        .toList();
  }

  // ── UW 8: Generate Reports ──
  /// [reportType] selects which of the four UW 8 report endpoints to
  /// call. [start]/[end] are optional ISO dates (omitted means
  /// all-time, matching the real backend's own default). Throws a
  /// [NoReportDataException] on the real backend's 404 "No data
  /// available for the selected period" case, so the screen can show
  /// that exact message rather than a generic error.
  Future<List<PlatformReportRow>> getPlatformReport(
    AdminReportType reportType, {
    DateTime? start,
    DateTime? end,
  }) async {
    final path = switch (reportType) {
      AdminReportType.agreements => ApiEndpoints.adminReportsAgreements,
      AdminReportType.orders => ApiEndpoints.adminReportsOrders,
      AdminReportType.vendorPerformance =>
        ApiEndpoints.adminReportsVendorPerformance,
      AdminReportType.marketDemand => ApiEndpoints.adminReportsMarketDemand,
    };
    try {
      final response = await _client.dio.get(path, queryParameters: {
        if (start != null) 'start': start.toIso8601String().split('T').first,
        if (end != null) 'end': end.toIso8601String().split('T').first,
      });
      return (response.data['data'] as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw NoReportDataException();
      rethrow;
    }
  }

  /// Downloads the same report as CSV bytes. NOT a plain `<a href>`
  /// link -- this app authenticates with a Bearer token attached by
  /// ApiClient's own interceptor (AuthTokenHolder), not a cookie; the
  /// backend does also set `access_token`/`refresh_token` cookies on
  /// login (authController.js's setAuthCookies), but with
  /// `sameSite: 'strict'`, which a cross-origin link navigation
  /// (admin app and API on different ports/origins in any real
  /// deployment) would never send anyway. Going through the
  /// authenticated client and triggering the browser download
  /// client-side (see web_download.dart) is the only way this
  /// actually works.
  Future<List<int>> fetchPlatformReportCsv(
    AdminReportType reportType, {
    DateTime? start,
    DateTime? end,
  }) async {
    final path = switch (reportType) {
      AdminReportType.agreements => ApiEndpoints.adminReportsAgreements,
      AdminReportType.orders => ApiEndpoints.adminReportsOrders,
      AdminReportType.vendorPerformance =>
        ApiEndpoints.adminReportsVendorPerformance,
      AdminReportType.marketDemand => ApiEndpoints.adminReportsMarketDemand,
    };
    try {
      final response = await _client.dio.get(path,
          queryParameters: {
            'format': 'csv',
            if (start != null)
              'start': start.toIso8601String().split('T').first,
            if (end != null) 'end': end.toIso8601String().split('T').first,
          },
          options: Options(responseType: ResponseType.bytes));
      return response.data as List<int>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw NoReportDataException();
      rethrow;
    }
  }
}

enum AdminReportType { agreements, orders, vendorPerformance, marketDemand }

class NoReportDataException implements Exception {}
