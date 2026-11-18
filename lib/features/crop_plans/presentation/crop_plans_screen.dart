// lib/features/crop_plans/presentation/crop_plans_screen.dart
//
// Crop card follows the same countdown-hero pattern already
// established and validated for the web app this session (large
// urgency-colored number + small label), not a generic list item.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../../../shared/widgets/verification_banner.dart';
import '../../buyer_mode/application/buyer_mode_controller.dart';
import '../../buyer_mode/presentation/widgets/buyer_mode_banner.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/presentation/widgets/production_plan_card.dart';
import '../data/crop_plans_repository.dart';
import '../domain/crop_plan.dart';
import 'add_crop_plan_screen.dart';
import 'edit_crop_plan_screen.dart';
import 'create_listing_from_plan_screen.dart';

final cropPlansRepositoryProvider = Provider<CropPlansRepository>(
    (ref) => CropPlansRepository(ref.watch(apiClientProvider)));

/// Previously the repository already supported filtering by stage,
/// but nothing in the UI exposed it -- this screen always fetched
/// every stage with no way to narrow down, unlike Orders/Agreements'
/// equivalent status filters.
final _stageFilterProvider = StateProvider<CropStage?>((ref) => null);

final cropPlansProvider = FutureProvider.autoDispose<List<CropPlan>>((ref) {
  final stage = ref.watch(_stageFilterProvider);
  return ref.watch(cropPlansRepositoryProvider).getCropPlans(stage: stage);
});

