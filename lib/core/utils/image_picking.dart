// lib/core/utils/image_picking.dart
//
// Every real backend upload endpoint this app talks to enforces a
// server-side file size limit (5MB for products/crop-plans/profile/
// agreements, 10MB for KYC — verified against each route's multer
// config this session) -- but every ImagePicker call site across the
// app only set imageQuality, with no maxWidth/maxHeight constraint.
// A modern phone camera can produce 12MP+ photos that exceed even the
// 10MB KYC limit at 85% JPEG quality alone, so this centralizes a
// real, meaningful size guard rather than leave 7 separate call sites
// each relying on JPEG compression alone to stay under a hard server
// limit.

import 'package:image_picker/image_picker.dart';

/// 1600px on the long edge comfortably preserves enough detail for ID
/// photos, product listings, and profile pictures, while keeping
/// typical JPEG output well under even the stricter 5MB limit most
/// endpoints enforce.
///
/// Returns null on failure the same way a user-cancelled picker does
/// (rather than letting a PlatformException propagate uncaught) --
/// ImagePicker.pickImage can genuinely throw in some edge cases
/// (another picker already active, certain permission states on some
/// Android versions), and none of the 6 real call sites across this
/// app wrapped this call in a try/catch. Fixing it once here, at the
/// source, rather than in each of the 6 places that call this.
Future<XFile?> pickAndCompressImage(
    {ImageSource source = ImageSource.gallery}) async {
  try {
    return await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
  } catch (_) {
    return null;
  }
}

/// Counterpart to [pickAndCompressImage] for product reviews (UW
/// 14.1), which now accept a short video alongside photos --
/// routes/reviews.js's own multer config was widened to accept common
/// video extensions in the same upload field, up to 50MB. No
/// compression knob exists for video the way imageQuality does for
/// stills; the 50MB server-side ceiling is the real constraint, same
/// null-on-failure contract as the image picker above.
Future<XFile?> pickVideo({ImageSource source = ImageSource.gallery}) async {
  try {
    return await ImagePicker().pickVideo(source: source);
  } catch (_) {
    return null;
  }
}
