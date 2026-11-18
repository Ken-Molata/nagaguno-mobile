// lib/features/walkthrough/domain/walkthrough_step.dart
//
// UW 2.3: "a short sequence of highlighted screen elements with brief
// explanations (for a Buyer: browsing listings, requesting against a
// production plan, finding past orders; for a Farmer or Vendor:
// creating a listing or plan, reviewing incoming requests, the
// fulfillment status buttons of Section 7.5)." Built as full-screen
// explanatory steps, not a literal overlay highlighting real on-screen
// widgets -- a more robust, more accessible choice for the elderly/
// low-vision users this app already designs around (overlay
// positioning is fragile across device sizes and text scales, exactly
// the audience this step exists to serve), while still delivering the
// same real content: a short, skippable, role-specific tour.
//
// Only Buyer and Farmer/Vendor variants exist -- Admin never reaches
// this screen at all (the router sends an admin straight to /admin),
// matching UW 2.3's own role list exactly ("relevant to their role
// (Buyer, Farmer, or Vendor)").
import 'package:flutter/material.dart';

class WalkthroughStep {
  const WalkthroughStep(
      {required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;
}

const _buyerSteps = [
  WalkthroughStep(
    icon: Icons.storefront_outlined,
    title: 'Browse Crop Listings',
    description:
        'Explore fresh produce from local farmers and vendors in the Marketplace tab.',
  ),
  WalkthroughStep(
    icon: Icons.handshake_outlined,
    title: 'Request a Production Plan',
    description:
        'Found a crop that\'s still growing? Request a Smart Agreement directly against the farmer\'s production plan.',
  ),
  WalkthroughStep(
    icon: Icons.receipt_long_outlined,
    title: 'Find Your Past Orders',
    description:
        'Check the status of anything you\'ve ordered, any time, from the Orders tab.',
  ),
];

const _sellerSteps = [
  WalkthroughStep(
    icon: Icons.add_circle_outline,
    title: 'Create a Listing or Plan',
    description:
        'List produce you\'ve already harvested, or create a production plan for a crop that\'s still growing.',
  ),
  WalkthroughStep(
    icon: Icons.inbox_outlined,
    title: 'Review Incoming Requests',
    description:
        'Buyers can request Smart Agreements against your production plans. Accept, decline, or counter-propose from the Agreements tab.',
  ),
  WalkthroughStep(
    icon: Icons.local_shipping_outlined,
    title: 'Mark Orders as You Fulfill Them',
    description:
        'Move an order from Preparing to Dispatched or Ready for Pickup as you get it ready.',
  ),
];

// UW 21.5 Tagalog variants, same titles/descriptions as _buyerSteps and
// _sellerSteps above, index-for-index -- kept as a parallel translation
// table rather than a field on WalkthroughStep itself, so the existing
// 'buyer'/'farmer'/'vendor' const lists and every test asserting
// against their exact English titles stay untouched.
const _buyerStepsTl = [
  WalkthroughStep(
    icon: Icons.storefront_outlined,
    title: 'Tingnan ang mga Listing ng Ani',
    description:
        'Tuklasin ang sariwang ani mula sa mga lokal na magsasaka at vendor sa Marketplace tab.',
  ),
  WalkthroughStep(
    icon: Icons.handshake_outlined,
    title: 'Mag-request ng Production Plan',
    description:
        'May nakita kang tanim na tumutubo pa? Mag-request ng Smart Agreement direkta sa production plan ng magsasaka.',
  ),
  WalkthroughStep(
    icon: Icons.receipt_long_outlined,
    title: 'Hanapin ang Iyong Mga Nakaraang Order',
    description:
        'Suriin ang status ng anumang in-order mo, anumang oras, mula sa Orders tab.',
  ),
];

const _sellerStepsTl = [
  WalkthroughStep(
    icon: Icons.add_circle_outline,
    title: 'Gumawa ng Listing o Plano',
    description:
        'I-list ang anihan mo, o gumawa ng production plan para sa tanim na tumutubo pa.',
  ),
  WalkthroughStep(
    icon: Icons.inbox_outlined,
    title: 'Suriin ang Papasok na Request',
    description:
        'Maaaring mag-request ang mga buyer ng Smart Agreement sa iyong mga production plan. Tanggapin, tanggihan, o mag-counter-propose mula sa Agreements tab.',
  ),
  WalkthroughStep(
    icon: Icons.local_shipping_outlined,
    title: 'Markahan ang Order Habang Inihahanda Mo',
    description:
        'Ilipat ang order mula Preparing patungong Dispatched o Ready for Pickup habang inihahanda mo ito.',
  ),
];

/// Pure, testable: which role gets which steps. Falls back to the
/// buyer steps for any unrecognized role (defensive only -- Admin is
/// the one real role excluded by the router before this screen is
/// ever reached, not by this function). [language] defaults to 'en' so
/// every existing call site and test keeps getting the original
/// English steps unchanged -- same backward-compatible pattern as
/// timeBasedGreeting's own language parameter.
List<WalkthroughStep> walkthroughStepsForRole(String role,
    {String language = 'en'}) {
  final tl = language == 'tl';
  return switch (role) {
    'farmer' || 'vendor' => tl ? _sellerStepsTl : _sellerSteps,
    _ => tl ? _buyerStepsTl : _buyerSteps,
  };
}
