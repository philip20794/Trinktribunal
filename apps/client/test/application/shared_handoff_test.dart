import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/shared_phone_controller.dart';
import 'package:trinktribunal/application/content_history_store.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/models/domain_error.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/user_profile.dart';

import '../domain/selection_support.dart';
import '../support/shared_handoff.dart';

List<UserProfile> people(int count) => [
  for (var i = 0; i < count; i++)
    UserProfile(
      player: Player(id: PlayerId('p$i'), name: 'Alex'),
      avatar: AvatarConfig(),
    ),
];
final histories = <SharedPhoneController, ContentHistoryStore>{};
SharedPhoneController session(int count) {
  final history = ContentHistoryStore();
  final game = SharedPhoneController(
    questions: questions([for (var i = 1; i <= 4; i++) questionJson('00$i-a')]),
    rules: rules([ruleJson('unused_rule')]),
    random: TestRandom(),
    clock: () => now,
    newId: () => 'handoff',
    historyStore: history,
  );
  histories[game] = history;
  game.start(
    config: game.configure(
      playerCount: count,
      targetCases: 3,
      requestedRuleEvents: 0,
    ),
    roster: people(count),
  );
  return game;
}

Map<String, dynamic> saved(SharedPhoneController game) =>
    jsonDecode(jsonEncode(game.toSnapshot())) as Map<String, dynamic>;
void restore(SharedPhoneController game, Map<String, dynamic> json) => game
    .restoreValidated(game.validateSnapshot(json, histories[game]!.history));

