// lib/ml/image_validation/crop_identity_checker.dart
//
// Confirms a photo actually shows the SPECIFIC crop a seller claims,
// for the freshness-override flow (freshness_classifier.dart) --
// distinct from produce_classifier.dart's generic "is this produce at
// all" check. Same underlying ML Kit base Image Labeling model
// (there's no second model to fetch/fabricate for this), just
// re-queried against a per-crop keyword set instead of the generic
// produce-keyword list.
//
// Deliberately scoped to only the 8 crops freshness_classifier.dart's
// bundled model actually covers -- there's no reason for this checker
// to exist for any other crop.
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// English visual-category keywords ML Kit's base label vocabulary
/// might plausibly return for each of the 8 covered crops -- NOT a
/// translation of the local Tagalog name (which never appears in ML
/// Kit's own label set), the same "keyword family, not an exact
/// enumerated vocabulary" approach produce_classifier.dart already
/// uses, since ML Kit's full label set isn't published anywhere this
/// could be checked against.
const _cropKeywords = {
  'Ampalaya': ['bitter melon', 'bitter gourd', 'gourd', 'melon', 'vegetable'],
  'Banana': ['banana', 'plantain', 'fruit'],
  'Cucumber': ['cucumber', 'vegetable'],
  'Eggplant': ['eggplant', 'aubergine', 'vegetable'],
  'Orange': ['orange', 'citrus', 'fruit'],
  'Papaya': ['papaya', 'fruit'],
  'Pineapple': ['pineapple', 'fruit'],
  'Tomato': ['tomato', 'vegetable', 'fruit'],
};

class CropIdentityResult {
  const CropIdentityResult({required this.matches, required this.topLabels});
  final bool matches;
  final List<String> topLabels;
}

class CropIdentityChecker {
  CropIdentityChecker()
      : _labeler = ImageLabeler(
            // Lower than produce_classifier.dart's 0.5: a specific
            // crop label is plausibly a lower-confidence match than a
            // broad category one, and this check's own false-positive
            // cost (seller proceeds to the freshness model on a
            // mismatched photo) is lower than produce_classifier's
            // (rejecting a real listing photo outright).
            options: ImageLabelerOptions(confidenceThreshold: 0.4));

  final ImageLabeler _labeler;

  /// [imagePath] must be a local file path, never an already-uploaded
  /// URL. [claimedCrop] should be one of freshness_classifier.dart's
  /// FreshnessModelInfo.coveredCrops -- calling this for anything else
  /// falls back to a bare lowercase string match with no real keyword
  /// list behind it.
  Future<CropIdentityResult> check(String imagePath, String claimedCrop) async {
    final labels =
        await _labeler.processImage(InputImage.fromFilePath(imagePath));
    final topLabels = labels.map((l) => l.label).toList();
    final keywords = _cropKeywords[claimedCrop] ?? [claimedCrop.toLowerCase()];
    final matches = labels.any(
      (l) => keywords.any((k) => l.label.toLowerCase().contains(k)),
    );
    return CropIdentityResult(matches: matches, topLabels: topLabels);
  }

  Future<void> dispose() => _labeler.close();
}
