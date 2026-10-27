import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/models/content_history.dart';
import 'package:trinktribunal/domain/models/domain_error.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/domain/question_deck.dart';
import 'package:trinktribunal/domain/selection/person_assignment.dart';

import 'selection_support.dart';

void main() {
  test(
    'all 491 named /431 anonymous questions draw without repeats then exhaust',
    () {
      for (final mode in [GameMode.sharedPhone, GameMode.physicalCards]) {
        final deck = QuestionDeck(
          questions: actualQuestions(),
          mode: mode,
          random: TestRandom(),
          clock: () => now,
        );
        var state = selection();
        final count = mode == GameMode.physicalCards ? 431 : 491;
        for (var i = 0; i < count; i++) {
          state = deck.draw(
            state: state,
            eventId: 'q$i',
            activePlayers: mode.hasPlayerRegistry ? players : [],
          );
        }
        expect(state.drawnIds(ContentKind.question).length, count);
        expect(state.history.entries.length, count);
        expect(
          () => deck.draw(
            state: state,
            eventId: 'exhausted',
            activePlayers: players,
          ),
          throwsA(
            isA<DomainException>().having(
              (e) => e.code,
              'code',
              DomainErrorCode.contentExhausted,
            ),
          ),
        );
      }
    },
  );
  test('zero-use then minimum-use selection; six-hour boundary; language-independent IDs', () {
    final history = ContentHistory([
      for (var i = 0; i < 2; i++)
        ContentHistoryEntry(
          eventId: 'a$i',
          kind: ContentKind.question,
          contentId: '001-a',
          timestampUtc: now,
        ),
      ContentHistoryEntry(
        eventId: 'b',
        kind: ContentKind.question,
        contentId: '001-b',
        timestampUtc: now,
      ),
      ContentHistoryEntry(
        eventId: 'c',
        kind: ContentKind.question,
        contentId: '002-a',
        timestampUtc: now.subtract(const Duration(hours: 6)),
      ),
    ]);
    final entries = questions([
      questionJson('001-a'),
      questionJson('001-b'),
      questionJson('002-a'),
    ]);
    final deck = QuestionDeck(
      questions: entries,
      mode: GameMode.physicalCards,
      random: TestRandom(),
      clock: () => now,
    );
    var state = deck.draw(
      state: selection(history: history),
      eventId: 'new1',
      activePlayers: [],
    );
    expect(state.assignments['new1']!.entry.id, '002-a');
    state = deck.draw(state: state, eventId: 'new2', activePlayers: []);
    expect(state.assignments['new2']!.entry.id, '001-b');
    final enDeck = QuestionDeck(
      questions: actualQuestions('en')
          .where((q) => ['001-a', '001-b', '002-a'].contains(q.id)),
      mode: GameMode.physicalCards,
      random: TestRandom(),
      clock: () => now,
    );
    final fresh = enDeck.draw(
      state: selection(history: state.history),
      eventId: 'new-game',
      activePlayers: [],
    );
    expect(fresh.assignments['new-game']!.entry.id, '002-a');
  });
  test('ties use injected randomness; retry and rendering do not recount or redraw', () {
    final random = TestRandom(last: true);
    final entries = questions([questionJson('001-a'), questionJson('001-b')]);
    final deck = QuestionDeck(
      questions: entries,
      mode: GameMode.physicalCards,
      random: random,
      clock: () => now,
    );
    final state = deck.draw(
      state: selection(),
      eventId: 'event',
      activePlayers: [],
    );
    expect(state.assignments['event']!.entry.id, '001-b');
    final calls = random.calls;
    expect(
      identical(
        deck.draw(state: state, eventId: 'event', activePlayers: []),
        state,
      ),
      true,
    );
    expect(random.calls, calls);
    expect(state.history.entries.length, 1);
  });
  test(
    'one-time bindings shared by text and scales; unique persons count once',
    () {
      final roles = <String, Object>{
        'player1': {'selection': 'random'},
        'player2': {
          'selection': 'random',
          'differentFrom': ['player1'],
        },
      };
      final entry = questions([questionJson('001-a', roles: roles)]).single;
      final deck = QuestionDeck(
        questions: [entry],
        mode: GameMode.sharedPhone,
        random: TestRandom(),
        clock: () => now,
      );
      final state = deck.draw(
        state: selection(),
        eventId: 'q',
        activePlayers: players,
      );
      final assignment = state.assignments['q']!;
      expect(assignment.bindings, {
        'player1': players[0],
        'player2': players[1],
      });
      expect(state.counts.countFor(players[0]), 1);
      final names = {for (final p in players) p: p.value};
      expect(entry.renderFor(assignment.names(names)).green, 'A');
      names[players[0]] = 'Neuer Name';
      expect(
        entry.renderFor(assignment.names(names)).text,
        'Neuer Name B Neuer Name',
      );
      expect(state.counts.countFor(players[0]), 1);
      expect(() => assignment.bindings.clear(), throwsUnsupportedError);
    },
  );
  test('four single-role references include judge and use all four before repeating', () {
    final entries = questions([
      for (var i = 1; i <= 4; i++)
        questionJson(
          '00$i-a',
          roles: {
            'player1': {'selection': 'random'},
          },
        ),
    ]);
    final deck = QuestionDeck(
      questions: entries,
      mode: GameMode.sharedPhone,
      random: TestRandom(),
      clock: () => now,
    );
    var state = selection();
    for (var i = 0; i < 4; i++) {
      state = deck.draw(state: state, eventId: 'q$i', activePlayers: players);
    }
    expect(state.counts.values.values, everyElement(1));
  });
  test('constraints solve full graph before fairness; three roles can use two people', () {
    final roles = <String, Object>{
      'player1': {
        'selection': 'random',
        'differentFrom': ['player2'],
      },
      'player2': {
        'selection': 'random',
        'differentFrom': ['player3'],
      },
      'player3': {'selection': 'random'},
    };
    final entry = questions([questionJson('001-a', roles: roles)]).single;
    final solver = PersonAssignment(
      roles: entry.players,
      activePlayers: players.take(2),
      counts: selection().counts,
    );
    final binding = solver.bind(TestRandom())!;
    expect(binding['player1'], binding['player3']);
    expect(binding['player1'], isNot(binding['player2']));
    final impossibleRoles = {
      ...roles,
      'player1': {
        'selection': 'random',
        'differentFrom': ['player2', 'player3'],
      },
    };
    final impossible = questions([
      questionJson('001-a', roles: impossibleRoles),
    ]).single;
    expect(
      PersonAssignment(
        roles: impossible.players,
        activePlayers: players.take(2),
        counts: selection().counts,
      ).bind(TestRandom()),
      isNull,
    );
  });
}
