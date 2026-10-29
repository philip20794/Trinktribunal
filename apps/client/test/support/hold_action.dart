import 'package:trinktribunal/design/hold_action_button.dart';
import 'package:flutter_test/flutter_test.dart';

Future<TestGesture> startChargedHold(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump();
  final button = target.evaluate().single.widget is HoldActionButton
      ? tester.widget<HoldActionButton>(target)
      : tester.widget<HoldActionButton>(
          find.ancestor(of: target, matching: find.byType(HoldActionButton)),
        );
  await tester.pump(button.duration);
  await tester.pumpAndSettle();
  return gesture;
}

Future<void> holdAction(WidgetTester tester, Finder target) async {
  final gesture = await startChargedHold(tester, target);
  await gesture.up();
  await tester.pumpAndSettle();
}
