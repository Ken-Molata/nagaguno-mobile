// lib/features/agreements/presentation/new_agreement_screen.dart
//
// Rewritten against the real POST /agreements (UW 4.1/5.1): a Smart
// Agreement always originates from a specific production plan
// (crop_plan_id), with price pre-filled from the plan and overridable,
// and the delivery term is a RANGE constrained to the plan's estimated
// harvest month -- not a free-text product name, arbitrary price, and
// single date up to a year out, which is what this screen sent before
// and would have 422'd against the current backend.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/pricing.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../../buyer_mode/presentation/widgets/buyer_mode_banner.dart';
import 'agreements_screen.dart';

class NewAgreementScreen extends ConsumerStatefulWidget {
  const NewAgreementScreen({
    super.key,
    required this.cropPlanId,
    required this.cropName,
    required this.sellerName,
    required this.unit,
    required this.suggestedPrice,
    required this.availableQuantity,
    required this.harvestMonth,
    required this.harvestYear,
  });

  final String cropPlanId;
  final String cropName;
  final String sellerName;
  final String unit;
  final double suggestedPrice;
  final double availableQuantity;
  final int harvestMonth;
  final int harvestYear;

  @override
  ConsumerState<NewAgreementScreen> createState() => _NewAgreementScreenState();
}

class _NewAgreementScreenState extends ConsumerState<NewAgreementScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _quantityController = TextEditingController();
  late final _priceController = TextEditingController(
      text: widget.suggestedPrice > 0
          ? widget.suggestedPrice.toStringAsFixed(2)
          : '');
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _deliveryStart;
  DateTime? _deliveryEnd;
  bool _submitting = false;
  String? _errorMessage;

  DateTime get _harvestMonthStart =>
      DateTime(widget.harvestYear, widget.harvestMonth, 1);
  DateTime get _harvestMonthEnd =>
      DateTime(widget.harvestYear, widget.harvestMonth + 1, 0);

  double get _totalPreview {
    final qty = parsePositiveDoubleOrZero(_quantityController.text);
    final price = parsePositiveDoubleOrZero(_priceController.text);
    return calculateTotal(quantity: qty, pricePerUnit: price);
  }

  Future<void> _pickDeliveryStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _harvestMonthStart,
      firstDate: _harvestMonthStart,
      lastDate: _harvestMonthEnd,
    );
    if (picked == null) return;
    setState(() {
      _deliveryStart = picked;
      if (_deliveryEnd != null && _deliveryEnd!.isBefore(picked)) {
        _deliveryEnd = picked;
      }
    });
  }

  Future<void> _pickDeliveryEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryStart ?? _harvestMonthStart,
      firstDate: _deliveryStart ?? _harvestMonthStart,
      lastDate: _harvestMonthEnd,
    );
    if (picked != null) setState(() => _deliveryEnd = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deliveryStart == null || _deliveryEnd == null) {
      setState(() => _errorMessage = 'Please select a delivery date range.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(agreementsRepositoryProvider).createAgreement(
            cropPlanId: widget.cropPlanId,
            quantity: double.parse(_quantityController.text.trim()),
            pricePerUnit: double.tryParse(_priceController.text.trim()),
            deliveryDateStart: _deliveryStart!,
            deliveryDateEnd: _deliveryEnd!,
            deliveryAddress: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      ref.invalidate(agreementsListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      // REAL BUG FOUND AND FIXED: every real backend validation message
      // this endpoint can return (verification required, quantity
      // exhausted, the delivery-range-vs-harvest-month check, "this
      // plan has no listed price yet") was discarded in favor of one
      // hardcoded generic string -- the exact "Something went wrong.
      // Please try again." a buyer would see regardless of which of
      // those was the real cause, with no way to tell which one it
      // actually was.
      if (mounted) {
        setState(() => _errorMessage = friendlyErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _fmt(DateTime? d) => d == null
      ? 'Select date'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Agreement')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BuyerModeBanner(),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: AppColors.backgroundStart,
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Row(children: [
                    const Icon(Icons.storefront_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: Text(
                            '${widget.cropName} from ${widget.sellerName}',
                            style: AppTypography.body)),
                  ]),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Up to ${widget.availableQuantity.toStringAsFixed(0)} ${widget.unit} available. Delivery must fall within '
                  '${_harvestMonthStart.month}/${_harvestMonthStart.year} (the plan\'s estimated harvest month).',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                        color: AppColors.statusCancelledBg,
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: AppColors.statusCancelledFg)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: 'Quantity (${widget.unit})'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null) return 'Enter a valid number';
                    if (parsed <= 0) return 'Must be greater than zero';
                    if (widget.availableQuantity > 0 &&
                        parsed > widget.availableQuantity) {
                      return 'Only ${widget.availableQuantity.toStringAsFixed(0)} ${widget.unit} is available';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText:
                          'Price per Unit (₱) — leave as-is to use the listed price'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null) return 'Enter a valid number';
                    if (parsed <= 0) return 'Must be greater than zero';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                    alignment: Alignment.centerRight,
                    child: Text('Total: ₱${_totalPreview.toStringAsFixed(2)}',
                        style: AppTypography.h3)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDeliveryStart,
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Delivery From'),
                          child: Text(_fmt(_deliveryStart)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: _deliveryStart == null ? null : _pickDeliveryEnd,
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Delivery To'),
                          child: Text(_fmt(_deliveryEnd)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                      labelText: 'Delivery Address (optional)'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent))
                      : const Text('Send Agreement Request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
