// lib/features/farmers/presentation/saved_farmers_screen.dart
//
// Closes a real gap that was actually a backend gap, not just a
// Flutter one: the saved_farmers table and its RLS policy existed all
// session, and the buyer dashboard displayed a real count from it,
// but there was no API endpoint anywhere to actually save or unsave a
// farmer, or list them. Added POST/DELETE /profiles/farmers/:id/save
// and GET /profiles/farmers/saved to the real backend this round.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import 'farmers_screen.dart';

final savedFarmersProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(farmersRepositoryProvider).getSavedFarmers());

class SavedFarmersScreen extends ConsumerWidget {
  const SavedFarmersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedFarmersProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.savedFarmers)),
      body: savedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.couldntLoadSavedFarmers),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
                onPressed: () => ref.invalidate(savedFarmersProvider),
                child: Text(s.retry)),
          ]),
        ),
        data: (farmers) {
          if (farmers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(s.noSavedFarmersYetTapHeart,
                    textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(savedFarmersProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: farmers.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
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
                  subtitle: f.barangay != null ? Text(f.barangay!) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/farmers/${f.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
