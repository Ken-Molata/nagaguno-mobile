// lib/admin_web/presentation/account_recovery/admin_recovery_detail_dialog.dart
//
// UW 2.5 Step 4's two-column "Submitted by the user" / "On record in
// the account" table, the flag icons, and the three decision actions
// (Approve and unlock / Request more information / Reject). Field
// names match GET /account-recovery/admin/:id's real response exactly
// (routes/accountRecovery.js, read in full this session).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/admin/data/admin_repository.dart'
    show adminRepositoryProvider;
import '../../../features/admin/domain/admin_models.dart';
import '../widgets/admin_decision_dialogs.dart' show adminErrorMessage;

const _rejectReasons = {
  'details_mismatch': 'Name, date of birth, or age on the ID does not match the account records',
  'different_id_type': 'ID is not the same ID used when the account was verified',
  'face_mismatch': 'Face does not match the verification on record',
  'liveness_failed': 'Liveness check not passed',
  'unreadable': 'ID unreadable or of insufficient image quality',
  'altered_or_fraudulent': 'Document appears altered or fraudulent',
  'cannot_confirm': 'Could not confirm that the account belongs to this person',
  'other': 'Other',
};

// REAL GAP FOUND AND FIXED, live-caught: same raw-ISO-timestamp issue
// as submitted/onRecord's date_of_birth (fixed in routes/
// accountRecovery.js's asDateOnly), just missed here -- this one is a
// genuine timestamp (not just a date), so it keeps the time component
// instead of truncating to a bare date. Mirrors admin_recovery_queue_
// screen.dart's own local _fmt(DateTime) convention (no intl
// dependency in this app) rather than adding a formatting package for
// one string.
String _twoDigits(int n) => n.toString().padLeft(2, '0');

String _fmtDateTime(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.parse(iso).toLocal();
  return '${d.year}-${_twoDigits(d.month)}-${_twoDigits(d.day)} ${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
}

const _moreInfoItems = {
  'retake_id_photo': 'Retake the ID photo',
  'repeat_selfie': 'Repeat the selfie check',
  'contact': 'Enter the email or phone number the account was registered with',
  'other': 'Other',
};

class AdminRecoveryDetailDialog extends ConsumerStatefulWidget {
  const AdminRecoveryDetailDialog(
      {super.key, required this.id, required this.onDecided});
  final String id;
  final VoidCallback onDecided;

  @override
  ConsumerState<AdminRecoveryDetailDialog> createState() =>
      _AdminRecoveryDetailDialogState();
}

