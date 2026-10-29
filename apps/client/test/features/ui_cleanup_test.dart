import '../support/roster_setup.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/data/catalogs/catalog.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/design/case_file.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/domain/models/game_mode.dart' as domain;
import 'package:trinktribunal/features/home/home_screen.dart';
import 'package:trinktribunal/features/home/mode_preview_screen.dart';
import 'package:trinktribunal/features/rules/game_rules_screen.dart';
import 'package:trinktribunal/features/setup/card_mode_screen.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../design/court_scene_test.dart' show reviewImage;
import 'home_profile_settings_test.dart' show tapVisible;
import '../accessibility/screen_matrix_test.dart' show accessibilityHost;

const review = bool.fromEnvironment('TT_RENDER_REVIEW');
const boundary = ValueKey('scene-review');
Future<void> host(
  WidgetTester tester,
  Widget child,
  String language, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: accessibilityHost(
        child,
        language: language,
        size: size,
        textScale: scale,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (!review) return;
    final font = FontLoader('CourtRoboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      font.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final language in ['de', 'en']) {
    testWidgets(
      'four home entries, no diagnostic/gallery, concise rules: $language',
      (tester) async {
        final strings = AppStrings(language);
        await host(
          tester,
          const HomeScreen(),
          language,
          size: const Size(390, 844),
        );
        expect(find.byIcon(Icons.palette_outlined), findsNothing);
        expect(find.text(strings.get('catalogDiagnostics')), findsNothing);
        for (final key in [
          'modeCards',
          'modePhone',
          'modeMulti',
          'gameRules',
        ]) {
          expect(find.text(strings.get(key)).hitTestable(), findsOneWidget);
        }
        await reviewImage(tester, 'cleanup-home-$language');
        await tapVisible(tester, find.text(strings.get('gameRules')));
        expect(find.byType(GameRulesScreen), findsOneWidget);
        expect(rulesStepIcons.length, 4);
        await reviewImage(tester, 'cleanup-rules-$language');
        await tester.tap(find.byKey(const ValueKey('rules-back')));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text(strings.get('modeCards')));
        expect(find.byType(ModePreviewScreen), findsOneWidget);
        await reviewImage(tester, 'cleanup-intro-cards-$language-1');
        expect(tester.takeException(), isNull);
      },
    );

    for (final mode in GameMode.values) {
      testWidgets(
        'mode intro remains readable and continue reachable at 200 percent: $mode, $language',
        (tester) async {
          await host(
            tester,
            ModePreviewScreen(mode: mode),
            language,
            scale: 2,
            size: const Size(320, 640),
          );
          await reviewImage(tester, 'cleanup-intro-${mode.name}-$language-2');
          final strings = AppStrings(language);
          final prefix = [
            'introCards',
            'introPhone',
            'introOnline',
          ][mode.index];
          for (var step = 1; step <= 3; step++) {
            final text = find.text(strings.get('$prefix$step'));
            await Scrollable.ensureVisible(tester.element(text));
            await tester.pumpAndSettle();
            expect(text, findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          expect(
            find.text(strings.get('introContinue')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byType(CourtPaper),
              matching: find.byType(Image),
            ),
            findsNothing,
          );
        },
      );
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'playing surface and rules contain game data without instruction clutter: $language, $scale',
        (tester) async {
          final strings = AppStrings(language);
          await host(
            tester,
            const CardModeScreen(),
            language,
            scale: scale,
            size: const Size(390, 844),
          );
          await reviewImage(tester, 'cleanup-setup-$language-${scale.toInt()}');
          await addTestPlayers(tester);
          await tapVisible(tester, find.text(strings.get('localGameOptions')));
          tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(3);
          await tester.pumpAndSettle();
          await tester.tap(find.text(strings.get('rosterApply')));
          await tester.pumpAndSettle();
          await tapVisible(tester, find.text(strings.get('startHearing')));
          final container = ProviderScope.containerOf(
            tester.element(find.byType(CardModeScreen)),
          );
          final cards = container.read(localSessionProvider);
          expect(find.byType(CourtQuestion), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(CourtPaper),
              matching: find.byType(Image),
            ),
            findsNothing,
          );
          for (final key in [
            'withoutVerdict',
            'restartGame',
            'cardRestartSetup',
            'backToSelectionKeepGame',
            'ruleEventHelp',
            'cardRotateHelp',
          ]) {
            expect(find.text(strings.get(key)), findsNothing);
          }
          expect(
            find.textContaining(
              strings.get('cardsDistribution', {'count': 7, 'max': 12}),
            ),
            findsNothing,
          );
          await reviewImage(
            tester,
            'cleanup-question-$language-${scale.toInt()}',
          );
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(strings.get('activeRules')));
          await tester.pumpAndSettle();
          final empty = find.text(strings.get('rulesNone'));
          await tester.scrollUntilVisible(
            empty,
            120,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          expect(empty, findsOneWidget);
          expect(
            DefaultTextStyle.of(tester.element(empty)).style.color,
            CourtSceneTokens.cream,
          );
          expect(find.text(strings.get('rulesHelp')), findsNothing);
          await reviewImage(
            tester,
            'cleanup-empty-rules-$language-${scale.toInt()}',
          );
          await tapVisible(tester, find.text(strings.get('backToCase')));
          await tapVisible(tester, find.text(strings.get('nextCase')));
          expect(cards.state!.phase, domain.GamePhase.ruleEvent);
          final rule = container
              .read(catalogsProvider)
              .requireValue
              .rules[language]!
              .entries
              .firstWhere(
                (entry) =>
                    entry.id ==
                    (cards.state!.newRule!.entry as DrinkingRule).id,
              );
          expect(find.text(rule.text), findsOneWidget);
          await reviewImage(
            tester,
            'cleanup-new-rule-$language-${scale.toInt()}',
          );
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(strings.get('activeRules')));
          await tester.pumpAndSettle();
          expect(find.text(rule.text).last, findsOneWidget);
          expect(
            DefaultTextStyle.of(tester.element(find.text(rule.text).last))
                .style
                .color,
            CourtSceneTokens.cream,
          );
          await reviewImage(
            tester,
            'cleanup-active-rules-$language-${scale.toInt()}',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
