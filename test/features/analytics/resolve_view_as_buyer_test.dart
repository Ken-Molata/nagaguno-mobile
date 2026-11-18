// test/features/analytics/resolve_view_as_buyer_test.dart
//
// The mobile-side counterpart to the real backend's resolveViewAsBuyer
// (routes/analytics.js -- same name deliberately, same contract):
// whether this screen should fetch/display sales or purchases. A pure
// function, not a ref-based helper (see sales_analytics_screen.dart's
// own comment for why), so it's testable directly with no provider
// container or widget tree needed.
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/analytics/presentation/sales_analytics_screen.dart';
import 'package:nagaguno_mobile/features/authentication/domain/nagaguno_user.dart';

NagagunoUser _user(String role) => NagagunoUser(
    id: 'u1', fullName: 'Test User', role: role, accountStatus: 'active');

void main() {
  group('resolveViewAsBuyer', () {
    test('a null user (not yet loaded) is never viewAsBuyer', () {
      expect(resolveViewAsBuyer(user: null, buyerModeOn: true), isFalse);
    });

    test(
        'a plain Buyer is ALWAYS viewAsBuyer, independent of the Buyer Mode toggle',
        () {
      expect(
          resolveViewAsBuyer(user: _user('buyer'), buyerModeOn: false), isTrue);
      expect(
          resolveViewAsBuyer(user: _user('buyer'), buyerModeOn: true), isTrue);
    });

    test('a Farmer sees their own sales by default (Buyer Mode off)', () {
      expect(resolveViewAsBuyer(user: _user('farmer'), buyerModeOn: false),
          isFalse);
    });

    test(
        'a Farmer sees their purchases once Buyer Mode is switched on -- UW 1.5/16.5',
        () {
      expect(
          resolveViewAsBuyer(user: _user('farmer'), buyerModeOn: true), isTrue);
    });

    test('a Vendor follows the same rule as a Farmer', () {
      expect(resolveViewAsBuyer(user: _user('vendor'), buyerModeOn: false),
          isFalse);
      expect(
          resolveViewAsBuyer(user: _user('vendor'), buyerModeOn: true), isTrue);
    });

    test(
        'an Admin account is never viewAsBuyer, even with the toggle somehow on',
        () {
      expect(
          resolveViewAsBuyer(user: _user('admin'), buyerModeOn: true), isFalse);
    });
  });
}
