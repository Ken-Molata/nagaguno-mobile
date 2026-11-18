// lib/features/reports/data/reports_repository.dart
//
// Matches the real routes/reports.js exactly, including its camelCase
// body field names (reportedUserId, violationGroup, violationType,
// orderId, ...) -- NOT the snake_case convention most of this
// backend's other POST bodies use (verified directly against the
// route's own `const { reportedUserId, ... } = req.body` destructure).
import 'package:dio/dio.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/report_models.dart';

class ReportException implements Exception {
  ReportException(this.message);
  final String message;
}

class ReportsRepository {
  ReportsRepository(this._client);
  final ApiClient _client;

  Future<String> submitReport({
    required String reportedUserId,
    required String violationGroup,
    required String violationType,
    String? essay,
    List<String> photoPaths = const [],
    String? orderId,
    String? agreementId,
    String? productId,
    String? messageId,
    String? reviewId,
    String? productReviewId,
    bool reportProfilePicture = false,
  }) async {
    if ((essay == null || essay.trim().isEmpty) && photoPaths.isEmpty) {
      throw ReportException('Provide a description and/or at least one photo.');
    }
    try {
      final formData = FormData.fromMap({
        'reportedUserId': reportedUserId,
        'violationGroup': violationGroup,
        'violationType': violationType,
        if (essay != null && essay.trim().isNotEmpty) 'essay': essay.trim(),
        if (orderId != null) 'orderId': orderId,
        if (agreementId != null) 'agreementId': agreementId,
        if (productId != null) 'productId': productId,
        if (messageId != null) 'messageId': messageId,
        if (reviewId != null) 'reviewId': reviewId,
        if (productReviewId != null) 'productReviewId': productReviewId,
        if (reportProfilePicture) 'reportProfilePicture': 'true',
        for (final path in photoPaths)
          'photos': await MultipartFile.fromFile(path),
      });
      final response =
          await _client.dio.post(ApiEndpoints.reports, data: formData);
      return response.data['data']['id'] as String;
    } on DioException catch (e) {
      final message = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      throw ReportException(message ?? 'Failed to submit report.');
    }
  }

  Future<List<MyReport>> getMyReports() async {
    final response = await _client.dio.get(ApiEndpoints.reportsMine);
    return (response.data['data'] as List)
        .map((j) => MyReport.fromJson(j))
        .toList();
  }
}
