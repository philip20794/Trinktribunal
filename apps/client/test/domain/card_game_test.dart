import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/config/game_config.dart';
import 'package:trinktribunal/domain/local_game_reducer.dart';
import 'package:trinktribunal/domain/models/content_history.dart';
import 'package:trinktribunal/domain/models/domain_error.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import 'selection_support.dart';

GameConfig config({int cases = 3, int events = 2, int players = 4}) =>
    GameConfig(
      mode: GameMode.physicalCards,
      playerCount: players,
      targetCases: cases,
      requestedRuleEvents: events,
      capacity: CatalogCapacity(questions: 431, rules: 22),
    );
LocalGameReducer reducer() => LocalGameReducer(
  questions: actualQuestions(),
  drinkingRules: actualRules(),
  random: TestRandom(),
  clock: () => now,
);

void main() {
  test('three cases/two rule events: five files, one skip, no duplicate completions', () {
    final engine = reducer();
    var state = engine.start(
      id: GameId('demo'),
      config: config(),
      history: ContentHistory([]),
    );
    final first = state.currentEventId;
    expect(state.caseNumber, 1);
    expect(state.rules.active, isEmpty);
    state = engine.completeCase(
      state,
      roundId: first,
      confirmed: true,
      manualErrors: 2,
      fullOrderConfirmed: true,
    );
    expect(state.phase, GamePhase.ruleEvent);
    expect(state.completedCases, 1);
    expect(state.rules.active.length, 1);
    expect(
      identical(
        engine.completeCase(state, roundId: first, confirmed: true),
        state,
      ),
      true,
    );
    final ruleOne = state.currentEventId;
    state = engine.continueAfterRule(state, eventId: ruleOne);
    expect(state.caseNumber, 2);
    expect(
      identical(engine.continueAfterRule(state, eventId: ruleOne), state),
      true,
    );
    final second = state.currentEventId;
    expect(
      identical(
        engine.completeCase(state, roundId: second, confirmed: false),
        state,
      ),
      true,
    );
    state = engine.completeCase(state, roundId: second, confirmed: true);
    expect(state.completedCases, 2);
    expect(state.lastCompletion, CaseCompletion.withoutVerdict);
    expect(state.manualErrors, isNull);
    expect(state.rules.active.length, 2);
    expect(
      identical(
        engine.completeCase(state, roundId: second, confirmed: true),
        state,
      ),
      true,
    );
    state = engine.continueAfterRule(state, eventId: state.currentEventId);
    expect(state.caseNumber, 3);
    final third = state.currentEventId;
    state = engine.completeCase(
      state,
      roundId: third,
      confirmed: true,
      manualErrors: 0,
      fullOrderConfirmed: true,
    );
    expect(state.phase, GamePhase.finished);
    expect(state.completedCases, 3);
    expect(state.rules.selection.history.entries.length, 5);
    expect(state.rules.selection.drawnIds(ContentKind.question).length, 3);
    expect(state.rules.active.length, 2);
    expect(state.manualErrors, 0);
    expect(
      identical(
        engine.completeCase(state, roundId: third, confirmed: true),
        state,
      ),
      true,
    );
  });
  test(
    'invalid manual scores and missing full-order confirmation preserve state',
    () {
      final engine = reducer();
      final state = engine.start(
        id: GameId('manual'),
        config: config(),
        history: ContentHistory([]),
      );
      for (final value in [-1, 1, 4, 99]) {
        expect(
          () => engine.completeCase(
            state,
            roundId: state.currentEventId,
            confirmed: true,
            manualErrors: value,
            fullOrderConfirmed: true,
          ),
          throwsA(isA<DomainException>()),
        );
      }
      expect(
        () => engine.completeCase(
          state,
          roundId: state.currentEventId,
          confirmed: true,
          manualErrors: 0,
        ),
        throwsA(isA<DomainException>()),
      );
      expect(
        () => engine.completeCase(state, roundId: 'stale', confirmed: true),
        throwsA(isA<DomainException>()),
      );
      expect(state.completedCases, 0);
      expect(state.rules.selection.history.entries.length, 1);
    },
  );
  test('F=1 produces no rule and no synthetic score; F=50 completes exactly 50 cases', () {
    for (final count in [1, 50]) {
      final engine = reducer();
      var state = engine.start(
        id: GameId('f$count'),
        config: config(cases: count, events: 7),
        history: ContentHistory([]),
      );
      var actions = 0;
      while (state.phase != GamePhase.finished) {
        if (state.phase == GamePhase.casePresented) {
          state = engine.completeCase(
            state,
            roundId: state.currentEventId,
            confirmed: true,
          );
        } else {
          state = engine.continueAfterRule(
            state,
            eventId: state.currentEventId,
          );
        }
        actions++;
        expect(actions, lessThan(100));
      }
      expect(state.completedCases, count);
      expect(state.rules.active.length, count == 1 ? 0 : 7);
      expect(state.manualErrors, isNull);
    }
  });
  test('exhausted question catalog pauses without invented completion', () {
    final engine = LocalGameReducer(
      questions: questions([questionJson('001-a')]),
      drinkingRules: [],
      random: TestRandom(),
      clock: () => now,
    );
    var state = engine.start(
      id: GameId('small'),
      config: config(events: 0),
      history: ContentHistory([]),
    );
    state = engine.completeCase(
      state,
      roundId: state.currentEventId,
      confirmed: true,
    );
    expect(state.phase, GamePhase.paused);
    expect(state.completedCases, 1);
    expect(state.rules.selection.history.entries.length, 1);
    expect(state.pauseReason, contains('Keine weitere'));
  });
  test('empty rule candidates reduce target without skipping a case', () {
    final engine = LocalGameReducer(
      questions: actualQuestions(),
      drinkingRules: [],
      random: TestRandom(),
      clock: () => now,
    );
    var state = engine.start(
      id: GameId('no-rules'),
      config: config(),
      history: ContentHistory([]),
    );
    state = engine.completeCase(
      state,
      roundId: state.currentEventId,
      confirmed: true,
    );
    expect(state.phase, GamePhase.ruleEvent);
    expect(state.newRule, isNull);
    expect(state.effectiveRuleTarget, 1);
    state = engine.continueAfterRule(state, eventId: state.currentEventId);
    expect(state.caseNumber, 2);
    expect(state.completedCases, 1);
  });
}
