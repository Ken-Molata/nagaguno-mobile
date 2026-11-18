// lib/features/reviews/presentation/user_reviews_section.dart
//
// Reusable "Ratings & Reviews" block (average, star breakdown, recent
// comments) -- embedded in FarmerDetailScreen/VendorDetailScreen,
// since UW 12.3/12.4's rating display and UW 14's reviews are the same
// underlying data (GET /reviews/user/:userId), not two features.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../authentication/application/auth_controller.dart';
import '../../reports/presentation/report_user_screen.dart';
import '../../reports/domain/report_models.dart';
import '../data/reviews_repository.dart';
import '../domain/review.dart';

final reviewsRepositoryProvider = Provider<ReviewsRepository>(
    (ref) => ReviewsRepository(ref.watch(apiClientProvider)));
final userReviewsProvider =
    FutureProvider.autoDispose.family<ReviewsResult, String>(
  (ref, userId) =>
      ref.watch(reviewsRepositoryProvider).getReviewsForUser(userId),
);

class UserReviewsSection extends ConsumerWidget {
  const UserReviewsSection({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(userReviewsProvider(userId));
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Text(result.averageRating.toStringAsFixed(1),
                        style: AppTypography.display.copyWith(fontSize: 32)),
                    _StarRow(rating: result.averageRating.round()),
                    Text(
                        '${result.totalCount} review${result.totalCount == 1 ? '' : 's'}',
                        style: AppTypography.label),
                  ],
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    children: List.generate(5, (i) {
                      final star = 5 - i;
                      final count = result.breakdown[star] ?? 0;
                      final fraction = result.totalCount == 0
                          ? 0.0
                          : count / result.totalCount;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          children: [
                            Text('$star', style: AppTypography.label),
                            const SizedBox(width: 4),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                    value: fraction,
                                    minHeight: 6,
                                    backgroundColor: AppColors.border,
                                    color: AppColors.accentDark),
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                                width: 24,
                                child: Text('$count',
                                    style: AppTypography.label,
                                    textAlign: TextAlign.right)),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...result.reviews.take(5).map((r) => Padding(
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
                          // UW 12.3/12.4: "each showing the reviewer's
                          // name and photo... and the date" -- both
                          // were already on the Review model
                          // (reviewerAvatar/createdAt) and simply
                          // unrendered here.
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
                          _StarRow(rating: r.rating, size: 14),
                          // UW 9.1: "A posted review... pre-linked to
                          // that review." The reviewer here is always
                          // a buyer (only buyers review a seller).
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
                                      reviewId: r.id,
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
                        const SizedBox(height: 4),
                        Text(_formatDate(r.createdAt),
                            style: AppTypography.label
                                .copyWith(color: AppColors.textMuted)),
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

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _formatDate(DateTime d) =>
    '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, this.size = 16});
  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
          5,
          (i) => Icon(
                i < rating ? Icons.star : Icons.star_border,
                size: size,
                color: AppColors.accentDark,
              )),
    );
  }
}
