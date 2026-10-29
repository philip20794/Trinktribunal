import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/court_motion.dart';

void main() {
  testWidgets(
    'file entrance keeps controls available immediately and settles within its budget',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CourtMotion(
                style: CourtMotionStyle.file,
                child: FilledButton(
                  onPressed: () => taps++,
                  child: const Text('Continue'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Continue'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.tap(find.text('Continue'));
      expect(taps, 1);
      await tester.pump(const Duration(milliseconds: 220));
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(CourtMotion),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(transform.transform.storage[13], 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final accessible in [false, true]) {
    testWidgets(
      'reduced/accessible motion renders the same usable content without a tween: $accessible',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                disableAnimations: !accessible,
                accessibleNavigation: accessible,
              ),
              child: const CourtMotion(
                style: CourtMotionStyle.stamp,
                child: Text('Verdict'),
              ),
            ),
          ),
        );
        expect(find.text('Verdict'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is TweenAnimationBuilder<double>,
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
