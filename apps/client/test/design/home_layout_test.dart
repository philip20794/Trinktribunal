import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/home_layout.dart';

void main() {
  test('native startup and transient narrow viewports never create negative constraints', () {
    for (final width in [0.0, 1.0, 20.0, 39.0, 40.0]) {
      expect(homeCardWidth(width), 0.0, reason: 'viewport $width');
    }
  });
  test(
    'phone fills padded width; desktop keeps three equal bounded columns',
    () {
      expect(homeCardWidth(360), 320);
      expect(homeCardWidth(840), 256);
      expect(homeCardWidth(1056), 328);
      expect(homeCardWidth(1440), 328);
    },
  );
}
