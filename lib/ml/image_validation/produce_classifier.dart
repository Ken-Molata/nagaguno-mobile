// lib/ml/image_validation/produce_classifier.dart
//
// UW 11's produce photo validation ("reject non-crop images") — still
// unbuilt even after this session's Vision SafeSearch pass, since
// SafeSearch only screens for adult/violent/racy content and never
// checks the subject of the photo at all. Runs ON-DEVICE, before the
// photo is ever uploaded, via google_mlkit_image_labeling — the same
// ML Kit family already used for KYC liveness detection in this app
// (see ml/inference/liveness_detector.dart), not a separately bundled
// MobileNet .tflite file: this environment has no way to download or
// fabricate a real pretrained model binary (no network access to a
// model zoo, and a model file isn't something to invent the way code
// can be written). Google documents ML Kit's base on-device Image
// Labeling model as a lightweight MobileNet-derived architecture,
// fetched/managed by Play Services the same way the face-detection
// model already is here — the real, buildable equivalent of what was
// asked for, not a different feature standing in for it.
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Keyword-family match against ML Kit's returned label text, rather
/// than an exact enumerated vocabulary: the base on-device model's
/// full label set isn't published anywhere this session could check
/// against, so matching broad categories (fruit/vegetable/plant/food)
/// plus the specific produce names most likely to appear directly in
/// an ImageNet/Open-Images-derived vocabulary is the honest middle
/// ground between guessing an exact list and not checking anything.
const _produceKeywords = [
  'fruit',
  'vegetable',
  'plant',
  'produce',
  'food',
  'crop',
  'leaf',
  'flower',
  'tree',
  'agriculture',
  'farm',
  'seed',
  'grain',
  'banana',
  'tomato',
  'corn',
  'maize',
  'potato',
  'onion',
  'garlic',
  'carrot',
  'cabbage',
  'pepper',
  'cucumber',
  'eggplant',
  'mango',
  'rice',
  'root',
  'tuber',
  'squash',
  'pumpkin',
  'bean',
  'pea',
  'herb',
  'citrus',
  'melon',
  'berry',
  'nut',
  'legume',
];

class ProduceCheckResult {
  const ProduceCheckResult(
      {required this.looksLikeProduce, required this.topLabels});
  final bool looksLikeProduce;
  final List<String> topLabels;
}

class ProduceClassifier {
  ProduceClassifier()
      : _labeler = ImageLabeler(
            options: ImageLabelerOptions(confidenceThreshold: 0.5));

  final ImageLabeler _labeler;

  /// [imagePath] must be a local file path (e.g. straight from
  /// image_picker) — never something already uploaded, matching UW
  /// 11's "before being uploaded" framing exactly.
  Future<ProduceCheckResult> check(String imagePath) async {
    final labels =
        await _labeler.processImage(InputImage.fromFilePath(imagePath));
    final topLabels = labels.map((l) => l.label).toList();
    final looksLikeProduce = labels.any(
      (l) => _produceKeywords
          .any((keyword) => l.label.toLowerCase().contains(keyword)),
    );
    return ProduceCheckResult(
        looksLikeProduce: looksLikeProduce, topLabels: topLabels);
  }

  Future<void> dispose() => _labeler.close();
}
