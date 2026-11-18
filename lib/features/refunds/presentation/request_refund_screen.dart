// lib/features/refunds/presentation/request_refund_screen.dart
//
// UW 9.4: buyer's entry point into the refund flow -- see
// domain/refund_request.dart's header comment for the gap this closes.
// Reached from order_detail_screen.dart, either because the buyer
// chose to request one directly, or because a cancel attempt on an
// already-paid order was refused server-side (routes/orders.js's
// ALREADY_PAID response) and pointed here instead.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_picking.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../data/refunds_repository.dart';
import '../domain/refund_request.dart';

class RequestRefundScreen extends ConsumerStatefulWidget {
  const RequestRefundScreen(
      {super.key, required this.orderId, required this.sellerName});
  final String orderId;
  final String sellerName;

  @override
  ConsumerState<RequestRefundScreen> createState() =>
      _RequestRefundScreenState();
}

class _RequestRefundScreenState extends ConsumerState<RequestRefundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  String? _reasonCode;
  final List<XFile> _photos = [];
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _addPhoto() async {
    if (_photos.length >= 5) return;
    final picked = await pickAndCompressImage();
    if (picked != null) setState(() => _photos.add(picked));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // UW 9.4 / the real backend's own rule: a description and/or at
    // least one photo is required -- a bare reason code with neither
    // isn't enough evidence to act on.
    if (_noteController.text.trim().isEmpty && _photos.isEmpty) {
      setState(() => _errorMessage =
          'Add a description and/or at least one photo as evidence.');
      return;
    }
    if (_reasonCode == 'other' && _noteController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Describe the reason for "Other".');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(refundsRepositoryProvider).fileRequest(
            orderId: widget.orderId,
            reasonCode: _reasonCode!,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            photoPaths: _photos.map((f) => f.path).toList(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund request sent.')),
      );
    } catch (e) {
      if (mounted) setState(() => _errorMessage = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request a Refund')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Order with ${widget.sellerName}',
                    style: AppTypography.body
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.lg),
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
                Text('Reason', style: AppTypography.label),
                const SizedBox(height: AppSpacing.xs),
                RadioGroup<String>(
                  groupValue: _reasonCode,
                  onChanged: (v) => setState(() => _reasonCode = v),
                  child: Column(
                    children: refundReasonLabels.entries
                        .map((e) => RadioListTile<String>(
                              value: e.key,
                              title: Text(e.value),
                              contentPadding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _noteController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Describe what happened',
                      hintText: 'Required if you don\'t attach a photo'),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Photos (optional, up to 5)',
                    style: AppTypography.label),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final photo in _photos)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: Image.file(File(photo.path),
                                width: 72, height: 72, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: IconButton(
                              icon: const Icon(Icons.cancel,
                                  size: 18, color: AppColors.error),
                              onPressed: () =>
                                  setState(() => _photos.remove(photo)),
                            ),
                          ),
                        ],
                      ),
                    if (_photos.length < 5)
                      InkWell(
                        onTap: _addPhoto,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm)),
                          child: const Icon(Icons.add_a_photo_outlined,
                              color: AppColors.textMuted),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: (_submitting || _reasonCode == null)
                      ? null
                      : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent))
                      : const Text('Submit Request'),
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
    _noteController.dispose();
    super.dispose();
  }
}
