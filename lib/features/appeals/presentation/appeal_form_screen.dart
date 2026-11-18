// lib/features/appeals/presentation/appeal_form_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_picking.dart';
import '../data/appeals_repository.dart';
import '../domain/appeal.dart';
import 'account_status_screen.dart';

class AppealFormScreen extends ConsumerStatefulWidget {
  const AppealFormScreen({super.key, required this.targetType});
  final AppealTargetType targetType;

  @override
  ConsumerState<AppealFormScreen> createState() => _AppealFormScreenState();
}

class _AppealFormScreenState extends ConsumerState<AppealFormScreen> {
  final _essayController = TextEditingController();
  final List<String> _photoPaths = [];
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _addPhoto() async {
    if (_photoPaths.length >= 5) return;
    final file = await pickAndCompressImage();
    if (file != null) setState(() => _photoPaths.add(file.path));
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(appealsRepositoryProvider).submitAppeal(
            targetType: widget.targetType,
            essay: _essayController.text,
            photoPaths: _photoPaths,
          );
      ref.invalidate(myAppealsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Appeal submitted. An admin will review it.')));
    } on AppealException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Appeal ${widget.targetType.label}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                  'Explain why this decision should be reversed. You can include a written explanation, photos, or both.',
                  style: AppTypography.body),
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
              TextFormField(
                controller: _essayController,
                maxLines: 5,
                decoration: const InputDecoration(
                    labelText: 'Explanation (optional if you attach photos)'),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final path in _photoPaths)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppRadius.sm)),
                        child: Image.file(File(path), fit: BoxFit.cover),
                      ),
                    ),
                  if (_photoPaths.length < 5)
                    InkWell(
                      onTap: _addPhoto,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppRadius.sm)),
                        child: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                ],
              ),
              Text('${_photoPaths.length}/5 photos',
                  style: AppTypography.label),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accent))
                    : const Text('Submit Appeal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _essayController.dispose();
    super.dispose();
  }
}
