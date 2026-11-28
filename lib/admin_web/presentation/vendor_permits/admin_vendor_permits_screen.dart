// lib/admin_web/presentation/vendor_permits/admin_vendor_permits_screen.dart
//
// The review queue for routes/vendorPermits.js's business-permit
// submissions -- same manual-review pattern as KYC Route B.
//
// The detail dialog uses the SAME two-column "Submitted by the user"
// / "On record" layout admin_recovery_detail_dialog.dart already
// established for account recovery, rather than a flat labeled dump
// of the reference table -- by explicit request: the reference row
// shown is only ever demo_registered_vendor_registry's data (see that
// table's own migration comment), but the admin screen itself no
// longer calls that out in its copy; which rows are real is explained
// outside the app, not by on-screen disclaimer text.
//
// REAL BUG FOUND AND FIXED, history worth keeping: this originally
// matched a reference row by permit_type alone, so "On record" showed
// an unrelated demo business under every submission of that type --
// looking like a verified match when it wasn't one. Fixed to match on
// permit_number (then widened to also require permit_type, since
// permit numbers are only unique within a type). BY EXPLICIT REQUEST,
// the match now runs on a 4-field identity instead: permit number,
// TIN, date issued, and expiry date together -- business name and
// business address are shown to the admin for their own eyes but
// deliberately play no part in the match. If nothing in the small
// demo registry matches all four, "No matching on-record reference
// found" is shown instead of a misleadingly unrelated row. There is
// also no auto-approval of any kind here or anywhere in this flow --
// that was tried once and explicitly reverted; every submission
// always goes to manual admin review with the document photo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/vendor_permits/application/vendor_permits_provider.dart';
import '../../../features/vendor_permits/domain/vendor_permit_models.dart';
import '../widgets/admin_queue_scaffold.dart';
import '../widgets/admin_decision_dialogs.dart';

final _vendorPermitQueueProvider =
    FutureProvider.autoDispose<List<AdminVendorPermitRow>>(
        (ref) => ref.watch(vendorPermitsRepositoryProvider).getAdminQueue());

class AdminVendorPermitsScreen extends ConsumerWidget {
  const AdminVendorPermitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(_vendorPermitQueueProvider);

    return AdminQueueScaffold<AdminVendorPermitRow>(
      title: 'Vendor Business Permits',
      subtitle:
          'Proof of a real registered business, required before a Vendor '
          'account can list products. Every submission is manually '
          'reviewed -- there is no automated registry check.',
      asyncItems: queueAsync,
      onRetry: () => ref.invalidate(_vendorPermitQueueProvider),
      emptyLabel: 'No business permit submissions awaiting review.',
      columns: const ['Vendor', 'Business Name', 'Permit Type', 'Permit #', 'Expiry', 'Filed'],
      rowCells: (item) => [
        Text(item.vendorName),
        Text(item.businessName),
        Text(item.permitTypeLabel),
        Text(item.permitNumber),
        item.expiryDate == null
            ? const Text('—')
            : Text(_fmt(item.expiryDate!),
                style: item.isExpired
                    ? const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)
                    : null),
        Text(_fmt(item.submittedAt)),
      ],
      onOpen: (item) => showDialog(
        context: context,
        builder: (_) => _VendorPermitDetailDialog(
          row: item,
          onDecided: () => ref.invalidate(_vendorPermitQueueProvider),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _VendorPermitDetailDialog extends ConsumerStatefulWidget {
  const _VendorPermitDetailDialog({required this.row, required this.onDecided});
  final AdminVendorPermitRow row;
  final VoidCallback onDecided;

  @override
  ConsumerState<_VendorPermitDetailDialog> createState() =>
      _VendorPermitDetailDialogState();
}

class _VendorPermitDetailDialogState
    extends ConsumerState<_VendorPermitDetailDialog> {
  String? _documentUrl;
  String? _documentError;
  // The single reference row that matches this submission's
  // permit_type, if any exists -- not the whole registry. Computed
  // client-side from the small (handful of rows) registry list;
  // getDemoRegistry() still returns all of them since that's also
  // used elsewhere, but this dialog only ever shows the one relevant
  // to THIS submission.
  DemoRegisteredVendor? _matchingReference;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(vendorPermitsRepositoryProvider);
    String? documentUrl;
    String? documentError;
    DemoRegisteredVendor? matchingReference;
    String? error;

    try {
      documentUrl = await repo.getAdminDocumentUrl(widget.row.id);
    } catch (_) {
      documentError = 'Document unavailable.';
    }
    try {
      final registry = await repo.getDemoRegistry();
      // REAL CHANGE, BY EXPLICIT REQUEST: the match moved off
      // (permitType, permitNumber) onto a 4-field identity --
      // permit number, TIN, date issued, and expiry date.
      // businessName/businessAddress are shown to the admin for their
      // own eyes but deliberately play no part in the match itself.
      // All four must agree, including a null expiry_date on both
      // sides counting as equal (a document with no printed expiry,
      // e.g. a BIR Form 2303, genuinely has none on either side, not a
      // mismatch).
      final submittedNumber = widget.row.permitNumber.trim().toLowerCase();
      final submittedTin = widget.row.tin?.trim().toLowerCase();
      for (final v in registry) {
        final vTin = v.tin?.trim().toLowerCase();
        if (submittedNumber.isNotEmpty &&
            v.permitNumber.trim().toLowerCase() == submittedNumber &&
            vTin == submittedTin &&
            v.dateIssued == widget.row.dateIssued &&
            v.expiryDate == widget.row.expiryDate) {
          matchingReference = v;
          break;
        }
      }
    } catch (_) {
      error = "Couldn't load the on-record reference.";
    }

    if (mounted) {
      setState(() {
        _documentUrl = documentUrl;
        _documentError = documentError;
        _matchingReference = matchingReference;
        _error = error;
        _loading = false;
      });
    }
  }

  // REAL BUG FOUND AND FIXED: this never caught a failed decide() call
  // -- the backend was throwing on every single Approve/Reject (a
  // separate bug, now fixed: notify() inserted a notification_type
  // value that was never added to the enum, so the whole transaction,
  // including the status update, rolled back every time), and with no
  // try/catch here, that error vanished silently: no SnackBar, no
  // dialog staying open with an explanation, nothing -- while the
  // submission quietly stayed pending. Now mirrors the same
  // catch-and-report pattern every other admin decision screen uses
  // (e.g. admin_settlements_screen.dart).
  Future<void> _decide({required bool approve, String? rejectionReason}) async {
    try {
      await runAdminDecision(context, () async {
        await ref.read(vendorPermitsRepositoryProvider).decide(
              widget.row.id,
              approve: approve,
              rejectionReason: rejectionReason,
            );
      });
      if (mounted) {
        // Captured before pop() so it's not read from a context that's
        // about to be torn down -- the ScaffoldMessengerState itself
        // belongs to the underlying screen and stays valid regardless.
        final messenger = ScaffoldMessenger.of(context);
        widget.onDecided();
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(
            content: Text(approve ? 'Submission approved.' : 'Submission rejected.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(adminErrorMessage(e,
                fallback: "Couldn't record that decision. Please try again."))));
      }
    }
  }

