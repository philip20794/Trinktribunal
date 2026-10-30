import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/case_file.dart';
import 'package:trinktribunal/design/case_stage.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/design/illustrated_paper.dart';

import '../features/ui_cleanup_test.dart' show host;
import 'court_scene_test.dart' show reviewImage;

void main() {
  setUpAll(() async {
    final font = FontLoader('CourtRoboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      font.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
    }
    await font.load();
  });
  // Logical portrait viewports, including both compact SE generations.
  for (final size in [
    const Size(320, 568),
    const Size(375, 667),
    const Size(412, 915),
    const Size(412, 923),
    const Size(440, 956),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final long in [false, true]) {
        testWidgets('front-card regions: $size / $scale / long=$long', (
          tester,
        ) async {
          final question = long
              ? List.filled(80, 'Wie reagierst du vor Gericht?').join(' ')
              : 'Wie reagierst du vor Gericht?';
          await host(
            tester,
            CourtScaffold(
              title: const Text('Fallakte'),
              footer: CourtActionBar(
                primary: FilledButton(
                  onPressed: () {},
                  child: const Text('Weiter'),
                ),
              ),
              body: CaseStage(
                judge: const Text('Richter'),
                rules: 0,
                onRules: () {},
                child: CourtQuestion(
                  label: 'FALL 1 / 20',
                  text: question,
                  green: long
                      ? List.filled(12, 'Sehr freundlich').join(' ')
                      : 'Sehr freundlich',
                  connector: '',
                  red: long
                      ? List.filled(12, 'Sehr unfreundlich').join(' ')
                      : 'Sehr unfreundlich',
                  maximum: 30,
                ),
              ),
            ),
            'de',
            size: size,
            scale: scale,
          );
          final paper = tester.getRect(find.byType(IllustratedPaper));
          final stage = tester.getRect(find.byType(CaseStage));
          final front = tester.getRect(
            find.byKey(const ValueKey('case-front-card')),
          );
          final content = tester.getRect(
            find.byKey(const ValueKey('case-content')),
          );
          final header = tester.getRect(
            find.byKey(const ValueKey('case-header')),
          );
          final footer = tester.getRect(
            find.byKey(const ValueKey('question-range-box')),
          );
          final area = tester.getRect(
            find.byKey(const ValueKey('case-question-area')),
          );
          expect(paper.width / paper.height, closeTo(1024 / 1536, .001));
          expect(stage.contains(paper.topLeft), isTrue);
          expect(stage.contains(paper.bottomRight), isTrue);
          expect(front.contains(content.topLeft), isTrue);
          expect(front.contains(content.bottomRight), isTrue);
          expect(footer.bottom, closeTo(content.bottom, 1));
          expect(area.top, greaterThanOrEqualTo(header.bottom));
          expect(area.bottom, lessThanOrEqualTo(footer.top));
          expect(header.top - content.top, inInclusiveRange(4, 12));
          expect(footer.height, greaterThanOrEqualTo(82));
          final text = tester.widget<Text>(find.text(question));
          expect(text.style!.fontSize, inInclusiveRange(16, 28));
          if (long) {
            final scroller = find.byKey(const ValueKey('case-question-scroll'));
            expect(scroller, findsOneWidget);
            final before = tester.getRect(
              find.byKey(const ValueKey('question-range-box')),
            );
            await tester.drag(scroller, const Offset(0, -120));
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.byKey(const ValueKey('question-range-box'))),
              before,
            );
            final position = tester
                .state<ScrollableState>(
                  find.descendant(
                    of: scroller,
                    matching: find.byType(Scrollable),
                  ),
                )
                .position;
            expect(position.pixels, greaterThan(0));
          }
          expect(find.text('Weiter').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (scale == 1 && !long || size.width == 320 && long && scale == 2) {
            await reviewImage(
              tester,
              'front-card-${size.width.toInt()}-${size.height.toInt()}-$scale-$long',
            );
          }
        });
      }
    }
  }
}
