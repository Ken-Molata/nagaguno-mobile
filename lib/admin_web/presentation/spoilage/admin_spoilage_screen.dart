// lib/admin_web/presentation/spoilage/admin_spoilage_screen.dart
// UW 3.3/3.4: spoilage monitoring across all live listings. Read-only --
// the real backend's /spoilage/dashboard is a GET with no admin action
// endpoint (the per-listing discount/hiding is fully automatic).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;

final _spoilageProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getSpoilageDashboard());

const _stageColors = {
  'fresh': (AppColors.statusSuccessBg, AppColors.statusSuccessFg),
  'near_spoilage': (AppColors.statusPendingBg, AppColors.statusPendingFg),
  'critical': (AppColors.statusCancelledBg, AppColors.statusCancelledFg),
  'expired': (AppColors.backgroundStart, AppColors.textMuted),
};

class AdminSpoilageScreen extends ConsumerWidget {
  const AdminSpoilageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDashboard = ref.watch(_spoilageProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spoilage Monitoring', style: AppTypography.h1),
          const SizedBox(height: 2),
          const Text(
              'Every perishable listing by shelf-life stage, including ones already auto-hidden on expiry.',
              style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          asyncDashboard.when(
              loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator())),
              error: (_, __) => SizedBox(
                height: 200,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Couldn\'t load the spoilage dashboard.'),
                    const SizedBox(height: AppSpacing.sm),
                    ElevatedButton(
                        onPressed: () => ref.invalidate(_spoilageProvider),
                        child: const Text('Retry')),
                  ]),
                ),
              ),
              data: (dashboard) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (final entry in dashboard.counts.entries)
                        _StageCard(stage: entry.key, count: entry.value),
                      _StageCard(
                          stage: 'Auto-discounts applied',
                          count: dashboard.autoDiscountsApplied,
                          colorOverride: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dashboard.listings.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, i) {
                          final l = dashboard.listings[i];
                          final (bg, fg) =
                              _stageColors[l.stage] ?? _stageColors['fresh']!;
                          return ListTile(
                            title: Text(l.name),
                            subtitle: Text(
                                l.productStatus == 'hidden'
                                    ? '${l.sellerName} · Hidden${l.autoHiddenReason != null ? ' (${l.autoHiddenReason})' : ''}'
                                    : l.sellerName,
                                style: AppTypography.bodySmall),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill)),
                              child: Text(
                                  '${l.stage.replaceAll('_', ' ')} · ${l.remainingPct.toStringAsFixed(0)}%',
                                  style: AppTypography.label.copyWith(color: fg)),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage, required this.count, this.colorOverride});
  final String stage;
  final int count;
  final Color? colorOverride;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count',
              style: AppTypography.h2.copyWith(color: colorOverride)),
          const SizedBox(height: 2),
          Text(stage.replaceAll('_', ' '), style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
