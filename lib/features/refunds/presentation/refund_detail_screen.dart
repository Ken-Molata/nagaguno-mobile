// lib/features/refunds/presentation/refund_detail_screen.dart
//
// UW 9.4: one shared screen for both sides of a refund request --
// see domain/refund_request.dart's header comment for the gap this
// closes (the real backend already supported every action here with
// no mobile caller at all). Buyer and seller see the same facts, with
// the actions available to each role shown only to that role.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_picking.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../../authentication/application/auth_controller.dart';
import '../data/refunds_repository.dart';
import '../domain/refund_request.dart';

final _refundDetailProvider = FutureProvider.autoDispose.family(
  (ref, String id) => ref.watch(refundsRepositoryProvider).getDetail(id),
);

class RefundDetailScreen extends ConsumerStatefulWidget {
  const RefundDetailScreen({super.key, required this.refundId});
  final String refundId;

  @override
  ConsumerState<RefundDetailScreen> createState() =>
      _RefundDetailScreenState();
}

class _RefundDetailScreenState extends ConsumerState<RefundDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      ref.invalidate(_refundDetailProvider(widget.refundId));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(String action) async {
    String? reasonCode;
    String? note;
    if (action == 'decline') {
      final result = await _showDeclineDialog();
      if (result == null) return;
      (reasonCode, note) = result;
    }
    await _run(() => ref.read(refundsRepositoryProvider).respond(
        widget.refundId,
        action: action,
        reasonCode: reasonCode,
        note: note));
  }

  Future<(String, String?)?> _showDeclineDialog() {
    String? reasonCode;
    final noteController = TextEditingController();
    return showDialog<(String, String?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Decline Refund Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioGroup<String>(
                  groupValue: reasonCode,
                  onChanged: (v) => setDialogState(() => reasonCode = v),
                  child: Column(
                    children: refundDeclineReasonLabels.entries
                        .map((e) => RadioListTile<String>(
                            value: e.key,
                            title: Text(e.value),
                            contentPadding: EdgeInsets.zero))
                        .toList(),
                  ),
                ),
                if (reasonCode == 'other')
                  TextField(
                    controller: noteController,
                    decoration:
                        const InputDecoration(labelText: 'Explain why'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel')),
            TextButton(
              onPressed: reasonCode == null
                  ? null
                  : () => Navigator.of(dialogContext)
                      .pop((reasonCode!, noteController.text.trim())),
              child: const Text('Decline'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeWithProof() async {
    final picked = await pickAndCompressImage();
    if (picked == null) return;
    await _run(() => ref
        .read(refundsRepositoryProvider)
        .complete(widget.refundId, proofPath: picked.path));
  }

  String _statusLabel(RefundStatus s) => switch (s) {
        RefundStatus.pending => 'Pending',
        RefundStatus.declined => 'Declined',
        RefundStatus.verified => 'Accepted — Awaiting Refund',
        RefundStatus.inProgress => 'In Progress',
        RefundStatus.refunded => 'Refunded',
        RefundStatus.underAdminReview => 'Under Admin Review',
        RefundStatus.dismissed => 'Dismissed by Admin',
      };

  Color _statusColor(RefundStatus s) => switch (s) {
        RefundStatus.refunded || RefundStatus.verified =>
          AppColors.statusSuccessFg,
        RefundStatus.declined || RefundStatus.dismissed => AppColors.error,
        _ => AppColors.accentDark,
      };

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(_refundDetailProvider(widget.refundId));
    final userId = ref.watch(authControllerProvider).user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Refund Request')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Couldn\'t load this refund request.')),
        data: (refund) {
          final isSeller = userId == refund.sellerId;
          final isBuyer = userId == refund.buyerId;
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: _statusColor(refund.status)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(_statusLabel(refund.status),
                      style: AppTypography.label
                          .copyWith(color: _statusColor(refund.status))),
                ),
                // REAL GAP FOUND AND FIXED: the real refund amount +
                // "check your account" reminder already existed as the
                // backend's own 'refund_sent' notification text
                // (routes/refunds.js's POST /:id/complete) -- but that
                // only ever reached Notifications, never this screen
                // itself, which is where a buyer actually lands after
                // tapping that notification. Shown here too now, same
                // wording, so it's not buried one tap away.
                if (refund.status == RefundStatus.refunded) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.verificationPendingBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 16, color: AppColors.accentDark),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            '₱${refund.totalAmount.toStringAsFixed(2)} has been refunded. Check your linked account for confirmation.',
                            style: AppTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text('Reason', style: AppTypography.label),
                Text(refundReasonLabels[refund.reasonCode] ?? refund.reasonCode,
                    style: AppTypography.body),
                if (refund.essay != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(refund.essay!, style: AppTypography.body),
                ],
                if (refund.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: refund.photoUrls.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.network(refund.photoUrls[i],
                            width: 80, height: 80, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],
                if (refund.declineReason != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Decline Reason', style: AppTypography.label),
                  Text(refund.declineReason!, style: AppTypography.body),
                ],
                if (refund.adminReason != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Admin Decision', style: AppTypography.label),
                  Text(refund.adminReason!, style: AppTypography.body),
                ],
                if (refund.refundProofUrl != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Refund Proof', style: AppTypography.label),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.network(refund.refundProofUrl!),
                  ),
                ],
                // UW 1.2/9.4: the seller needs to see where to actually
                // send the money once they've accepted -- only present
                // once verified/in_progress, per the real backend's own
                // gating (routes/refunds.js's GET /:id).
                if (isSeller && refund.buyerPaymentMethods.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Send the refund to', style: AppTypography.label),
                  const SizedBox(height: AppSpacing.xs),
                  ...refund.buyerPaymentMethods.map((m) => Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                            color: AppColors.backgroundStart,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m['gcash_number'] != null)
                              Text('GCash: ${m['gcash_number']}'),
                            if (m['bank_name'] != null)
                              Text(
                                  '${m['bank_name']}: ${m['bank_account_number']} (${m['bank_account_name']})'),
                          ],
                        ),
                      )),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (isSeller && refund.status == RefundStatus.pending)
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _respond('decline'),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            foregroundColor: AppColors.error),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy ? null : () => _respond('accept'),
                        child: const Text('Accept'),
                      ),
                    ),
                  ]),
                if (isSeller && refund.status == RefundStatus.verified) ...[
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => ref
                            .read(refundsRepositoryProvider)
                            .processLater(widget.refundId)),
                    child: const Text('Process Later'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: _busy ? null : _completeWithProof,
                    child: const Text('Mark as Sent'),
                  ),
                ],
                if (isSeller && refund.status == RefundStatus.inProgress)
                  ElevatedButton(
                    onPressed: _busy ? null : _completeWithProof,
                    child: const Text('Mark as Sent'),
                  ),
                if (isBuyer && refund.status == RefundStatus.declined)
                  ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => ref
                            .read(refundsRepositoryProvider)
                            .escalate(widget.refundId)),
                    child: const Text('Escalate to Admin'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
