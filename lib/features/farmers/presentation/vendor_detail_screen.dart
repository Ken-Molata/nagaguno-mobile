// lib/features/farmers/presentation/vendor_detail_screen.dart
//
// Mirrors farmer_detail_screen.dart, minus the save/heart action (no
// saved_vendors table exists — see vendors_repository.dart's comment).
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
import '../../blocks/presentation/block_user_button.dart';
import '../../marketplace/presentation/product_detail_screen.dart';
import 'vendors_screen.dart';

final _vendorDetailProvider = FutureProvider.autoDispose.family(
    (ref, String id) =>
        ref.watch(vendorsRepositoryProvider).getVendorDetail(id));

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

class VendorDetailScreen extends ConsumerWidget {
  const VendorDetailScreen({super.key, required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorAsync = ref.watch(_vendorDetailProvider(vendorId));
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.vendorProfileTitle),
        actions: [
          // UW 9/17.7: Seller Conduct report -- role is implicit
          // (this screen only ever shows a Vendor).
          if (vendorAsync.valueOrNull != null) ...[
            ReportMenuButton(
              reportedUserId: vendorAsync.valueOrNull!.id,
              reportedUserName: vendorAsync.valueOrNull!.displayName,
              fixedGroup: ViolationGroup.sellerConduct,
            ),
            BlockUserButton(
              userId: vendorAsync.valueOrNull!.id,
              userName: vendorAsync.valueOrNull!.displayName,
            ),
          ],
        ],
      ),
      body: vendorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(s.couldntLoadVendor)),
        data: (vendor) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.backgroundStart,
                  backgroundImage: vendor.businessPhotoUrl != null
                      ? NetworkImage(vendor.businessPhotoUrl!)
                      : null,
                  child: vendor.businessPhotoUrl == null
                      ? const Icon(Icons.storefront_outlined,
                          size: 40, color: AppColors.primary)
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                  child: Text(vendor.displayName,
                      style: AppTypography.h1, textAlign: TextAlign.center)),
              if (vendor.barangay != null)
                Center(
                    child:
                        Text(vendor.barangay!, style: AppTypography.bodySmall)),
              const SizedBox(height: AppSpacing.xs),
              // UW 12.3: the profile SUBJECT's verification badge and
              // join date -- see farmer_detail_screen.dart's identical
              // fix and the comment on VerificationBadge for why
              // VerificationBanner was wrong here.
              Center(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    VerificationBadge(isVerified: vendor.isVerified),
                    if (vendor.createdAt != null)
                      Text(s.joinedYear('${vendor.createdAt!.year}'),
                          style: AppTypography.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _messageUser(context, ref,
                      userId: vendor.id, userName: vendor.displayName),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(s.messageLabel),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (vendor.aboutBusiness != null) ...[
                Text(s.aboutLabel, style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(vendor.aboutBusiness!, style: AppTypography.body),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(s.ratingsAndReviewsLabel, style: AppTypography.h3),
              const SizedBox(height: AppSpacing.sm),
              UserReviewsSection(userId: vendorId),
              const SizedBox(height: AppSpacing.lg),
              if (vendor.products.isNotEmpty) ...[
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
                  itemCount: vendor.products.length,
                  itemBuilder: (context, i) {
                    final p = vendor.products[i];
                    return InkWell(
                      // REAL BUG FOUND AND FIXED: same cross-shell-branch
                      // push failure as farmer_detail_screen.dart's own
                      // fix -- see that file's comment for the full
                      // explanation. Navigator.push works from any entry
                      // point regardless of which shell branch is active.
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
              // REAL BUG FOUND AND FIXED: a Vendor's "Open for Agreement
              // Requests" section used to sit here, same as a Farmer's --
              // per explicit direction, a Vendor can no longer own a
              // crop plan at all (routes/cropPlans.js is now Farmer-
              // only), so vendor.cropPlans is permanently empty and this
              // whole section would always render nothing but a dead
              // "No open production plans right now." Removed rather
              // than left showing a state that can never be otherwise.
            ],
          ),
        ),
      ),
    );
  }
}
