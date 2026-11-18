// lib/admin_web/presentation/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;

final _analyticsProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getAnalytics());

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(_analyticsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard', style: AppTypography.h1),
          const SizedBox(height: AppSpacing.lg),
          analyticsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Couldn\'t load analytics.'),
            data: (a) => Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _StatCard(label: 'Buyers', value: '${a.usersByRole['buyer'] ?? 0}'),
                _StatCard(label: 'Farmers', value: '${a.usersByRole['farmer'] ?? 0}'),
                _StatCard(label: 'Vendors', value: '${a.usersByRole['vendor'] ?? 0}'),
                _StatCard(
                    label: 'Total Revenue',
                    value: '₱${a.totalRevenue.toStringAsFixed(2)}'),
                for (final entry in a.ordersByStatus.entries)
                  _StatCard(
                      label: 'Orders: ${entry.key}',
                      value: '${entry.value}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTypography.h2),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
