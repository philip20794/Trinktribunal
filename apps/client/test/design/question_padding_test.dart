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
  for (final (size, cardHeight) in [
    (const Size(320, 568), 320.0),
    (const Size(360, 700), 520.0),
    (const Size(390, 844), 560.0),
    (const Size(430, 932), 650.0),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'compact paper margins at ${size.width}, height $cardHeight, text scale $scale',
        (tester) async {
          await host(
            tester,
            CasePaperScope(
              maxHeight: cardHeight,
              child: SizedBox(
                height: cardHeight,
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
            size: size,
            scale: scale,
          );
          final paper = tester.getRect(find.byType(IllustratedPaper));
          final box = tester.getRect(
            find.byKey(const ValueKey('question-range-box')),
          );
          expect(
            paper.bottom - box.bottom,
            inInclusiveRange(size.width * .12 + 8, size.width * .12 + 24),
          );
          expect(box.left - paper.left, inInclusiveRange(30, 48));
          expect(paper.right - box.right, closeTo(box.left - paper.left, 1));
          expect(box.top, greaterThan(paper.top));
          for (var frame = 0; frame < 3; frame++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump();
          }
          await reviewImage(
            tester,
            'question-insets-${size.width.toInt()}-${scale.toInt()}',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
