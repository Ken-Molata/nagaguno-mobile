// lib/features/reviews/presentation/product_review_dialog.dart
//
// UW 14.1: a separate review of the product itself (up to 3 photos),
// distinct from reviewing the seller (review_dialog.dart). Called
// per order item from OrderDetailScreen, buyer-only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_picking.dart';
import 'user_reviews_section.dart';
import '../data/reviews_repository.dart';

const _videoExtensions = {'.mp4', '.mov', '.webm', '.m4v'};
bool _looksLikeVideo(String path) =>
    _videoExtensions.any((ext) => path.toLowerCase().endsWith(ext));

/// Returns true if a review was successfully posted.
Future<bool> showProductReviewDialog(BuildContext context, WidgetRef ref,
    {required String orderItemId, required String productName}) async {
  int rating = 0;
  final commentController = TextEditingController();
  final photoPaths = <String>[];
  String? errorMessage;
  bool submitting = false;

  final posted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text('Review $productName'),
        content: SingleChildScrollView(
          child: Column(
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
                          icon: Icon(
                              i < rating ? Icons.star : Icons.star_border,
                              color: AppColors.accentDark,
                              size: 32),
                          onPressed: () => setDialogState(() => rating = i + 1),
                        )),
              ),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Comment (optional)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final path in photoPaths)
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                      // REAL GAP FOUND AND FIXED: a video attachment
                      // used to be impossible here at all -- only
                      // pickAndCompressImage() was ever wired up, even
                      // though nothing about a product review should
                      // be photo-only. Shown with a distinct icon so a
                      // picked video isn't mistaken for a still photo
                      // in this preview strip.
                      child: Icon(_looksLikeVideo(path)
                          ? Icons.videocam_outlined
                          : Icons.image_outlined),
                    ),
                  if (photoPaths.length < 3) ...[
                    InkWell(
                      onTap: () async {
                        final file = await pickAndCompressImage();
                        if (file != null) {
                          setDialogState(() => photoPaths.add(file.path));
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppRadius.sm)),
                        child: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final file = await pickVideo();
                        if (file != null) {
                          setDialogState(() => photoPaths.add(file.path));
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppRadius.sm)),
                        child: const Icon(Icons.video_call_outlined),
                      ),
                    ),
                  ],
                ],
              ),
              Text('${photoPaths.length}/3 photos or videos',
                  style: AppTypography.label),
            ],
          ),
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
                      await ref
                          .read(reviewsRepositoryProvider)
                          .submitProductReview(
                            orderItemId: orderItemId,
                            rating: rating,
                            comment: commentController.text,
                            photoPaths: photoPaths,
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
