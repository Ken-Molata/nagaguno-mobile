// test/features/accessibility/accessibility_settings_test.dart
//
// UW 21.6: AccessibilitySettings.textScale -- the four named tiers'
// exact multipliers ("Standard (100%), Large (125%), Extra Large
// (150%), Maximum (175%)"), the one piece of pure logic this
// account-backed settings feature has (accessibilitySettingsProvider
// itself just derives from authControllerProvider's cached user,
// nothing to unit test independent of that).
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/accessibility/application/accessibility_settings.dart';

void main() {
  group('AccessibilitySettings.textScale', () {
    test('standard is 100%', () {
      expect(const AccessibilitySettings(textSize: 'standard').textScale, 1.0);
    });

    test('large is 125%', () {
      expect(const AccessibilitySettings(textSize: 'large').textScale, 1.25);
    });

    test('extra_large is 150%', () {
      expect(const AccessibilitySettings(textSize: 'extra_large').textScale, 1.5);
    });

    test('maximum is 175%', () {
      expect(const AccessibilitySettings(textSize: 'maximum').textScale, 1.75);
    });

    test('an unrecognized tier falls back to 100% rather than throwing', () {
      expect(const AccessibilitySettings(textSize: 'bogus').textScale, 1.0);
    });

    test('the default constructor is Standard', () {
      expect(const AccessibilitySettings().textScale, 1.0);
      expect(const AccessibilitySettings().highContrast, false);
      expect(const AccessibilitySettings().boldText, false);
      expect(const AccessibilitySettings().reduceMotion, false);
    });
  });
}
