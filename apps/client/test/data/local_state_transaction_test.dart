import '../support/shared_handoff.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/content_history_store.dart';
import 'package:trinktribunal/application/local_session_controller.dart';
import 'package:trinktribunal/application/local_state_transaction.dart';
import 'package:trinktribunal/application/shared_phone_controller.dart';
import 'package:trinktribunal/data/atomic_state_storage_io.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/user_profile.dart';

import '../domain/selection_support.dart';
import '../support/memory_atomic_state_storage.dart';

var _idCounter = 0;
final _roster = [
  for (final id in players)
    UserProfile(
      player: Player(id: id, name: id.value),
      avatar: AvatarConfig(),
    ),
];

final class Harness {
  Harness(this.storage, {String signature = 'catalog-v1', DateTime? time})
    : time = time ?? now {
    cards = LocalSessionController(
      questions: actualQuestions(),
      rules: actualRules(),
      random: TestRandom(),
      clock: () => this.time,
      newId: () => 'cards${_idCounter++}',
      historyStore: history,
    );
    phone = SharedPhoneController(
      questions: actualQuestions(),
      rules: actualRules(),
      random: TestRandom(),
      clock: () => this.time,
      newId: () => 'phone${_idCounter++}',
      historyStore: history,
    );
    transaction = LocalStateTransaction(
      storage: storage,
      cards: cards,
      shared: phone,
      history: history,
      catalogSignature: signature,
      clock: () => this.time,
    );
  }
  final MemoryAtomicStateStorage storage;
  final ContentHistoryStore history = ContentHistoryStore();
  DateTime time;
  late LocalSessionController cards;
  late SharedPhoneController phone;
  late LocalStateTransaction transaction;
  void startPhone({int cases = 3, int rules = 2}) => phone.start(
    config: phone.configure(
      playerCount: 4,
      targetCases: cases,
      requestedRuleEvents: rules,
    ),
    roster: _roster,
  );
  void startCards({int cases = 3, int rules = 0}) => cards.start(
    cards.configure(
      playerCount: 4,
      targetCases: cases,
      requestedRuleEvents: rules,
    ),
  );
}

void finishHandoff(SharedPhoneController phone) => finishSharedNumbers(phone);

