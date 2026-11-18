// lib/features/admin/presentation/admin_home_screen.dart
//
// Admin has no bottom-nav tab structure at all — per the earlier UX
// plan, Admin is web/desktop-primary; this is a deliberately minimal
// mobile entry point (dashboard summary + link to the one genuinely
// mobile-appropriate admin task, KYC review), not an attempt at full
// desktop-panel parity.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../authentication/application/auth_controller.dart';
import '../data/admin_repository.dart';
import 'admin_users_screen.dart';
import 'kyc_review_screen.dart';

final _analyticsProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getAnalytics());

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(_analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NagaGuno Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            analyticsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Couldn\'t load analytics.'),
              data: (a) => Row(
                children: [
                  _StatTile(
                      label: 'Buyers', value: '${a.usersByRole['buyer'] ?? 0}'),
                  _StatTile(
                      label: 'Farmers',
                      value: '${a.usersByRole['farmer'] ?? 0}'),
                  _StatTile(
                      label: 'Vendors',
                      value: '${a.usersByRole['vendor'] ?? 0}'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: const BorderSide(color: AppColors.border)),
              leading: const Icon(Icons.verified_user_outlined,
                  color: AppColors.primary),
              title: const Text('Verification Queue'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const KycReviewScreen())),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Deliberately narrower than "full platform oversight" (see
            // the note below) -- search/filter/view plus the same
            // restrict-or-restore action the Verification Queue above
            // already models for admin decisions on mobile, using the
            // real GET /admin/users, which already supported
            // role/status/search server-side with nothing in this app
            // calling it yet.
            ListTile(
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: const BorderSide(color: AppColors.border)),
              leading:
                  const Icon(Icons.people_outline, color: AppColors.primary),
              title: const Text('Manage Users'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                  color: AppColors.backgroundStart,
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              child: const Text(
                'Listing moderation and full platform oversight are available on the NagaGuno web admin panel.',
                style: AppTypography.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: AppTypography.h2.copyWith(color: AppColors.accent)),
          Text(label,
              style: AppTypography.label.copyWith(color: Colors.white70)),
        ]),
      ),
    );
  }
}
