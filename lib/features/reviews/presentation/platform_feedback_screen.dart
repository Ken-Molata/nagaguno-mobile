// lib/features/reviews/presentation/platform_feedback_screen.dart
//
// UW 14.4: general platform feedback (admin-only visibility, not a
// public review) -- a real, working endpoint with no mobile screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'user_reviews_section.dart';
import '../data/reviews_repository.dart';

class PlatformFeedbackScreen extends ConsumerStatefulWidget {
  const PlatformFeedbackScreen({super.key});
  @override
  ConsumerState<PlatformFeedbackScreen> createState() =>
      _PlatformFeedbackScreenState();
}

class _PlatformFeedbackScreenState
    extends ConsumerState<PlatformFeedbackScreen> {
  final _messageController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (_messageController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your feedback.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(reviewsRepositoryProvider)
          .submitFeedback(_messageController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for the feedback!')));
    } on ReviewException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Feedback')),
      body: SafeArea(
        // Same real bug class as login_screen.dart (caught on a real
        // device at a larger text size): a bare Padding+Column here
        // would overflow instead of scrolling once content exceeds the
        // viewport.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                  'Tell us what\'s working, what\'s not, or what you\'d like to see.',
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
                controller: _messageController,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Your Feedback'),
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
                    : const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
