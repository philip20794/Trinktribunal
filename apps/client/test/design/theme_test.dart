import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/court_theme.dart';

void main() {
  test('primary text and semantic colors meet readable contrast on paper', () {
    for (final color in [
      CourtTokens.ink,
      CourtTokens.wood,
      CourtTokens.red,
      CourtTokens.blue,
      CourtTokens.green,
    ]) {
      final a = color.computeLuminance();
      final b = CourtTokens.paper.computeLuminance();
      expect(
        (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
  test('responsive bank and reduced-motion tokens', () {
    for (final width in [360.0, 390.0, 768.0, 1440.0]) {
      expect(CourtTokens.bankColumns(width, 2), 2);
      expect(CourtTokens.bankColumns(width, 1), width >= 600 ? 3 : 2);
    }
    expect(CourtTokens.motionDuration(true), Duration.zero);
    expect(
      CourtTokens.motionDuration(false).inMilliseconds,
      lessThanOrEqualTo(150),
    );
    expect(CourtTokens.touchTarget, greaterThanOrEqualTo(48));
  });
  test('theme uses bundled font, files and license exist', () {
    expect(courtTheme().textTheme.bodyMedium!.fontFamily, 'CourtRoboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      expect(
        File('assets/fonts/roboto-$weight.ttf').lengthSync(),
        greaterThan(100000),
      );
    }
    expect(
      File('assets/fonts/roboto_license.txt').readAsStringSync(),
      contains('Apache License'),
    );
  });
}
