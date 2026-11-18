// test/features/kyc/liveness_challenge_test.dart
//
// UW 10.2 Screen Flash Challenge -- LivenessChallenge.fromJson (the
// server-assigned color sequence/head-turn direction/code) and the
// two LivenessCaptureResult factories, since the submit flow branches
// on .optedOut.
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/kyc/domain/liveness_challenge.dart';

void main() {
  group('LivenessChallenge.fromJson', () {
    test('parses all fields', () {
      final challenge = LivenessChallenge.fromJson({
        'challengeCode': 'abc123',
        'colorSequence': ['white', 'red', 'blue'],
        'headTurnDirection': 'left',
        'expiresAt': '2026-01-01T00:05:00Z',
      });
      expect(challenge.challengeCode, 'abc123');
      expect(challenge.colorSequence, ['white', 'red', 'blue']);
      expect(challenge.headTurnDirection, 'left');
      expect(challenge.expiresAt, DateTime.parse('2026-01-01T00:05:00Z'));
    });
  });

  group('LivenessCaptureResult', () {
    test('optedOut() carries no capture data', () {
      const result = LivenessCaptureResult.optedOut();
      expect(result.optedOut, isTrue);
      expect(result.challengeCode, isNull);
      expect(result.neutralPath, isNull);
      expect(result.colorPaths, isEmpty);
      expect(result.headTurnSkipped, isFalse);
      expect(result.headTurnPath, isNull);
    });

    test('completed() with a head-turn photo', () {
      const result = LivenessCaptureResult.completed(
        challengeCode: 'abc123',
        neutralPath: '/tmp/neutral.jpg',
        colorPaths: ['/tmp/c1.jpg', '/tmp/c2.jpg', '/tmp/c3.jpg'],
        headTurnSkipped: false,
        headTurnPath: '/tmp/head.jpg',
      );
      expect(result.optedOut, isFalse);
      expect(result.colorPaths, hasLength(3));
      expect(result.headTurnSkipped, isFalse);
      expect(result.headTurnPath, '/tmp/head.jpg');
    });

    test('completed() with the head-turn step skipped', () {
      const result = LivenessCaptureResult.completed(
        challengeCode: 'abc123',
        neutralPath: '/tmp/neutral.jpg',
        colorPaths: ['/tmp/c1.jpg', '/tmp/c2.jpg', '/tmp/c3.jpg'],
        headTurnSkipped: true,
      );
      expect(result.headTurnSkipped, isTrue);
      expect(result.headTurnPath, isNull);
    });
  });
}
