// lib/features/agreements/presentation/agreement_detail_screen.dart
//
// Rewritten against the real routes/agreement.js after this session's
// UW 4.1 negotiation-loop rewrite. The old version here only ever
// handled payment-proof upload/review and a plain cancel -- none of
// which match the current backend (proof moved to orders.js; there is
// no generic PATCH /:id). This now surfaces Accept / Reject / Propose
// New Terms for whichever party is the current responding party (UW
// 4.1), the farmer-initiated adjustment flow (UW 5.2), cancel with a
// required reason, and the negotiation history (UW 4.1's "the terms
// being countered remain visible").

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/linear_progress_tracker.dart';
import '../../../core/theme/app_theme.dart';
import '../../authentication/application/auth_controller.dart';
import '../../buyer_mode/application/buyer_mode_controller.dart';
import '../../buyer_mode/presentation/widgets/buyer_mode_label.dart';
import '../domain/agreement.dart';
import '../domain/agreement_round.dart';
import 'agreements_screen.dart';

final _agreementDetailProvider = FutureProvider.autoDispose.family(
  (ref, String id) =>
      ref.watch(agreementsRepositoryProvider).getAgreementDetail(id),
);

final _agreementRoundsProvider =
    FutureProvider.autoDispose.family<List<AgreementRound>, String>(
  (ref, id) => ref.watch(agreementsRepositoryProvider).getRounds(id),
);

const _rejectReasons = {
  'price_too_low_or_high': 'Price too low / too high',
  'quantity_unavailable_or_unneeded': 'Quantity not available / not needed',
  'delivery_window_unworkable': 'Delivery window does not work',
  'no_longer_interested': 'No longer interested',
  'other': 'Other',
};

const _cancelReasons = {
  'found_better_option': 'Found a better option elsewhere',
  'changed_mind': 'Changed my mind',
  'circumstances_changed': 'Circumstances changed',
  'other': 'Other',
};

const _adjustmentReasons = {
  'weather_or_climate_damage': 'Weather or climate damage',
  'pest_or_disease': 'Pest or disease',
  'lower_than_expected_yield': 'Lower than expected yield',
  'delay_in_planting_or_cultivation': 'Delay in planting or cultivation',
  'resource_or_input_shortage': 'Resource or input shortage',
  'other': 'Other',
};

class AgreementDetailScreen extends ConsumerStatefulWidget {
  const AgreementDetailScreen({super.key, required this.agreementId});
  final String agreementId;

  @override
  ConsumerState<AgreementDetailScreen> createState() =>
      _AgreementDetailScreenState();
}

class _AgreementDetailScreenState extends ConsumerState<AgreementDetailScreen> {
  bool _busy = false;

