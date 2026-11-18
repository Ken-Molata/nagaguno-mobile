// lib/features/kyc/domain/liveness_challenge.dart
//
// UW 10.2 Route B: the server-assigned parts of one capture attempt.
// Fetched fresh from POST /kyc/liveness-challenge at the start of each
// attempt (including a retry), never reused across attempts.

class LivenessChallenge {
  const LivenessChallenge({
    required this.challengeCode,
    required this.colorSequence,
    required this.headTurnDirection,
    required this.expiresAt,
  });

  final String challengeCode;
  final List<String> colorSequence; // e.g. ['white', 'red', 'green']
  final String headTurnDirection; // 'left' | 'right'
  final DateTime expiresAt;

  factory LivenessChallenge.fromJson(Map<String, dynamic> json) =>
      LivenessChallenge(
        challengeCode: json['challengeCode'] as String,
        colorSequence: List<String>.from(json['colorSequence'] as List),
        headTurnDirection: json['headTurnDirection'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

/// Result of a completed (or opted-out / head-turn-skipped) capture
/// attempt, handed back to KycSubmissionScreen the same way
/// LivenessCameraScreen's onCaptured(path) used to.
class LivenessCaptureResult {
  const LivenessCaptureResult.optedOut()
      : optedOut = true,
        challengeCode = null,
        neutralPath = null,
        colorPaths = const [],
        headTurnSkipped = false,
        headTurnPath = null;

  const LivenessCaptureResult.completed({
    required String this.challengeCode,
    required String this.neutralPath,
    required this.colorPaths,
    required this.headTurnSkipped,
    this.headTurnPath,
  }) : optedOut = false;

  final bool optedOut;
  final String? challengeCode;
  final String? neutralPath;
  final List<String> colorPaths; // exactly 3, in capture order
  final bool headTurnSkipped;
  final String? headTurnPath;
}
