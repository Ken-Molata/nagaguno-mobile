// lib/features/recommendations/presentation/similar_products_section.dart
//
// Product-detail "You may also like" -- real item-item collaborative
// filtering (GET /recommendations/similar/:product_id), falling back
// server-side to same-category popularity when the product has no CF
// data yet. Previously had zero UI consumer anywhere in the app
// despite the endpoint existing and having just been upgraded to use
// the real ml-service model this session (confirmed via grep before
// building). Kept free of CF/similarity-score jargon in the visible
// copy, same as the Recommendations widget's own "Recommended For
// You" title.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/product_categories.dart';
import '../data/recommendations_repository.dart';
import '../domain/recommendation.dart';

final similarProductsProvider =
    FutureProvider.autoDispose.family<List<SimilarProduct>, String>(
  (ref, productId) => ref
      .watch(recommendationsRepositoryProvider)
      .getSimilarProducts(productId),
);

class SimilarProductsSection extends ConsumerWidget {
  const SimilarProductsSection({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similarAsync = ref.watch(similarProductsProvider(productId));

    return similarAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You May Also Like', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final p = products[i];
                  return SizedBox(
                    width: 130,
                    child: InkWell(
                      onTap: () =>
                          context.push('/marketplace/product/${p.productId}'),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 1.4,
                              child: p.imageUrl != null
                                  ? Image.network(p.imageUrl!,
                                      fit: BoxFit.cover)
                                  : Container(
                                      color: AppColors.backgroundStart,
                                      child: Center(
                                          child: Text(
                                              categoryEmoji[p.category] ??
                                                  '🌱',
                                              style: const TextStyle(
                                                  fontSize: 32))),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.productName,
                                      style: AppTypography.body.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                      '₱${p.pricePhp.toStringAsFixed(2)}/${p.unit}',
                                      style: AppTypography.label),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
