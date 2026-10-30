import 'package:trinktribunal/design/court_dialog.dart';

import '../support/roster_setup.dart';

import 'package:trinktribunal/design/hold_action_button.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/domain/local_game_reducer.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/features/home/home_screen.dart';
import 'package:trinktribunal/features/rules/game_rules_screen.dart';
import 'package:trinktribunal/features/setup/card_mode_screen.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../accessibility/screen_matrix_test.dart' show accessibilityHost;

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    // Phase changes can retain a scroll offset below a lazily built action.
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.minScrollExtent);
    await tester.pumpAndSettle();
  }
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      400,
      scrollable: find.byType(Scrollable).first,
    );
  }
  // Center long localized labels below the pinned app bar after scroll/layout.
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['de', 'en']) {
    testWidgets(
      'general rules reachable from home and fully localized, $language',
      (tester) async {
        final strings = AppStrings(language);
        await tester.pumpWidget(
          accessibilityHost(const HomeScreen(), language: language),
        );
        await tester.pumpAndSettle();
        await tap(tester, strings.get('gameRules'));
        await tester.pumpAndSettle();
        expect(find.byType(GameRulesScreen), findsOneWidget);
        for (final key in [
          'rulesStep1Body',
          'rulesStep2Body',
          'rulesStep3Body',
          'rulesStep4Body',
          'rulesScoringTitle',
        ]) {
          final finder = find.text(strings.get(key));
          await tester.scrollUntilVisible(
            finder,
            400,
            scrollable: find.byType(Scrollable),
          );
          expect(finder, findsOneWidget);
          expect(tester.takeException(), isNull);
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
          await tester.tap(find.byKey(const ValueKey('rules-extra-close')));
          await tester.pumpAndSettle();
        }
      },
    );
    testWidgets(
      'physical Next and help preserve state without extra play controls, $language',
      (tester) async {
        final strings = AppStrings(language);
        await tester.pumpWidget(
          accessibilityHost(const CardModeScreen(), language: language),
        );
        await tester.pumpAndSettle();
        await addTestPlayers(tester);
        await tap(tester, strings.get('startHearing'));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CardModeScreen)),
        );
        final cards = container.read(localSessionProvider);
        final id = cards.state!.currentEventId;
        final next = find.ancestor(
          of: find.text(strings.get('nextCase')),
          matching: find.byType(HoldActionButton),
        );
        expect(next.hitTestable(), findsOneWidget);
        expect(
          tester.widget<HoldActionButton>(next).duration,
          const Duration(milliseconds: 500),
        );
        final callback = tester.widget<HoldActionButton>(next).onCompleted!;
        callback();
        callback();
        await tester.pumpAndSettle();
        expect(find.byType(CourtDialog), findsNothing);
        expect(cards.state!.completedCases, 1);
        expect(
          cards.state!.lastCompletion,
          CaseCompletion.playedWithoutRecordedVerdict,
        );
        expect(cards.state!.manualErrors, isNull);
        expect(cards.state!.currentEventId, isNot(id));
        final beforeHelp = cards.toSnapshot();
        await tester.tap(find.byTooltip(strings.get('gameRules')));
        await tester.pumpAndSettle();
        expect(find.byType(GameRulesScreen), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('rules-back')));
        await tester.pumpAndSettle();
        expect(cards.toSnapshot(), beforeHelp);
        if (cards.state!.phase == GamePhase.ruleEvent) {
          await tap(tester, strings.get('ruleUnderstood'));
        }
        expect(find.text(strings.get('withoutVerdict')), findsNothing);
        expect(find.text(strings.get('restartGame')), findsNothing);
        expect(find.text(strings.get('cardRestartSetup')), findsNothing);
        expect(find.text(strings.get('cardsDistribution')), findsNothing);
      },
    );
  }
}