  void _refresh() {
    ref.invalidate(_agreementDetailProvider(widget.agreementId));
    ref.invalidate(_agreementRoundsProvider(widget.agreementId));
    ref.invalidate(agreementsListProvider);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Something went wrong. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() => _run(
      () => ref.read(agreementsRepositoryProvider).accept(widget.agreementId));

  Future<void> _reject() async {
    final result = await _showReasonDialog(
        title: 'Reject Agreement', reasons: _rejectReasons);
    if (result == null) return;
    await _run(() => ref
        .read(agreementsRepositoryProvider)
        .reject(widget.agreementId, reasonCode: result.$1, note: result.$2));
  }

  Future<void> _cancel() async {
    final result = await _showReasonDialog(
        title: 'Cancel Agreement', reasons: _cancelReasons);
    if (result == null) return;
    await _run(() async {
      await ref
          .read(agreementsRepositoryProvider)
          .cancel(widget.agreementId, reasonCode: result.$1, note: result.$2);
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<(String, String?)?> _showReasonDialog(
      {required String title, required Map<String, String> reasons}) {
    String? selected;
    final noteController = TextEditingController();
    return showDialog<(String, String?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (v) => setDialogState(() => selected = v),
                child: Column(
                  children: reasons.entries
                      .map((e) => RadioListTile<String>(
                            title: Text(e.value),
                            value: e.key,
                          ))
                      .toList(),
                ),
              ),
              if (selected == 'other')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                      controller: noteController,
                      decoration:
                          const InputDecoration(labelText: 'Please specify')),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel')),
            TextButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.of(dialogContext)
                      .pop((selected!, noteController.text.trim())),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _propose(Agreement agreement) async {
    final quantityController =
        TextEditingController(text: agreement.quantity.toStringAsFixed(0));
    final priceController =
        TextEditingController(text: agreement.pricePerUnit.toStringAsFixed(2));
    final noteController = TextEditingController();
    DateTime? start = agreement.deliveryDateStart;
    DateTime? end = agreement.deliveryDateEnd;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Propose New Terms'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                    controller: quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Quantity (${agreement.unit})')),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                    controller: priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Price per Unit (₱)')),
                const SizedBox(height: AppSpacing.sm),
                // UW 4.1: "The screen calculates and displays the
                // resulting total (price per unit x quantity) live as
                // either field is edited, so the responding party sees
                // the full cost of their own counter-offer before
                // submitting it."
                AnimatedBuilder(
                  animation: Listenable.merge([quantityController, priceController]),
                  builder: (context, _) {
                    final qty = double.tryParse(quantityController.text.trim());
                    final price = double.tryParse(priceController.text.trim());
                    final total = (qty != null && price != null) ? qty * price : null;
                    return Text(
                      'Total: ${total != null ? '₱${total.toStringAsFixed(2)}' : '—'}',
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: start ?? DateTime.now(),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)));
                        if (picked != null) {
                          setDialogState(() => start = picked);
                        }
                      },
                      child: Text(start == null
                          ? 'From'
                          : '${start!.year}-${start!.month}-${start!.day}'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: end ?? start ?? DateTime.now(),
                            firstDate: start ??
                                DateTime.now()
                                    .subtract(const Duration(days: 365)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)));
                        if (picked != null) setDialogState(() => end = picked);
                      },
                      child: Text(end == null
                          ? 'To'
                          : '${end!.year}-${end!.month}-${end!.day}'),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                    controller: noteController,
                    decoration:
                        const InputDecoration(labelText: 'Note (optional)'),
                    maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Send')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    await _run(() => ref.read(agreementsRepositoryProvider).propose(
          widget.agreementId,
          quantity: double.tryParse(quantityController.text.trim()),
          pricePerUnit: double.tryParse(priceController.text.trim()),
          deliveryDateStart: start,
          deliveryDateEnd: end,
          note: noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        ));
  }

  Future<void> _requestAdjustment(Agreement agreement) async {
    String? reasonCode;
    final noteController = TextEditingController();
    final quantityController = TextEditingController();
    bool changeHarvest = false;
    int month = DateTime.now().month;
    int year = DateTime.now().year;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Request Adjustment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                    'Revise committed quantity and/or your plan\'s estimated harvest month.',
                    style: AppTypography.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                    controller: quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText:
                            'New quantity (${agreement.unit}, optional)')),
                CheckboxListTile(
                  value: changeHarvest,
                  title: const Text('Change estimated harvest month'),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) =>
                      setDialogState(() => changeHarvest = v ?? false),
                ),
                if (changeHarvest)
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: month,
                        decoration: const InputDecoration(labelText: 'Month'),
                        items: List.generate(12, (i) => i + 1)
                            .map((m) => DropdownMenuItem(
                                value: m, child: Text(m.toString())))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => month = v ?? month),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: year,
                        decoration: const InputDecoration(labelText: 'Year'),
                        items: [year, year + 1]
                            .map((y) => DropdownMenuItem(
                                value: y, child: Text(y.toString())))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => year = v ?? year),
                      ),
                    ),
                  ]),
                const SizedBox(height: AppSpacing.sm),
                RadioGroup<String>(
                  groupValue: reasonCode,
                  onChanged: (v) => setDialogState(() => reasonCode = v),
                  child: Column(
                    children: _adjustmentReasons.entries
                        .map((e) => RadioListTile<String>(
                              title: Text(e.value),
                              value: e.key,
                              contentPadding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                ),
                if (reasonCode == 'other')
                  TextField(
                      controller: noteController,
                      decoration:
                          const InputDecoration(labelText: 'Please specify')),
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
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || reasonCode == null) return;

    await _run(() => ref.read(agreementsRepositoryProvider).farmerAdjustment(
          widget.agreementId,
          quantity: double.tryParse(quantityController.text.trim()),
          harvestMonth: changeHarvest ? month : null,
          harvestYear: changeHarvest ? year : null,
          reasonCode: reasonCode!,
          note: noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final agreementAsync =
        ref.watch(_agreementDetailProvider(widget.agreementId));
    final currentUser = ref.watch(authControllerProvider).user;
    final userId = currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Agreement Details')),
      body: agreementAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Couldn\'t load this agreement.')),
        data: (agreement) {
          final isBuyer = userId != null && userId == agreement.buyerId;
          final isSeller = userId != null && userId == agreement.sellerId;
          final canRespond = agreement.canRespond(userId);
          final canCancel = isBuyer || isSeller
              ? (agreement.status == AgreementStatus.pending ||
                  agreement.status == AgreementStatus.negotiating)
              : false;
          final canAdjust = isSeller &&
              (agreement.status == AgreementStatus.pending ||
                  agreement.status == AgreementStatus.negotiating ||
                  agreement.status == AgreementStatus.active);

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(children: [
                  Expanded(
                      child:
                          Text(agreement.productName, style: AppTypography.h1)),
                  if (isBuyerModeRecord(
                      viewerRole: currentUser?.role,
                      viewerId: userId,
                      recordBuyerId: agreement.buyerId))
                    const BuyerModeLabel(),
                ]),
                const SizedBox(height: AppSpacing.xs),
                Text('with ${agreement.counterpartyName(userId)}',
                    style: AppTypography.body),
                const SizedBox(height: AppSpacing.md),
                _AgreementProgressTracker(agreement: agreement),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                    label: 'Quantity',
                    value:
                        '${agreement.quantity.toStringAsFixed(0)} ${agreement.unit}'),
                _DetailRow(
                    label: 'Price per Unit',
                    value: '₱${agreement.pricePerUnit.toStringAsFixed(2)}'),
                _DetailRow(
                    label: 'Total',
                    value: '₱${agreement.totalPrice.toStringAsFixed(2)}'),
                if (agreement.deliveryDateStart != null &&
                    agreement.deliveryDateEnd != null)
                  _DetailRow(
                      label: 'Delivery Window',
                      value:
                          '${_fmt(agreement.deliveryDateStart!)} – ${_fmt(agreement.deliveryDateEnd!)}'),
                if (agreement.deliveryAddress != null)
                  _DetailRow(
                      label: 'Delivery Address',
                      value: agreement.deliveryAddress!),
                if (agreement.notes != null)
                  _DetailRow(label: 'Notes', value: agreement.notes!),
                if (agreement.status == AgreementStatus.rejected &&
                    agreement.rejectionReason != null)
                  _DetailRow(
                      label: 'Rejection Reason',
                      value: agreement.rejectionReason!),
                if (agreement.status == AgreementStatus.expired &&
                    agreement.expiredReason != null)
                  _DetailRow(
                      label: 'Expired Because',
                      value: agreement.expiredReason == 'quantity_exhausted'
                          ? 'Quantity exhausted'
                          : 'Harvest timeline passed'),
                const SizedBox(height: AppSpacing.lg),
                if (canRespond &&
                    agreement.cropPlanPricePerUnit != null &&
                    agreement.cropPlanPricePerUnit != agreement.pricePerUnit)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Original price',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.textMuted)),
                              Text(
                                  '₱${agreement.cropPlanPricePerUnit!.toStringAsFixed(2)}/${agreement.unit}',
                                  style: AppTypography.body),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward,
                            size: 16, color: AppColors.textMuted),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Proposed price',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.textMuted)),
                              Text(
                                  '₱${agreement.pricePerUnit.toStringAsFixed(2)}/${agreement.unit}',
                                  style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (canRespond) ...[
                  const Text('It\'s your turn to respond.',
                      style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: _busy ? null : _reject,
                            child: const Text('Reject'))),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: OutlinedButton(
                            onPressed: _busy ? null : () => _propose(agreement),
                            child: const Text('Counter'))),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: ElevatedButton(
                            onPressed: _busy ? null : _accept,
                            child: const Text('Accept'))),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (agreement.status == AgreementStatus.active &&
                    agreement.orderId != null) ...[
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/orders/${agreement.orderId}'),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('View Order & Payment'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (canAdjust) ...[
                  OutlinedButton.icon(
                    onPressed:
                        _busy ? null : () => _requestAdjustment(agreement),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Request Adjustment'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (canCancel) ...[
                  OutlinedButton(
                    onPressed: _busy ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error),
                    child: const Text('Cancel Agreement'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const Text('Negotiation History', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.sm),
                _RoundsHistory(
                    agreementId: widget.agreementId, unit: agreement.unit),
              ],
            ),
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    // REAL BUG FOUND AND FIXED: same class as order_detail_screen.dart's
    // own _DetailRow -- `value` here can be a long free-text field
    // (deliveryAddress, notes, rejectionReason), which as a plain
    // unbounded Row child demands enough width to squeeze the Expanded
    // label down to near-zero, wrapping it one character per line.
    // Giving both a flex share means neither can collapse the other.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 2,
              child: Text(label, style: AppTypography.bodySmall)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.right,
                style: AppTypography.body
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _AgreementProgressTracker extends StatelessWidget {
  const _AgreementProgressTracker({required this.agreement});
  final Agreement agreement;

  static const _steps = [
    ProgressStep(label: 'Requested', icon: Icons.hourglass_empty),
    ProgressStep(label: 'Active', icon: Icons.handshake_outlined),
    ProgressStep(label: 'Fulfilled', icon: Icons.check_circle_outline),
  ];

  @override
  Widget build(BuildContext context) {
    switch (agreement.status) {
      case AgreementStatus.cancelled:
        return const CancelledStatusBanner(label: 'Agreement Cancelled');
      case AgreementStatus.rejected:
        return const CancelledStatusBanner(label: 'Agreement Rejected');
      case AgreementStatus.expired:
        return const CancelledStatusBanner(label: 'Agreement Expired');
      case AgreementStatus.pending:
        return const LinearProgressTracker(steps: _steps, currentIndex: 0);
      case AgreementStatus.negotiating:
        return const LinearProgressTracker(steps: _steps, currentIndex: 0);
      case AgreementStatus.active:
        return const LinearProgressTracker(steps: _steps, currentIndex: 1);
      case AgreementStatus.fulfilled:
        return const LinearProgressTracker(steps: _steps, currentIndex: 2);
    }
  }
}

class _RoundsHistory extends ConsumerWidget {
  const _RoundsHistory({required this.agreementId, required this.unit});
  final String agreementId;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundsAsync = ref.watch(_agreementRoundsProvider(agreementId));
    return roundsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Couldn\'t load negotiation history.',
          style: AppTypography.bodySmall),
      data: (rounds) {
        if (rounds.isEmpty) {
          return const Text('No history yet.', style: AppTypography.bodySmall);
        }
        return Column(
          children: rounds
              .map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r.actorName} — ${_actionLabel(r.action)}',
                              style: AppTypography.body
                                  .copyWith(fontWeight: FontWeight.w600)),
                          if (r.quantity != null && r.pricePerUnit != null)
                            Text(
                                '${r.quantity!.toStringAsFixed(0)} $unit @ ₱${r.pricePerUnit!.toStringAsFixed(2)}',
                                style: AppTypography.bodySmall),
                          if (r.reason != null)
                            Text(r.reason!, style: AppTypography.bodySmall),
                          if (r.note != null)
                            Text(r.note!, style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  String _actionLabel(String action) => switch (action) {
        'initial' => 'Requested',
        'accept' => 'Accepted',
        'counter' => 'Countered',
        'reject' => 'Rejected',
        'cancel' => 'Cancelled',
        'farmer_adjustment' => 'Adjusted',
        _ => action,
      };
}
