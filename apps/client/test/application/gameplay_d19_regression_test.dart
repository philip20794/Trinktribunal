import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/shared_phone_controller.dart';
import 'package:trinktribunal/domain/local_game_reducer.dart';
import 'package:trinktribunal/domain/models/domain_error.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';

import '../data/local_state_transaction_test.dart' show Harness;
import '../support/memory_atomic_state_storage.dart';
import '../support/shared_handoff.dart';

void main() {
  test('both local modes: ten rerolls with atomic process restores, then one played/judged completion and rule', () async {
    final storage = MemoryAtomicStateStorage();
    var device = Harness(storage);
    device.startCards(rules: 2);
    device.startPhone();
    final numbers = device.phone.toSnapshot()!['numbers'];
    final judge = device.phone.view!.judge;
    for (var i = 0; i < 10; i++) {
      device.cards.rerollCurrentQuestion(device.cards.state!.currentEventId);
      final recipient = openSharedRecipient(device.phone);
      device.phone.revealOwnNumber(
        roundId: recipient.roundId,
        player: recipient.recipient!,
      );
      device.phone.rerollCurrentQuestion(roundId: recipient.roundId);
      final cardId = device.cards.state!.currentEventId,
          phoneId = device.phone.view!.roundId;
      await device.transaction.save();
      device = Harness(storage);
      await device.transaction.load();
      expect(device.transaction.restored, isTrue);
      expect(device.cards.state!.currentEventId, cardId);
      expect(device.phone.view!.roundId, phoneId);
      expect(device.phone.toSnapshot()!['numbers'], numbers);
      expect(device.phone.view!.judge, judge);
      expect(device.phone.view!.numberStage, SharedNumberStage.caseFile);
      expect(device.phone.view!.visibleSecret, isNull);
      expect(device.phone.view!.completedCases, 0);
      expect(device.cards.state!.completedCases, 0);
    }
    expect(device.history.history.entries, hasLength(22));
    final cardId = device.cards.state!.currentEventId,
        phoneId = device.phone.view!.roundId;
    finishSharedNumbers(device.phone);
    device.phone.beginOrdering(phoneId);
    device.phone.move(phoneId, 0, 1);
    device.phone.confirmOrder(phoneId, confirmed: true);
    for (var cursor = 0; cursor < 3; cursor++) {
      device.phone.revealNext(phoneId, expectedCursor: cursor);
    }
    expect(device.phone.view!.verdict!.errors, 2);
    expect(
      () => device.phone.rerollCurrentQuestion(roundId: phoneId),
      throwsA(isA<DomainException>()),
    );
    device.phone.completeCase(phoneId, confirmed: true);
    device.cards.advancePlayedCase(cardId);
    await device.transaction.save();
    device = Harness(storage);
    await device.transaction.load();
    final savedCards = device.cards.toSnapshot(),
        savedPhone = device.phone.toSnapshot();
    device.cards.advancePlayedCase(cardId);
    device.phone.completeCase(phoneId, confirmed: true);
    expect(device.cards.toSnapshot(), savedCards);
    expect(device.phone.toSnapshot(), savedPhone);
    expect(
      device.cards.state!.lastCompletion,
      CaseCompletion.playedWithoutRecordedVerdict,
    );
    expect(device.cards.state!.manualErrors, isNull);
    expect(device.cards.state!.completedCases, 1);
    expect(device.phone.view!.completedCases, 1);
    expect(device.cards.state!.phase, GamePhase.ruleEvent);
    expect(device.phone.view!.phase, GamePhase.ruleEvent);
    expect(device.cards.state!.rules.active, hasLength(1));
    expect(device.phone.view!.activeRules, hasLength(1));
    expect(device.history.history.entries, hasLength(24));
  });
}