void main() {
  test(
    'invalid numbers, orders, cursor, bindings and IDs reject whole snapshots',
    () async {
      final baseline = MemoryAtomicStateStorage();
      final first = Harness(baseline);
      first.startPhone();
      finishHandoff(first.phone);
      first.phone.beginOrdering(first.phone.view!.roundId);
      await first.transaction.save();
      final changes = <void Function(Map<String, dynamic>)>[
        (json) => json['shared']['numbers'].updateAll((key, value) => 1),
        (json) => json['shared']['order'][1] = json['shared']['order'][0],
        (json) => json['shared']['revealCursor'] = 99,
        (json) =>
            json['shared']['rules']['assignments'][0]['event']['contentId'] =
                '999-a',
        (json) =>
            json['shared']['rules']['counts'].updateAll((key, value) => -1),
        (json) => json['shared']['slots'][0] = 0,
      ];
      for (final change in changes) {
        final json = jsonDecode(baseline.primary!) as Map<String, dynamic>;
        change(json);
        final storage = MemoryAtomicStateStorage()..primary = jsonEncode(json);
        final rejected = Harness(storage);
        await rejected.transaction.load();
        expect(rejected.transaction.needsReset, true);
        expect(rejected.phone.view, isNull);
        expect(rejected.history.history.entries, isEmpty);
      }
    },
  );
  test(
    'pending roster survives restore while active handoff remains frozen',
    () async {
      final storage = MemoryAtomicStateStorage();
      final first = Harness(storage);
      first.startPhone();
      first.phone.applyRoster(_roster.skip(1).toList());
      await first.transaction.save();
      final resumed = Harness(storage);
      await resumed.transaction.load();
      expect(resumed.transaction.error, isNull);
      expect(resumed.phone.view!.roster.length, 4);
      expect(resumed.phone.view!.pendingRoster!.length, 3);
      expect(resumed.phone.view!.judge, players[0]);
      resumed.phone.completeCase(
        resumed.phone.view!.roundId,
        confirmed: true,
        withoutVerdict: true,
      );
      expect(resumed.phone.view!.roster.length, 3);
      expect(resumed.phone.view!.judge, players[1]);
    },
  );
  for (final phase in [
    GamePhase.numbers,
    GamePhase.answers,
    GamePhase.ordering,
    GamePhase.revealing,
    GamePhase.judged,
    GamePhase.ruleEvent,
    GamePhase.paused,
    GamePhase.finished,
  ]) {
    test(
      'shared snapshot roundtrip: ${phase.name}, no redraw, secrets hidden',
      () async {
        final storage = MemoryAtomicStateStorage();
        final first = Harness(storage);
        first.startPhone(
          cases: phase == GamePhase.finished ? 1 : 3,
          rules: phase == GamePhase.finished ? 0 : 2,
        );
        final phone = first.phone;
        final round = phone.view!.roundId;
        if (phase == GamePhase.numbers) {
          openSharedRecipient(phone);
          phone.revealOwnNumber(roundId: round, player: phone.view!.recipient!);
        }
        if ([
          GamePhase.answers,
          GamePhase.ordering,
          GamePhase.revealing,
          GamePhase.judged,
        ].contains(phase)) {
          finishHandoff(phone);
        }
        if ([
          GamePhase.ordering,
          GamePhase.revealing,
          GamePhase.judged,
        ].contains(phase)) {
          phone.beginOrdering(round);
        }
        if ([GamePhase.revealing, GamePhase.judged].contains(phase)) {
          phone.confirmOrder(round, confirmed: true);
          final steps = phase == GamePhase.judged
              ? phone.view!.order.length
              : 1;
          for (var i = 0; i < steps; i++) {
            phone.revealNext(round, expectedCursor: i);
          }
        }
        if (phase == GamePhase.paused) {
          phone.applyRoster(_roster.take(2).toList());
        }
        if ([
          GamePhase.ruleEvent,
          GamePhase.paused,
          GamePhase.finished,
        ].contains(phase)) {
          phone.completeCase(round, confirmed: true, withoutVerdict: true);
        }
        expect(phone.view!.phase, phase);
        final snapshot = jsonDecode(jsonEncode(phone.toSnapshot()));
        await first.transaction.save();
        expect(first.transaction.error, isNull);
        final resumed = Harness(storage);
        await resumed.transaction.load();
        expect(resumed.transaction.error, isNull);
        expect(resumed.transaction.restored, true);
        expect(resumed.phone.toSnapshot(), snapshot);
        expect(resumed.phone.view!.visibleSecret, isNull);
        expect(
          resumed.phone.personCounts.values,
          first.phone.personCounts.values,
        );
        expect(
          resumed.history.history.entries.length,
          first.history.history.entries.length,
        );
      },
    );
  }
  test(
    'cards resume at file/rule/end without extra question or completion',
    () async {
      for (final phase in [
        GamePhase.casePresented,
        GamePhase.ruleEvent,
        GamePhase.finished,
      ]) {
        final storage = MemoryAtomicStateStorage();
        final first = Harness(storage);
        first.startCards(
          cases: phase == GamePhase.finished ? 1 : 3,
          rules: phase == GamePhase.finished ? 0 : 2,
        );
        if (phase != GamePhase.casePresented) {
          first.cards.completeCase(
            roundId: first.cards.state!.currentEventId,
            confirmed: true,
          );
        }
        await first.transaction.save();
        final resumed = Harness(storage);
        await resumed.transaction.load();
        expect(resumed.transaction.error, isNull);
        expect(resumed.cards.state!.phase, phase);
        expect(
          resumed.cards.toSnapshot(),
          jsonDecode(jsonEncode(first.cards.toSnapshot())),
        );
        expect(
          resumed.history.history.entries.length,
          first.history.history.entries.length,
        );
      }
    },
  );
  test(
    'crash between backup and replace keeps both previous game AND history',
    () async {
      final storage = MemoryAtomicStateStorage();
      final first = Harness(storage);
      first.startCards();
      await first.transaction.save();
      final old = storage.primary;
      first.cards.completeCase(
        roundId: first.cards.state!.currentEventId,
        confirmed: true,
      );
      storage.failAfterBackup = true;
      await first.transaction.save();
      expect(first.transaction.error, isNotNull);
      expect(storage.primary, old);
      final resumed = Harness(storage);
      await resumed.transaction.load();
      expect(resumed.cards.state!.completedCases, 0);
      expect(resumed.history.history.entries.length, 1);
      expect(
        first.cards.state!.completedCases,
        1,
      ); // Play is not blocked by IO failure.
    },
  );
  test(
    'corrupt primary falls back to last valid backup; bad half-state rejected',
    () async {
      final storage = MemoryAtomicStateStorage();
      final first = Harness(storage);
      first.startCards();
      await first.transaction.save();
      first.cards.completeCase(
        roundId: first.cards.state!.currentEventId,
        confirmed: true,
      );
      await first.transaction.save();
      storage.primary = 'broken';
      final resumed = Harness(storage);
      await resumed.transaction.load();
      expect(resumed.cards.state!.completedCases, 0);
      expect(resumed.history.history.entries.length, 1);
      expect(resumed.transaction.error, contains('vorherige'));
      final broken = jsonDecode(storage.backup!) as Map<String, dynamic>;
      broken['history'] = [];
      storage.primary = jsonEncode(broken);
      storage.backup = null;
      final rejected = Harness(storage);
      await rejected.transaction.load();
      expect(rejected.cards.state, isNull);
      expect(rejected.history.history.entries, isEmpty);
      expect(rejected.transaction.needsReset, true);
    },
  );
  test('catalog/schema mismatch and unavailable storage allow a new game with warnings', () async {
    final storage = MemoryAtomicStateStorage();
    final first = Harness(storage);
    first.startCards();
    await first.transaction.save();
    final incompatible = Harness(storage, signature: 'catalog-v2');
    await incompatible.transaction.load();
    expect(incompatible.transaction.needsReset, true);
    expect(incompatible.cards.state, isNull);
    expect(incompatible.history.history.entries.length, 1);
    final schema = jsonDecode(storage.primary!) as Map<String, dynamic>;
    schema['formatVersion'] = 99;
    storage.primary = jsonEncode(schema);
    final invalid = Harness(storage);
    await invalid.transaction.load();
    expect(invalid.transaction.needsReset, true);
    storage.failRead = true;
    final unavailable = Harness(storage);
    await unavailable.transaction.load();
    expect(unavailable.transaction.error, isNotNull);
    unavailable.startCards();
    expect(unavailable.cards.state, isNotNull);
  });
  test(
    'six-hour expiry prunes history while retaining in-game used IDs',
    () async {
      final storage = MemoryAtomicStateStorage();
      final first = Harness(storage);
      first.startCards();
      final question = first.cards.state!.currentQuestion!.entry.id;
      first.time = now.add(const Duration(hours: 7));
      await first.transaction.save();
      final resumed = Harness(storage, time: first.time);
      await resumed.transaction.load();
      expect(resumed.transaction.error, isNull);
      expect(resumed.history.history.entries, isEmpty);
      resumed.cards.completeCase(
        roundId: resumed.cards.state!.currentEventId,
        confirmed: true,
      );
      expect(resumed.cards.state!.currentQuestion!.entry.id, isNot(question));
      expect(resumed.history.history.entries.length, 1);
    },
  );
  test(
    'queued saves keep newest complete envelope and discard preserves history',
    () async {
      final storage = MemoryAtomicStateStorage();
      final first = Harness(storage);
      first.startCards();
      final gate = Completer<void>();
      storage.beforeCommit = () => gate.future;
      final one = first.transaction.save();
      first.cards.completeCase(
        roundId: first.cards.state!.currentEventId,
        confirmed: true,
      );
      final two = first.transaction.save();
      gate.complete();
      await Future.wait([one, two]);
      final resumed = Harness(storage);
      await resumed.transaction.load();
      expect(resumed.cards.state!.completedCases, 1);
      expect(resumed.history.history.entries.length, 2);
      await resumed.transaction.discardGames();
      final discarded = Harness(storage);
      await discarded.transaction.load();
      expect(discarded.cards.state, isNull);
      expect(discarded.phone.view, isNull);
      expect(discarded.history.history.entries.length, 2);
    },
  );
  test('native adapter replaces complete files and ignores interrupted temporary file', () async {
    final root = await Directory.systemTemp.createTemp(
      'trinktribunal-state-unit-',
    );
    addTearDown(() async {
      // Only files directly in this newly-created test directory, no recursion.
      for (final file in root.listSync().whereType<File>()) {
        await file.delete();
      }
      await root.delete();
    });
    final adapter = FileAtomicStateStorage(() async => root);
    await adapter.commit('first');
    await adapter.commit('second', previousValid: 'first');
    await File('${root.path}/local-state.pending.json')
        .writeAsString('interrupted');
    expect(await adapter.readCandidates(), ['second', 'first']);
  });
}
