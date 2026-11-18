// lib/admin_web/presentation/kyc_routes/admin_kyc_routes_screen.dart
//
// UW 10.1: "The route for each ID type is kept in a Route table (one
// row per ID type) that the Admin can edit in the Admin Dashboard."
// Read side is KycRepository.getIdTypes() (GET /kyc/id-types, open to
// any authenticated user -- the submission forms need it too); only
// the edit action here is Admin-only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;
import '../../../features/kyc/application/kyc_status_provider.dart'
    show kycRepositoryProvider;
import '../../../features/kyc/domain/kyc_models.dart';

final _idTypesProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(kycRepositoryProvider).getIdTypes());

class AdminKycRoutesScreen extends ConsumerWidget {
  const AdminKycRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTypes = ref.watch(_idTypesProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('KYC Route Table', style: AppTypography.h1),
          const SizedBox(height: 2),
          const Text(
              'Which verification route (automatic via Didit, or manual review) each ID type uses, and whether a back-of-card image is required.',
              style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: asyncTypes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Couldn\'t load the Route table.'),
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton(
                      onPressed: () => ref.invalidate(_idTypesProvider),
                      child: const Text('Retry')),
                ]),
              ),
              data: (types) => Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: ListView.separated(
                  itemCount: types.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, i) {
                    final t = types[i];
                    return ListTile(
                      title: Text(t.label),
                      subtitle: Text(
                          'id_type: ${t.idType} · back image ${t.backRequired ? 'required' : 'not required'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: t.route == 'A'
                                    ? AppColors.statusSuccessBg
                                    : AppColors.statusPreparingBg,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill)),
                            child: Text(
                                t.route == 'A'
                                    ? 'Route A — Automatic'
                                    : 'Route B — Manual',
                                style: AppTypography.label.copyWith(
                                    color: t.route == 'A'
                                        ? AppColors.statusSuccessFg
                                        : AppColors.statusPreparingFg)),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit',
                            onPressed: () => _showEditDialog(context, ref, t),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // REAL GAP FOUND AND FIXED, per explicit product feedback: Route A
  // vs B isn't an Admin judgment call -- it's tracking whether Didit
  // itself can scan a given ID type at all, a fact about Didit's own
  // capability, not something to flip by hand day-to-day. Back-image
  // requirement, in contrast, genuinely is the Admin's call per ID
  // type. Dropped the route radio group from this edit form entirely
  // (the underlying column, and the pill showing it in the list above,
  // both stay exactly as they were -- just not hand-edited here);
  // `route` is simply never sent in the PATCH below, and the backend's
  // own COALESCE leaves it untouched.
  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, IdTypeConfig current) async {
    bool backRequired = current.backRequired;
    final labelController = TextEditingController(text: current.label);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Edit ${current.label}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              const SizedBox(height: AppSpacing.md),
              CheckboxListTile(
                value: backRequired,
                title: const Text('Back-of-card image required'),
                contentPadding: EdgeInsets.zero,
                onChanged: (v) =>
                    setDialogState(() => backRequired = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    await ref.read(adminRepositoryProvider).updateIdTypeRoute(
          current.idType,
          backRequired: backRequired,
          label: labelController.text.trim().isEmpty
              ? null
              : labelController.text.trim(),
        );
    ref.invalidate(_idTypesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${current.label} updated.')));
    }
  }
}
