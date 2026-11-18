// lib/features/crop_plans/presentation/create_listing_from_plan_screen.dart
//
// UW 15.2's "reached its estimated harvest date, prompting listing or
// production plan update": the real action behind that prompt. Name,
// category, and unit come straight from the plan and aren't editable
// here -- they're shown read-only -- since the server pre-fills a new
// crop listing (UW 3) from the production plan (UW 5) it's created
// against (routes/products.js's POST /from-plan/:planId). The one
// thing the plan genuinely cannot supply is the real harvest date
// (UW 5: the plan only ever has "month and year, never a specific
// day"), so that's still required here exactly as in an ordinary
// listing.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/produce_photo_picker.dart';
import '../../products/data/my_products_repository.dart';
import '../../products/presentation/my_products_screen.dart';
import '../domain/crop_plan.dart';

const _storageConditions = {
  'room_temperature': 'Room Temperature',
  'refrigerated': 'Refrigerated',
};

class CreateListingFromPlanScreen extends ConsumerStatefulWidget {
  const CreateListingFromPlanScreen({super.key, required this.plan});
  final CropPlan plan;

  @override
  ConsumerState<CreateListingFromPlanScreen> createState() =>
      _CreateListingFromPlanScreenState();
}

class _CreateListingFromPlanScreenState
    extends ConsumerState<CreateListingFromPlanScreen> {
  /// The "remaining unlisted quantity" ledger (routes/products.js's
  /// remainingPlanQuantity) -- falls back to the plan's full
  /// quantityKg only if this screen was somehow reached without it
  /// (GET /production always includes it, so that fallback should
  /// never actually be exercised in practice).
  double get _remaining =>
      widget.plan.remainingQuantity ?? widget.plan.quantityKg;

  late final _priceController =
      TextEditingController(text: widget.plan.pricePerUnit.toString());
  late final _stockController =
      TextEditingController(text: _remaining.toString());
  final _shelfLifeController = TextEditingController();
  String _storageCondition = 'room_temperature';
  DateTime? _harvestedAt;
  String? _newPhotoPath;
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _pickPhoto() async {
    final path = await pickProducePhoto(context);
    if (path != null) setState(() => _newPhotoPath = path);
  }

  Future<void> _pickHarvestedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _harvestedAt = picked);
  }

  Future<void> _submit() async {
    if (_harvestedAt == null) {
      setState(() => _errorMessage = 'Select the date you harvested.');
      return;
    }
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _errorMessage = 'Enter a price greater than ₱0.');
      return;
    }
    final requestedStock = double.tryParse(_stockController.text.trim());
    if (requestedStock == null || requestedStock <= 0) {
      setState(() => _errorMessage = 'Enter a quantity greater than 0.');
      return;
    }
    // Same cap the server itself enforces (routes/products.js's
    // remainingPlanQuantity) -- checked here too for immediate
    // feedback, not as a substitute for that server-side check.
    if (requestedStock > _remaining) {
      setState(() => _errorMessage =
          'Only ${_remaining.toStringAsFixed(0)} ${widget.plan.unit} remaining from this plan.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(myProductsRepositoryProvider).createListingFromPlan(
            planId: widget.plan.id,
            harvestedAt: _harvestedAt!,
            pricePerUnit: price,
            stockQty: double.tryParse(_stockController.text.trim()),
            storageCondition: _storageCondition,
            shelfLifeDays: int.tryParse(_shelfLifeController.text.trim()),
            photoPath: _newPhotoPath,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Listing created from production plan.')));
    } on MissingBarangayException {
      if (mounted) {
        setState(() => _errorMessage =
            'Please set your barangay in your profile before listing products.');
      }
    } on ProductRepositoryException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Listing')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('From your production plan',
                  style: AppTypography.label),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                    color: AppColors.backgroundStart,
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(
                  children: [
                    if (widget.plan.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.network(widget.plan.imageUrl!,
                            width: 40, height: 40, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.plan.cropName, style: AppTypography.h3),
                          Text(
                              '${widget.plan.category} · ${widget.plan.quantityKg.toStringAsFixed(0)} ${widget.plan.unit} planned',
                              style: AppTypography.bodySmall),
                          Text(
                              '${_remaining.toStringAsFixed(0)} ${widget.plan.unit} remaining to list',
                              style: AppTypography.bodySmall.copyWith(
                                  color: _remaining > 0
                                      ? AppColors.textMuted
                                      : AppColors.error,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: AppColors.statusCancelledBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(_errorMessage!,
                      style:
                          const TextStyle(color: AppColors.statusCancelledFg)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              InkWell(
                onTap: _pickPhoto,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundStart,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _newPhotoPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Image.file(File(_newPhotoPath!),
                              fit: BoxFit.cover),
                        )
                      : widget.plan.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: Image.network(widget.plan.imageUrl!,
                                  fit: BoxFit.cover),
                            )
                          : const Center(
                              child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    size: 32, color: AppColors.textMuted),
                                Text('Add a listing photo (optional)')
                              ],
                            )),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _pickHarvestedDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Harvest Date'),
                  child: Text(_harvestedAt == null
                      ? 'Select the date you harvested'
                      : '${_harvestedAt!.year}-${_harvestedAt!.month.toString().padLeft(2, '0')}-${_harvestedAt!.day.toString().padLeft(2, '0')}'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Price per Unit (₱)'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: 'Quantity (${widget.plan.unit})'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _storageCondition,
                      decoration:
                          const InputDecoration(labelText: 'Storage Condition'),
                      items: _storageConditions.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _storageCondition = v!),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _shelfLifeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Shelf Life (days, optional)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: (_submitting || _remaining <= 0) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accent))
                    : Text(_remaining <= 0
                        ? 'Nothing Left to List'
                        : 'Create Listing'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _stockController.dispose();
    _shelfLifeController.dispose();
    super.dispose();
  }
}
