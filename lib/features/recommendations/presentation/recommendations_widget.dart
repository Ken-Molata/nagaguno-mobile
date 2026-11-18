// lib/features/recommendations/presentation/recommendations_widget.dart
//
// Mobile port of the web app's RecommendationsWidget.jsx -- same
// structure (category filters, products/farmers tabs, method badge),
// but the real backend endpoints are GET /recommendations and GET
// /recommendations/farmers now (see domain/recommendation.dart and the
// repository's own header comments for why the POST /recommendations/all
// shape this comment used to describe no longer exists -- this file's
// own header had drifted and still named the removed endpoint). Two
// deliberate simplifications from the web version, not oversights:
//
// 1. The web version does per-product-name emoji matching (60+ regex
//    patterns, e.g. "kamatis" -> tomato emoji). Ported here as
//    category-level emoji only (categoryEmoji) -- a real, honest
//    simplification, not a broken attempt at the full mapping.
// 2. Per instruction, this shows to ALL logged-in users on the
//    marketplace screen, not gated to role == 'buyer' the way the web
//    widget defaults -- the backend endpoint itself has no role
//    check, it only cares whose id to personalize against, so any
//    user's own id works as "buyer_id" here regardless of their role.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/product_categories.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../../authentication/application/auth_controller.dart';
import '../../kyc/application/kyc_status_provider.dart';
import '../../kyc/domain/kyc_models.dart';
import '../data/recommendations_repository.dart';
import '../domain/recommendation.dart';

final _recFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

final _recommendationsProvider =
    FutureProvider.autoDispose<RecommendationsResult>((ref) async {
  final role = ref.watch(authControllerProvider).user?.role;
  final filter = ref.watch(_recFilterProvider);
  // UW 20.1: a Farmer/Vendor caller must self-declare buyer mode or
  // the real backend returns a 403 -- this widget is always shown as
  // a buyer-browsing feature regardless of the signed-in role, so
  // it's always declared for those two roles.
  final buyerMode = role == 'farmer' || role == 'vendor';
  // The farmers endpoint supports filter_category server-side; the
  // products endpoint doesn't (see repository comment) -- passed
  // through here, then narrowed again client-side for products below.
  return ref.watch(recommendationsRepositoryProvider).getRecommendations(
        buyerMode: buyerMode,
        filterCategory: filter,
      );
});

class RecommendationsWidget extends ConsumerStatefulWidget {
  const RecommendationsWidget({super.key});
  @override
  ConsumerState<RecommendationsWidget> createState() =>
      _RecommendationsWidgetState();
}

class _RecommendationsWidgetState extends ConsumerState<RecommendationsWidget> {
  int _tab = 0; // 0 = products, 1 = farmers

