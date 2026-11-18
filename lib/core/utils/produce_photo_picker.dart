// lib/core/utils/produce_photo_picker.dart
//
// Shared by every screen that uploads a produce photo (product
// listings, crop plans). UW 11 says "reject non-crop images" and this
// is now a STRICT gate, per explicit instruction: no "use anyway"
// override exists anymore -- a photo that fails either on-device check
// below is rejected outright and the seller must pick a different one.
// Two separate, distinct checks, each with its own rejection message:
//   1. FacePresenceDetector -- a photo containing a human face is
//      always rejected (product/crop photos must show only the item).
//   2. ProduceClassifier -- a photo that doesn't look like produce at
//      all is rejected.
// Both run on-device, before the file is ever handed back for upload.
// The backend (routes/products.js, routes/cropPlans.js) now runs the
// same two checks again server-side via Google Cloud Vision
// (utils/visionService.js's checkProducePhoto) when that API key is
// configured -- a non-mobile or modified client can't bypass this the
// way it could when the check existed only here. Without that key,
// this on-device gate is the only enforcement; it still has no
// override, but a modified client skips it entirely, same caveat as
// before -- see visionService.js's header for the full picture.

import 'package:flutter/material.dart';
import 'image_picking.dart';
import '../theme/app_theme.dart';
import '../../ml/image_validation/produce_classifier.dart';
import '../../ml/image_validation/face_presence_detector.dart';

/// Returns the picked file's path, or null if the user cancelled the
/// picker or the photo was rejected by either check. There is no
/// override -- a rejected photo must be replaced, not force-accepted.
///
/// UW 11: "Uploading shows 'Checking image...'" then, on success,
/// "'Image verified.'" -- both were missing even though the checks
/// themselves ran; added here as a non-dismissible loading dialog
/// around the on-device checks and a brief confirmation on success,
/// so this follows the same Loading/Success/Failure pattern (Section
/// 19) every other validated action in this codebase already follows.
Future<String?> pickProducePhoto(BuildContext context) async {
  final file = await pickAndCompressImage();
  if (file == null) return null;

  if (!context.mounted) return null;
  _showChecking(context);

  Future<void> dismissChecking() async {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  final faceDetector = FacePresenceDetector();
  try {
    final hasFace = await faceDetector.containsFace(file.path);
    if (hasFace) {
      await dismissChecking();
      if (context.mounted) {
        await _showRejection(
          context,
          title: 'Photo rejected',
          message:
              'This photo shows a human face. Product and crop photos must show only the item itself — please choose a different photo.',
        );
      }
      return null;
    }
  } finally {
    await faceDetector.dispose();
  }

  final classifier = ProduceClassifier();
  try {
    final result = await classifier.check(file.path);
    if (!result.looksLikeProduce) {
      await dismissChecking();
      if (context.mounted) {
        // UW 11's exact rejection text, verbatim -- kept identical to
        // utils/visionService.js's PRODUCE_PHOTO_REJECTION_MESSAGES.not_produce
        // on the backend, same reasoning as this session's other
        // shared-wording fixes (the two must never drift apart).
        await _showRejection(
          context,
          title: 'Photo rejected',
          message:
              'This doesn\'t look like a crop or agricultural produce. Please upload a clear photo of the product.',
        );
      }
      return null;
    }
  } finally {
    await classifier.dispose();
  }

  await dismissChecking();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image verified.'), duration: Duration(seconds: 2)));
  }
  return file.path;
}

void _showChecking(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: AppSpacing.md),
          Text('Checking image...'),
        ],
      ),
    ),
  );
}

Future<void> _showRejection(BuildContext context,
    {required String title, required String message}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.accent),
          child: const Text('Choose Another Photo'),
        ),
      ],
    ),
  );
}
