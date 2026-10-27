import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/models/content_history.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/domain/rules/drinking_rules.dart';
import 'package:trinktribunal/domain/question_deck.dart';
import 'package:trinktribunal/domain/selection/person_assignment.dart';

import 'selection_support.dart';

void main() {
  test(
    'conflicts work in either direction, independently of catalog validation',
    () {
      final pair = rules([
        ruleJson('a', excludes: ['b']),
        ruleJson('b', excludes: ['a']),
      ]);
      final plain = rules([ruleJson('a')]).single;
      expect(rulesConflict(plain, pair[1]), true);
      expect(rulesConflict(pair[1], plain), true);
      final real = actualRules();
      expect(
        rulesConflict(
          real.firstWhere((r) => r.id == 'imaginary_kobold'),
          real.firstWhere((r) => r.id == 'imaginary_fly'),
        ),
        false,
      );
    },
  );
  test(
    'conflict filter precedes history priority, skipped slots are idempotent',
    () {
      final catalog = rules([
        ruleJson('a', excludes: ['b']),
        ruleJson('b', excludes: ['a']),
        ruleJson('c'),
      ]);
      final history = ContentHistory([
        ContentHistoryEntry(
          eventId: 'old',
          kind: ContentKind.rule,
          contentId: 'c',
          timestampUtc: now,
        ),
      ]);
      final engine = DrinkingRules(
        rules: catalog,
        mode: GameMode.physicalCards,
        random: TestRandom(),
        clock: () => now,
      );
      var state = engine.activate(
        state: RuleState(selection: selection(history: history)),
        eventId: 'r1',
        activePlayers: [],
      );
      expect(state.active.single.entry.id, 'a');
      state = engine.activate(state: state, eventId: 'r2', activePlayers: []);
      expect(state.active.map((a) => a.entry.id), ['a', 'c']);
      state = engine.activate(state: state, eventId: 'r3', activePlayers: []);
      expect(state.skippedEvents, {'r3'});
      expect(state.selection.history.entries.length, 3);
      expect(
        identical(
          engine.activate(state: state, eventId: 'r3', activePlayers: []),
          state,
        ),
        true,
      );
      expect(
        identical(
          engine.activate(state: state, eventId: 'r1', activePlayers: []),
          state,
        ),
        true,
      );
    },
  );
  test('deactivation retains drawn IDs and prevents redrawing', () {
    final engine = DrinkingRules(
      rules: rules([ruleJson('a')]),
      mode: GameMode.physicalCards,
      random: TestRandom(),
      clock: () => now,
    );
    var state = engine.activate(
      state: RuleState(selection: selection()),
      eventId: 'r1',
      activePlayers: [],
    );
    state = state.deactivate('a');
    expect(state.active, isEmpty);
    expect(state.selection.drawnIds(ContentKind.rule), {'a'});
    state = engine.activate(state: state, eventId: 'r2', activePlayers: []);
    expect(state.skippedEvents, {'r2'});
    expect(state.activations.length, 1);
  });
  test('question and rule roles share fairness counters and count people only once', () {
    final role = <String, Object>{
      'player1': {'selection': 'random'},
    };
    final deck = QuestionDeck(
      questions: questions([questionJson('001-a', roles: role)]),
      mode: GameMode.sharedPhone,
      random: TestRandom(),
      clock: () => now,
    );
    var selected = deck.draw(
      state: selection(),
      eventId: 'q',
      activePlayers: players,
    );
    final engine = DrinkingRules(
      rules: rules([
        for (final id in ['a', 'b', 'c']) ruleJson(id, roles: role),
      ]),
      mode: GameMode.sharedPhone,
      random: TestRandom(),
      clock: () => now,
    );
    var state = RuleState(selection: selected);
    for (var i = 0; i < 3; i++) {
      state = engine.activate(
        state: state,
        eventId: 'r$i',
        activePlayers: players,
      );
    }
    expect(state.selection.counts.values.values, everyElement(1));
    final assignment = state.active.first;
    final calls = state.selection.history.entries.length;
    expect(
      assignment.entry.render(
        assignment.entry.text,
        assignment.names({for (final p in players) p: 'Alex'}),
      ),
      'Alex Alex',
    );
    selected = engine
        .activate(state: state, eventId: 'r0', activePlayers: players)
        .selection;
    expect(selected.history.entries.length, calls);
    expect(selected.counts.values.values, everyElement(1));
  });
  test('same person can fill unconstrained roles and is counted once', () {
    final entry = rules([
      ruleJson(
        'a',
        roles: {
          'player1': {'selection': 'random'},
          'player2': {'selection': 'random'},
        },
      ),
    ]).single;
    final engine = DrinkingRules(
      rules: [entry],
      mode: GameMode.sharedPhone,
      random: TestRandom(),
      clock: () => now,
    );
    final state = engine.activate(
      state: RuleState(selection: selection()),
      eventId: 'r',
      activePlayers: players,
    );
    expect(state.active.single.bindings.values.toSet(), {players.first});
    expect(state.selection.counts.countFor(players.first), 1);
  });
  test(
    'constraint feasibility takes priority over lower personal counters',
    () {
      final entry = rules([
        ruleJson(
          'a',
          roles: {
            'player1': {'selection': 'random'},
            'player2': {
              'selection': 'random',
              'differentFrom': ['player1'],
            },
          },
        ),
      ]).single;
      final counts = selection(counts: {players[0]: 0, players[1]: 10}).counts;
      final bound = PersonAssignment(
        roles: entry.players,
        activePlayers: players.take(2),
        counts: counts,
        fixedBindings: {'player1': players[0]},
      ).bind(TestRandom())!;
      expect(bound['player2'], players[1]);
    },
  );
  test('unfulfillable graph is skipped and card mode excludes all roles', () {
    final entries = rules([
      ruleJson(
        'a',
        roles: {
          'player1': {'selection': 'random'},
          'player2': {
            'selection': 'random',
            'differentFrom': ['player1'],
          },
        },
      ),
    ]);
    for (final mode in [GameMode.sharedPhone, GameMode.physicalCards]) {
      final engine = DrinkingRules(
        rules: entries,
        mode: mode,
        random: TestRandom(),
        clock: () => now,
      );
      final state = engine.activate(
        state: RuleState(selection: selection()),
        eventId: 'r',
        activePlayers: players.take(1).toList(),
      );
      expect(state.active, isEmpty);
      expect(state.selection.history.entries, isEmpty);
    }
  });
  test(
    'leave rebinds only missing roles; retry leaves counts and history intact',
    () {
      final entry = rules([
        ruleJson(
          'a',
          roles: {
            'player1': {'selection': 'random'},
            'player2': {
              'selection': 'random',
              'differentFrom': ['player1'],
            },
          },
        ),
      ]).single;
      final engine = DrinkingRules(
        rules: [entry],
        mode: GameMode.sharedPhone,
        random: TestRandom(),
        clock: () => now,
      );
      final initial = engine.activate(
        state: RuleState(selection: selection()),
        eventId: 'r',
        activePlayers: players,
      );
      final rebound = engine.rebind(
        state: initial,
        activePlayers: players.skip(1).toList(),
      );
      expect(rebound.active.single.bindings, {
        'player1': players[2],
        'player2': players[1],
      });
      expect(rebound.selection.counts.values, {
        players[0]: 1,
        players[1]: 1,
        players[2]: 1,
        players[3]: 0,
      });
      expect(rebound.selection.history.entries.length, 1);
      final again = engine.rebind(
        state: rebound,
        activePlayers: players.skip(1).toList(),
      );
      expect(again.selection.counts.values, rebound.selection.counts.values);
      final impossible = engine.rebind(
        state: rebound,
        activePlayers: [players[1]],
      );
      expect(impossible.inactiveIds, {'a'});
    },
  );
  test(
    'four short games keep six-hour usage while resetting per-game rules',
    () {
      var history = ContentHistory([]);
      final engine = DrinkingRules(
        rules: actualRules(),
        mode: GameMode.sharedPhone,
        random: TestRandom(),
        clock: () => now,
      );
      final allDrawn = <String>{};
      for (var game = 0; game < 4; game++) {
        var state = RuleState(selection: selection(history: history));
        for (var i = 0; i < 6; i++) {
          state = engine.activate(
            state: state,
            eventId: '$game:r$i',
            activePlayers: players,
          );
        }
        expect(state.activations.length, 6);
        expect(state.active.length, 6);
        for (final assignment in state.active) {
          for (final other in state.active) {
            if (other != assignment) {
              expect(
                rulesConflict(
                  assignment.entry as dynamic,
                  other.entry as dynamic,
                ),
                false,
              );
            }
          }
          allDrawn.add(assignment.entry.id);
        }
        history = state.selection.history;
      }
      expect(allDrawn.length, greaterThanOrEqualTo(22));
      expect(history.entries.length, 24);
    },
  );
}