class CropPlansScreen extends ConsumerWidget {
  const CropPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);

    // REAL GAP FOUND AND FIXED: this screen never once checked
    // buyerModeProvider -- a Farmer/Vendor who switched into Buyer
    // mode (UW 1.5) still saw their own "manage my crop plans" screen
    // here (Add Crop FAB, edit/delete/stage menu) with no way to
    // instead browse OTHER sellers' production plans to request a
    // Smart Agreement against, which is the entire point of buyer
    // mode. Now reuses the exact same market-wide Production Plans
    // browse view the Marketplace tab's own "Production Plans" toggle
    // already shows (same provider, same card widget) -- not a second,
    // separately-built browse screen.
    if (ref.watch(buyerModeProvider)) {
      return _BuyerModeProductionBrowse(s: s);
    }

    final plansAsync = ref.watch(cropPlansProvider);
    final selectedStage = ref.watch(_stageFilterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.myProductionTitle)),
      floatingActionButton: LockedButton(
        label: s.addCropLabel,
        onPressed: () async {
          await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddCropPlanScreen()));
          ref.invalidate(cropPlansProvider);
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VerificationBanner(),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                itemCount: CropStage.values.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return ChoiceChip(
                      label: Text(s.allLabel),
                      selected: selectedStage == null,
                      onSelected: (_) =>
                          ref.read(_stageFilterProvider.notifier).state = null,
                    );
                  }
                  final stage = CropStage.values[i - 1];
                  return ChoiceChip(
                    label: Text(s.cropStageLabel(stage.name)),
                    selected: selectedStage == stage,
                    onSelected: (_) =>
                        ref.read(_stageFilterProvider.notifier).state = stage,
                  );
                },
              ),
            ),
            Expanded(
              child: plansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.couldntLoadCropPlans),
                    const SizedBox(height: AppSpacing.sm),
                    ElevatedButton(
                        onPressed: () => ref.invalidate(cropPlansProvider),
                        child: Text(s.retry)),
                  ]),
                ),
                data: (plans) {
                  if (plans.isEmpty) {
                    final message = selectedStage == null
                        ? s.noCropPlansYetTapAddCrop
                        : s.noCropPlansWithStage(
                            s.cropStageLabel(selectedStage.name));
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(message, textAlign: TextAlign.center),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(cropPlansProvider.future),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.md, AppSpacing.md, 80),
                      children: plans.map((p) => _CropCard(plan: p)).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Buyer-mode view of the Production tab -- browse every seller's
/// published production plans and request a Smart Agreement against
/// one, exactly as the Marketplace tab's own "Production Plans"
/// toggle already does. See this screen's own build() comment for why
/// this exists instead of the Farmer/Vendor's usual manage view.
class _BuyerModeProductionBrowse extends ConsumerWidget {
  const _BuyerModeProductionBrowse({required this.s});
  final AppStrings s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(productionPlansProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.productionPlansLabel)),
      body: SafeArea(
        child: Column(
          children: [
            const BuyerModeBanner(),
            Expanded(
              child: plansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.couldntLoadProductionPlans),
                    const SizedBox(height: AppSpacing.sm),
                    ElevatedButton(
                        onPressed: () => ref.invalidate(productionPlansProvider),
                        child: Text(s.retry)),
                  ]),
                ),
                data: (plans) {
                  if (plans.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(s.noProductionPlansOpenForRequests,
                            textAlign: TextAlign.center),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(productionPlansProvider.future),
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.md, AppSpacing.md, 80),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: plans.length,
                      itemBuilder: (context, i) =>
                          ProductionPlanCard(plan: plans[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropCard extends ConsumerWidget {
  const _CropCard({required this.plan});
  final CropPlan plan;

  Color _urgencyColor(int? days) {
    if (days == null) return AppColors.textMuted;
    if (days <= 3) return AppColors.spoilageCritical;
    if (days <= 7) return AppColors.spoilageNear;
    return AppColors.spoilageFresh;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = plan.daysRemaining;
    final isPastDue = days != null && days < 0;
    final s = ref.watch(appStringsProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                isPastDue ? s.dueLabel : '${days ?? '—'}',
                style: AppTypography.display
                    .copyWith(fontSize: 36, color: _urgencyColor(days)),
              ),
              Text(isPastDue ? '' : s.daysLabel, style: AppTypography.label),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (plan.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.network(plan.imageUrl!,
                            width: 32, height: 32, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Expanded(
                        child: Text(plan.cropName, style: AppTypography.h3)),
                  ],
                ),
                Text(plan.category, style: AppTypography.bodySmall),
                const SizedBox(height: 4),
                Text(
                    '${plan.quantityKg.toStringAsFixed(0)} ${plan.unit} · ${plan.fieldLocation}',
                    style: AppTypography.bodySmall),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.backgroundStart,
                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(s.cropStageLabel(plan.stage.name).toUpperCase(),
                      style: AppTypography.label),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'edit') {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EditCropPlanScreen(plan: plan)));
                ref.invalidate(cropPlansProvider);
                return;
              }
              if (value == 'create_listing') {
                final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) =>
                            CreateListingFromPlanScreen(plan: plan)));
                if (created == true) ref.invalidate(cropPlansProvider);
                return;
              }
              if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(s.deleteThisCropPlanQuestion),
                    // Real backend does a HARD delete here (verified
                    // this session) — no undo, unlike products' soft
                    // delete — so the confirmation copy says so plainly.
                    content: Text(
                        s.cropPlanWillBePermanentlyRemoved(plan.cropName)),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: Text(s.cancel)),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(s.deleteLabel,
                            style: const TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await ref
                        .read(cropPlansRepositoryProvider)
                        .deleteCropPlan(plan.id);
                    ref.invalidate(cropPlansProvider);
                  } catch (e) {
                    // REAL BUG FOUND AND FIXED: this always showed the
                    // generic "couldn't delete, try again" regardless
                    // of cause -- including the backend's real 409
                    // "this plan has an agreement requested or active
                    // against it" (routes/cropPlans.js's
                    // hasActiveAgreements guard), which is a deliberate,
                    // permanent block, not a transient failure "try
                    // again" implies. Every other screen in the app
                    // already surfaces the backend's own message via
                    // friendlyErrorMessage; this was the one holdout.
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(friendlyErrorMessage(e))));
                    }
                  }
                }
                return;
              }
              // Stage change -- previously fired with no error
              // handling at all: a failed request would throw
              // unhandled, and there was no feedback either way,
              // success or failure.
              try {
                final stage =
                    CropStage.values.firstWhere((cs) => cs.name == value);
                await ref
                    .read(cropPlansRepositoryProvider)
                    .updateCropPlan(id: plan.id, stage: stage);
                ref.invalidate(cropPlansProvider);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(s.couldntUpdateStageTryAgain)));
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(s.editDetailsLabel)),
              PopupMenuItem(
                  value: 'create_listing',
                  child: Text(s.createListingFromPlanLabel)),
              const PopupMenuDivider(),
              ...CropStage.values.map((cs) => PopupMenuItem(
                  value: cs.name,
                  child: Text(s.markAsStage(s.cropStageLabel(cs.name))))),
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'delete',
                  child: Text(s.deleteLabel,
                      style: const TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    );
  }
}
