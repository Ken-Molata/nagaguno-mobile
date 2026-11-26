// lib/features/products/presentation/add_edit_product_screen.dart

import '../../../core/constants/product_categories.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/produce_photo_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../data/my_products_repository.dart';
import '../domain/my_product.dart';
import 'my_products_screen.dart';

// Category list kept as the single source of truth matching the real
// spoilage_category_defaults table values, same list used in the
// marketplace screen — not independently re-invented here.

const _units = ['kg', 'g', 'piece', 'bundle', 'sack', 'liter'];

class AddEditProductScreen extends ConsumerStatefulWidget {
  const AddEditProductScreen({super.key, this.existing});
  final MyProduct? existing;

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.existing?.name);
  late final _priceController =
      TextEditingController(text: widget.existing?.pricePerUnit.toString());
  late final _stockController =
      TextEditingController(text: widget.existing?.stockQty.toString() ?? '0');
  late final _descriptionController =
      TextEditingController(text: widget.existing?.description);
  late String _category = widget.existing?.category ?? productCategories.first;
  late String _unit = widget.existing?.unit ?? 'kg';
  late DateTime? _harvestedAt = widget.existing?.harvestedAt;
  String? _newPhotoPath;
  bool _submitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  // REAL INTEGRITY GAP FOUND AND FIXED, BY EXPLICIT REQUEST: harvest
  // date drives the ENTIRE automatic spoilage calculation (Part I of
  // the project documentation -- remaining_pct is computed from
  // CURRENT_DATE minus harvested_at). Letting a seller freely re-edit
  // it after creation meant they could reset an aging listing's
  // computed freshness stage back to "fresh" at will, with no
  // verification at all -- the exact same unverified-override gap the
  // manual spoilage dropdown's removal (spoilage_monitoring_screen.dart)
  // already closed, just reached through a completely different
  // screen. Harvest date is now fixed once a listing is created; it
  // can only ever be set at creation time.
  bool get _harvestDateLocked => _isEditing;

  // REAL INTEGRITY GAP FOUND AND FIXED, BY EXPLICIT REQUEST: the
  // automatic spoilage discount (auto_discount_pct) combines
  // ADDITIVELY with listed_price to produce the generated
  // price_per_unit column (Part I of the project documentation) --
  // but nothing stopped a seller from simply raising listed_price
  // while that automatic discount was active, silently cancelling out
  // its real economic effect while the "% off" badge buyers see still
  // displayed as if a genuine markdown were in effect. Price is now
  // locked while an automatic spoilage discount is currently applied;
  // it unlocks again once the discount clears (the listing recovers,
  // or is removed from sale).
  bool get _priceLocked => widget.existing?.hasActiveAutoDiscount ?? false;

  Future<void> _pickPhoto() async {
    // UW 11: runs the on-device produce check (ml/image_validation/
    // produce_classifier.dart) before accepting the photo at all.
    final path = await pickProducePhoto(context);
    if (path != null) setState(() => _newPhotoPath = path);
  }

  Future<void> _pickHarvestedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _harvestedAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      // Required server-side to be not in the future ("Harvest date
      // can't be in the future.", re-verified this session).
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _harvestedAt = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_harvestedAt == null) {
      setState(() => _errorMessage = 'Select a harvest date.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final repo = ref.read(myProductsRepositoryProvider);
    try {
      if (_isEditing) {
        await repo.updateProduct(
          id: widget.existing!.id,
          name: _nameController.text.trim(),
          category: _category,
          pricePerUnit: double.parse(_priceController.text.trim()),
          unit: _unit,
          stockQty: double.tryParse(_stockController.text.trim()) ?? 0,
          harvestedAt: _harvestedAt,
          description: _descriptionController.text.trim(),
          photoPath: _newPhotoPath,
        );
      } else {
        await repo.addProduct(
          name: _nameController.text.trim(),
          category: _category,
          pricePerUnit: double.parse(_priceController.text.trim()),
          unit: _unit,
          stockQty: double.tryParse(_stockController.text.trim()) ?? 0,
          harvestedAt: _harvestedAt!,
          description: _descriptionController.text.trim(),
          photoPath: _newPhotoPath,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
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
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
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
                InkWell(
                  onTap: _pickPhoto,
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundStart,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _newPhotoPath != null ||
                            widget.existing?.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            child: _newPhotoPath != null
                                ? Image.file(File(_newPhotoPath!),
                                    fit: BoxFit.cover)
                                : Image.network(widget.existing!.imageUrl!,
                                    fit: BoxFit.cover),
                          )
                        : const Center(
                            child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  size: 32, color: AppColors.textMuted),
                              Text('Add a photo')
                            ],
                          )),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  // 200 matches the real products.name VARCHAR(200)
                  // column limit exactly -- there's no explicit
                  // backend-level length check (verified this
                  // session), so exceeding this would otherwise
                  // surface as a raw, unfriendly database error
                  // rather than a clean validation message.
                  maxLength: 200,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required.'
                      : null,
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        enabled: !_priceLocked,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Price per Unit (₱)',
                          helperText: _priceLocked
                              ? 'Locked while an automatic spoilage discount is active'
                              : null,
                          helperMaxLines: 2,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final parsed = double.tryParse(v.trim());
                          if (parsed == null) return 'Enter a valid number';
                          // The real backend has NO server-side check
                          // against this at all (verified this session
                          // -- just parseFloat with no range/sign
                          // validation), so this client-side check is
                          // the only thing preventing a negative price
                          // from genuinely being stored and shown to
                          // buyers.
                          if (parsed <= 0) {
                            return 'Price must be greater than zero';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _unit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: _units
                            .map((u) =>
                                DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setState(() => _unit = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _stockController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Stock Quantity'),
                  // Same real gap as price: no server-side check
                  // against a negative value exists.
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return null; // optional, defaults to 0 server-side
                    }
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null) return 'Enter a valid number';
                    if (parsed < 0) return 'Stock cannot be negative';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: _harvestDateLocked ? null : _pickHarvestedDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Harvest Date',
                      helperText: _harvestDateLocked
                          ? 'Fixed once set -- drives the automatic spoilage calculation'
                          : null,
                      helperMaxLines: 2,
                      enabled: !_harvestDateLocked,
                    ),
                    child: Text(_harvestedAt == null
                        ? 'Select date'
                        : '${_harvestedAt!.year}-${_harvestedAt!.month.toString().padLeft(2, '0')}-${_harvestedAt!.day.toString().padLeft(2, '0')}'),
                  ),
                ),
                // UW 3.3: storage condition and shelf life are no longer
                // collected here -- the backend already resolves a
                // default from the per-crop reference table
                // (resolveShelfLifeDays) when they're omitted, and an
                // edit's COALESCE-based UPDATE leaves an existing
                // value untouched when this screen doesn't send one.
                // "Shelf life seems wrong?" below remains the real
                // channel for a farmer to correct it, instead of a
                // raw days field most sellers have no reason to touch.
                // UW 3.3 "Farmer feedback" -- only meaningful for an
                // existing listing (a new one has no observed history
                // yet to report against).
                if (widget.existing != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          _showShelfLifeFeedbackDialog(widget.existing!),
                      child: const Text('Shelf life seems wrong?'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)'),
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
                      : Text(_isEditing ? 'Save Changes' : 'Add Product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showShelfLifeFeedbackDialog(MyProduct product) async {
    String direction = 'shorter';
    final daysController = TextEditingController();
    final noteController = TextEditingController();
    String? dialogError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Shelf Life Seems Wrong?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dialogError != null) ...[
                  Text(dialogError!,
                      style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: AppSpacing.sm),
                ],
                RadioGroup<String>(
                  groupValue: direction,
                  onChanged: (v) => setDialogState(() => direction = v!),
                  child: const Column(children: [
                    RadioListTile<String>(
                        value: 'longer',
                        title: Text('Lasts longer than shown'),
                        dense: true),
                    RadioListTile<String>(
                        value: 'shorter',
                        title: Text('Spoils sooner than shown'),
                        dense: true),
                  ]),
                ),
                TextField(
                  controller: daysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Days you observed'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Note (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final days = int.tryParse(daysController.text.trim());
                if (days == null || days <= 0) {
                  setDialogState(
                      () => dialogError = 'Enter the number of days.');
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(myProductsRepositoryProvider).submitShelfLifeFeedback(
            product.id,
            direction: direction,
            observedDays: int.parse(daysController.text.trim()),
            note: noteController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Thanks. Our team will review this.')));
      }
    } on ProductRepositoryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
