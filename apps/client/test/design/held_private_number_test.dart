import 'package:flutter/material.dart';

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/private_number.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

class _Harness extends StatefulWidget {
  const _Harness();
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool shown = false;
  int completions = 0, reveals = 0;
  @override
  Widget build(BuildContext context) => HeldPrivateNumber(
    number: shown ? 37 : null,
    onReveal: () => setState(() {
      shown = true;
      reveals++;
    }),
    onHide: () => setState(() => shown = false),
    onDone: () => setState(() => completions++),
  );
}

Future<void> pump(WidgetTester tester) => tester.pumpWidget(
  const AppLanguageScope(
    language: 'de',
    child: MaterialApp(home: Scaffold(body: _Harness())),
  ),
);
Finder get hold => find.text(const AppStrings('de').get('holdToReveal'));

void main() {
  testWidgets(
    'a supplied stale value cannot appear without a new physical hold',
    (tester) async {
      await tester.pumpWidget(
        AppLanguageScope(
          language: 'de',
          child: MaterialApp(
            home: Scaffold(
              body: HeldPrivateNumber(
                number: 37,
                onReveal: () {},
                onHide: () {},
                onDone: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('37'), findsNothing);
      final gesture = await tester.startGesture(tester.getCenter(hold));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('37'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('37'), findsNothing);
    },
  );
  testWidgets(
    'pointer hold stays visible outside; up/cancel hide and never advance',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pump(tester);
        expect(find.text('37'), findsNothing);
        final label = const AppStrings('de')
            .get('secretNumber', {'number': 37});
        expect(find.bySemanticsLabel(label), findsNothing);
        var gesture = await tester.startGesture(tester.getCenter(hold));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.text('37'), findsOneWidget);
        expect(find.bySemanticsLabel(label), findsOneWidget);
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.text('37'), findsNothing);
        gesture = await tester.startGesture(tester.getCenter(hold));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        await gesture.cancel();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.text('37'), findsNothing);
        gesture = await tester.startGesture(tester.getCenter(hold));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        await gesture.moveTo(const Offset(-10, -10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.text('37'), findsOneWidget);
        await gesture.moveTo(tester.getCenter(hold));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.text('37'), findsOneWidget);
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(
          tester.state<_HarnessState>(find.byType(_Harness)).completions,
          0,
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.down(tester.getCenter(hold));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.text('37'), findsOneWidget);
        await mouse.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.text('37'), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );
  for (final key in [LogicalKeyboardKey.space, LogicalKeyboardKey.enter]) {
    testWidgets(
      'held ${key.keyLabel} reveals once, repeat does not toggle, key up hides',
      (tester) async {
        await pump(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.sendKeyDownEvent(key);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.text('37'), findsOneWidget);
        await tester.sendKeyRepeatEvent(key);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.text('37'), findsOneWidget);
        expect(tester.state<_HarnessState>(find.byType(_Harness)).reveals, 1);
        await tester.sendKeyUpEvent(key);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.text('37'), findsNothing);
      },
    );
  }
  testWidgets(
    'focus loss, background and dialog hide a held value; return never reopens it',
    (tester) async {
      await pump(tester);
      var gesture = await tester.startGesture(tester.getCenter(hold));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('37'), findsNothing);
      await gesture.up();
      gesture = await tester.startGesture(tester.getCenter(hold));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('37'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('37'), findsNothing);
      await gesture.up();
      gesture = await tester.startGesture(tester.getCenter(hold));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      final context = tester.element(find.byType(_Harness));
      final dialog = showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text('Help'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.state<_HarnessState>(find.byType(_Harness)).shown, isFalse);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await dialog;
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('37'), findsNothing);
    },
  );
  testWidgets(
    'Done stays disabled until a real reveal, then remains available while concealed',
    (tester) async {
      await pump(tester);
      final done = find.widgetWithText(
        FilledButton,
        'Fertig – weiter zum nächsten Spieler',
      );
      expect(tester.widget<FilledButton>(done).onPressed, isNull);
      final gesture = await tester.startGesture(tester.getCenter(hold));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(tester.widget<FilledButton>(done).onPressed, isNotNull);
      await tester.tap(done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      final state = tester.state<_HarnessState>(find.byType(_Harness));
      expect(state.shown, isFalse);
      expect(state.reveals, 1);
      expect(state.completions, 1);
    },
  );
}
