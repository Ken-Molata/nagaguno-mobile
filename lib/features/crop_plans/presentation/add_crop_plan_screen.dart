// lib/features/crop_plans/presentation/add_crop_plan_screen.dart

import '../../../core/constants/product_categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/produce_photo_picker.dart';
import '../../../core/theme/app_theme.dart';
import 'crop_plans_screen.dart';

class AddCropPlanScreen extends ConsumerStatefulWidget {
  const AddCropPlanScreen({super.key});
  @override
  ConsumerState<AddCropPlanScreen> createState() => _AddCropPlanScreenState();
}

class _AddCropPlanScreenState extends ConsumerState<AddCropPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  String _category = productCategories.first;
  DateTime? _plantingDate;
  DateTime? _harvestDate;
  String? _photoPath;
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _pickDate(bool isPlanting) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
    if (_plantingDate == null || _harvestDate == null) {
      setState(() => _errorMessage = 'Please select both dates.');
      return;
    }
    if (!_harvestDate!.isAfter(_plantingDate!)) {
      setState(
          () => _errorMessage = 'Harvest date must be after planting date.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(cropPlansRepositoryProvider).addCropPlan(
            name: _nameController.text.trim(),
            category: _category,
            quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
            pricePerUnit: double.tryParse(_priceController.text.trim()) ?? 0,
            fieldLocation: _locationController.text.trim(),
            plantingDate: _plantingDate!,
            expectedHarvestDate: _harvestDate!,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            photoPath: _photoPath,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Something went wrong. Please try again.');
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
      appBar: AppBar(title: const Text('Add Crop Plan')),
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
                  // Matches the real crop_plans.crop_name VARCHAR(150) limit.
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
                  // Real backend has no server-side check against a
                  // negative/zero/non-numeric quantity either
                  // (verified against routes/cropPlans.js) -- the
                  // previous validator only checked non-empty, not
                  // that it was even a valid number at all.
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
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  // UW 5: "Price per unit" is a field the plan is
                  // created with; UW 5.1 pre-fills the agreement
                  // request form from it. Required server-side.
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
                  // Matches the real crop_plans.field_location VARCHAR(255) limit.
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
                    if (path != null) setState(() => _photoPath = path);
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(_photoPath == null
                      ? 'Add a Photo (optional)'
                      : 'Photo Added'),
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
                      : const Text('Add Crop Plan'),
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
