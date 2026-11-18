// lib/features/crop_plans/presentation/edit_crop_plan_screen.dart
//
// Closes a real gap: crop plans could be created and stage-updated,
// but nothing let a farmer correct the core details afterward
// (wrong quantity entered, field location changed, harvest date
// pushed back) despite the real backend's PATCH /:id supporting all
// of this already.

import '../../../core/constants/product_categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/produce_photo_picker.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/crop_plan.dart';
import 'crop_plans_screen.dart';

class EditCropPlanScreen extends ConsumerStatefulWidget {
  const EditCropPlanScreen({super.key, required this.plan});
  final CropPlan plan;
  @override
  ConsumerState<EditCropPlanScreen> createState() => _EditCropPlanScreenState();
}

class _EditCropPlanScreenState extends ConsumerState<EditCropPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.plan.cropName);
  late final _quantityController =
      TextEditingController(text: widget.plan.quantityKg.toString());
  late final _priceController =
      TextEditingController(text: widget.plan.pricePerUnit.toString());
  late final _locationController =
      TextEditingController(text: widget.plan.fieldLocation);
  late final _notesController = TextEditingController(text: widget.plan.notes);
  late String _category = widget.plan.category;
  late DateTime? _plantingDate = widget.plan.plantingDate;
  late DateTime? _harvestDate = widget.plan.expectedHarvest;
  String? _newPhotoPath;
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _pickDate(bool isPlanting) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          (isPlanting ? _plantingDate : _harvestDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      setState(
          () => isPlanting ? _plantingDate = picked : _harvestDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_plantingDate != null &&
        _harvestDate != null &&
        !_harvestDate!.isAfter(_plantingDate!)) {
      setState(
          () => _errorMessage = 'Harvest date must be after planting date.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(cropPlansRepositoryProvider).updateCropPlan(
            id: widget.plan.id,
            name: _nameController.text.trim(),
            category: _category,
            quantity: double.tryParse(_quantityController.text.trim()),
            pricePerUnit: double.tryParse(_priceController.text.trim()),
            fieldLocation: _locationController.text.trim(),
            plantingDate: _plantingDate,
            expectedHarvestDate: _harvestDate,
            notes: _notesController.text.trim(),
            photoPath: _newPhotoPath,
          );
      ref.invalidate(cropPlansProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      // REAL BUG FOUND AND FIXED: this discarded the real backend
      // message -- including the one that actually matters here,
      // "This plan has an agreement requested or active against it.
      // Changing quantity or harvest timing now requires the farmer-
      // initiated adjustment flow..." -- in favor of a generic string
      // that gave no hint an agreement was even the reason, let alone
      // that Add Stock (below) is the way to still raise quantity.
      if (mounted) {
        setState(() => _errorMessage = friendlyErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // UW 4.3: PATCH (the Save Changes button above) refuses any
  // quantity/harvest edit once an agreement exists against this plan --
  // this is the separate path that CAN still raise quantity in that
  // case, reopening any request that previously expired from this
  // plan selling out (see crop_plans_repository.dart's own comment).
  Future<void> _addStock() async {
    final controller = TextEditingController();
    final additional = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Stock'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: 'Additional quantity (${widget.plan.unit})'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (additional == null || additional <= 0 || !mounted) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final (_, message) = await ref
          .read(cropPlansRepositoryProvider)
          .addQuantity(widget.plan.id, additional);
      ref.invalidate(cropPlansProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) setState(() => _errorMessage = friendlyErrorMessage(e));
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
      appBar: AppBar(title: const Text('Edit Crop Plan')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Crop Name'),
                  maxLength: 150,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: productCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Expected Quantity (kg)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null) return 'Enter a valid number';
                    if (parsed <= 0) return 'Must be greater than zero';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _submitting ? null : _addStock,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Stock'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Price per Unit (₱)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null) return 'Enter a valid number';
                    if (parsed <= 0) return 'Must be greater than zero';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _locationController,
                  decoration:
                      const InputDecoration(labelText: 'Field Location'),
                  maxLength: 255,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(true),
                        child: InputDecorator(
                            decoration: const InputDecoration(
                                labelText: 'Planting Date'),
                            child: Text(_fmt(_plantingDate))),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(false),
                        child: InputDecorator(
                            decoration: const InputDecoration(
                                labelText: 'Expected Harvest'),
                            child: Text(_fmt(_harvestDate))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () async {
                    // UW 11: on-device produce check before accepting.
                    final path = await pickProducePhoto(context);
                    if (path != null) setState(() => _newPhotoPath = path);
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(_newPhotoPath == null
                      ? 'Change Photo'
                      : 'New Photo Selected'),
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
                      : const Text('Save Changes'),
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
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
