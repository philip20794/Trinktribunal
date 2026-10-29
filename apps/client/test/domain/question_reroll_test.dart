import '../support/shared_handoff.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/content_history_store.dart';
import 'package:trinktribunal/application/local_session_controller.dart';
import 'package:trinktribunal/application/shared_phone_controller.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/models/domain_error.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/user_profile.dart';

import 'selection_support.dart';

final catalog = questions([
  for (var i = 1; i <= 20; i++)
    questionJson('${i.toString().padLeft(3, '0')}-a'),
]);
final ruleCatalog = rules([ruleJson('rule_1'), ruleJson('rule_2')]);
Map<String, dynamic> copy(Object? value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

SharedPhoneController shared({
  bool personal = false,
  int count = 20,
  ContentHistoryStore? history,
}) {
  final session = SharedPhoneController(
    questions: questions([
      for (var i = 1; i <= count; i++)
        questionJson(
          '${i.toString().padLeft(3, '0')}-a',
          roles: personal
              ? {
                  'player1': {'selection': 'random'},
                }
              : null,
        ),
    ]),
    rules: ruleCatalog,
    random: TestRandom(),
    clock: () => now,
    newId: () => 'reroll_game',
    historyStore: history,
  );
  session.start(
    config: session.configure(
      playerCount: 4,
      targetCases: count < 3 ? 1 : 3,
      requestedRuleEvents: count < 3 ? 0 : 2,
    ),
    roster: [
      for (final id in players)
        UserProfile(
          player: Player(id: id, name: id.value),
          avatar: AvatarConfig(),
        ),
    ],
  );
  return session;
}

void prepare(SharedPhoneController session, GamePhase phase) {
  finishSharedNumbers(session);
  if (phase == GamePhase.answers) return;
  session.beginOrdering(session.view!.roundId);
  if (phase == GamePhase.ordering) return;
  session.confirmOrder(session.view!.roundId, confirmed: true);
}

void main() {
  test('executes shared Dart/TypeScript ten-reroll fixture', () {
    final fixture = jsonDecode(
      File('../../packages/protocol/fixtures/transitions/core/reroll-v1.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final history = ContentHistoryStore();
    final session = SharedPhoneController(
      questions: questions([
        for (final id in fixture['questions'] as List)
          questionJson(id as String),
      ]),
      rules: ruleCatalog,
      random: TestRandom(),
      clock: () => now,
      newId: () => 'fixture_reroll',
      historyStore: history,
    );
    session.start(
      config: session.configure(
        playerCount: 4,
        targetCases: 3,
        requestedRuleEvents: 2,
      ),
      roster: [
        for (final id in fixture['players'] as List)
          UserProfile(
            player: Player(id: PlayerId(id as String), name: id),
            avatar: AvatarConfig(),
          ),
      ],
    );
    for (var i = 0; i < fixture['rerolls']; i++) {
      session.rerollCurrentQuestion(roundId: session.view!.roundId);
    }
    final view = session.view!, saved = copy(session.toSnapshot());
    expect({
      'phase': view.phase.name,
      'completed': view.completedCases,
      'judge': view.judge!.value,
      'question': view.question!.entry.id,
      'drawn': history.history.entries.length,
      'history': history.history.entries.length,
      'slots': saved['slots'],
      'numbers': saved['numbers'],
    }, fixture['expected']);
  });

  test('physical cards reroll ten times, restore every draw and complete only one case/slot', () {
    final session = LocalSessionController(
      questions: catalog,
      rules: ruleCatalog,
      random: TestRandom(),
      clock: () => now,
      newId: () => 'cards_reroll',
    );
    session.start(
      session.configure(playerCount: 4, targetCases: 3, requestedRuleEvents: 2),
    );
    final ids = <String>{session.state!.currentQuestion!.entry.id};
    for (var i = 0; i < 10; i++) {
      final previous = session.state!, slots = previous.schedule.slots;
      session.rerollCurrentQuestion(previous.currentEventId);
      final next = session.state!;
      expect(next.completedCases, 0);
      expect(next.schedule.slots, slots);
      expect(ids.add(next.currentQuestion!.entry.id), isTrue);
      final saved = copy(session.toSnapshot());
      session.rerollCurrentQuestion(previous.currentEventId);
      expect(session.toSnapshot(), saved);
      session.restoreValidated(
        session.validateSnapshot(saved, session.history),
      );
      expect(session.toSnapshot(), saved);
    }
    expect(session.history.entries, hasLength(11));
    final active = session.state!.currentEventId;
    session.completeCase(roundId: active, confirmed: true);
    expect(session.state!.completedCases, 1);
    expect(session.state!.phase, GamePhase.ruleEvent);
    final saved = copy(session.toSnapshot());
    session.completeCase(roundId: active, confirmed: true);
    expect(session.toSnapshot(), saved);
    session.restoreValidated(session.validateSnapshot(saved, session.history));
    session.continueAfterRule(session.state!.currentEventId);
    expect(session.state!.completedCases, 1);
    expect(session.state!.questionDraws.length, 2);
  });

  test('shared phone preserves numbers/judge/slots, consumes all ten replacements and binds fairly', () {
    final history = ContentHistoryStore(),
        session = shared(personal: true, history: history);
    final initial = copy(session.toSnapshot()), judge = session.view!.judge;
    final ids = <String>{session.view!.question!.entry.id};
    for (var i = 0; i < 10; i++) {
      final previous = openSharedRecipient(session);
      session.revealOwnNumber(
        roundId: previous.roundId,
        player: previous.recipient!,
      );
      expect(session.rerollCurrentQuestion(roundId: previous.roundId), isTrue);
      expect(ids.add(session.view!.question!.entry.id), isTrue);
      final saved = copy(session.toSnapshot());
      expect(saved['numbers'], initial['numbers']);
      expect(saved['slots'], initial['slots']);
      expect(session.view!.judge, judge);
      expect(session.view!.completedCases, 0);
      expect(session.view!.visibleSecret, isNull);
      expect(session.rerollCurrentQuestion(roundId: previous.roundId), isFalse);
      expect(session.toSnapshot(), saved);
      session.restoreValidated(
        session.validateSnapshot(saved, history.history),
      );
      expect(session.toSnapshot(), saved);
      expect(session.view!.visibleSecret, isNull);
    }
    expect(history.history.entries, hasLength(11));
    final counts = session.personCounts.values.values.toList()..sort();
    expect(counts.fold<int>(0, (sum, count) => sum + count), 11);
    expect(counts.last - counts.first, lessThanOrEqualTo(1));
    final round = session.view!.roundId;
    session.completeCase(round, confirmed: true, withoutVerdict: true);
    expect(session.view!.completedCases, 1);
    expect(session.view!.phase, GamePhase.ruleEvent);
    final saved = copy(session.toSnapshot());
    session.completeCase(round, confirmed: true, withoutVerdict: true);
    expect(session.toSnapshot(), saved);
  });

  for (final phase in [
    GamePhase.answers,
    GamePhase.ordering,
    GamePhase.revealing,
  ]) {
    test('reroll from $phase clears the old draft and rejects stale input', () {
      final session = shared();
      prepare(session, phase);
      final previous = session.view!;
      final numbers = copy(session.toSnapshot())['numbers'];
      session.rerollCurrentQuestion(roundId: previous.roundId);
      expect(session.view!.phase, GamePhase.answers);
      expect(session.view!.order, isEmpty);
      expect(session.toSnapshot()!['numbers'], numbers);
      expect(
        () => session.revealNext(previous.roundId, expectedCursor: 0),
        throwsA(isA<DomainException>()),
      );
    });
  }

  test('public reveal prevents reroll; no candidates preserves every field and counter', () {
    final public = shared();
    prepare(public, GamePhase.revealing);
    public.revealNext(public.view!.roundId, expectedCursor: 0);
    final before = copy(public.toSnapshot());
    expect(
      () => public.rerollCurrentQuestion(roundId: public.view!.roundId),
      throwsA(isA<DomainException>()),
    );
    expect(public.toSnapshot(), before);
    final exhausted = shared(count: 2);
    exhausted.rerollCurrentQuestion(roundId: exhausted.view!.roundId);
    final saved = copy(exhausted.toSnapshot());
    expect(
      () => exhausted.rerollCurrentQuestion(roundId: exhausted.view!.roundId),
      throwsA(
        isA<DomainException>().having(
          (e) => e.code,
          'code',
          DomainErrorCode.contentExhausted,
        ),
      ),
    );
    expect(exhausted.toSnapshot(), saved);
  });

  test('known old snapshots migrate only one question per case; missing/duplicate ledger fails closed', () {
    final history = ContentHistoryStore(), session = shared(history: history);
    final old = copy(session.toSnapshot())..remove('questionDraws');
    expect(session.validateSnapshot(old, history.history), isNotNull);
    session.rerollCurrentQuestion(roundId: session.view!.roundId);
    final missing = copy(session.toSnapshot())..remove('questionDraws');
    expect(
      () => session.validateSnapshot(missing, history.history),
      throwsFormatException,
    );
    final duplicate = copy(session.toSnapshot());
    final ids = (duplicate['questionDraws'] as Map).values.first as List;
    ids.add(ids.first);
    expect(
      () => session.validateSnapshot(duplicate, history.history),
      throwsFormatException,
    );
  });
}
