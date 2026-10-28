import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/content_history_store.dart';
import 'package:trinktribunal/application/local_session_controller.dart';
import 'package:trinktribunal/application/local_state_transaction.dart';
import 'package:trinktribunal/application/shared_phone_controller.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/user_profile.dart';

import '../domain/selection_support.dart';
import '../support/memory_atomic_state_storage.dart';
import '../support/shared_handoff.dart';

class _Device {
  _Device(MemoryAtomicStateStorage storage) {
    cards = LocalSessionController(
      questions: actualQuestions(),
      rules: actualRules(),
      random: TestRandom(),
      clock: () => now,
      newId: () => 'cards',
      historyStore: history,
    );
    phone = SharedPhoneController(
      questions: actualQuestions(),
      rules: actualRules(),
      random: TestRandom(),
      clock: () => now,
      newId: () => 'phone',
      historyStore: history,
    );
    disk = LocalStateTransaction(
      storage: storage,
      cards: cards,
      shared: phone,
      history: history,
      catalogSignature: 'production-catalog-fixture',
      clock: () => now,
    );
  }
  final history = ContentHistoryStore();
  late final LocalSessionController cards;
  late final SharedPhoneController phone;
  late final LocalStateTransaction disk;
}

void main() {
  test('both local modes complete 8-player / 50-case / 7-rule games with a process restore after every case', () async {
    final storage = MemoryAtomicStateStorage();
    var device = _Device(storage);
    final roster = [
      for (var i = 0; i < 8; i++)
        UserProfile(
          player: Player(id: PlayerId('player$i'), name: 'Person $i'),
          avatar: AvatarConfig(),
        ),
    ];
    device.cards.start(device.cards.configure(playerCount: 8));
    device.phone.start(
      config: device.phone.configure(playerCount: 8),
      roster: roster,
    );
    final cardQuestions = <String>{}, phoneQuestions = <String>{};
    var cardRules = 0, phoneRules = 0;
    for (var index = 0; index < 50; index++) {
      final card = device.cards.state!;
      expect(cardQuestions.add(card.currentQuestion!.entry.id), isTrue);
      device.cards.completeCase(
        roundId: card.currentEventId,
        confirmed: true,
        manualErrors: const [0, 2, 3, 4, 5, 6, 7][index % 7],
        fullOrderConfirmed: true,
      );
      device.cards.completeCase(roundId: card.currentEventId, confirmed: true);
      if (device.cards.state!.phase == GamePhase.ruleEvent) {
        cardRules++;
        device.cards.continueAfterRule(device.cards.state!.currentEventId);
      }
      final phone = device.phone;
      expect(phoneQuestions.add(phone.view!.question!.entry.id), isTrue);
      while (phone.view!.phase == GamePhase.numbers) {
        if (phone.view!.numberStage == SharedNumberStage.judgeHandoff) {
          final view = phone.view!;
          phone.confirmJudge(roundId: view.roundId, judge: view.judge!);
          continue;
        }
        final view = openSharedRecipient(phone);
        expect(view.visibleSecret, isNull);
        phone.revealOwnNumber(roundId: view.roundId, player: view.recipient!);
        phone.hideSecret();
        expect(phone.view!.visibleSecret, isNull);
        phone.revealOwnNumber(roundId: view.roundId, player: view.recipient!);
        phone.acknowledgeNumber(roundId: view.roundId, player: view.recipient!);
      }
      final round = phone.view!.roundId;
      phone.beginOrdering(round);
      if (index.isOdd) phone.move(round, 0, 6);
      phone.confirmOrder(round, confirmed: true);
      for (var cursor = 0; cursor < 7; cursor++) {
        phone.revealNext(round, expectedCursor: cursor);
      }
      expect(phone.view!.verdict, isNotNull);
      phone.completeCase(round, confirmed: true);
      phone.completeCase(round, confirmed: true);
      if (phone.view!.phase == GamePhase.ruleEvent) {
        phoneRules++;
        phone.continueRule(afterCase: index + 1);
      }
      expect(device.cards.state!.completedCases, index + 1);
      expect(phone.view!.completedCases, index + 1);
      final cardBefore = jsonEncode(device.cards.toSnapshot());
      final phoneBefore = jsonEncode(phone.toSnapshot());
      final historyBefore = device.history.history.entries.length;
      await device.disk.save();
      expect(device.disk.error, isNull);
      device = _Device(storage);
      await device.disk.load();
      expect(
        device.disk.restored,
        isTrue,
        reason: 'case ${index + 1}: ${device.disk.error}',
      );
      expect(jsonEncode(device.cards.toSnapshot()), cardBefore);
      expect(jsonEncode(device.phone.toSnapshot()), phoneBefore);
      expect(device.history.history.entries.length, historyBefore);
      expect(device.phone.view!.visibleSecret, isNull);
    }
    expect(device.cards.state!.phase, GamePhase.finished);
    expect(device.phone.view!.phase, GamePhase.finished);
    expect(cardQuestions.length, 50);
    expect(phoneQuestions.length, 50);
    expect(cardRules, 7);
    expect(phoneRules, 7);
    expect(device.cards.state!.rules.active.length, 7);
    expect(device.phone.view!.activeRules.length, 7);
    expect(device.history.history.entries.length, 114);
  });
}
