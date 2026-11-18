// lib/features/reviews/presentation/review_dialog.dart
//
// UW 14.1/14.2: review the counterparty once an order is Delivered.
// Called from OrderDetailScreen, which had no reviewing UI at all for
// a real, working backend feature.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'user_reviews_section.dart';
import '../data/reviews_repository.dart';

/// Returns true if a review was successfully posted.
Future<bool> showReviewDialog(BuildContext context, WidgetRef ref,
    {required String orderId, required String counterpartyName}) async {
  int rating = 0;
  final commentController = TextEditingController();
  String? errorMessage;
  bool submitting = false;

  final posted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text('Review $counterpartyName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (errorMessage != null) ...[
              Text(errorMessage!,
                  style: const TextStyle(color: AppColors.statusCancelledFg)),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  5,
                  (i) => IconButton(
                        icon: Icon(i < rating ? Icons.star : Icons.star_border,
                            color: AppColors.accentDark, size: 32),
                        onPressed: () => setDialogState(() => rating = i + 1),
                      )),
            ),
            TextField(
              controller: commentController,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Comment (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: submitting
                ? null
                : () async {
                    if (rating == 0) {
                      setDialogState(
                          () => errorMessage = 'Select a star rating.');
                      return;
                    }
                    setDialogState(() {
                      submitting = true;
                      errorMessage = null;
                    });
                    try {
                      await ref.read(reviewsRepositoryProvider).submitReview(
                            orderId: orderId,
                            rating: rating,
                            comment: commentController.text,
                          );
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop(true);
                    } on ReviewException catch (e) {
                      setDialogState(() {
                        submitting = false;
                        errorMessage = e.message;
                      });
                    } catch (_) {
                      setDialogState(() {
                        submitting = false;
                        errorMessage =
                            'Something went wrong. Please try again.';
                      });
                    }
                  },
            child: const Text('Submit'),
          ),
        ],
      ),
    ),
  );
  return posted ?? false;
}