void main() {
  test('restore retains case/handoff/judge stages; private restore requires the same person to take over again', () {
    final game = session(4);
    restore(game, saved(game));
    expect(game.view!.numberStage, SharedNumberStage.caseFile);
    final view = openSharedRecipient(game);
    game.revealOwnNumber(roundId: view.roundId, player: view.recipient!);
    final json = saved(game);
    expect(json['numberStage'], 'recipientHandoff');
    expect(json.containsKey('visible'), isFalse);
    restore(game, json);
    expect(game.view!.numberStage, SharedNumberStage.recipientHandoff);
    expect(game.view!.recipient, view.recipient);
    expect(game.view!.visibleSecret, isNull);
    expect(
      () =>
          game.revealOwnNumber(roundId: view.roundId, player: view.recipient!),
      throwsA(isA<DomainException>()),
    );
    expect(
      () => game.acknowledgeNumber(
        roundId: view.roundId,
        player: view.recipient!,
      ),
      throwsA(isA<DomainException>()),
    );
    openSharedRecipient(game);
    while (game.view!.numberStage != SharedNumberStage.judgeHandoff) {
      final current = openSharedRecipient(game);
      game.acknowledgeNumber(
        roundId: current.roundId,
        player: current.recipient!,
      );
    }
    expect(game.view!.recipient, isNull);
    restore(game, saved(game));
    expect(game.view!.numberStage, SharedNumberStage.judgeHandoff);
    expect(
      () => game.beginOrdering(view.roundId),
      throwsA(isA<DomainException>()),
    );
    expect(
      game.confirmJudge(roundId: view.roundId, judge: PlayerId('p3')),
      isFalse,
    );
    expect(
      game.confirmJudge(roundId: view.roundId, judge: view.judge!),
      isTrue,
    );
    expect(
      game.confirmJudge(roundId: view.roundId, judge: view.judge!),
      isFalse,
    );
    expect(game.view!.phase, GamePhase.answers);
    expect(game.view!.completedCases, 0);
  });
  test('known old snapshot keeps frozen order, cursor, numbers and current recipient instead of guessing a previous judge', () {
    final game = session(4);
    for (var i = 0; i < 2; i++) {
      game.completeCase(
        game.view!.roundId,
        confirmed: true,
        withoutVerdict: true,
      );
    }
    final json = saved(game);
    final numbers = json['numbers'], round = json['roundId'];
    for (final key in [
      'handoffVersion',
      'numberStage',
      'previousJudge',
      'legacyHandoffOrder',
    ]) {
      json.remove(key);
    }
    json['recipients'] = ['p0', 'p1', 'p3'];
    json['handoffIndex'] = 1;
    restore(game, json);
    expect(game.view!.recipient, PlayerId('p1'));
    expect(game.view!.numberStage, SharedNumberStage.recipientHandoff);
    expect(game.toSnapshot()!['legacyHandoffOrder'], isTrue);
    expect(game.toSnapshot()!['numbers'], numbers);
    expect(game.view!.roundId, round);
    expect(game.view!.completedCases, 2);
    expect(game.view!.visibleSecret, isNull);
    restore(game, saved(game));
    expect(game.view!.recipient, PlayerId('p1'));
  });
  test('unknown/unsafe stage versions, cursor/order and previous judge fail closed without changing the game', () {
    final game = session(4), before = saved(game);
    for (final change in <void Function(Map<String, dynamic>)>[
      (s) => s['handoffVersion'] = 3,
      (s) => s['numberStage'] = 'recipientNumber',
      (s) => s['numberStage'] = 'judgeHandoff',
      (s) => s['handoffIndex'] = 1,
      (s) => s['recipients'] = ['p2', 'p1', 'p3'],
      (s) => s['previousJudge'] = 'unknown',
    ]) {
      final candidate = saved(game);
      change(candidate);
      expect(() => restore(game, candidate), throwsA(isA<FormatException>()));
      expect(saved(game), before);
    }
  });
  test('interruption and reroll close private view; stale recipient/instance callbacks cannot open another value', () {
    final game = session(4), view = openSharedRecipient(game);
    game.revealOwnNumber(roundId: view.roundId, player: view.recipient!);
    game.interruptPrivateHandoff();
    expect(game.view!.visibleSecret, isNull);
    expect(game.view!.recipient, view.recipient);
    expect(game.view!.numberStage, SharedNumberStage.recipientHandoff);
    openSharedRecipient(game);
    game.acknowledgeNumber(roundId: view.roundId, player: view.recipient!);
    expect(
      game.confirmRecipient(roundId: view.roundId, player: view.recipient!),
      isFalse,
    );
    final before = saved(game);
    game.rerollCurrentQuestion(roundId: view.roundId);
    expect(game.toSnapshot()!['numbers'], before['numbers']);
    expect(game.toSnapshot()!['recipients'], before['recipients']);
    expect(game.view!.numberStage, SharedNumberStage.caseFile);
    expect(
      () =>
          game.revealOwnNumber(roundId: view.roundId, player: view.recipient!),
      throwsA(isA<DomainException>()),
    );
  });
  for (var count = 3; count <= 20; count++) {
    test(
      '$count people: first case is cyclic, next case starts with previous judge, doubles skip nobody',
      () {
        final game = session(count), first = game.view!;
        expect(first.numberStage, SharedNumberStage.caseFile);
        expect(first.recipient, isNull);
        expect(game.toSnapshot()!['recipients'], [
          for (var i = 1; i < count; i++) 'p$i',
        ]);
        expect(game.beginNumberHandoff(first.roundId), isTrue);
        expect(game.beginNumberHandoff(first.roundId), isFalse);
        final recipient = game.view!.recipient!;
        expect(
          game.confirmRecipient(roundId: first.roundId, player: first.judge!),
          isFalse,
        );
        expect(
          game.confirmRecipient(roundId: first.roundId, player: recipient),
          isTrue,
        );
        expect(
          game.confirmRecipient(roundId: first.roundId, player: recipient),
          isFalse,
        );
        // Looking at the number is voluntary; a hidden number may be passed on.
        game.acknowledgeNumber(roundId: first.roundId, player: recipient);
        final after = saved(game);
        game.acknowledgeNumber(roundId: first.roundId, player: recipient);
        expect(saved(game), after);
        finishSharedNumbers(game);
        expect(game.view!.phase, GamePhase.answers);
        expect(game.view!.completedCases, 0);
        game.completeCase(first.roundId, confirmed: true, withoutVerdict: true);
        expect(game.view!.judge, PlayerId('p1'));
        expect(game.toSnapshot()!['recipients'], [
          'p0',
          for (var i = 2; i < count; i++) 'p$i',
        ]);
        expect(game.view!.numberStage, SharedNumberStage.caseFile);
        expect(game.view!.visibleSecret, isNull);
      },
    );
  }
  test('roster edits are frozen for the case; removed previous judge uses cyclic fallback', () {
    final game = session(4), before = saved(game);
    final original = people(5);
    game.applyRoster([original[3], original[2], original[1], original[4]]);
    expect(game.toSnapshot()!['recipients'], before['recipients']);
    game.completeCase(
      game.view!.roundId,
      confirmed: true,
      withoutVerdict: true,
    );
    expect(game.view!.judge, PlayerId('p1'));
    expect(game.toSnapshot()!['recipients'], ['p4', 'p3', 'p2']);
  });
}
