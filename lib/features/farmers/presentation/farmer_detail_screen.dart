// lib/features/farmers/presentation/farmer_detail_screen.dart
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../../shared/widgets/verification_banner.dart';
import '../../reviews/presentation/user_reviews_section.dart';
import '../../conversations/data/conversations_repository.dart';
import '../../reports/presentation/report_menu_button.dart';
import '../../reports/domain/report_models.dart';
import '../../authentication/application/auth_controller.dart';
import '../../blocks/presentation/block_user_button.dart';
import '../../marketplace/presentation/product_detail_screen.dart';
import 'farmers_screen.dart';

final _farmerDetailProvider = FutureProvider.autoDispose.family(
    (ref, String id) =>
        ref.watch(farmersRepositoryProvider).getFarmerDetail(id));

Future<void> _messageUser(BuildContext context, WidgetRef ref,
    {required String userId, required String userName}) async {
  try {
    final conversationId = await ref
        .read(conversationsRepositoryProvider)
        .openConversation(recipientId: userId);
    if (context.mounted) {
      context.push(
          '/conversations/$conversationId?name=${Uri.encodeComponent(userName)}');
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ref.read(appStringsProvider).couldntOpenConversationTryAgain)));
    }
  }
}

final _isSavedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, farmerId) async {
  final saved = await ref.watch(farmersRepositoryProvider).getSavedFarmers();
  return saved.any((f) => f.id == farmerId);
});