class _AdminRecoveryDetailDialogState
    extends ConsumerState<AdminRecoveryDetailDialog> {
  RecoveryDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail =
          await ref.read(adminRepositoryProvider).getRecoveryDetail(widget.id);
      if (mounted) setState(() => _detail = detail);
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn\'t load this request.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(Map<String, dynamic> body) async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .submitRecoveryDecision(widget.id,
              decision: body['decision'],
              reasonCode: body['reasonCode'],
              note: body['note'],
              items: body['items'],
              other: body['other']);
      if (!mounted) return;
      widget.onDecided();
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = adminErrorMessage(e, fallback: 'Couldn\'t record that decision. Please try again.'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _linkAccount() async {
    final userId = await showDialog<String>(
      context: context,
      builder: (_) => _LinkAccountSearchDialog(),
    );
    if (userId == null) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .linkRecoveryAccount(widget.id, userId: userId);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = adminErrorMessage(e, fallback: 'Couldn\'t link this account.'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _detail == null
                  ? Center(child: Text(_error!))
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final d = _detail!;
    final flags = (d['flags'] as Map).cast<String, dynamic>();
    final submitted = (d['submitted'] as Map).cast<String, dynamic>();
    final onRecord = d['onRecord'] as Map?;
    final status = d['status'] as String;
    final decided = !['awaiting_review', 'more_info_needed'].contains(status);
    // UW 2.5 "Admin accounts": "reviewed by a different Admin" -- the
    // backend enforces this on decide/link-account (self-review is
    // rejected), this badge is just so a reviewing Admin sees it up
    // front rather than discovering it from a 403 after filling in a
    // decision.
    final isAdminAccount = onRecord?['role'] == 'admin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Row(children: [
              Text('Request ${d['request_number']}', style: AppTypography.h2),
              if (isAdminAccount) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.statusDispatchedBg,
                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text('Admin account',
                      style: AppTypography.label
                          .copyWith(color: AppColors.statusDispatchedFg)),
                ),
              ],
            ]),
          ),
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop()),
        ]),
        const SizedBox(height: AppSpacing.xs),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final entry in flags.entries)
            if (entry.value == true)
              Chip(
                label: Text(entry.key.replaceAll('_', ' ')),
                backgroundColor: AppColors.statusPendingBg,
                labelStyle: const TextStyle(
                    color: AppColors.statusPendingFg, fontSize: 11),
                visualDensity: VisualDensity.compact,
              ),
        ]),
        // Shows once the user has actually answered a prior "Request
        // More Information" decision (POST /account-recovery/respond)
        // -- a retake_id_photo/repeat_selfie answer already overwrote
        // this row's own id_front_url/id_back_url/route_b_capture_urls/
        // liveness_* columns in place, so the "Submitted by the user"
        // card below already shows the new photos automatically; this
        // is just the "yes, they already replied" signal plus whatever
        // has no photo of its own (contact/other).
        if (d['responded_at'] != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
                color: AppColors.statusSuccessBg,
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Responded ${_fmtDateTime(d['responded_at'] as String?)} — answered: ${((d['more_info_items'] as List?) ?? const [])
                        .map((k) => _moreInfoItems[k] ?? k)
                        .join('; ')}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.statusSuccessFg)),
                if ((d['other_response'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text('"${d['other_response']}"',
                      style: AppTypography.bodySmall),
                ],
                if (d['contact_for_updates'] != null) ...[
                  const SizedBox(height: 2),
                  Text('Contact on file now: ${d['contact_for_updates']}',
                      style: AppTypography.bodySmall),
                ],
              ],
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
                        title: 'Submitted by the user', fields: {
                  'Full name': submitted['full_name']?.toString() ?? '—',
                  'Date of birth': submitted['date_of_birth']?.toString() ?? '—',
                  'Age': submitted['age']?.toString() ?? '—',
                  'Password': submitted['password']?.toString() ?? '—',
                  'ID type': submitted['id_type']?.toString() ?? '—',
                  // REAL GAP FOUND AND FIXED, live-caught: this card had
                  // no field at all for WHY the user is recovering (the
                  // reason they picked on the account's own Step 3,
                  // which already determines flags like
                  // account_never_verified upstream) and no contact
                  // value to actually compare against onRecord's
                  // Email/Phone row -- the comparison the two-column
                  // layout exists for had nothing to compare on this
                  // one specific point.
                  'Reason for recovery': submitted['reason_other'] != null
                      ? '${submitted['reason']}: "${submitted['reason_other']}"'
                      : submitted['reason']?.toString() ?? '—',
                  'Contact provided': submitted['contact_for_updates']?.toString() ?? '—',
                }, imageUrls: [
                  submitted['id_front_url'] as String?,
                  submitted['id_back_url'] as String?,
                  submitted['liveness_photo_url'] as String?,
                ])),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: onRecord == null
                      ? Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                              color: AppColors.backgroundStart,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('On record in the account',
                                  style: AppTypography.h3),
                              const SizedBox(height: AppSpacing.sm),
                              const Text(
                                  'Account not identified by user. Search and link one before approving.',
                                  style: AppTypography.bodySmall),
                              const SizedBox(height: AppSpacing.sm),
                              OutlinedButton(
                                  onPressed: _submitting ? null : _linkAccount,
                                  child: const Text('Find & Link Account')),
                            ],
                          ),
                        )
                      : _ColumnCard(title: 'On record in the account', fields: {
                          'Full name': onRecord['full_name']?.toString() ?? '—',
                          'Date of birth':
                              onRecord['date_of_birth']?.toString() ?? '—',
                          'Age': onRecord['age']?.toString() ?? '—',
                          'Email':
                              '${onRecord['email'] ?? '—'} (${onRecord['email_verified'] == true ? 'verified' : 'not verified'})',
                          'Phone':
                              '${onRecord['phone_number'] ?? '—'} (${onRecord['phone_verified'] == true ? 'verified' : 'not verified'})',
                          'ID type': onRecord['id_type']?.toString() ?? '—',
                          'Open orders/agreements':
                              '${onRecord['open_orders_count'] ?? 0} orders, ${onRecord['active_agreements_count'] ?? 0} agreements',
                          'Prior requests (30d)':
                              onRecord['prior_recovery_requests_30d']?.toString() ?? '0',
                        }, imageUrls: [
                          onRecord['id_front_url'] as String?,
                          onRecord['liveness_photo_url'] as String?,
                        ]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: AppSpacing.sm),
        ],
        // UW 19: "Submitting shows 'Submitting decision...'"
        if (_submitting) ...[
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: AppSpacing.sm),
              Text('Submitting decision...', style: AppTypography.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (!decided)
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => _showRejectDialog(),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => _showMoreInfoDialog(),
                child: const Text('Request More Information'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting || onRecord == null
                    ? null
                    : () => _decide({'decision': 'approved'}),
                child: const Text('Approve and Unlock'),
              ),
            ),
          ])
        else
          Text('Status: $status', style: AppTypography.bodySmall),
      ],
    );
  }

  Future<void> _showRejectDialog() async {
    String? reasonCode;
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Reject Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RadioGroup<String>(
                  groupValue: reasonCode,
                  onChanged: (v) => setDialogState(() => reasonCode = v),
                  child: Column(
                    children: _rejectReasons.entries
                        .map((e) => RadioListTile<String>(
                            title: Text(e.value), value: e.key, dense: true))
                        .toList(),
                  ),
                ),
                if (reasonCode == 'other')
                  TextField(
                      controller: noteController,
                      decoration:
                          const InputDecoration(labelText: 'Explain why')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: reasonCode == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _decide({
        'decision': 'rejected',
        'reasonCode': reasonCode,
        'note': noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      });
    }
  }

  Future<void> _showMoreInfoDialog() async {
    final selected = <String>{};
    final otherController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Request More Information'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in _moreInfoItems.entries)
                  CheckboxListTile(
                    title: Text(entry.value),
                    value: selected.contains(entry.key),
                    dense: true,
                    onChanged: (v) => setDialogState(() {
                      if (v == true) {
                        selected.add(entry.key);
                      } else {
                        selected.remove(entry.key);
                      }
                    }),
                  ),
                if (selected.contains('other'))
                  TextField(
                      controller: otherController,
                      decoration:
                          const InputDecoration(labelText: 'Explain what is needed')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _decide({
        'decision': 'more_info_needed',
        'items': selected.toList(),
        'other': otherController.text.trim().isEmpty ? null : otherController.text.trim(),
      });
    }
  }
}

