import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/case_file.dart';
import 'package:trinktribunal/design/illustrated_paper.dart';

import '../features/ui_cleanup_test.dart' show host;
import 'court_scene_test.dart' show reviewImage;

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('TT_RENDER_REVIEW')) return;
    final font = FontLoader('CourtRoboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      font.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
    }
    await font.load();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'range box retains clear lower paper margin at text scale $scale',
      (tester) async {
        await host(
          tester,
          CasePaperScope(
            maxHeight: 520,
            child: SizedBox(
              height: 520,
              child: CourtQuestion(
                label: 'Fall 1 von 20',
                text: 'Wie überzeugend wäre deine Verteidigung vor Gericht?',
                green: 'Überhaupt nicht überzeugend',
                connector: '',
                red: 'Absolut überzeugend',
                maximum: 30,
              ),
            ),
          ),
          'de',
          size: const Size(360, 700),
          scale: scale,
        );
        final paper = tester.getRect(find.byType(IllustratedPaper));
        final box = tester.getRect(
          find.byKey(const ValueKey('question-range-box')),
        );
        expect(paper.bottom - box.bottom, greaterThan(60));
        expect(box.top, greaterThan(paper.top));
        for (var frame = 0; frame < 3; frame++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await reviewImage(tester, 'question-bottom-inset-${scale.toInt()}');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
