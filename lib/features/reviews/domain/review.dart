// lib/features/reviews/domain/review.dart
//
// UW 14 (Reviews & Ratings). Fields verified against the real
// GET /reviews/user/:userId and POST /reviews (routes/reviews.js) this
// session -- the `reviews` table already existed and was already
// being read from (recommendation.js/marketplace.js's own AVG(rating)
// seller-rating queries), but nothing ever wrote a row to it before
// this backend pass, and nothing in this app had a screen for it at all.
//
// UW 14.1's separate PRODUCT review (up to 3 photos, distinct from the
// seller review above) is now built too, via the additive
// product_reviews table (GET /reviews/product/:productId / POST
// /reviews/product) -- `reviews` itself still only models the
// seller<->buyer direction, so [Review] below stays as it was;
// [photoUrls]/[productId]/[productName] are populated only for a
// product review's rows, which otherwise share this exact shape
// (reviewer_id/name/avatar, rating, comment, created_at).

class Review {
  const Review({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    required this.rating,
    required this.createdAt,
    this.reviewerAvatar,
    this.comment,
    this.photoUrls = const [],
    this.productId,
    this.productName,
  });

  final String id;
  final String reviewerId;
  final String reviewerName;
  final int rating;
  final DateTime createdAt;
  final String? reviewerAvatar;
  final String? comment;

  /// Only ever populated on a product review's row.
  final List<String> photoUrls;
  final String? productId;
  final String? productName;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        reviewerId: json['reviewer_id'] as String,
        reviewerName: json['reviewer_name'] as String,
        rating: int.tryParse(json['rating'].toString()) ?? 0,
        createdAt: DateTime.parse(json['created_at']),
        reviewerAvatar: json['reviewer_avatar'] as String?,
        comment: json['comment'] as String?,
        photoUrls: (json['photo_urls'] as List? ?? []).cast<String>(),
        productId: json['product_id'] as String?,
        productName: json['product_name'] as String?,
      );
}

/// UW 12.3/12.4: "a granular rating breakdown -- the count ... at each
/// star level, 5 down to 1."
class ReviewsResult {
  const ReviewsResult({required this.reviews, required this.breakdown});
  final List<Review> reviews;
  final Map<int, int> breakdown;

  int get totalCount => breakdown.values.fold(0, (a, b) => a + b);

  double get averageRating {
    final total = totalCount;
    if (total == 0) return 0;
    final sum =
        breakdown.entries.fold<int>(0, (acc, e) => acc + e.key * e.value);
    return sum / total;
  }

  factory ReviewsResult.fromJson(Map<String, dynamic> json) {
    final breakdownJson = json['breakdown'] as Map<String, dynamic>;
    return ReviewsResult(
      reviews:
          (json['reviews'] as List).map((r) => Review.fromJson(r)).toList(),
      breakdown: breakdownJson.map((k, v) => MapEntry(int.parse(k), v as int)),
    );
  }
}