class FarmerDetailScreen extends ConsumerWidget {
  const FarmerDetailScreen({super.key, required this.farmerId});
  final String farmerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmerAsync = ref.watch(_farmerDetailProvider(farmerId));
    final isSavedAsync = ref.watch(_isSavedProvider(farmerId));
    final s = ref.watch(appStringsProvider);
    // REAL BUG FOUND AND FIXED, live-caught: a Farmer toggled into
    // buyer mode could open their own profile (/farmers/<their own
    // id>) and tap "Request" on their own production plans -- POST
    // /agreements already rejects it server-side, but the button
    // itself still worked right up to that rejection. Every plan
    // listed below belongs to `farmerId` by definition, so one check
    // against the viewed profile covers the whole list.
    final isOwnProfile = ref.watch(authControllerProvider).user?.id == farmerId;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.farmerProfileTitle),
        actions: [
          isSavedAsync.when(
            data: (isSaved) => IconButton(
              icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border,
                  color: isSaved ? AppColors.error : null),
              onPressed: () async {
                final repo = ref.read(farmersRepositoryProvider);
                try {
                  if (isSaved) {
                    await repo.unsaveFarmer(farmerId);
                  } else {
                    await repo.saveFarmer(farmerId);
                  }
                  ref.invalidate(_isSavedProvider(farmerId));
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(s.somethingWentWrongTryAgain)));
                  }
                }
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // UW 9/17.7: a Seller Conduct report against this Farmer.
          // Role is implicit here (this screen only ever shows a
          // Farmer), so no role lookup is needed the way the generic
          // entry point would -- seller_conduct is always correct.
          if (farmerAsync.valueOrNull != null) ...[
            ReportMenuButton(
              reportedUserId: farmerAsync.valueOrNull!.id,
              reportedUserName: farmerAsync.valueOrNull!.displayName,
              fixedGroup: ViolationGroup.sellerConduct,
            ),
            // UW 9.3: independent of reporting -- see BlockUserButton's
            // own header comment for the gap this closes.
            BlockUserButton(
              userId: farmerAsync.valueOrNull!.id,
              userName: farmerAsync.valueOrNull!.displayName,
            ),
          ],
        ],
      ),
      body: farmerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(s.couldntLoadFarmer)),
        data: (farmer) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.backgroundStart,
                  backgroundImage: farmer.farmPhotoUrl != null
                      ? NetworkImage(farmer.farmPhotoUrl!)
                      : null,
                  child: farmer.farmPhotoUrl == null
                      ? const Icon(Icons.grass,
                          size: 40, color: AppColors.primary)
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                  child: Text(farmer.displayName,
                      style: AppTypography.h1, textAlign: TextAlign.center)),
              if (farmer.barangay != null)
                Center(
                    child:
                        Text(farmer.barangay!, style: AppTypography.bodySmall)),
              const SizedBox(height: AppSpacing.xs),
              // UW 12.3: the profile SUBJECT's verification badge and
              // join date -- not VerificationBanner, which is always
              // the viewer's own status (see verification_banner.dart).
              Center(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    VerificationBadge(isVerified: farmer.isVerified),
                    if (farmer.createdAt != null)
                      Text(s.joinedYear('${farmer.createdAt!.year}'),
                          style: AppTypography.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _messageUser(context, ref,
                      userId: farmer.id, userName: farmer.displayName),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(s.messageLabel),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (farmer.aboutFarm != null) ...[
                Text(s.aboutLabel, style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(farmer.aboutFarm!, style: AppTypography.body),
                const SizedBox(height: AppSpacing.lg),
              ],
              // UW 12.3/12.4/14: a real, working ratings/reviews
              // backend (routes/reviews.js) with no screen anywhere in
              // this app to show it.
              Text(s.ratingsAndReviewsLabel, style: AppTypography.h3),
              const SizedBox(height: AppSpacing.sm),
              UserReviewsSection(userId: farmerId),
              const SizedBox(height: AppSpacing.lg),
              // farmer.products was already returned by the real
              // detail endpoint all along -- the model just never
              // parsed it, and nothing displayed it, until now.
              if (farmer.products.isNotEmpty) ...[
                Text(s.productsLabel, style: AppTypography.h3),
                const SizedBox(height: AppSpacing.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: farmer.products.length,
                  itemBuilder: (context, i) {
                    final p = farmer.products[i];
                    return InkWell(
                      // REAL BUG FOUND AND FIXED: '/marketplace/product/:id'
                      // is declared as a NESTED child route inside the
                      // Marketplace tab's own StatefulShellBranch (app_
                      // router.dart) -- this screen is a top-level route
                      // reached from outside that shell entirely (the
                      // Farmers directory), and context.push() of a path
                      // nested under a different shell branch than the
                      // one currently active doesn't resolve the way a
                      // normal push does, confirmed live: tapping a
                      // product here did nothing/failed to open at all.
                      // A plain Navigator.push straight to the screen
                      // itself sidesteps that branch-routing entirely and
                      // works from any entry point.
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailScreen(productId: p.id))),
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
                              aspectRatio: 1.3,
                              child: p.imageUrl != null
                                  ? Image.network(p.imageUrl!,
                                      fit: BoxFit.cover)
                                  : Container(
                                      color: AppColors.backgroundStart,
                                      child: const Icon(Icons.image_outlined)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: AppTypography.body
                                          .copyWith(fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                      '₱${p.pricePerUnit.toStringAsFixed(0)}/${p.unit}',
                                      style: AppTypography.label),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              // UW 4.1/5.1: a Smart Agreement is requested against one
              // of the farmer's open production plans, not "the
              // farmer" in general -- there was no way to reach that
              // plan-picking step at all before this list existed.
              if (farmer.cropPlans.isNotEmpty) ...[
                Text(s.openForAgreementRequestsLabel,
                    style: AppTypography.h3),
                const SizedBox(height: AppSpacing.sm),
                ...farmer.cropPlans.map((plan) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(plan.cropName,
                                      style: AppTypography.body.copyWith(
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                    '${s.stockAvailable(plan.availableQuantity.toStringAsFixed(0), plan.unit)} · ₱${plan.pricePerUnit.toStringAsFixed(2)}/${plan.unit}',
                                    style: AppTypography.bodySmall,
                                  ),
                                  Text(
                                    s.estHarvestLabel(
                                        '${plan.expectedHarvest.year}-${plan.expectedHarvest.month.toString().padLeft(2, '0')}'),
                                    style: AppTypography.label,
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: (isOwnProfile ||
                                      plan.availableQuantity <= 0)
                                  ? null
                                  : () => context.push(
                                        '/agreements/new'
                                        '?cropPlanId=${plan.id}'
                                        '&cropName=${Uri.encodeComponent(plan.cropName)}'
                                        '&sellerName=${Uri.encodeComponent(farmer.displayName)}'
                                        '&unit=${Uri.encodeComponent(plan.unit)}'
                                        '&price=${plan.pricePerUnit}'
                                        '&available=${plan.availableQuantity}'
                                        '&harvestMonth=${plan.expectedHarvest.month}'
                                        '&harvestYear=${plan.expectedHarvest.year}',
                                      ),
                              child: Text(s.requestLabel),
                            ),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: AppSpacing.sm),
              ] else ...[
                const SizedBox(height: AppSpacing.sm),
                Text(s.noOpenProductionPlansRightNow,
                    style: AppTypography.bodySmall),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
