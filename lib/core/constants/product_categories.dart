// lib/core/constants/product_categories.dart
//
// Consolidated from what was five separate copies of the identical
// list (four private `_categories` constants across crop plan/product
// screens, plus onboarding's own public one) -- noticed while adding
// a fifth need for it in the recommendations feature, and fixed at
// the source rather than add a sixth duplicate.

const productCategories = [
  'Vegetables',
  'Fruits',
  'Rice',
  'Herbs',
  'Root Crops',
  'Legumes',
  'Others'
];

/// Matches the web app's real emoji-per-category mapping exactly
/// (RecommendationsWidget.jsx's CROP_EMOJI_MAP) -- kept for visual
/// consistency with the existing web app, not invented separately.
const categoryEmoji = {
  'Vegetables': '🥬',
  'Fruits': '🍎',
  'Rice': '🌾',
  'Herbs': '🌿',
  'Root Crops': '🥕',
  'Legumes': '🫘',
  'Others': '📦',
};
