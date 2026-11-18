// lib/admin_web/presentation/account_recovery/admin_recovery_queue_screen.dart
//
// UW 2.5 Step 4: the Admin review queue for Locked-Out Account
// Recovery. The backend (routes/accountRecovery.js's /admin/* trio)
// has existed since earlier this session with zero UI anywhere --
// this is that missing piece.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;
import '../../../features/admin/domain/admin_models.dart';
import '../widgets/admin_queue_scaffold.dart';
import 'admin_recovery_detail_dialog.dart';

final _recoveryQueueProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).getRecoveryQueue());

class AdminRecoveryQueueScreen extends ConsumerWidget {
  const AdminRecoveryQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(_recoveryQueueProvider);

    return AdminQueueScaffold<RecoveryQueueItem>(
      title: 'Account Recovery',
      subtitle:
          'Locked-out users who could not verify by email or phone.',
      asyncItems: queueAsync,
      onRetry: () => ref.invalidate(_recoveryQueueProvider),
      emptyLabel: 'No recovery requests awaiting review.',
      columns: const ['Request #', 'Account', 'Reason', 'Status', 'Submitted'],
      rowCells: (item) => [
        Text(item.requestNumber),
        Row(children: [
          Flexible(
            child: Text(item.accountFullName ?? 'Not identified by user',
                overflow: TextOverflow.ellipsis,
                style: item.accountIdentified
                    ? null
                    : const TextStyle(
                        color: AppColors.statusPendingFg,
                        fontStyle: FontStyle.italic)),
          ),
          // UW 2.5 "Admin accounts": flagged up front so a reviewing
          // Admin knows the "different Admin must review" rule applies
          // before opening the request.
          if (item.role == 'admin') ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: AppColors.statusDispatchedBg,
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: Text('Admin',
                  style: AppTypography.label
                      .copyWith(color: AppColors.statusDispatchedFg, fontSize: 10)),
            ),
          ],
        ]),
        Text(item.reason.replaceAll('_', ' ')),
        _StatusChip(status: item.status),
        Text(_fmt(item.createdAt)),
      ],
      onOpen: (item) => showDialog(
        context: context,
        builder: (_) => AdminRecoveryDetailDialog(
          id: item.id,
          onDecided: () => ref.invalidate(_recoveryQueueProvider),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = status == 'more_info_needed'
        ? (AppColors.statusPendingBg, AppColors.statusPendingFg)
        : (AppColors.backgroundStart, AppColors.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(status.replaceAll('_', ' '),
          style: AppTypography.label.copyWith(color: fg)),
    );
  }
}
