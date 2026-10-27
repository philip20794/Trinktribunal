import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/config/game_config.dart';
import 'package:trinktribunal/domain/models/content_history.dart';
import 'package:trinktribunal/domain/models/domain_error.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/domain/models/game_state.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/person_selection_counts.dart';
import 'package:trinktribunal/domain/models/player.dart';

Map<String, dynamic> fixture(String name) => jsonDecode(
  File('../../packages/protocol/fixtures/rules/$name.json').readAsStringSync(),
) as Map<String, dynamic>;
final invalidState = isA<DomainException>().having(
  (e) => e.code,
  'code',
  DomainErrorCode.invalidState,
);
final a = PlayerId('A');
final b = PlayerId('B');
final c = PlayerId('C');

void main() {
  test(
    'typed IDs are stable map keys and names are independent of identity',
    () {
      expect(PlayerId('A'), a);
      expect({a: 2}[PlayerId('A')], 2);
      expect(a == GameId('A'), false);
      expect(a == RoundId('A'), false);
      for (final invalid in ['', ' ', ' A', 'A ']) {
        expect(() => PlayerId(invalid), throwsA(invalidState));
      }
      final player = Player(id: a, name: '  Alex  ');
      final renamed = player.renamed('Alice');
      expect(player.name, 'Alex');
      expect(renamed.name, 'Alice');
      expect(renamed.id, a);
      expect(Player(id: b, name: 'Alex').id, isNot(a));
    },
  );

  test('shared Unicode name fixture validates graphemes after trimming', () {
    final data = fixture('name-graphemes');
    final cases = data['input']['cases'] as List;
    for (var i = 0; i < cases.length; i++) {
      final raw = cases[i]['raw'] as String;
      if (data['expected']['valid'][i] == true) {
        expect(Player(id: a, name: raw).name, cases[i]['expectedTrimmed']);
      } else {
        expect(
          () => Player(id: a, name: raw),
          throwsA(
            isA<DomainException>().having(
              (e) => e.code.value,
              'code',
              data['expected']['errorForInvalid'],
            ),
          ),
        );
      }
    }
    expect(Player(id: a, name: '👩‍👩‍👧‍👦' * 24).name, '👩‍👩‍👧‍👦' * 24);
    expect(
      () => Player(id: a, name: '👩‍👩‍👧‍👦' * 25),
      throwsA(isA<DomainException>()),
    );
  });

  test('named games require unique IDs and keep same-name players', () {
    final config = GameConfig(
      mode: GameMode.sharedPhone,
      playerCount: 3,
      capacity: CatalogCapacity(questions: 491, rules: 25),
    );
    final players = [
      for (final id in [a, b, c]) Player(id: id, name: 'Alex'),
    ];
    final state = GameState.initial(
      id: GameId('game-1'),
      config: config,
      players: players,
    );
    players.clear();
    expect(state.players.length, 3);
    expect(state.phase, GamePhase.lobby);
    expect(state.completedCases, 0);
    expect(state.revision, 0);
    expect(state.personSelectionCounts.values, {a: 0, b: 0, c: 0});
    expect(() => state.players.clear(), throwsUnsupportedError);
    expect(
      () => state.personSelectionCounts.values.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => GameState.initial(id: GameId('bad'), config: config),
      throwsA(invalidState),
    );
    expect(
      () => GameState.initial(
        id: GameId('bad'),
        config: config,
        players: [for (var i = 0; i < 3; i++) Player(id: a, name: 'Alex')],
      ),
      throwsA(invalidState),
    );
  });

  test('card mode stores only a player count and never invents profiles', () {
    final config = GameConfig(
      mode: GameMode.physicalCards,
      playerCount: 8,
      capacity: CatalogCapacity(questions: 431, rules: 22),
    );
    final state = GameState.initial(id: GameId('cards'), config: config);
    expect(state.config.playerCount, 8);
    expect(state.players, isEmpty);
    expect(state.personSelectionCounts.values, isEmpty);
    expect(
      () => GameState.initial(
        id: GameId('bad'),
        config: config,
        players: [Player(id: a, name: 'Alex')],
      ),
      throwsA(invalidState),
    );
  });

  test('person counters copy input, count distinct references, and reject unknown IDs', () {
    final input = {a: 1, b: 0};
    final counts = PersonSelectionCounts(input);
    input[a] = 99;
    final next = counts.record([a, a, b]);
    expect(counts.values, {a: 1, b: 0});
    expect(next.values, {a: 2, b: 1});
    expect(() => counts.record([c]), throwsA(invalidState));
    expect(() => PersonSelectionCounts({a: -1}), throwsA(invalidState));
    expect(() => next.values[a] = 3, throwsUnsupportedError);
  });

  test('new participants use active maximum; local reactivation retains higher old count', () {
    final data = fixture('person-join');
    final input = data['input']['activeCounters'] as Map<String, dynamic>;
    final counts = PersonSelectionCounts({
      for (final e in input.entries) PlayerId(e.key): e.value as int,
    });
    final joined = counts.withParticipant(
      PlayerId('new'),
      previouslyActive: counts.values.keys,
    );
    expect(joined.countFor(PlayerId('new')), data['expected']['newCounter']);
    final reactivation = fixture('person-reactivation');
    final active =
        reactivation['input']['activeCounters'] as Map<String, dynamic>;
    final old = reactivation['input']['previousLocalPlayer'];
    final oldId = PlayerId(old['id'] as String);
    final previous = PersonSelectionCounts({
      for (final e in active.entries) PlayerId(e.key): e.value as int,
      oldId: old['count'] as int,
    });
    final resumed = previous.withParticipant(
      oldId,
      previouslyActive: active.keys.map(PlayerId.new),
    );
    expect(
      resumed.countFor(oldId),
      reactivation['expected']['localSameId']['newCounter'],
    );
    expect(
      PersonSelectionCounts({a: 9, b: 2})
          .withParticipant(a, previouslyActive: [b])
          .countFor(a),
      9,
    );
    expect(
      PersonSelectionCounts({a: 2, b: 9})
          .withParticipant(a, previouslyActive: [b])
          .countFor(a),
      9,
    );
    expect(
      PersonSelectionCounts({a: 100, b: 2})
          .withParticipant(c, previouslyActive: [b])
          .countFor(c),
      2,
    );
    expect(
      PersonSelectionCounts({})
          .withParticipant(a, previouslyActive: [])
          .countFor(a),
      0,
    );
  });

  test('new game resets fairness while device history remains intact', () {
    final config = GameConfig(
      mode: GameMode.sharedPhone,
      playerCount: 3,
      capacity: CatalogCapacity(questions: 491, rules: 25),
    );
    final players = [
      for (final id in [a, b, c]) Player(id: id, name: 'Alex'),
    ];
    final first = GameState.initial(
      id: GameId('first'),
      config: config,
      players: players,
    );
    final used = first.personSelectionCounts.record([a]);
    final history = ContentHistory([
      ContentHistoryEntry(
        eventId: 'e1',
        kind: ContentKind.question,
        contentId: '001-a',
        timestampUtc: DateTime.utc(2026, 10, 27),
      ),
    ]);
    final next = GameState.initial(
      id: GameId('next'),
      config: config,
      players: players,
    );
    expect(used.countFor(a), 1);
    expect(next.personSelectionCounts.countFor(a), 0);
    expect(
      history.recentCount(
        ContentKind.question,
        '001-a',
        DateTime.utc(2026, 10, 27, 1),
      ),
      1,
    );
  });

  test(
    'history fixture respects exact six-hour cutoff and distinct content kinds',
    () {
      final data = fixture('history-window');
      final input = data['input'];
      final now = DateTime.parse(input['nowUtc'] as String);
      final entries = <ContentHistoryEntry>[
        for (var i = 0; i < (input['ids'] as List).length; i++)
          ContentHistoryEntry(
            eventId: 'e$i',
            kind: ContentKind.question,
            contentId: input['ids'][i] as String,
            timestampUtc: DateTime.parse(input['previousUtc'][i] as String),
          ),
      ];
      final history = ContentHistory(entries);
      entries.clear();
      final expected = data['expected']['recentCounts'] as Map<String, dynamic>;
      for (final e in expected.entries) {
        expect(history.recentCount(ContentKind.question, e.key, now), e.value);
        expect(history.recentCount(ContentKind.rule, e.key, now), 0);
      }
      expect(() => history.entries.clear(), throwsUnsupportedError);
    },
  );

  test('history events are immutable, UTC-normalized and idempotent', () {
    final timestamp = DateTime.parse('2026-10-27T12:00:00+02:00');
    final entry = ContentHistoryEntry(
      eventId: 'e1',
      kind: ContentKind.rule,
      contentId: 'rule_a',
      timestampUtc: timestamp,
    );
    expect(entry.timestampUtc.isUtc, true);
    final empty = ContentHistory([]);
    final history = empty.record(entry);
    expect(empty.entries, isEmpty);
    expect(identical(history.record(entry), history), true);
    expect(
      history.recentCount(
        ContentKind.rule,
        'rule_a',
        DateTime.parse('2026-10-27T12:00:00Z'),
      ),
      1,
    );
    expect(
      () => history.record(
        ContentHistoryEntry(
          eventId: 'e1',
          kind: ContentKind.rule,
          contentId: 'other',
          timestampUtc: timestamp,
        ),
      ),
      throwsA(invalidState),
    );
    expect(() => ContentHistory([entry, entry]), throwsA(invalidState));
    expect(
      () => ContentHistoryEntry(
        eventId: '',
        kind: ContentKind.rule,
        contentId: 'r',
        timestampUtc: timestamp,
      ),
      throwsA(invalidState),
    );
  });
}
