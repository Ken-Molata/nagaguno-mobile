// lib/features/kyc/presentation/screen_flash_challenge_screen.dart
//
// UW 10.2 "Route B: Screen Flash Challenge" -- replaces
// liveness_camera_screen.dart's blink-based check (built against an
// earlier, now-superseded "KYC Liveness Detection spec"; the current
// UW is explicit that "blinking alone is not used as the liveness
// check, because a blink can be imitated with a short video or an
// animated photo"). This is a discrete 5-photo capture sequence
// (neutral, 3 color flashes, a head turn), not the continuous
// frame-classification stream the old screen ran, so it does not
// reuse ml/inference/liveness_detector.dart -- that whole approach is
// what this replaces, not a dependency of it.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/liveness_challenge.dart';

enum _Phase {
  loading,
  instructions,
  permissionDenied,
  cameraUnavailable,
  neutralReady,
  neutralCountdown,
  colorFlash,
  headTurnPrompt,
  headTurnHolding,
  finishing,
}

// UW 10.2 step 3: "each for about one second (slower than three
// changes per second, so it does not strobe)."
const _colorFlashDuration = Duration(milliseconds: 1000);
// Step 2's "after a 3-second countdown one photo is taken" and step
// 4's "hold still... One photo is taken automatically 3 seconds
// later" share the same 3-second wait.
const _captureDelay = Duration(seconds: 3);

const _colorSwatches = {
  'white': Colors.white,
  'red': Color(0xFFE53E3E),
  'green': Color(0xFF38A169),
  'blue': Color(0xFF3182CE),
};

class ScreenFlashChallengeScreen extends StatefulWidget {
  const ScreenFlashChallengeScreen(
      {super.key, required this.fetchChallenge, required this.onCompleted});

  /// Issues a fresh challenge for this attempt. Injected rather than
  /// calling a repository directly, since this screen is shared by
  /// KYC (authenticated, KycRepository.fetchLivenessChallenge) and
  /// Account Recovery (unauthenticated, gated by its own Step 1 token
  /// instead -- AccountRecoveryRepository.fetchLivenessChallenge).
  final Future<LivenessChallenge> Function() fetchChallenge;

  /// Called once with the finished (or opted-out) capture result.
  final void Function(LivenessCaptureResult result) onCompleted;

  @override
  State<ScreenFlashChallengeScreen> createState() =>
      _ScreenFlashChallengeScreenState();
}

