// lib/features/spoilage/presentation/photo_freshness_check_screen.dart
//
// Lets a seller correct (or confirm) an automatic spoilage flag with a
// real photo, instead of only a self-reported dropdown choice
// (spoilage_monitoring_screen.dart's existing "Report Spoilage"
// dialog, unchanged). Two checks run in sequence:
//   1. CropIdentityChecker (on-device, ML Kit) confirms the photo
//      actually matches this listing's own crop -- rejects, say, a
//      banana photo on an eggplant listing, before the photo is ever
//      uploaded.
//   2. The freshness model itself runs SERVER-SIDE (ml-service/
//      freshness.py's /predict-freshness, via routes/spoilage.js's
//      POST /cv-override/:productId) -- NOT on-device. On-device
//      inference was tried first and abandoned after reproducing a
//      real, confirmed bug in the Flutter TFLite plugin ecosystem that
//      made it unbuildable; running it server-side also means the
//      backend computes the real stage itself from the photo rather
//      than trusting whatever a client claims. The backend classifies
//      AND applies the result in the same call, so this screen shows
//      the outcome, not a separate predict-then-confirm step.
// Only reachable for the crops that model actually covers --
// resolveCoveredCrop below is what the caller (spoilage_monitoring_
// screen.dart) uses to decide whether to even show the entry point,
// against the list SpoilageRepository.getFreshnessCoveredCrops()
// fetches from the backend (not bundled on-device).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_picking.dart';
import '../../../ml/image_validation/crop_identity_checker.dart';
import '../data/spoilage_repository.dart';
import '../domain/spoilage_listing.dart';
import 'spoilage_monitoring_screen.dart' show spoilageRepositoryProvider;

// Mirrors the relevant subset of nagaguno-backend/utils/
// cropNameAliases.js -- only the Tagalog names that map to one of the
// freshness model's covered crops. A listing already named in English
// matches the covered-crops list directly, no alias needed.
const _localCropAliases = {
  'talong': 'Eggplant',
  'kamatis': 'Tomato',
  'saging': 'Banana',
  'pinya': 'Pineapple',
  'pipino': 'Cucumber',
};

/// Resolves a listing's own free-typed name to one of the freshness
/// model's covered crops, or null if it isn't one of them at all --
/// the caller must not offer this feature when this returns null.
String? resolveCoveredCrop(String listingName, List<String> coveredCrops) {
  final lower = listingName.trim().toLowerCase();
  for (final crop in coveredCrops) {
    if (lower.contains(crop.toLowerCase())) return crop;
  }
  final alias = _localCropAliases[lower];
  if (alias != null && coveredCrops.contains(alias)) return alias;
  for (final word in lower.split(RegExp(r'\s+'))) {
    final wordAlias = _localCropAliases[word];
    if (wordAlias != null && coveredCrops.contains(wordAlias)) return wordAlias;
  }
  return null;
}

class PhotoFreshnessCheckScreen extends ConsumerStatefulWidget {
  const PhotoFreshnessCheckScreen(
      {super.key, required this.listing, required this.matchedCrop});
  final SpoilageListing listing;
  final String matchedCrop;

  @override
  ConsumerState<PhotoFreshnessCheckScreen> createState() =>
      _PhotoFreshnessCheckScreenState();
}

class _PhotoFreshnessCheckScreenState
    extends ConsumerState<PhotoFreshnessCheckScreen> {
  final _cropChecker = CropIdentityChecker();

  String? _photoPath;
  bool _busy = false;
  String? _statusMessage;
  String? _error;
  CvOverrideResult? _result;

  @override
  void dispose() {
    _cropChecker.dispose();
    super.dispose();
  }

  Future<void> _pickAndCheck(ImageSource source) async {
    final file = await pickAndCompressImage(source: source);
    if (file == null) return;

    setState(() {
      _photoPath = file.path;
      _busy = true;
      _error = null;
      _result = null;
      _statusMessage = 'Checking photo...';
    });

    try {
      final identity = await _cropChecker.check(file.path, widget.matchedCrop);
      if (!identity.matches) {
        setState(() {
          _busy = false;
          _error =
              "This doesn't look like a photo of ${widget.matchedCrop}. Please take a clearer photo of this listing's own produce.";
        });
        return;
      }

      setState(() => _statusMessage = 'Analyzing freshness...');
      final result = await ref
          .read(spoilageRepositoryProvider)
          .applyCvOverride(widget.listing.productId, photoPath: file.path);
      setState(() {
        _busy = false;
        _result = result;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Something went wrong checking this photo. Please try again.';
      });
    }
  }

  String _stageLabel(String s) => switch (s) {
        'fresh' => 'Fresh',
        'near_spoilage' => 'Near Spoilage',
        'critical' => 'Critical',
        'expired' => 'Expired',
        _ => s,
      };

  Color _stageColor(String s) => switch (s) {
        'fresh' => AppColors.spoilageFresh,
        'near_spoilage' => AppColors.spoilageNear,
        'critical' => AppColors.spoilageCritical,
        'expired' => AppColors.spoilageExpired,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify Freshness: ${widget.listing.name}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Take or upload a photo of this exact ${widget.matchedCrop} listing. '
                'The system will check it really is ${widget.matchedCrop}, then estimate '
                'how fresh it looks and update the status right away -- this can correct '
                'the automatic status in either direction, not just toward more spoiled.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_photoPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.file(File(_photoPath!), height: 220, fit: BoxFit.cover),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickAndCheck(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickAndCheck(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Upload Photo'),
                    ),
                  ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppSpacing.sm),
                    Text(_statusMessage ?? '', style: AppTypography.bodySmall),
                  ]),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: AppColors.statusCancelledBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.statusCancelledFg)),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: _stageColor(_result!.stage),
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text('Updated to: ${_stageLabel(_result!.stage)}',
                            style: AppTypography.h3),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          '${(_result!.remainingPct * 100).toStringAsFixed(0)}% of shelf life remaining (estimated from your photo)',
                          style: AppTypography.bodySmall),
                      const SizedBox(height: 2),
                      Text(
                          'This is an automated estimate, not an exact measurement -- '
                          'retake the photo above if this doesn\'t look right.',
                          style: AppTypography.label
                              .copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
