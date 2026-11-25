// lib/admin_web/presentation/vendor_permits/admin_vendor_permits_screen.dart
//
// The review queue for routes/vendorPermits.js's business-permit
// submissions -- same manual-review pattern as KYC Route B. Shows the
// submitted document (via a short-lived signed URL) and a demo-only
// cross-check registry an admin can eyeball, never an automated match.

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
  List<DemoRegisteredVendor> _demoRegistry = const [];
  bool _loading = true;
  // REAL BUG FOUND AND FIXED while live-verifying this screen: a
  // Future.wait([getAdminDocumentUrl, getDemoRegistry]) meant ONE
  // failing call (e.g. a document whose storage object is missing --
  // confirmed live against a real pending submission) discarded BOTH
  // results, blanking out the demo registry too even though that call
  // had actually succeeded. Each call now fails independently, so the
  // admin still sees everything that loaded, with a specific message
  // only for whichever piece didn't.
  String? _documentError;
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
    List<DemoRegisteredVendor> demoRegistry = const [];
    String? error;

    try {
      documentUrl = await repo.getAdminDocumentUrl(widget.row.id);
    } catch (_) {
      documentError = 'Document unavailable.';
    }
    try {
      demoRegistry = await repo.getDemoRegistry();
    } catch (_) {
      error = "Couldn't load the demo registry.";
    }

    if (mounted) {
      setState(() {
        _documentUrl = documentUrl;
        _documentError = documentError;
        _demoRegistry = demoRegistry;
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _decide({required bool approve, String? rejectionReason}) async {
    await runAdminDecision(context, () async {
      await ref.read(vendorPermitsRepositoryProvider).decide(
            widget.row.id,
            approve: approve,
            rejectionReason: rejectionReason,
          );
    });
    if (mounted) {
      widget.onDecided();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(
                          child: Text('Business Permit Submission',
                              style: AppTypography.h2)),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop()),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _row('Vendor', row.vendorName),
                            _row('Business name', row.businessName),
                            _row('Permit type', row.permitTypeLabel),
                            _row('Permit number', row.permitNumber),
                            _row('TIN', row.tin ?? 'Not provided (filed before this was required)'),
                            _row('Business address', row.businessAddress ?? 'Not provided (filed before this was required)'),
                            _row('Issuing office', row.issuingAuthority ?? 'Not provided (filed before this was required)'),
                            _row('Date issued', row.dateIssued == null
                                ? 'Not provided (filed before this was required)'
                                : _fmt(row.dateIssued!)),
                            _row('Expiry date', row.expiryDate == null
                                ? 'Not shown on document'
                                : _fmt(row.expiryDate!)),
                            if (row.isExpired) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  'The expiry date entered by the vendor has already passed. This is only a date comparison against what they themselves entered -- not a registry check.',
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            if (_documentUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                child: Image.network(_documentUrl!,
                                    height: 220, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Text(
                                        'Document could not be displayed (it may be a PDF — open the link directly).')),
                              )
                            else if (_documentError != null)
                              Text(_documentError!,
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
                            const SizedBox(height: AppSpacing.md),
                            if (_demoRegistry.isNotEmpty) ...[
                              Text('Demo reference registry (manual cross-check only — not a real registry integration)',
                                  style: AppTypography.bodySmall
                                      .copyWith(fontStyle: FontStyle.italic)),
                              const SizedBox(height: AppSpacing.xs),
                              ..._demoRegistry.map((v) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                        '${v.businessName} — ${v.permitType} ${v.permitNumber}'
                                        '${v.tin != null ? ' — TIN ${v.tin}' : ''}'
                                        '${v.businessAddress != null ? ' — ${v.businessAddress}' : ''}',
                                        style: AppTypography.bodySmall),
                                  )),
                            ],
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

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 140, child: Text(label, style: AppTypography.bodySmall)),
          Expanded(child: Text(value, style: AppTypography.body)),
        ]),
      );

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
