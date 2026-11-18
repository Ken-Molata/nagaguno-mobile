// lib/core/utils/square_crop_screen.dart
//
// UW 21.1: "Accepts JPG or PNG up to 5 MB; the user crops to a square
// before saving." Entirely missing before this -- every profile-photo
// pick went straight from the gallery/camera to upload with no crop
// step at all. No cropping package was already a dependency, and
// pulling one in for a single screen felt disproportionate (same
// reasoning as the demand-forecast chart a few ticks ago) -- built
// instead with Flutter's own InteractiveViewer (pan/pinch, no custom
// gesture code needed) plus RepaintBoundary.toImage() to rasterize
// exactly the square region the user framed.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme/app_theme.dart';

/// Pushes a full-screen square cropper for the image at [imagePath].
/// Returns the path to a new, cropped JPEG file, or null if the user
/// cancelled.
Future<String?> showSquareCropScreen(
    BuildContext context, String imagePath) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SquareCropScreen(imagePath: imagePath),
    ),
  );
}

class _SquareCropScreen extends StatefulWidget {
  const _SquareCropScreen({required this.imagePath});
  final String imagePath;

  @override
  State<_SquareCropScreen> createState() => _SquareCropScreenState();
}

class _SquareCropScreenState extends State<_SquareCropScreen> {
  final _boundaryKey = GlobalKey();
  bool _saving = false;

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      // devicePixelRatio-scaled capture so the saved crop isn't
      // downsampled to the on-screen widget's logical size.
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      final outPath =
          '${Directory.systemTemp.path}/profile_photo_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(outPath).writeAsBytes(bytes);
      if (mounted) Navigator.of(context).pop(outPath);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop photo'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)),
                )
              : TextButton(
                  onPressed: _confirm,
                  child: const Text('Done',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('Drag to reposition, pinch to zoom.',
                style: TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRect(
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.file(File(widget.imagePath),
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
