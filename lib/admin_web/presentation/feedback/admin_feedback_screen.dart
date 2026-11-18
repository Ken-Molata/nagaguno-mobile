// lib/admin_web/presentation/feedback/admin_feedback_screen.dart
// UW 14.4: platform feedback, routed to the Admin Dashboard, not tied
// to any specific transaction/product/user decision -- read-only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;

final _feedbackProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getPlatformFeedback());

class AdminFeedbackScreen extends ConsumerWidget {
  const AdminFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFeedback = ref.watch(_feedbackProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Platform Feedback', style: AppTypography.h1),
          const SizedBox(height: 2),
          const Text('General feedback about the platform, not tied to a specific transaction.',
              style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: asyncFeedback.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Couldn\'t load feedback.')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No feedback submitted yet.'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final f = items[i];
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.message, style: AppTypography.body),
                          const SizedBox(height: 4),
                          Text('${f.fullName} (${f.role}) · ${_fmt(f.createdAt)}',
                              style: AppTypography.bodySmall),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
