// lib/features/reviews/data/reviews_repository.dart
//
// Matches the real routes/reviews.js exactly.

import 'package:dio/dio.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/review.dart';

class ReviewException implements Exception {
  ReviewException(this.message);
  final String message;
}

class ReviewsRepository {
  ReviewsRepository(this._client);
  final ApiClient _client;

  /// Either party on a delivered order may review the other, once.
  /// A 409 means this order was already reviewed by the caller.
  Future<void> submitReview(
      {required String orderId, required int rating, String? comment}) async {
    try {
      await _client.dio.post(ApiEndpoints.reviews, data: {
        'order_id': orderId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      });
    } on DioException catch (e) {
      final message = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      throw ReviewException(message ?? 'Failed to post review.');
    }
  }

  Future<ReviewsResult> getReviewsForUser(String userId,
      {int limit = 20, int offset = 0}) async {
    final response = await _client.dio
        .get(ApiEndpoints.reviewsForUser(userId), queryParameters: {
      'limit': limit,
      'offset': offset,
    });
    return ReviewsResult.fromJson(response.data['data']);
  }

  /// UW 14.1: a separate review of the product itself, distinct from
  /// [submitReview] above. [orderItemId] (not orderId) is the key --
  /// one order can contain more than one product. Up to 3
  /// [photoPaths]; a 409 means this exact order item was already reviewed.
  Future<void> submitProductReview({
    required String orderItemId,
    required int rating,
    String? comment,
    List<String> photoPaths = const [],
  }) async {
    try {
      final formData = FormData.fromMap({
        'order_item_id': orderItemId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
        for (final path in photoPaths.take(3))
          'photos': await MultipartFile.fromFile(path),
      });
      await _client.dio.post(ApiEndpoints.reviewsProduct, data: formData);
    } on DioException catch (e) {
      final message = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      throw ReviewException(message ?? 'Failed to post review.');
    }
  }

  Future<ReviewsResult> getReviewsForProduct(String productId,
      {int limit = 20, int offset = 0}) async {
    final response = await _client.dio
        .get(ApiEndpoints.reviewsForProduct(productId), queryParameters: {
      'limit': limit,
      'offset': offset,
    });
    return ReviewsResult.fromJson(response.data['data']);
  }

  /// UW 14.4: general platform feedback, admin-only visibility.
  Future<void> submitFeedback(String message) async {
    try {
      await _client.dio.post(ApiEndpoints.reviewsFeedback,
          data: {'message': message.trim()});
    } on DioException catch (e) {
      final errMessage = (e.response?.data is Map
          ? e.response?.data['message']
          : null) as String?;
      throw ReviewException(errMessage ?? 'Failed to submit feedback.');
    }
  }
}