class _ColumnCard extends StatelessWidget {
  const _ColumnCard(
      {required this.title, required this.fields, this.imageUrls = const []});
  final String title;
  final Map<String, String> fields;
  final List<String?> imageUrls;

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
                children: [
                  SizedBox(
                      width: 140,
                      child: Text(entry.key, style: AppTypography.bodySmall)),
                  Expanded(child: Text(entry.value, style: AppTypography.body)),
                ],
              ),
            ),
          if (imageUrls.any((u) => u != null)) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: imageUrls
                  .whereType<String>()
                  .map((u) => ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.network(u,
                            height: 90, width: 90, fit: BoxFit.cover),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkAccountSearchDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LinkAccountSearchDialog> createState() =>
      _LinkAccountSearchDialogState();
}

class _LinkAccountSearchDialogState
    extends ConsumerState<_LinkAccountSearchDialog> {
  final _controller = TextEditingController();
  List<AdminUserListItem> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final results = await ref
          .read(adminRepositoryProvider)
          .getUsers(search: _controller.text.trim());
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Find Account by Name'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  onSubmitted: (_) => _search(),
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _loading ? null : _search),
            ]),
            const SizedBox(height: AppSpacing.sm),
            if (_loading) const CircularProgressIndicator(),
            ..._results.map((u) => ListTile(
                  title: Text(u.fullName),
                  subtitle: Text('${u.role} · ${u.email}'),
                  onTap: () => Navigator.of(context).pop(u.id),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
      ],
    );
  }
}
