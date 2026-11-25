// lib/features/walkthrough/presentation/walkthrough_screen.dart
//
// UW 2.3 First-Time Walkthrough. Reached two ways: automatically, via
// app_router.dart's redirect, the first time an authenticated user
// who hasn't seen it yet navigates anywhere other than /onboarding or
// here itself; or manually, replayed from Profile ("App Walkthrough"
// tile) -- same screen either way, per the spec's own "may replay it
// later."
//
// "The walkthrough can be skipped at any point and never blocks
// access to the platform" -- Skip and the final "Get Started" do the
// exact same thing (mark seen, go home); there is no way to get stuck
// here.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope. The
// per-role step content itself is translated too, via
// walkthrough_step.dart's own language parameter (same backward-
// compatible pattern as greeting.dart's timeBasedGreeting).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/localization/app_strings.dart';
import '../../authentication/application/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/walkthrough_step.dart';

final _profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(apiClientProvider)));

// Keys are the stored data values (unchanged); labels renamed by rank
// to the conventional Small/Default/Large/Extra Large ladder, same as
// accessibility_settings_screen.dart's full Settings-page equivalent.
Map<String, String> _textSizeLabels(AppStrings s) => {
      'standard': s.textSizeSmall,
      'large': s.textSizeDefault,
      'extra_large': s.textSizeLarge,
      'maximum': s.textSizeExtraLarge,
    };

class WalkthroughScreen extends ConsumerStatefulWidget {
  const WalkthroughScreen({super.key});
  @override
  ConsumerState<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends ConsumerState<WalkthroughScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _finishing = false;

  int get _pageCount {
    final role = ref.read(authControllerProvider).user?.role ?? 'buyer';
    return 1 + walkthroughStepsForRole(role).length; // text-size step + role steps
  }

  Future<void> _setTextSize(String value) async {
    try {
      await ref
          .read(_profileRepositoryProvider)
          .updateAccountSettings(textSize: value);
      await ref.read(authControllerProvider.notifier).refreshUser();
    } catch (_) {
      // Best-effort, same as every other accessibility toggle in this
      // app -- a failed save here shouldn't block moving through the
      // walkthrough itself.
    }
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      await ref.read(_profileRepositoryProvider).markWalkthroughSeen();
      await ref.read(authControllerProvider.notifier).refreshUser();
    } catch (_) {
      // Best-effort: even if marking "seen" fails, the user must
      // still reach home -- "never blocks access to the platform."
    }
    if (mounted) context.go('/home');
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authControllerProvider).user?.role ?? 'buyer';
    final s = ref.watch(appStringsProvider);
    final steps = walkthroughStepsForRole(role, language: s.language);
    final isLastPage = _page == steps.length; // index 0 is the text-size step

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              bottom: 88,
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _TextSizeStep(onChanged: _setTextSize),
                  for (final step in steps) _StepCard(step: step),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: TextButton(
                  onPressed: _finishing ? null : _finish,
                  child: Text(s.skipLabel),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(
                        _pageCount,
                        (i) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _page
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_page > 0)
                          TextButton(
                              onPressed: _back, child: Text(s.backLabel)),
                        const SizedBox(width: AppSpacing.sm),
                        ElevatedButton(
                          // REAL BUG FOUND AND FIXED: the app-wide
                          // ElevatedButtonTheme sets minimumSize to
                          // Size.fromHeight(48), i.e. Size(double.infinity,
                          // 48) -- a deliberate "full width by default"
                          // style that only works when the button sits in
                          // a context giving it bounded width (a Column, or
                          // an explicit SizedBox). Placed directly in a Row
                          // (to sit beside the dots/Back button) it instead
                          // receives unbounded width from the Row, and
                          // Size.fromHeight's infinite minWidth then can
                          // never be satisfied -- confirmed via the Dart VM
                          // service's debugDumpRenderTree: this button's
                          // entire subtree sat permanently
                          // NEEDS-LAYOUT/constraints-and-size-MISSING, with
                          // no exception ever thrown, which is what made
                          // this whole screen appear to silently freeze
                          // (every sibling after it in the same Column
                          // never got a layout pass either). This is the
                          // only ElevatedButton in the app placed inside a
                          // Row rather than a Column, which is why no other
                          // screen ever hit it. Overriding minimumSize here
                          // to a finite width fixes it without touching the
                          // shared theme.
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(64, 48)),
                          onPressed: _finishing ? null : _next,
                          child: Text(isLastPage ? s.getStarted : s.nextLabel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _TextSizeStep extends ConsumerWidget {
  const _TextSizeStep({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textSize =
        ref.watch(authControllerProvider).user?.textSize ?? 'standard';
    final s = ref.watch(appStringsProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_size, size: 48, color: AppColors.primary),
          const SizedBox(height: AppSpacing.md),
          Text(s.isTheTextEasyToRead, style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(s.pickComfortableSizeNote, style: AppTypography.body),
          const SizedBox(height: AppSpacing.lg),
          RadioGroup<String>(
            groupValue: textSize,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            child: Column(
              children: _textSizeLabels(s)
                  .entries
                  .map((e) => RadioListTile<String>(
                      title: Text(e.value,
                          style: AppTypography.body.copyWith(
                              fontSize: 15 *
                                  switch (e.key) {
                                    'large' => 1.25,
                                    'extra_large' => 1.5,
                                    'maximum' => 1.75,
                                    _ => 1.0,
                                  })),
                      value: e.key,
                      contentPadding: EdgeInsets.zero))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});
  final WalkthroughStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(step.icon, size: 64, color: AppColors.primary),
          const SizedBox(height: AppSpacing.lg),
          Text(step.title,
              style: AppTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(step.description,
              style: AppTypography.body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
