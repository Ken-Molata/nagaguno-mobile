// lib/features/onboarding/presentation/onboarding_flow_screen.dart
//
// Simplified from the original 5-screen spec to 4, deliberately: the
// spec's "Role-Specific" screen (buyer shopping context: household/
// bulk/restaurant, etc.) has no corresponding backend column — only
// selected_categories, price_preference, and recommendation_priority
// actually exist (migration 004, buyer_profiles/farmer_profiles/
// vendor_profiles). Building a screen that collects data with nowhere
// real to persist it would be dishonest UI, not a shortcut worth
// taking. Farmer/vendor skip the discovery-preferences step entirely
// (those two columns only exist on buyer_profiles), going straight
// from categories to completion.

import '../../../core/constants/product_categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/localization/app_strings.dart';
import '../../authentication/application/auth_controller.dart';
import '../../vendor_permits/presentation/business_permit_submission_screen.dart';
import '../data/preferences_repository.dart';
import '../domain/preferences.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
    (ref) => PreferencesRepository(ref.watch(apiClientProvider)));

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});
  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  // 0 = welcome, 1 = categories, 2 = discovery (buyer only),
  // 3 = business permit (vendor only), 4 = completion.
  int _step = 0;
  final Set<String> _selectedCategories = {};
  String? _pricePreference;
  final Set<String> _recommendationPriorities = {};
  bool _submitting = false;

  bool get _isBuyer => ref.read(authControllerProvider).user?.isBuyer ?? false;
  bool get _isVendor =>
      ref.read(authControllerProvider).user?.isVendor ?? false;

  void _next() {
    if (_step == 1) {
      if (_isBuyer) {
        setState(() => _step = 2);
        return;
      }
      if (_isVendor) {
        // Vendor accounts resell produce rather than selling what they
        // grow themselves (routes/vendorPermits.js's own reasoning) --
        // ask for proof of a real registered business before they can
        // start listing, right alongside KYC verification.
        setState(() => _step = 3);
        return;
      }
      _submitAndFinish(); // farmer skips straight to completion
      return;
    }
    setState(() => _step++);
  }

  Future<void> _submitAndFinish() async {
    setState(() => _submitting = true);
    try {
      await ref.read(preferencesRepositoryProvider).submitPreferences(
            selectedCategories: _selectedCategories.toList(),
            pricePreference: _pricePreference,
            recommendationPriorities: _recommendationPriorities.toList(),
          );
      setState(() => _step = 4);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                ref.read(appStringsProvider).couldntSavePreferences)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: SafeArea(
        child: switch (_step) {
          0 => _buildWelcome(s),
          1 => _buildCategorySelection(s),
          2 => _buildDiscoveryPreferences(s),
          // allowSkip: false -- see that parameter's own doc comment.
          // A Vendor must at least submit (not necessarily be approved
          // yet) before onboarding can finish, same restriction KYC
          // already carries at the action level (requireVerified on
          // routes/products.js, routes/agreement.js).
          3 => BusinessPermitSubmissionScreen(
              onDone: _submitAndFinish, allowSkip: false),
          _ => _buildCompletion(s),
        },
      ),
    );
  }

  Widget _buildWelcome(AppStrings s) {
    final name =
        ref.read(authControllerProvider).user?.fullName.split(' ').first ?? '';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(s.welcomeToNagaGuno(name),
              textAlign: TextAlign.center,
              style: AppTypography.display.copyWith(fontSize: 28)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            s.chooseInterestsIntro,
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(onPressed: _next, child: Text(s.getStarted)),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => context.go('/home'),
            child: Text(s.setUpLater),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelection(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.whatAreYouInterestedIn, style: AppTypography.h1),
          const SizedBox(height: AppSpacing.xs),
          Text(s.chooseOneOrMore, style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.6,
              children: productCategories.map((cat) {
                final selected = _selectedCategories.contains(cat);
                return _CategoryCard(
                  label: cat,
                  selected: selected,
                  onTap: () => setState(() => selected
                      ? _selectedCategories.remove(cat)
                      : _selectedCategories.add(cat)),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: _selectedCategories.isEmpty ? null : _next,
            child: Text(s.continueLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryPreferences(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.aCoupleMoreThings, style: AppTypography.h1),
          const SizedBox(height: AppSpacing.xs),
          Text(s.thisStepIsOptional, style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          Text(s.pricePreference, style: AppTypography.label),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: pricePreferenceOptions
                .map((p) => ChoiceChip(
                      label: Text(p),
                      selected: _pricePreference == p,
                      onSelected: (_) => setState(() => _pricePreference = p),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          // UW 21.4: "Shopping preferences: Proximity, Freshness,
          // Affordability. All optional; the user may clear every
          // one." A multi-select (FilterChip, not ChoiceChip) --
          // these three are independent toggles, not a single choice.
          Text(s.whatMattersMostToYou, style: AppTypography.label),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: shoppingPreferenceOptions.entries
                .map((e) => FilterChip(
                      label: Text(e.value),
                      selected: _recommendationPriorities.contains(e.key),
                      onSelected: (selected) => setState(() => selected
                          ? _recommendationPriorities.add(e.key)
                          : _recommendationPriorities.remove(e.key)),
                    ))
                .toList(),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _submitting ? null : _submitAndFinish,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent))
                : Text(s.continueLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletion(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle,
              size: 64, color: AppColors.statusSuccessFg),
          const SizedBox(height: AppSpacing.md),
          Text(s.yourNagaGunoIsReady,
              style: AppTypography.h1, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            s.onboardingCompletionBody,
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
              onPressed: () => context.go('/home'),
              child: Text(s.exploreNagaGuno)),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.body.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
