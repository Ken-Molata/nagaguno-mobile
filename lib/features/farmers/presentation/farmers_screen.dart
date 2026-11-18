// lib/features/farmers/presentation/farmers_screen.dart
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/localization/app_strings.dart';
import '../data/farmers_repository.dart';
import '../domain/farmer_summary.dart';

final farmersRepositoryProvider = Provider<FarmersRepository>(
    (ref) => FarmersRepository(ref.watch(apiClientProvider)));
final farmersListProvider = FutureProvider.autoDispose<List<FarmerSummary>>(
    (ref) => ref.watch(farmersRepositoryProvider).getFarmers());

class FarmersScreen extends ConsumerWidget {
  const FarmersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmersAsync = ref.watch(farmersListProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.farmersTitle)),
      body: farmersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.couldntLoadFarmers),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
                onPressed: () => ref.invalidate(farmersListProvider),
                child: Text(s.retry)),
          ]),
        ),
        data: (farmers) {
          if (farmers.isEmpty) {
            return Center(child: Text(s.noFarmersFound));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: farmers.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final f = farmers[i];
              return ListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: const BorderSide(color: AppColors.border)),
                leading: CircleAvatar(
                  backgroundColor: AppColors.backgroundStart,
                  backgroundImage: f.farmPhotoUrl != null
                      ? NetworkImage(f.farmPhotoUrl!)
                      : null,
                  child: f.farmPhotoUrl == null
                      ? const Icon(Icons.grass, color: AppColors.primary)
                      : null,
                ),
                title: Text(f.displayName,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text([
                  if (f.barangay != null) f.barangay!,
                  if (f.productCount != null)
                    s.productsCountSuffix(f.productCount!)
                ].join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/farmers/${f.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
