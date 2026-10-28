import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/local_game_reducer.dart';
import 'package:trinktribunal/domain/models/content_history.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import 'card_game_test.dart' show reducer, config;
import '../data/local_state_transaction_test.dart' show Harness;
import '../support/memory_atomic_state_storage.dart';

void main() {
  test('normal physical Next completes exactly one case/slot without a recorded verdict', () {
    final engine = reducer();
    var state = engine.start(
      id: GameId('next'),
      config: config(),
      history: ContentHistory([]),
    );
    for (var i = 1; i <= 3; i++) {
      final id = state.currentEventId;
      state = engine.advancePlayedCase(state, roundId: id);
      expect(state.completedCases, i);
      expect(state.lastCompletion, CaseCompletion.playedWithoutRecordedVerdict);
      expect(state.manualErrors, isNull);
      expect(
        state.toSnapshot()['lastCompletion'],
        'played_without_recorded_verdict',
      );
      expect(engine.advancePlayedCase(state, roundId: id), same(state));
      expect(state.rules.active.length, i < 3 ? i : 2);
      if (i < 3) {
        expect(state.phase, GamePhase.ruleEvent);
        state = engine.continueAfterRule(state, eventId: state.currentEventId);
      }
    }
    expect(state.phase, GamePhase.finished);
  });
  test('physical played marker persists atomically after reroll and does not reinterpret old verdicts', () async {
    final storage = MemoryAtomicStateStorage(), first = Harness(storage);
    first.startCards();
    first.cards.rerollCurrentQuestion(first.cards.state!.currentEventId);
    first.cards.advancePlayedCase(first.cards.state!.currentEventId);
    await first.transaction.save();
    final restored = Harness(storage);
    await restored.transaction.load();
    expect(restored.transaction.restored, isTrue);
    expect(restored.cards.state!.completedCases, 1);
    expect(
      restored.cards.state!.lastCompletion,
      CaseCompletion.playedWithoutRecordedVerdict,
    );
    expect(restored.cards.state!.manualErrors, isNull);
    final engine = reducer(),
        original = engine.start(
          id: GameId('legacy'),
          config: config(),
          history: ContentHistory([]),
        );
    final manual = engine.completeCase(
      original,
      roundId: original.currentEventId,
      confirmed: true,
      manualErrors: 2,
      fullOrderConfirmed: true,
    );
    final loaded = engine.restore(
      manual.toSnapshot(),
      manual.rules.selection.history,
    );
    expect(loaded.lastCompletion, CaseCompletion.judged);
    expect(loaded.manualErrors, 2);
    final skipped = engine.completeCase(
      original,
      roundId: original.currentEventId,
      confirmed: true,
    );
    expect(
      engine
          .restore(skipped.toSnapshot(), skipped.rules.selection.history)
          .lastCompletion,
      CaseCompletion.withoutVerdict,
    );
    expect(
      engine.completeCase(
        original,
        roundId: original.currentEventId,
        confirmed: false,
      ),
      same(original),
    );
  });
}
