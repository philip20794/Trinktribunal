import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/design/game_finished_panel.dart';
import 'package:trinktribunal/design/illustrated_paper.dart';

import 'court_scene_test.dart' show host, reviewImage;

void main() {
  for (final size in [
    const Size(280, 640),
    const Size(390, 844),
    const Size(760, 1100),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('finished parchment fits $size at $scale', (tester) async {
        var taps = 0;
        await host(
          tester,
          CourtScaffold(
            title: const Text('Trinktribunal'),
            body: GameFinishedPanel(onNewGame: () => taps++),
          ),
          size: size,
          scale: scale,
        );
        expect(find.byType(IllustratedPaper), findsOneWidget);
        final paper = tester.getRect(find.byType(IllustratedPaper));
        final content = tester.getRect(
          find.byKey(const ValueKey('game-finished-content')),
        );
        expect(paper.contains(content.topLeft), isTrue);
        expect(paper.contains(content.bottomRight), isTrue);
        final button = find.byKey(const ValueKey('finished-new-game'));
        expect(button.hitTestable(), findsOneWidget);
        await reviewImage(
          tester,
          'game-finished-${size.width.toInt()}-${scale.toInt()}',
        );
        await tester.tap(button);
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
