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
    for (final phone in [const Size(320, 640), const Size(390, 844)]) {
      testWidgets(
        'all essential rules fit without scrolling: $language/$phone',
        (tester) async {
          await host(
            tester,
            const GameRulesScreen(),
            language,
            size: phone,
            scale: 1,
          );
          final scrollable = find.descendant(
            of: find.byKey(const ValueKey('rules-scroll')),
            matching: find.byType(Scrollable),
          );
          expect(
            tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
            closeTo(0, .1),
          );
          expect(
            find.byKey(const ValueKey('rules-extra-users')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('rules-extra-book-open')).hitTestable(),
            findsOneWidget,
          );
          final correct = tester.getRect(
            find.byKey(const ValueKey('correct-1')),
          );
          final judge = tester.getRect(find.byKey(const ValueKey('judge-1')));
          expect(judge.top, closeTo(correct.top, .1));
          expect(judge.left, greaterThan(correct.left));
          expect(tester.takeException(), isNull);
        },
      );
    }
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
              expect(find.byType(CourtArt), findsNWidgets(6));
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
              ]) {
                final value = strings.get(key, {'count': 2});
                expect(value, isNot(key));
                final target = find.text(value).first;
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
                    find.byWidgetPredicate(
                      (w) => w is RulesIcon && w.name == 'x',
                    ),
                    findsNWidgets(2),
                  );
                  expect(
                    find.byWidgetPredicate(
                      (w) => w is RulesIcon && w.name == 'check',
                    ),
                    findsNWidgets(4),
                  );
                  await reviewImage(
                    tester,
                    'rules-example-$language-${size.width.toInt()}-${scale.toInt()}',
                  );
                }
              }
              for (final extra in {
                'users': 'gameRulesAllJudgesBody',
                'book-open': 'gameRulesExtraRulesBody',
              }.entries) {
                final tile = find.byKey(ValueKey('rules-extra-${extra.key}'));
                await tester.ensureVisible(tile);
                await tester.pumpAndSettle();
                await tester.tap(tile);
                await tester.pumpAndSettle();
                expect(find.text(strings.get(extra.value)), findsOneWidget);
                await tester.tap(
                  find.byKey(const ValueKey('rules-extra-close')),
                );
                await tester.pumpAndSettle();
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