  static const _notProvided = 'Not provided (filed before this was required)';

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final ref_ = _matchingReference;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('Business Permit Submission — ${row.vendorName}',
                              style: AppTypography.h2)),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop()),
                    ]),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Filed ${_fmt(row.submittedAt)}', style: AppTypography.bodySmall),
                    if (row.isExpired) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          'The expiry date entered by the vendor has already passed.',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ColumnCard(
                                title: 'Submitted by the user',
                                fields: {
                                  'Business name': row.businessName,
                                  'Permit type': row.permitTypeLabel,
                                  'Permit number': row.permitNumber,
                                  'TIN': row.tin ?? _notProvided,
                                  'Business address': row.businessAddress ?? _notProvided,
                                  'Issuing office': row.issuingAuthority ?? _notProvided,
                                  'Date issued': row.dateIssued == null
                                      ? _notProvided
                                      : _fmt(row.dateIssued!),
                                  'Expiry date': row.expiryDate == null
                                      ? 'Not shown on document'
                                      : _fmt(row.expiryDate!),
                                },
                                imageUrl: _documentUrl,
                                imageError: _documentError,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: ref_ == null
                                  ? Container(
                                      padding: const EdgeInsets.all(AppSpacing.md),
                                      decoration: BoxDecoration(
                                        color: AppColors.backgroundStart,
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('On record', style: AppTypography.h3),
                                          const SizedBox(height: AppSpacing.sm),
                                          Text(
                                            'No matching on-record reference found for permit number "${row.permitNumber}" '
                                            '(matched on permit number, TIN, date issued, and expiry date together).',
                                            style: AppTypography.bodySmall,
                                          ),
                                        ],
                                      ),
                                    )
                                  : _ColumnCard(
                                      title: 'On record',
                                      fields: {
                                        'Business name': ref_.businessName,
                                        'Permit type': row.permitTypeLabel,
                                        'Permit number': ref_.permitNumber,
                                        'TIN': ref_.tin ?? '—',
                                        'Business address': ref_.businessAddress ?? '—',
                                        'Date issued': ref_.dateIssued == null
                                            ? '—'
                                            : _fmt(ref_.dateIssued!),
                                        'Expiry date': ref_.expiryDate == null
                                            ? 'Not shown on document'
                                            : _fmt(ref_.expiryDate!),
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final note = await showNoteDialog(
                              context: context,
                              title: 'Reject Submission',
                              label: 'Reason shown to the vendor',
                            );
                            if (note != null) {
                              await _decide(approve: false, rejectionReason: note);
                            }
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _decide(approve: true),
                          child: const Text('Approve'),
                        ),
                      ),
                    ]),
                  ],
                ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Same visual shape as account_recovery's own private _ColumnCard --
/// duplicated locally rather than exported/shared across two unrelated
/// admin screens for a single small widget.
class _ColumnCard extends StatelessWidget {
  const _ColumnCard({
    required this.title,
    required this.fields,
    this.imageUrl,
    this.imageError,
  });

  final String title;
  final Map<String, String> fields;
  final String? imageUrl;
  final String? imageError;

  @override
  Widget build(BuildContext context) {
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
          Text(title, style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in fields.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 120,
                      child: Text(entry.key, style: AppTypography.bodySmall)),
                  Expanded(child: Text(entry.value, style: AppTypography.body)),
                ],
              ),
            ),
          if (imageUrl != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.network(imageUrl!,
                  height: 180, width: double.infinity, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                      'Document could not be displayed (it may be a PDF — open the link directly).')),
            ),
          ] else if (imageError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(imageError!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
          ],
        ],
      ),
    );
  }
}