class _ScreenFlashChallengeScreenState
    extends State<ScreenFlashChallengeScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  _Phase _phase = _Phase.instructions;
  bool _permissionPermanentlyDenied = false;
  LivenessChallenge? _challenge;
  String? _neutralPath;
  final _colorPaths = <String>[];
  String? _headTurnPath;
  bool _headTurnSkipped = false;
  int _colorIndex = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.dispose();
      _cameraController = null;
    }
    // Deliberately no auto-resume: unlike the old continuous-stream
    // screen, this one is mid-timed-sequence more often than not, and
    // silently reinitializing the camera mid-countdown would capture
    // a photo the user never saw a prompt for. A backgrounded attempt
    // is simplest treated as abandoned -- the user returns to
    // whatever static phase they left (instructions/prompt text),
    // never mid-countdown, and taps through again.
  }

  Future<void> _startFlow() async {
    setState(() => _phase = _Phase.loading);
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() {
        _phase = _Phase.permissionDenied;
        _permissionPermanentlyDenied = status.isPermanentlyDenied;
      });
      return;
    }
    try {
      _challenge =
          await widget.fetchChallenge();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Couldn't start the check. Please try again.";
        _phase = _Phase.instructions;
      });
      return;
    }
    await _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _phase = _Phase.cameraUnavailable);
        return;
      }
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _cameraController = controller;
      await controller.initialize();
      if (!mounted || !identical(_cameraController, controller)) return;
      setState(() => _phase = _Phase.neutralReady);
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.cameraUnavailable);
    }
  }

  Future<void> _captureNeutral() async {
    setState(() => _phase = _Phase.neutralCountdown);
    await Future.delayed(_captureDelay);
    if (!mounted) return;
    final file = await _cameraController?.takePicture();
    if (file == null) return;
    _neutralPath = file.path;
    _colorIndex = 0;
    _colorPaths.clear();
    setState(() => _phase = _Phase.colorFlash);
    _runNextColorFlash();
  }

  Future<void> _runNextColorFlash() async {
    await Future.delayed(_colorFlashDuration);
    if (!mounted) return;
    final file = await _cameraController?.takePicture();
    if (file == null) return;
    _colorPaths.add(file.path);
    _colorIndex++;
    if (_colorIndex < 3) {
      setState(() {}); // repaint with the next color
      _runNextColorFlash();
    } else {
      setState(() => _phase = _Phase.headTurnPrompt);
    }
  }

  Future<void> _startHeadTurn() async {
    setState(() => _phase = _Phase.headTurnHolding);
    await Future.delayed(_captureDelay);
    if (!mounted) return;
    final file = await _cameraController?.takePicture();
    _headTurnPath = file?.path;
    await _finish();
  }

  /// "I can't turn my head" -- skips only this one step; the color
  /// result is still used, per UW 10.2.
  Future<void> _skipHeadTurn() async {
    _headTurnSkipped = true;
    await _finish();
  }

  Future<void> _finish() async {
    setState(() => _phase = _Phase.finishing);
    await _cameraController?.dispose();
    _cameraController = null;
    if (!mounted) return;
    widget.onCompleted(LivenessCaptureResult.completed(
      challengeCode: _challenge!.challengeCode,
      neutralPath: _neutralPath!,
      colorPaths: List.of(_colorPaths),
      headTurnSkipped: _headTurnSkipped,
      headTurnPath: _headTurnPath,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  void _optOut() {
    widget.onCompleted(const LivenessCaptureResult.optedOut());
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.instructions:
        return _buildInstructions();
      case _Phase.loading:
      case _Phase.finishing:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _Phase.permissionDenied:
        return _buildPermissionDenied();
      case _Phase.cameraUnavailable:
        return _buildCameraUnavailable();
      case _Phase.neutralReady:
        return _buildNeutralReady();
      case _Phase.neutralCountdown:
        return _buildCountdown('Hold still');
      case _Phase.colorFlash:
        return _buildColorFlash();
      case _Phase.headTurnPrompt:
        return _buildHeadTurnPrompt();
      case _Phase.headTurnHolding:
        return _buildCountdown(
            'Slowly turn your head to the ${_challenge!.headTurnDirection}, then hold still');
    }
  }

  Widget _buildInstructions() {
    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: SafeArea(
        // Same real bug class as login_screen.dart (caught on a real
        // device at a larger text size): a bare Padding+Column here
        // would overflow instead of scrolling once content exceeds the
        // viewport.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            // mainAxisSize.min is load-bearing here, not cosmetic: a
            // Column with the default mainAxisSize.max combined with a
            // non-start mainAxisAlignment (center, here) throws an
            // unbounded-height assertion once its parent is a
            // SingleChildScrollView (infinite main-axis constraints) --
            // min makes the Column size to its own content instead,
            // which keeps the center alignment meaningful without that
            // crash.
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phonelink_ring_outlined,
                  size: 72, color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                  'Find a place with normal indoor light, away from direct sunlight.',
                  textAlign: TextAlign.center,
                  style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Take off glasses if they shine. Hold the phone at arm\'s length and keep your face inside the oval. This check shows three colored screens in a row.',
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_errorMessage!,
                    style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: _startFlow,
                child: const Text('Start'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _optOut,
                child: const Text('I\'d rather not do this check'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Camera access is needed to verify it\'s really you.',
                  textAlign: TextAlign.center, style: AppTypography.body),
              const SizedBox(height: AppSpacing.md),
              if (_permissionPermanentlyDenied)
                const ElevatedButton(
                    onPressed: openAppSettings, child: Text('Open Settings'))
              else
                ElevatedButton(
                  onPressed: () => setState(() => _phase = _Phase.instructions),
                  child: const Text('Try Again'),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                  onPressed: _optOut,
                  child: const Text('I\'d rather not do this check')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraUnavailable() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              const Text('We couldn\'t access a camera on this device.',
                  textAlign: TextAlign.center, style: AppTypography.body),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                onPressed: _initCamera,
                child: const Text('Try Again'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                  onPressed: _optOut,
                  child: const Text('I\'d rather not do this check')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeutralReady() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          _ovalGuide(),
          const Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Text(
              'Keep the whole ID inside the frame — now keep your face inside the oval',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontFamily: 'DMSans'),
            ),
          ),
          Positioned(
            bottom: 40,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: ElevatedButton(
              onPressed: _captureNeutral,
              child: const Text('Take photo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdown(String text) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraController != null && _cameraController!.value.isInitialized)
            CameraPreview(_cameraController!),
          _ovalGuide(),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'DMSans'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorFlash() {
    final color = _challenge!.colorSequence[_colorIndex];
    return Scaffold(
      backgroundColor: _colorSwatches[color] ?? Colors.white,
      body: const Center(
        child: Text(
          'Keep looking at the screen',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.black54,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'DMSans'),
        ),
      ),
    );
  }

  Widget _buildHeadTurnPrompt() {
    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Slowly turn your head to the ${_challenge!.headTurnDirection}, then hold still.',
                textAlign: TextAlign.center,
                style: AppTypography.h2,
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: _startHeadTurn,
                child: const Text('Ready'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _skipHeadTurn,
                child: const Text('I can\'t turn my head'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ovalGuide() {
    return Center(
      child: Container(
        width: 240,
        height: 320,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 3),
          borderRadius: BorderRadius.circular(120),
        ),
      ),
    );
  }
}
