// lib/features/onboarding/presentation/preferences_settings_screen.dart
//
// UW 21.4 "Preferences & Interests": "Shown to Buyers and to Vendors
// in their buying capacity, as in Section 1.1." REAL, CONCRETE GAP
// FOUND AND FIXED this pass: Settings' own "Preferences & Interests"
// tile (profile_screen.dart) routed straight to OnboardingFlowScreen
// -- the first-time registration wizard ("Welcome to NagaGuno, Name!",
// "Get Started"/"Set Up Later", a "Your NagaGuno is ready" completion
// screen) -- every time, for every role including Farmer, and always
// starting from a BLANK selection regardless of what was already
// saved. That directly contradicts UW 21.9's "Any setting... can be
// reached from Settings or from the place where it comes up. Either
// way it is the same setting" -- reopening this from Settings should
// show and edit the CURRENT saved preferences, not silently reset
// them. This screen does that: loads GET /profiles/preferences first,
// pre-fills every control, and saves via the same PATCH endpoint and
// exact "Preferences saved." message onboarding already used.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/product_categories.dart';
import '../../../core/theme/app_theme.dart';
import 'onboarding_flow_screen.dart' show preferencesRepositoryProvider;
import '../domain/preferences.dart';

final _preferencesProvider = FutureProvider.autoDispose<UserPreferences>(
    (ref) => ref.watch(preferencesRepositoryProvider).getPreferences());

class PreferencesSettingsScreen extends ConsumerWidget {
  const PreferencesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(_preferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences & Interests')),
      body: SafeArea(
        child: preferencesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Couldn\'t load your preferences.'),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                  onPressed: () => ref.invalidate(_preferencesProvider),
                  child: const Text('Retry')),
            ]),
          ),
          data: (preferences) => _PreferencesForm(initial: preferences),
        ),
      ),
    );
  }
}

class _PreferencesForm extends ConsumerStatefulWidget {
  const _PreferencesForm({required this.initial});
  final UserPreferences initial;

  @override
  ConsumerState<_PreferencesForm> createState() => _PreferencesFormState();
}

class _PreferencesFormState extends ConsumerState<_PreferencesForm> {
  late final Set<String> _selectedCategories =
      widget.initial.selectedCategories.toSet();
  late String? _pricePreference = widget.initial.pricePreference;
  late final Set<String> _recommendationPriorities =
      widget.initial.recommendationPriorities.toSet();
  bool _saving = false;
  String? _errorMessage;

  Future<void> _save() async {
    // UW 21.4: "At least one must stay selected: 'Select at least one
    // category.'" Checked client-side so the user sees it immediately,
    // matching the backend's own identical validation exactly.
    if (_selectedCategories.isEmpty) {
      setState(() => _errorMessage = 'Select at least one category.');
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(preferencesRepositoryProvider).submitPreferences(
            selectedCategories: _selectedCategories.toList(),
            pricePreference: _pricePreference,
            recommendationPriorities: _recommendationPriorities.toList(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preferences saved.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage =
            'We couldn\'t save your preferences. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
                color: AppColors.statusCancelledBg,
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text(_errorMessage!,
                style: const TextStyle(color: AppColors.statusCancelledFg)),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const Text('Crop categories', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: productCategories
              .map((cat) => FilterChip(
                    label: Text(cat),
                    selected: _selectedCategories.contains(cat),
                    onSelected: _saving
                        ? null
                        : (selected) => setState(() => selected
                            ? _selectedCategories.add(cat)
                            : _selectedCategories.remove(cat)),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        const Text('Price preference', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: pricePreferenceOptions
              .map((p) => ChoiceChip(
                    label: Text(p),
                    selected: _pricePreference == p,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _pricePreference = p),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        const Text('Shopping preferences', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: shoppingPreferenceOptions.entries
              .map((e) => FilterChip(
                    label: Text(e.value),
                    selected: _recommendationPriorities.contains(e.key),
                    onSelected: _saving
                        ? null
                        : (selected) => setState(() => selected
                            ? _recommendationPriorities.add(e.key)
                            : _recommendationPriorities.remove(e.key)),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent))
              : const Text('Save Preferences'),
        ),
      ],
    );
  }
}
