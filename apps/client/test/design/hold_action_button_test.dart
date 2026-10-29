import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/hold_action_button.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

void main() {
  Future<void> host(
    WidgetTester tester,
    Widget button, {
    bool reduced = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppLanguageScope(
          language: 'de',
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: Center(child: SizedBox(width: 240, child: button)),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('fires once when the animation reaches completed status', (
    tester,
  ) async {
    var completed = 0;
    await host(
      tester,
      HoldActionButton(
        icon: Icons.visibility,
        label: 'Show',
        onCompleted: () => completed++,
      ),
    );
    final target = find.byType(HoldActionButton);
    final gesture = await tester.startGesture(tester.getCenter(target));
    final builder = tester.widget<AnimatedBuilder>(
      find.descendant(of: target, matching: find.byType(AnimatedBuilder)),
    );
    final controller = builder.animation as AnimationController;
    // Completed status must fire even if elapsed time rounds below the duration.
    controller.value = 1;
    await tester.pump();
    expect(completed, 1);
    controller.value = 1;
    await tester.pump();
    expect(completed, 1);
    await gesture.up();
  });

  testWidgets('each button uses its own hold duration', (tester) async {
    var completed = 0, released = 0;
    await host(
      tester,
      HoldActionButton(
        icon: Icons.visibility,
        label: 'Show',
        duration: const Duration(milliseconds: 800),
        onCompleted: () => completed++,
        onReleased: () => released++,
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldActionButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 799));
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(completed, 1);
    await gesture.up();
    expect(released, 1);
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'requires a continuous 1200ms hold and fires once, reduced=$reduced',
      (tester) async {
        var completed = 0, released = 0;
        await host(
          tester,
          HoldActionButton(
            icon: Icons.visibility,
            label: 'Show',
            onCompleted: () => completed++,
            onReleased: () => released++,
          ),
          reduced: reduced,
        );
        final target = find.byType(HoldActionButton);
        final first = await tester.startGesture(tester.getCenter(target));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1199));
        expect(completed, 0);
        await first.up();
        await tester.pump();
        expect(released, 1);
        final second = await tester.startGesture(tester.getCenter(target));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(completed, 1);
        await tester.pump(const Duration(seconds: 3));
        expect(completed, 1);
        await second.up();
        await tester.pump();
        expect(released, 2);
      },
    );
  }

  testWidgets('pointer cancellation and moving out reset the entire charge', (
    tester,
  ) async {
    var completed = 0, released = 0;
    await host(
      tester,
      HoldActionButton(
        icon: Icons.arrow_forward,
        label: 'Next',
        onCompleted: () => completed++,
        onReleased: () => released++,
      ),
    );
    final target = find.byType(HoldActionButton);
    final first = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 900));
    await first.cancel();
    await tester.pump(const Duration(seconds: 2));
    expect(completed, 0);
    final second = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 900));
    await second.moveTo(const Offset(1, 1));
    await tester.pump(const Duration(seconds: 2));
    await second.up();
    expect(completed, 0);
    expect(released, 2);
  });

  testWidgets(
    'keyboard hold reveals after the delay and releases on key up or background',
    (tester) async {
      var visible = false;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await host(
        tester,
        HoldActionButton(
          focusNode: focus,
          icon: Icons.visibility,
          label: 'Show',
          onCompleted: () => visible = true,
          onReleased: () => visible = false,
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(visible, true);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(visible, false);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(visible, true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(visible, false);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );
  testWidgets(
    'removing a held control releases it once and cancels its ticker',
    (tester) async {
      var released = 0;
      await host(
        tester,
        HoldActionButton(
          icon: Icons.visibility,
          label: 'Show',
          onCompleted: () {},
          onReleased: () => released++,
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldActionButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(released, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
