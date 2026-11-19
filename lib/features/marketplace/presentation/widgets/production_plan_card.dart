// lib/features/marketplace/presentation/widgets/production_plan_card.dart
//
// UW 5.1/12.5: a production-plan card for the marketplace's
// "Production Plans" view -- mirrors product_card.dart's seller-info
// row (photo/name/rating/barangay, overflow menu) and layout, but the
// primary action is "Request Agreement" (UW 4.1/5.1) rather than
// quick-add-to-cart, since a plan is a not-yet-harvested commitment,
// not stock a buyer can order directly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../authentication/application/auth_controller.dart';
import '../../../reports/domain/report_models.dart';
import '../../../reports/presentation/report_user_screen.dart';
import '../../domain/production_plan_listing.dart';

class ProductionPlanCard extends ConsumerWidget {
  const ProductionPlanCard({super.key, required this.plan});
  final ProductionPlanListing plan;

  void _openSellerProfile(BuildContext context) {
    final path = plan.sellerRole == 'vendor'
        ? '/vendors/${plan.sellerId}'
        : '/farmers/${plan.sellerId}';
    context.push(path);
  }

  void _openReport(BuildContext context) {
    // UW 12.1's own pre-set reason applies the same way here as it
    // does for an already-harvested listing's card.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportUserScreen(
        reportedUserId: plan.sellerId,
        reportedUserName: plan.displaySellerName,
        fixedGroup: ViolationGroup.transaction,
        initialType: 'crop_state_misrepresented',
      ),
    ));
  }

  void _requestAgreement(BuildContext context) {
    context.push('/agreements/new'
        '?cropPlanId=${plan.id}'
        '&cropName=${Uri.encodeComponent(plan.cropName)}'
        '&sellerName=${Uri.encodeComponent(plan.displaySellerName)}'
        '&unit=${Uri.encodeComponent(plan.unit)}'
        '&price=${plan.pricePerUnit ?? 0}'
        '&available=${plan.availableQuantity}'
        '&harvestMonth=${plan.expectedHarvest.month}'
        '&harvestYear=${plan.expectedHarvest.year}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // REAL BUG FOUND AND FIXED, live-caught: a Farmer toggled into
    // buyer mode could tap their OWN production plan here and reach
    // the agreement-request form -- POST /agreements already rejects
    // it server-side (farmer_id === buyer_id, "You cannot request your
    // own production plan."), but this card gave no indication
    // beforehand and still navigated on tap. Same self-ownership check
    // product_card.dart uses for its own quick-add button.
    final isOwnPlan =
        ref.watch(authControllerProvider).user?.id == plan.sellerId;
    return GestureDetector(
      onTap: isOwnPlan ? null : () => _requestAgreement(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: plan.imageUrl != null
                      ? Image.network(plan.imageUrl!, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.backgroundStart,
                          child: const Icon(Icons.eco_outlined,
                              size: 40, color: AppColors.textMuted)),
                ),
                if (isOwnPlan)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: const Text('Your plan',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'DMSans')),
                    ),
                  ),
                Positioned(
                  bottom: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert,
                          size: 16, color: Colors.white),
                      tooltip: 'More options',
                      onSelected: (value) => value == 'seller'
                          ? _openSellerProfile(context)
                          : _openReport(context),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                            value: 'seller',
                            child: Text('View seller profile')),
                        PopupMenuItem(value: 'report', child: Text('Report')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.cropName,
                      style: AppTypography.h3.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                      plan.pricePerUnit != null
                          ? '₱${plan.pricePerUnit!.toStringAsFixed(0)}/${plan.unit}'
                          : 'Price TBD',
                      style: AppTypography.h3
                          .copyWith(fontSize: 15, color: AppColors.primary)),
                  Text(
                      '${plan.availableQuantity.toStringAsFixed(0)} ${plan.unit} available',
                      style: AppTypography.bodySmall),
                  Text(
                      'Est. harvest: ${plan.expectedHarvest.year}-${plan.expectedHarvest.month.toString().padLeft(2, '0')}',
                      style: AppTypography.label
                          .copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openSellerProfile(context),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: AppColors.backgroundStart,
                          backgroundImage: plan.displaySellerPhoto != null
                              ? NetworkImage(plan.displaySellerPhoto!)
                              : null,
                          child: plan.displaySellerPhoto == null
                              ? const Icon(Icons.person,
                                  size: 10, color: AppColors.textMuted)
                              : null,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(plan.displaySellerName,
                              style:
                                  AppTypography.label.copyWith(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (plan.sellerRating != null) ...[
                          const Icon(Icons.star,
                              size: 11, color: AppColors.accent),
                          const SizedBox(width: 2),
                          Text(plan.sellerRating!.toStringAsFixed(1),
                              style:
                                  AppTypography.label.copyWith(fontSize: 10)),
                        ],
                      ],
                    ),
                  ),
                  if (plan.sellerBarangay != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 10, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(plan.sellerBarangay!,
                              style: AppTypography.bodySmall.copyWith(
                                  fontSize: 10, color: AppColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
