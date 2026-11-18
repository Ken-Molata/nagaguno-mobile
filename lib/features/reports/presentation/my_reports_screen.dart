// lib/features/reports/presentation/my_reports_screen.dart
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.
// report.violationLabel and report.adminReason are server/admin-
// authored content, not UI chrome, and stay untranslated here the
// same way notification text does.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import 'report_user_screen.dart' show reportsRepositoryProvider;
import '../domain/report_models.dart';

final myReportsProvider = FutureProvider.autoDispose<List<MyReport>>(
    (ref) => ref.watch(reportsRepositoryProvider).getMyReports());

class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  Color _statusColor(String status) => switch (status) {
        'verified' => AppColors.statusSuccessFg,
        'dismissed' => AppColors.statusCancelledFg,
        'more_info_requested' => AppColors.statusPendingFg,
        _ => AppColors.textMuted,
      };

  Color _statusBg(String status) => switch (status) {
        'verified' => AppColors.statusSuccessBg,
        'dismissed' => AppColors.statusCancelledBg,
        'more_info_requested' => AppColors.statusPendingBg,
        _ => AppColors.backgroundStart,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(myReportsProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.myReportsTitle)),
      body: SafeArea(
        child: reportsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(s.couldntLoadReports),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                  onPressed: () => ref.invalidate(myReportsProvider),
                  child: Text(s.retry)),
            ]),
          ),
          data: (reports) {
            if (reports.isEmpty) {
              return Center(child: Text(s.havenFiledAnyReportsYet));
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(myReportsProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: reports.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final report = reports[i];
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(report.violationLabel,
                                  style: AppTypography.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: _statusBg(report.status),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill)),
                            child: Text(s.reportStatusLabel(report.status),
                                style: TextStyle(
                                    color: _statusColor(report.status),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'DMSans')),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          '${report.createdAt.year}-${report.createdAt.month.toString().padLeft(2, '0')}-${report.createdAt.day.toString().padLeft(2, '0')}',
                          style: AppTypography.label,
                        ),
                        if (report.adminReason != null) ...[
                          const SizedBox(height: 4),
                          Text(report.adminReason!,
                              style: AppTypography.bodySmall),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
