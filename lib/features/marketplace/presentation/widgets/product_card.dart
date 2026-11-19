// lib/features/marketplace/presentation/widgets/product_card.dart
//
// UW 12.1: "Applies identically in both marketplace views... a crop
// listing card and a production plan card both show the same seller
// preview." This card previously showed only the seller's name behind
// a static verified checkmark -- the profile photo, barangay, and
// rating UW 12.1 also names were never rendered (barangay/photo were
// already on the Product model and simply unused; rating didn't exist
// anywhere in the GET /marketplace/products response at all, added
// alongside this). Also adds the card's own three-dot overflow menu
// (View seller profile / Report, pre-set to "Crop state misrepresented
// at listing" and pre-linked to this product) -- grepped this file and
// product_detail_screen.dart before this change: neither had ANY
// report entry point, despite UW 9.1 naming "a product card's overflow
// menu" as one of six places a report can start from.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../authentication/application/auth_controller.dart';
import '../../../cart/application/cart_controller.dart';
import '../../../cart/domain/cart_item.dart';
import '../../../reports/domain/report_models.dart';
import '../../../reports/presentation/report_user_screen.dart';
import '../../domain/product.dart';

class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  void _quickAddToCart(BuildContext context, WidgetRef ref) {
    if (product.stockQty == 0) return; // guarded by the disabled button below too
    ref.read(cartControllerProvider.notifier).addItem(CartItem(
          productId: product.id,
          sellerId: product.sellerId,
          sellerName: product.displaySellerName,
          name: product.name,
          unit: product.unit,
          unitPrice: product.displayPrice,
          quantity: 1,
          imageUrl: product.imageUrl,
          maxStock: product.stockQty,
        ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Added ${product.name} to cart.'),
          duration: const Duration(seconds: 1)),
    );
  }

  void _openSellerProfile(BuildContext context) {
    final path = product.sellerRole == 'vendor'
        ? '/vendors/${product.sellerId}'
        : '/farmers/${product.sellerId}';
    context.push(path);
  }

  void _openReport(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportUserScreen(
        reportedUserId: product.sellerId,
        reportedUserName: product.displaySellerName,
        fixedGroup: ViolationGroup.transaction,
        initialType: 'crop_state_misrepresented',
        productId: product.id,
      ),
    ));
  }

  Widget _maybeGrayscale(bool apply, Widget child) {
    if (!apply) return child;
    return ColorFiltered(
      colorFilter:
          const ColorFilter.mode(Colors.white, BlendMode.saturation),
      child: child,
    );
  }

  Color _spoilageColor(String? stage) {
    switch (stage) {
      case 'near_spoilage':
        return AppColors.spoilageNear;
      case 'critical':
        return AppColors.spoilageCritical;
      case 'expired':
        return AppColors.spoilageExpired;
      default:
        return AppColors.spoilageFresh;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final isSoldOut = product.stockQty == 0;
    // REAL BUG FOUND AND FIXED, live-caught: a Farmer/Vendor toggled
    // into buyer mode could quick-add their OWN listing to cart from
    // this card's floating button, with nothing in the UI suggesting
    // it was their own product -- POST /orders now rejects it
    // server-side (seller_id === buyer_id), but the button itself was
    // still shown and tappable. Hidden here, matching the same check
    // the backend guard uses.
    final isOwnListing =
        ref.watch(authControllerProvider).user?.id == product.sellerId;
    return GestureDetector(
      onTap: onTap,
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
                  child: _maybeGrayscale(
                    isSoldOut,
                    product.imageUrl != null
                        ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.backgroundStart,
                            child: const Icon(Icons.image_outlined,
                                size: 40, color: AppColors.textMuted)),
                  ),
                ),
                // Quantity is a real 0, not "unknown" (stockQty is nullable
                // and null means the field just isn't tracked) -- a buyer
                // tapping through to a fully out-of-stock listing with no
                // signal at all was the gap here.
                if (isSoldOut)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(AppRadius.sm)),
                        child: Text(s.soldOutLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'DMSans')),
                      ),
                    ),
                  ),
                if (!isSoldOut && product.hasActiveDiscount)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Text(
                          '${((product.flashSaleDiscountPct ?? 0) * 100).toStringAsFixed(0)}% OFF', // ×100: the real value is a fraction (0.30), not a percentage number (30) — verified against the backend
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'DMSans')),
                    ),
                  ),
                if (product.spoilageStage != null &&
                    product.spoilageStage != 'fresh')
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: _spoilageColor(product.spoilageStage),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                    ),
                  ),
                if (!isSoldOut && !isOwnListing)
                  Positioned(
                    bottom: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _quickAddToCart(context, ref),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.add_shopping_cart,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                // UW 9.1/12.1: the card's own three-dot overflow --
                // View seller profile (same destination as tapping the
                // seller row below) / Report (pre-linked to this
                // listing, violation type pre-set to "Crop state
                // misrepresented at listing").
                Positioned(
                  bottom: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon:
                          const Icon(Icons.more_vert, size: 16, color: Colors.white),
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
                  Text(product.name,
                      style: AppTypography.h3.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (product.hasActiveDiscount) ...[
                        Text('₱${product.pricePerUnit.toStringAsFixed(0)}',
                            style: AppTypography.bodySmall.copyWith(
                                decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                          '₱${product.displayPrice.toStringAsFixed(0)}/${product.unit}',
                          style: AppTypography.h3.copyWith(
                              fontSize: 15, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // UW 12.1: seller profile photo, name, and rating --
                  // tapping any of it "opens their full profile, rather
                  // than showing more detail inline."
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openSellerProfile(context),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: AppColors.backgroundStart,
                          backgroundImage: product.displaySellerPhoto != null
                              ? NetworkImage(product.displaySellerPhoto!)
                              : null,
                          child: product.displaySellerPhoto == null
                              ? const Icon(Icons.person,
                                  size: 10, color: AppColors.textMuted)
                              : null,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(product.displaySellerName,
                              style:
                                  AppTypography.label.copyWith(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (product.sellerRating != null) ...[
                          const Icon(Icons.star,
                              size: 11, color: AppColors.accent),
                          const SizedBox(width: 2),
                          Text(product.sellerRating!.toStringAsFixed(1),
                              style:
                                  AppTypography.label.copyWith(fontSize: 10)),
                        ],
                      ],
                    ),
                  ),
                  // UW 12.1: seller location (barangay/area of origin).
                  if (product.sellerBarangay != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 10, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(product.sellerBarangay!,
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
