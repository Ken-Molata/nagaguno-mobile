// lib/features/marketplace/presentation/product_detail_screen.dart
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
import '../../authentication/application/auth_controller.dart';
import '../../../core/utils/pricing.dart';
import '../application/marketplace_providers.dart';
import '../../reviews/presentation/product_reviews_section.dart';
import '../../recommendations/presentation/similar_products_section.dart';
import '../../cart/application/cart_controller.dart';
import '../../cart/domain/cart_item.dart';
import '../../cart/presentation/widgets/cart_icon_button.dart';
import '../../buyer_mode/presentation/widgets/buyer_mode_banner.dart';
import '../../../core/accessibility/read_aloud_button.dart';
import '../domain/product.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  double _quantity = 1;

  // Placing an order needs a payment method, a fulfillment method, and
  // delivery/pickup details (POST /orders' real validateFulfillment()
  // contract) -- CheckoutScreen collects that instead of this button
  // calling placeOrder() directly with none of it.
  void _goToCheckout() {
    context.push('/checkout?productId=${widget.productId}&quantity=$_quantity');
  }

  void _addToCart(Product product) {
    ref.read(cartControllerProvider.notifier).addItem(CartItem(
          productId: product.id,
          sellerId: product.sellerId,
          sellerName: product.displaySellerName,
          name: product.name,
          unit: product.unit,
          unitPrice: product.displayPrice,
          quantity: _quantity,
          imageUrl: product.imageUrl,
          maxStock: product.stockQty,
        ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ref.read(appStringsProvider).addedToCartMessage(
              _quantity.toStringAsFixed(0), product.unit, product.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(s.couldntLoadProduct)),
        data: (product) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                actions: const [CartIconButton()],
                flexibleSpace: FlexibleSpaceBar(
                  background: product.imageUrl != null
                      ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.backgroundStart,
                          child: const Icon(Icons.image_outlined, size: 60)),
                ),
              ),
              const SliverToBoxAdapter(child: BuyerModeBanner()),
              const SliverToBoxAdapter(child: VerificationBanner()),
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                sliver: SliverList(
                    delegate: SliverChildListDelegate([
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.backgroundStart,
                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text(product.category, style: AppTypography.label),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                          child: Text(product.name, style: AppTypography.h1)),
                      // UW 21.6 Read Aloud, for "listings" -- reads the
                      // name and description together; self-hides when
                      // the setting is off.
                      ReadAloudButton(
                          text: product.description == null
                              ? product.name
                              : '${product.name}. ${product.description}'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      if (product.hasActiveDiscount) ...[
                        Text('₱${product.pricePerUnit.toStringAsFixed(2)}',
                            style: AppTypography.body.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: AppColors.textMuted)),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                          '₱${product.displayPrice.toStringAsFixed(2)} / ${product.unit}',
                          style: AppTypography.h2),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 18, color: AppColors.textMuted),
                      const SizedBox(width: AppSpacing.xs),
                      // REAL BUG FOUND AND FIXED: this used to be
                      // non-tappable for vendor-sold products on the
                      // claim that no vendor profile screen existed --
                      // that's no longer true (app_router.dart's
                      // '/vendors/:id' + vendor_detail_screen.dart),
                      // and every other seller-name link in the app
                      // (product_card.dart, production_plan_card.dart,
                      // recommendations_widget.dart) already branches
                      // on sellerRole the same way. This was the one
                      // remaining dead end for a buyer trying to reach
                      // a vendor's profile from a product they found
                      // in the marketplace.
                      InkWell(
                        onTap: () => context.push(product.sellerRole ==
                                'vendor'
                            ? '/vendors/${product.sellerId}'
                            : '/farmers/${product.sellerId}'),
                        child: Text(product.displaySellerName,
                            style: AppTypography.body.copyWith(
                                decoration: TextDecoration.underline)),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.verified,
                          size: 16, color: AppColors.secondary),
                    ],
                  ),
                  if (product.sellerBarangay != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.textMuted),
                        const SizedBox(width: AppSpacing.xs),
                        Text(product.sellerBarangay!,
                            style: AppTypography.bodySmall),
                      ],
                    ),
                  ],
                  if (product.stockQty != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    product.stockQty == 0
                        ? Text(s.soldOutLabel,
                            style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700))
                        : Text(
                            s.stockAvailable(
                                '${product.stockQty}', product.unit),
                            style: AppTypography.bodySmall),
                  ],
                  if (product.description != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(product.description!, style: AppTypography.body),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(s.quantityLabel, style: AppTypography.label),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      IconButton.outlined(
                        onPressed: _quantity > 1 && product.stockQty != 0
                            ? () => setState(() => _quantity--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      SizedBox(
                          width: 60,
                          child: Text('$_quantity',
                              textAlign: TextAlign.center,
                              style: AppTypography.h3)),
                      IconButton.outlined(
                        // Previously had no upper bound at all -- a
                        // user could increment past available stock
                        // and only find out via a rejected order
                        // afterward. The real backend already
                        // validates this server-side (stock_qty <
                        // requested quantity is rejected), so this is
                        // a UX fix, not a data-integrity one, but
                        // still worth catching before submission.
                        onPressed: (product.stockQty == null ||
                                _quantity < product.stockQty!)
                            ? () => setState(() => _quantity++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                      const Spacer(),
                      Text(
                          '${s.totalPrefix}₱${calculateTotal(quantity: _quantity, pricePerUnit: product.displayPrice).toStringAsFixed(2)}',
                          style: AppTypography.h3),
                    ],
                  ),
                  if (product.stockQty != null &&
                      _quantity >= product.stockQty!) ...[
                    const SizedBox(height: 4),
                    Text(s.maximumAvailableQuantityReached,
                        style: AppTypography.label
                            .copyWith(color: AppColors.accentDark)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SimilarProductsSection(productId: product.id),
                  const SizedBox(height: AppSpacing.lg),
                  Text(s.reviewsLabel, style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.sm),
                  ProductReviewsSection(productId: product.id),
                ])),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: productAsync.maybeWhen(
        data: (product) {
          // REAL BUG FOUND AND FIXED, live-caught: a Farmer/Vendor
          // toggled into buyer mode could open their OWN listing here
          // and both Add to Cart and Place Order worked right up until
          // POST /orders' new seller_id === buyer_id guard rejected it
          // -- nothing in this screen told them why beforehand. Same
          // self-listing check as product_card.dart's quick-add button.
          final isOwnListing =
              ref.watch(authControllerProvider).user?.id == product.sellerId;
          if (isOwnListing) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: Text(s.thisIsYourOwnListing,
                            style: AppTypography.bodySmall)),
                  ],
                ),
              ),
            );
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: product.stockQty == 0
                          ? null
                          : () => _addToCart(product),
                      icon: const Icon(Icons.add_shopping_cart_outlined,
                          size: 18),
                      label: Text(product.stockQty == 0
                          ? s.soldOutLabel
                          : s.addToCartLabel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: product.stockQty == 0
                        ? ElevatedButton(
                            onPressed: null,
                            child: Text(s.soldOutLabel),
                          )
                        : LockedButton(
                            label: s.placeOrderLabel,
                            onPressed: _goToCheckout,
                          ),
                  ),
                ],
              ),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }
}
