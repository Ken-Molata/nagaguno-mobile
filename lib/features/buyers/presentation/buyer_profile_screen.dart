// lib/features/buyers/presentation/buyer_profile_screen.dart
//
// UW 12.4 Buyer Profile (Full View). Mirrors farmer_detail_screen.dart/
// vendor_detail_screen.dart's structure (photo, name, location,
// verification badge, date joined, ratings & reviews), minus a
// Products/Open-for-Agreement section (a buyer sells nothing) and plus
// the transaction-history-with-this-seller section UW 12.4 specifically
// calls for, that those two screens don't have an equivalent of.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../shared/widgets/verification_banner.dart';
import '../../reviews/presentation/user_reviews_section.dart';
import '../../conversations/data/conversations_repository.dart';
import '../../reports/presentation/report_menu_button.dart';
import '../../reports/domain/report_models.dart';
import '../../blocks/presentation/block_user_button.dart';
import '../data/buyers_repository.dart';

final buyersRepositoryProvider = Provider<BuyersRepository>(
    (ref) => BuyersRepository(ref.watch(apiClientProvider)));

final _buyerDetailProvider = FutureProvider.autoDispose.family(
    (ref, String id) => ref.watch(buyersRepositoryProvider).getBuyerDetail(id));

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couldn\'t open conversation. Please try again.')));
    }
  }
}

class BuyerProfileScreen extends ConsumerWidget {
  const BuyerProfileScreen({super.key, required this.buyerId});
  final String buyerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buyerAsync = ref.watch(_buyerDetailProvider(buyerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyer Profile'),
        actions: [
          // UW 12.4's overflow menu: Report, pre-linked to this user,
          // and (UW 9.1's own separate bullet) Report profile picture.
          if (buyerAsync.valueOrNull != null) ...[
            ReportMenuButton(
              reportedUserId: buyerAsync.valueOrNull!.id,
              reportedUserName: buyerAsync.valueOrNull!.fullName,
              fixedGroup: ViolationGroup.buyerConduct,
            ),
            BlockUserButton(
              userId: buyerAsync.valueOrNull!.id,
              userName: buyerAsync.valueOrNull!.fullName,
            ),
          ],
        ],
      ),
      body: buyerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Couldn\'t load this buyer.')),
        data: (buyer) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.backgroundStart,
                  backgroundImage: buyer.avatarUrl != null
                      ? NetworkImage(buyer.avatarUrl!)
                      : null,
                  child: buyer.avatarUrl == null
                      ? const Icon(Icons.person,
                          size: 40, color: AppColors.primary)
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                  child: Text(buyer.fullName,
                      style: AppTypography.h1, textAlign: TextAlign.center)),
              if (buyer.barangay != null)
                Center(
                    child:
                        Text(buyer.barangay!, style: AppTypography.bodySmall)),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    VerificationBadge(isVerified: buyer.isVerified),
                    if (buyer.createdAt != null)
                      Text('Joined ${buyer.createdAt!.year}',
                          style: AppTypography.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _messageUser(context, ref,
                      userId: buyer.id, userName: buyer.fullName),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Message'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Ratings & Reviews', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.sm),
              UserReviewsSection(userId: buyerId),
              const SizedBox(height: AppSpacing.lg),
              // UW 12.4: "Past orders and agreements between this buyer
              // and the specific Farmer/Vendor viewing the profile, not
              // the buyer's full platform-wide history."
              const Text('Transaction History', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.sm),
              if (buyer.transactions.isEmpty)
                const Text('No past orders or agreements with this buyer yet.',
                    style: AppTypography.bodySmall)
              else
                ...buyer.transactions.map((t) => Padding(
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
                                  Text(
                                      t.kind == 'agreement'
                                          ? 'Smart Agreement'
                                          : 'Order',
                                      style: AppTypography.body
                                          .copyWith(fontWeight: FontWeight.w600)),
                                  Text(t.status, style: AppTypography.bodySmall),
                                ],
                              ),
                            ),
                            Text('₱${t.amount.toStringAsFixed(2)}',
                                style: AppTypography.body),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
