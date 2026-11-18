// test/features/walkthrough/walkthrough_step_test.dart
//
// UW 2.3 First-Time Walkthrough: walkthroughStepsForRole, the one
// piece of pure logic this feature has (the screen itself just drives
// a PageView and two existing repository calls -- nothing else to
// unit test independent of widget rendering).
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/walkthrough/domain/walkthrough_step.dart';

void main() {
  group('walkthroughStepsForRole', () {
    test('a buyer gets exactly UW 2.3\'s three named buyer topics', () {
      final steps = walkthroughStepsForRole('buyer');
      expect(steps, hasLength(3));
      expect(steps[0].title, contains('Browse'));
      expect(steps[1].title, contains('Production Plan'));
      expect(steps[2].title, contains('Past Orders'));
    });

    test('a farmer gets UW 2.3\'s three named Farmer/Vendor topics', () {
      final steps = walkthroughStepsForRole('farmer');
      expect(steps, hasLength(3));
      expect(steps[0].title, contains('Create a Listing or Plan'));
      expect(steps[1].title, contains('Incoming Requests'));
      expect(steps[2].title, contains('Fulfill'));
    });

    test('a vendor gets the exact same steps as a farmer -- UW 2.3 groups them together', () {
      expect(walkthroughStepsForRole('vendor'), walkthroughStepsForRole('farmer'));
    });

    test('an unrecognized role falls back to the buyer steps rather than throwing or returning empty', () {
      expect(walkthroughStepsForRole('admin'), walkthroughStepsForRole('buyer'));
      expect(walkthroughStepsForRole('bogus'), walkthroughStepsForRole('buyer'));
    });

    test('every step has a non-empty title and description', () {
      for (final role in ['buyer', 'farmer', 'vendor']) {
        for (final step in walkthroughStepsForRole(role)) {
          expect(step.title, isNotEmpty);
          expect(step.description, isNotEmpty);
        }
      }
    });
  });
}
