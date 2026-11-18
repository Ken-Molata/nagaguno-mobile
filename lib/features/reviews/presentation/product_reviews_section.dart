// lib/features/reviews/presentation/product_reviews_section.dart
//
// UW 14.1: the product's own reviews (distinct from the seller's,
// shown via UserReviewsSection on the farmer/vendor profile) -- same
// visual shape, but keyed by product and including review photos.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../authentication/application/auth_controller.dart';
import '../../reports/presentation/report_user_screen.dart';
import '../../reports/domain/report_models.dart';
import 'user_reviews_section.dart';
import '../domain/review.dart';

final productReviewsProvider =
    FutureProvider.autoDispose.family<ReviewsResult, String>(
  (ref, productId) =>
      ref.watch(reviewsRepositoryProvider).getReviewsForProduct(productId),
);

class ProductReviewsSection extends ConsumerWidget {
  const ProductReviewsSection({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(productReviewsProvider(productId));
    final myUserId = ref.watch(authControllerProvider).user?.id;

    return reviewsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (result) {
        if (result.totalCount == 0) {
          return const Text('No reviews yet.', style: AppTypography.bodySmall);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < result.averageRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 18,
                          color: AppColors.accentDark,
                        )),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                  '${result.averageRating.toStringAsFixed(1)} (${result.totalCount} review${result.totalCount == 1 ? '' : 's'})',
                  style: AppTypography.bodySmall),
            ]),
            const SizedBox(height: AppSpacing.sm),
            ...result.reviews.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          // UW 14.1: "each with the reviewer's name and
                          // photo" -- reviewerAvatar was already on the
                          // Review model, just unrendered here.
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.backgroundStart,
                            backgroundImage: r.reviewerAvatar != null
                                ? NetworkImage(r.reviewerAvatar!)
                                : null,
                            child: r.reviewerAvatar == null
                                ? const Icon(Icons.person,
                                    size: 14, color: AppColors.textMuted)
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                              child: Text(r.reviewerName,
                                  style: AppTypography.body
                                      .copyWith(fontWeight: FontWeight.w600))),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                                5,
                                (i) => Icon(
                                    i < r.rating
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 14,
                                    color: AppColors.accentDark)),
                          ),
                          // UW 9.1/14.1: "Each posted review, and each
                          // photo attached to one, carries its own
                          // report option." The product review's
                          // reviewer is always a buyer (only buyers
                          // submit product reviews), so the group is
                          // fixed the same way the profile-level
                          // report entry points fix it from context.
                          if (r.reviewerId != myUserId)
                            PopupMenuButton<void>(
                              icon: const Icon(Icons.more_vert, size: 18),
                              tooltip: 'Report this review',
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  onTap: () =>
                                      Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => ReportUserScreen(
                                      reportedUserId: r.reviewerId,
                                      reportedUserName: r.reviewerName,
                                      fixedGroup: ViolationGroup.buyerConduct,
                                      productReviewId: r.id,
                                    ),
                                  )),
                                  child: const Text('Report this review'),
                                ),
                              ],
                            ),
                        ]),
                        if (r.comment != null) ...[
                          const SizedBox(height: 4),
                          Text(r.comment!, style: AppTypography.bodySmall),
                        ],
                        if (r.photoUrls.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          SizedBox(
                            height: 64,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: r.photoUrls.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: AppSpacing.xs),
                              itemBuilder: (context, i) => ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                                child: Image.network(r.photoUrls[i],
                                    width: 64, height: 64, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}
