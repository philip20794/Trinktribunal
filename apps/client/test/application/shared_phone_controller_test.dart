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

import '../domain/selection_support.dart';

List<UserProfile> roster() => [
  for (final id in players)
    UserProfile(
      player: Player(id: id, name: id.value),
      avatar: AvatarConfig(),
    ),
];
SharedPhoneController controller({ContentHistoryStore? history}) {
  var id = 0;
  return SharedPhoneController(
    questions: actualQuestions(),
    rules: actualRules(),
    random: TestRandom(),
    clock: () => now,
    newId: () => 'shared${id++}',
    historyStore: history,
  );
}

void handoff(SharedPhoneController session) {
  while (session.view!.phase == GamePhase.numbers) {
    final view = session.view!;
    expect(view.visibleSecret, isNull);
    expect(view.revealedNumbers, isEmpty);
    expect(view.verdict, isNull);
    session.revealOwnNumber(roundId: view.roundId, player: view.recipient!);
    expect(session.view!.visibleSecret, isNotNull);
    session.acknowledgeNumber(roundId: view.roundId, player: view.recipient!);
    session.acknowledgeNumber(roundId: view.roundId, player: view.recipient!);
  }
}

void main() {
  test('six judged cases with avatar/name update, insertion, join, rules and restart', () {
    final session = controller();
    final config = session.configure(
      playerCount: 4,
      targetCases: 6,
      requestedRuleEvents: 2,
    );
    session.start(config: config, roster: roster());
    for (var caseIndex = 0; caseIndex < 6; caseIndex++) {
      handoff(session);
      final round = session.view!.roundId;
      session.beginOrdering(round);
      if (caseIndex.isOdd) session.move(round, 0, 1);
      if (caseIndex == 0) {
        final changed = roster();
        changed[1] = UserProfile(
          player: changed[1].player.renamed('Alex'),
          avatar: AvatarConfig.feminine(),
        );
        changed.add(
          UserProfile(
            player: Player(id: PlayerId('E'), name: 'Alex'),
            avatar: AvatarConfig.masculine(),
          ),
        );
        session.applyRoster(changed);
        expect(session.view!.roster.length, 4);
        expect(session.view!.profiles[players[1]]!.avatar['hair'], 'long');
      }
      session.confirmOrder(round, confirmed: true);
      final count = session.view!.order.length;
      for (var cursor = 0; cursor < count; cursor++) {
        session.revealNext(round, expectedCursor: cursor);
      }
      expect(session.view!.verdict!.errors, caseIndex.isOdd ? 2 : 0);
      session.completeCase(round, confirmed: true);
      if (session.view!.phase == GamePhase.ruleEvent) {
        session.continueRule(afterCase: caseIndex + 1);
      }
    }
    expect(session.view!.phase, GamePhase.finished);
    expect(session.view!.roster.length, 5);
    expect(session.view!.activeRules.length, 2);
    final previousQuestion = session.view!.question!.entry.id;
    final nextRoster = session.view!.roster;
    session.start(
      config: session.configure(
        playerCount: 5,
        targetCases: 6,
        requestedRuleEvents: 2,
      ),
      roster: nextRoster,
      confirmedRestart: true,
    );
    expect(session.view!.question!.entry.id, isNot(previousQuestion));
    expect(session.view!.activeRules, isEmpty);
    expect(session.view!.visibleSecret, isNull);
  });
  test(
    'handoff opens only own number, hides on lifecycle/navigation, skips judge',
    () {
      final session = controller();
      session.start(
        config: session.configure(playerCount: 4),
        roster: roster(),
      );
      final initial = session.view!;
      expect(initial.recipient, players[1]);
      expect(initial.visibleSecret, isNull);
      session.revealOwnNumber(
        roundId: initial.roundId,
        player: initial.recipient!,
      );
      final number = session.view!.visibleSecret;
      session.hideSecret();
      expect(session.view!.visibleSecret, isNull);
      session.revealOwnNumber(
        roundId: initial.roundId,
        player: initial.recipient!,
      );
      expect(session.view!.visibleSecret, number);
      session.hideSecret();
      handoff(session);
      expect(session.view!.phase, GamePhase.answers);
      expect(session.view!.visibleSecret, isNull);
      expect(session.view!.revealedNumbers, isEmpty);
    },
  );
  test('ordering locks, reveal advances exactly once, verdict stays private until final step', () {
    final session = controller();
    session.start(
      config: session.configure(
        playerCount: 4,
        targetCases: 3,
        requestedRuleEvents: 0,
      ),
      roster: roster(),
    );
    handoff(session);
    final round = session.view!.roundId;
    session.beginOrdering(round);
    session.move(round, 0, 1);
    session.confirmOrder(round, confirmed: false);
    expect(session.view!.phase, GamePhase.ordering);
    session.confirmOrder(round, confirmed: true);
    expect(session.view!.revealedNumbers, isEmpty);
    expect(session.view!.verdict, isNull);
    expect(() => session.move(round, 0, 1), throwsA(isA<DomainException>()));
    for (var cursor = 0; cursor < 3; cursor++) {
      session.revealNext(round, expectedCursor: cursor);
      session.revealNext(round, expectedCursor: cursor);
      expect(session.view!.revealedNumbers.length, cursor + 1);
      if (cursor < 2) expect(session.view!.verdict, isNull);
    }
    expect(session.view!.verdict!.errors, 2);
    expect(session.view!.verdict!.sips[players[0]], 2);
    session.completeCase(round, confirmed: true);
    session.completeCase(round, confirmed: true);
    expect(session.view!.completedCases, 1);
    expect(session.view!.judge, players[1]);
    expect(session.view!.visibleSecret, isNull);
    expect(session.view!.revealedNumbers, isEmpty);
  });
  test(
    'nine cases cover two full judge rotations, two rules and restart reset',
    () {
      final session = controller();
      final config = session.configure(
        playerCount: 4,
        targetCases: 9,
        requestedRuleEvents: 2,
      );
      session.start(config: config, roster: roster());
      for (var i = 0; i < 9; i++) {
        expect(session.view!.judge, players[i % 4]);
        final round = session.view!.roundId;
        session.completeCase(round, confirmed: false, withoutVerdict: true);
        expect(session.view!.completedCases, i);
        session.completeCase(round, confirmed: true, withoutVerdict: true);
        session.completeCase(round, confirmed: true, withoutVerdict: true);
        if (session.view!.phase == GamePhase.ruleEvent) {
          final judge = session.view!.judge;
          session.continueRule(afterCase: i + 1);
          session.continueRule(afterCase: i + 1);
          expect(session.view!.judge, judge);
        }
      }
      expect(session.view!.phase, GamePhase.finished);
      expect(session.view!.activeRules.length, 2);
      expect(
        () => session.start(config: config, roster: roster()),
        throwsA(isA<DomainException>()),
      );
      session.start(config: config, roster: roster(), confirmedRestart: true);
      expect(session.view!.completedCases, 0);
      expect(session.view!.activeRules, isEmpty);
      expect(session.view!.verdict, isNull);
      expect(session.view!.visibleSecret, isNull);
    },
  );
  test('pending removals/reorder keep current roles; boundary uses old-cycle successor', () {
    final session = controller();
    session.start(
      config: session.configure(
        playerCount: 4,
        targetCases: 3,
        requestedRuleEvents: 0,
      ),
      roster: roster(),
    );
    final before = session.view!;
    final e = UserProfile(
      player: Player(id: PlayerId('E'), name: 'New'),
      avatar: AvatarConfig(),
    );
    final changedC = UserProfile(
      player: roster()[2].player.renamed('Renamed C'),
      avatar: AvatarConfig.feminine(),
    );
    session.revealOwnNumber(roundId: before.roundId, player: before.recipient!);
    final secret = session.view!.visibleSecret;
    session.applyRoster([roster()[3], changedC, e]);
    expect(session.view!.roster.length, 4);
    expect(session.view!.judge, players[0]);
    expect(session.view!.name(players[2]), 'Renamed C');
    expect(session.view!.visibleSecret, isNull);
    session.revealOwnNumber(roundId: before.roundId, player: before.recipient!);
    expect(session.view!.visibleSecret, secret);
    session.completeCase(before.roundId, confirmed: true, withoutVerdict: true);
    expect(session.view!.roster.map((p) => p.player.id), [
      players[3],
      players[2],
      e.player.id,
    ]);
    expect(session.view!.judge, players[2]);
    expect(session.view!.pendingRoster, isNull);
  });
  test(
    'fewer than three pauses before rule; roster recovery consumes slot once',
    () {
      final session = controller();
      session.start(
        config: session.configure(
          playerCount: 4,
          targetCases: 3,
          requestedRuleEvents: 2,
        ),
        roster: roster(),
      );
      session.applyRoster(roster().take(2).toList());
      session.completeCase(
        session.view!.roundId,
        confirmed: true,
        withoutVerdict: true,
      );
      expect(session.view!.phase, GamePhase.paused);
      expect(session.view!.activeRules, isEmpty);
      session.applyRoster(roster().take(3).toList());
      session.resumePaused();
      expect(session.view!.phase, GamePhase.ruleEvent);
      expect(session.view!.activeRules.length, 1);
      session.resumePaused();
      expect(session.view!.activeRules.length, 1);
      session.continueRule(afterCase: 1);
      expect(session.view!.phase, GamePhase.numbers);
      expect(session.view!.completedCases, 1);
    },
  );
  test('both local modes share six-hour history even when returning to an older session', () {
    final history = ContentHistoryStore();
    final catalog = questions([
      questionJson('001-a'),
      questionJson('001-b'),
      questionJson('002-a'),
    ]);
    final cards = LocalSessionController(
      questions: catalog,
      rules: [],
      random: TestRandom(),
      clock: () => now,
      newId: () => 'cards',
      historyStore: history,
    );
    cards.start(
      cards.configure(playerCount: 4, targetCases: 2, requestedRuleEvents: 0),
    );
    final shared = SharedPhoneController(
      questions: catalog,
      rules: [],
      random: TestRandom(),
      clock: () => now,
      newId: () => 'shared',
      historyStore: history,
    );
    shared.start(
      config: shared.configure(
        playerCount: 4,
        targetCases: 2,
        requestedRuleEvents: 0,
      ),
      roster: roster(),
    );
    expect(shared.view!.question!.entry.id, '001-b');
    cards.completeCase(roundId: cards.state!.currentEventId, confirmed: true);
    expect(cards.state!.currentQuestion!.entry.id, '002-a');
    expect(history.history.entries.length, 3);
  });
}
