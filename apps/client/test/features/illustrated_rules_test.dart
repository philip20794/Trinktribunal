import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/verdict.dart';
import 'package:trinktribunal/features/help/help_screen.dart';
import 'package:trinktribunal/features/home/home_screen.dart';
import 'package:trinktribunal/features/rules/game_rules_screen.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../design/court_scene_test.dart' show reviewImage;
import 'ui_cleanup_test.dart' show host;
import 'home_profile_settings_test.dart' show tapVisible;

const review = bool.fromEnvironment('TT_RENDER_REVIEW');
void main() {
  setUpAll(() async {
    if (!review) return;
    final font = FontLoader('CourtRoboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      font.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test(
    'the illustrated two-error example matches the actual normal verdict',
    () {
      final ids = {
        for (final value in rulesCorrectOrder) value: PlayerId('person$value'),
      };
      final judge = PlayerId('judge');
      final verdict = normalVerdict(
        judge: judge,
        numbers: {for (final value in rulesCorrectOrder) ids[value]!: value},
        proposed: [for (final value in rulesJudgeOrder) ids[value]!],
      );
      expect(verdict.errors, 2);
      expect(verdict.sips[judge], 2);
      expect(verdict.sips[ids[7]], 2);
      expect(verdict.sips[ids[2]], 2);
      expect(verdict.sips[ids[11]], 0);
    },
  );

  test(
    'all provided runtime SVGs and their notices are bundled locally',
    () async {
      for (final name in rulesIconNames) {
        final svg = await rootBundle.loadString(
          '$rulesAssetRoot/icons/svg/$name.svg',
        );
        expect(svg, contains('<svg'));
        expect(svg, isNot(contains('<script')));
        expect(svg, isNot(contains('href=')));
      }
      final notices = await rootBundle.loadString(
        '$rulesAssetRoot/LIZENZ-HINWEIS.txt',
      );
      expect(notices, contains('Lucide'));
      expect(notices, contains('ISC License'));
      expect(notices, contains('MIT License'));
    },
  );

  for (final language in ['de', 'en']) {
    for (final size in [
      const Size(320, 640),
      const Size(390, 1400),
      const Size(1440, 900),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'illustrated rules readable, labeled and complete: $language / $size / $scale',
          (tester) async {
            final strings = AppStrings(language);
            await host(
              tester,
              const GameRulesScreen(),
              language,
              size: size,
              scale: scale,
            );
            final semantics = tester.ensureSemantics();
            try {
              expect(find.byType(CourtArt), findsNothing);
              expect(find.text(strings.get('rulesIntroTitle')), findsOneWidget);
              await reviewImage(
                tester,
                'rules-layout-$language-${size.width.toInt()}-${scale.toInt()}',
              );
              for (final key in [
                'rulesStep1Body',
                'rulesStep2Body',
                'rulesStep3Body',
                'rulesStep4Body',
                'rulesJudgeOrderTitle',
                'rulesScoringResult',
                'rulesCorrectPerson',
                'gameRulesAllJudgesBody',
                'gameRulesExtraRulesBody',
              ]) {
                final value = strings.get(key, {'count': 2});
                expect(value, isNot(key));
                final target = find.text(
                  key == 'rulesJudgeOrderTitle' ? value.toUpperCase() : value,
                );
                await tester.scrollUntilVisible(
                  target,
                  220,
                  scrollable: find.byType(Scrollable).first,
                );
                await Scrollable.ensureVisible(
                  tester.element(target),
                  alignment: .1,
                );
                await tester.pumpAndSettle();
                expect(target, findsOneWidget);
                expect(tester.takeException(), isNull);
                if (key == 'rulesJudgeOrderTitle') {
                  expect(
                    find.text(strings.get('rulesIncorrectLabel')),
                    findsNWidgets(2),
                  );
                  expect(
                    find.text(strings.get('rulesCorrectLabel')),
                    findsOneWidget,
                  );
                  await reviewImage(
                    tester,
                    'rules-example-$language-${size.width.toInt()}-${scale.toInt()}',
                  );
                }
              }
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }

    testWidgets('rules back/help icons have real navigation: $language', (
      tester,
    ) async {
      final strings = AppStrings(language);
      await host(tester, const HomeScreen(), language);
      await tapVisible(tester, find.text(strings.get('gameRules')));
      expect(find.byType(GameRulesScreen), findsOneWidget);
      expect(find.byTooltip(strings.get('rulesHelp')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rules-help')));
      await tester.pumpAndSettle();
      expect(find.byType(HelpScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(GameRulesScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rules-back')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
