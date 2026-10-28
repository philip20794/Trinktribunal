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
    await tester.scrollUntilVisible(finder, 400);
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
        await tester.tap(find.byTooltip(strings.get('gameRules')));
        await tester.pumpAndSettle();
        expect(find.byType(GameRulesScreen), findsOneWidget);
        for (final section in [
          'Setup',
          'Errors',
          'Normal',
          'AllJudges',
          'Rotation',
          'ExtraRules',
          'Next',
        ]) {
          final finder = find.text(strings.get('gameRules${section}Body'));
          await tester.scrollUntilVisible(
            finder,
            400,
            scrollable: find.byType(Scrollable),
          );
          expect(finder, findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
    testWidgets(
      'physical Next has no penalty dialog; separate D-07 and help preserve state, $language',
      (tester) async {
        final strings = AppStrings(language);
        await tester.pumpWidget(
          accessibilityHost(const CardModeScreen(), language: language),
        );
        await tester.pumpAndSettle();
        await tap(tester, strings.get('startHearing'));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CardModeScreen)),
        );
        final cards = container.read(localSessionProvider);
        final id = cards.state!.currentEventId;
        final next = find.ancestor(
          of: find.text(strings.get('nextCase')),
          matching: find.byType(FilledButton),
        );
        await tester.scrollUntilVisible(next, 400);
        final callback = tester.widget<FilledButton>(next).onPressed!;
        callback();
        callback();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
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
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(cards.toSnapshot(), beforeHelp);
        if (cards.state!.phase == GamePhase.ruleEvent) {
          await tap(tester, strings.get('nextCase'));
        }
        final active = cards.state!.currentEventId;
        await tap(tester, strings.get('withoutVerdict'));
        expect(find.byType(AlertDialog), findsOneWidget);
        await tap(tester, strings.get('cancel'));
        expect(cards.state!.currentEventId, active);
        expect(cards.state!.completedCases, 1);
      },
    );
  }
}
