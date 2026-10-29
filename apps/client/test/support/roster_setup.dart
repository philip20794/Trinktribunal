import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> addTestPlayers(WidgetTester tester) async {
  for (final name in ['Alex', 'Bea', 'Cleo']) {
    await tester.enterText(
      find.byKey(const ValueKey('quick-player-name')),
      name,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}