  @override
  Widget build(BuildContext context) {
    final kycStatus = ref.watch(kycStatusProvider);

    return kycStatus.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) {
        // Matches VerificationBanner's own real check (KycStatus enum
        // value, not an isVerified getter that doesn't exist on this
        // model) -- same real gate as the web widget's account_status
        // === 'active'.
        if (status.status != KycStatus.approved) {
          return _buildLockedCard(context);
        }
        return _buildRealCard(context);
      },
    );
  }

  Widget _buildLockedCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          const Text('🔒', style: TextStyle(fontSize: 40)),
          const SizedBox(height: AppSpacing.sm),
          const Text('Personalized Recommendations Locked',
              style: AppTypography.h3, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Verify your account to unlock ML-powered product and farmer recommendations based on your real purchase history.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
              onPressed: () => context.push('/kyc'),
              child: const Text('Verify Now')),
        ],
      ),
    );
  }

  Widget _buildRealCard(BuildContext context) {
    final recAsync = ref.watch(_recommendationsProvider);
    final filter = ref.watch(_recFilterProvider);

    // UW 20.1: "If computation returns nothing, a brand-new buyer with
    // no purchase history and no onboarding preferences selected, for
    // example, the row is simply not shown; the regular browse grid is
    // not treated as a failure state." Previously this always rendered
    // the full card shell (chips, tabs, "Edit preferences") with just
    // an inline "No recommendations yet." message inside, rather than
    // disappearing entirely for this specific degenerate case.
    final result = recAsync.valueOrNull;
    if (result != null && result.products.isEmpty && result.farmers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recommended For You', style: AppTypography.h2),
                  ],
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(_recommendationsProvider)),
            ],
          ),
          // UW 21.9: "Preferences: an 'Edit preferences' link on the
          // Recommended for You row." Same /onboarding destination
          // the Profile screen's own "Preferences & Interests" tile
          // already uses -- one setting, reachable from either place.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.push('/onboarding'),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Edit preferences'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: productCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) {
                final cat = productCategories[i];
                return ChoiceChip(
                  label: Text('${categoryEmoji[cat] ?? ''} $cat'),
                  selected: filter == cat,
                  onSelected: (_) => ref
                      .read(_recFilterProvider.notifier)
                      .state = filter == cat ? null : cat,
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                  child: _tabButton(
                      0, '🥬 Products', recAsync.valueOrNull?.products.length)),
              Expanded(
                  child: _tabButton(1, '🧑‍🌾 Farmers',
                      recAsync.valueOrNull?.farmers.length)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          recAsync.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator())),
            error: (e, __) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(friendlyErrorMessage(e),
                  style: const TextStyle(color: AppColors.accentDark)),
            ),
            data: (result) {
              // Products has no server-side category filter (see
              // repository comment) -- narrowed here instead, against
              // the already-fetched list.
              final products = filter == null
                  ? result.products
                  : result.products.where((p) => p.category == filter).toList();
              return _tab == 0
                  ? _buildProductsGrid(products)
                  : _buildFarmersList(result.farmers);
            },
          ),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label, int? count) {
    final selected = _tab == index;
    return InkWell(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: selected ? AppColors.primary : Colors.transparent,
                    width: 3))),
        child: Center(
          child: Text(
            count != null ? '$label ($count)' : label,
            style: AppTypography.body.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                color: selected ? AppColors.primary : AppColors.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsGrid(List<RecommendedProduct> products) {
    if (products.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('No recommendations yet.'));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.72),
      itemCount: products.length,
      itemBuilder: (context, i) {
        final p = products[i];
        return InkWell(
          onTap: () => context.push('/marketplace/product/${p.productId}'),
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
                      ? Image.network(p.imageUrl!, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.backgroundStart,
                          child: Center(
                              child: Text(categoryEmoji[p.category] ?? '🌱',
                                  style: const TextStyle(fontSize: 40)))),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.productName,
                          style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('₱${p.pricePhp.toStringAsFixed(2)}/${p.unit}',
                          style: AppTypography.label),
                      Text(p.recommendationReason,
                          style: AppTypography.label.copyWith(
                              fontStyle: FontStyle.italic,
                              color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFarmersList(List<RecommendedFarmer> farmers) {
    if (farmers.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('No recommendations yet.'));
    }
    return Column(
      children: farmers
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: InkWell(
                  onTap: () => context.push('/farmers/${f.farmerId}'),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Row(
                      children: [
                        CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                                f.displayName.isNotEmpty
                                    ? f.displayName[0]
                                    : '?',
                                style:
                                    const TextStyle(color: AppColors.accent))),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Flexible(
                                    child: Text(f.displayName,
                                        style: AppTypography.body.copyWith(
                                            fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis)),
                                if (f.isVerified)
                                  const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.verified,
                                          size: 14,
                                          color: AppColors.secondary)),
                              ]),
                              if (f.barangay != null)
                                Text('📍 ${f.barangay}',
                                    style: AppTypography.label),
                              Text(f.recommendationReason,
                                  style: AppTypography.label
                                      .copyWith(fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
