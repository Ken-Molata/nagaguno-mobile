// lib/features/farmers/presentation/vendors_screen.dart
//
// Mirrors farmers_screen.dart. Closes a real gap: UW 5's Actor line
// covers both Farmer and Vendor creating a production plan, but a
// buyer had no way to browse vendors at all before this (only the
// Farmers list/detail existed).
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
import '../data/vendors_repository.dart';
import '../domain/vendor_summary.dart';

final vendorsRepositoryProvider = Provider<VendorsRepository>(
    (ref) => VendorsRepository(ref.watch(apiClientProvider)));
final vendorsListProvider = FutureProvider.autoDispose<List<VendorSummary>>(
    (ref) => ref.watch(vendorsRepositoryProvider).getVendors());

class VendorsScreen extends ConsumerWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(vendorsListProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.vendorsTitle)),
      body: vendorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.couldntLoadVendors),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
                onPressed: () => ref.invalidate(vendorsListProvider),
                child: Text(s.retry)),
          ]),
        ),
        data: (vendors) {
          if (vendors.isEmpty) {
            return Center(child: Text(s.noVendorsFound));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: vendors.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final v = vendors[i];
              return ListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: const BorderSide(color: AppColors.border)),
                leading: CircleAvatar(
                  backgroundColor: AppColors.backgroundStart,
                  backgroundImage: v.businessPhotoUrl != null
                      ? NetworkImage(v.businessPhotoUrl!)
                      : null,
                  child: v.businessPhotoUrl == null
                      ? const Icon(Icons.storefront_outlined,
                          color: AppColors.primary)
                      : null,
                ),
                title: Text(v.displayName,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text([
                  if (v.barangay != null) v.barangay!,
                  if (v.productCount != null)
                    s.productsCountSuffix(v.productCount!)
                ].join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/vendors/${v.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
