import 'dart:convert';
import 'dart:io';

import 'package:trinktribunal/data/catalogs/catalog.dart';
import 'package:trinktribunal/domain/event_schedule.dart';
import 'package:trinktribunal/domain/models/content_history.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/person_selection_counts.dart';
import 'package:trinktribunal/domain/number_assignment.dart';
import 'package:trinktribunal/domain/question_deck.dart';
import 'package:trinktribunal/domain/rules/drinking_rules.dart';
import 'package:trinktribunal/domain/selection/content_selection.dart';
import 'package:trinktribunal/domain/selection/person_assignment.dart';
import 'package:trinktribunal/domain/selection/random_source.dart';
import 'package:trinktribunal/domain/verdict.dart';

const parityPath = '../../packages/protocol/fixtures/rules/parity/v1.json';

final class _Indices implements RandomSource {
  _Indices(List<dynamic> values) : indices = values.cast<int>().toList();
  final List<int> indices;
  @override
  int nextInt(int bound) => indices.isEmpty ? 0 : indices.removeAt(0);
}

List<PlayerId> _players(dynamic ids) =>
    (ids as List<dynamic>).map((id) => PlayerId(id as String)).toList();
PersonSelectionCounts _counts(dynamic values) => PersonSelectionCounts({
  for (final entry in (values as Map<String, dynamic>).entries)
    PlayerId(entry.key): entry.value as int,
});
Map<String, int> _countJson(PersonSelectionCounts counts) => {
  for (final entry in counts.values.entries) entry.key.value: entry.value,
};
Map<String, dynamic> _entry(Map<String, dynamic> entry, bool question) {
  final roles = entry['roles'] as Map<String, dynamic>?;
  final text = roles == null
      ? entry['id']
      : roles.keys.map((role) => '{$role}').join(' ');
  return {
    'id': entry['id'],
    'text': text,
    'players': ?roles,
    if (question)
      'scale': {'green': 'green', 'connector': 'bis', 'red': 'red'}
    else
      'excludes': entry['excludes'] ?? <String>[],
  };
}

List<Question> _questions(List<dynamic> entries) => parseQuestions(
  jsonEncode({
    'version': 1,
    'language': 'de',
    'questions': entries
        .map((entry) => _entry(entry as Map<String, dynamic>, true))
        .toList(),
  }),
).entries;
List<DrinkingRule> _rules(List<dynamic> entries) => parseRules(
  jsonEncode({
    'version': 1,
    'language': 'de',
    'rules': entries
        .map((entry) => _entry(entry as Map<String, dynamic>, false))
        .toList(),
  }),
).entries;
ContentHistory _history(List<dynamic> entries) => ContentHistory(
  entries.map((raw) {
    final entry = raw as Map<String, dynamic>;
    return ContentHistoryEntry(
      eventId: entry['eventId'] as String,
      kind: ContentKind.values.byName(entry['kind'] as String),
      contentId: entry['contentId'] as String,
      timestampUtc: DateTime.parse(entry['timestampUtc'] as String),
    );
  }),
);
Map<String, dynamic> _assignment(ContentAssignment assignment) => {
  'contentId': assignment.entry.id,
  'bindings': {
    for (final entry in assignment.bindings.entries)
      entry.key: entry.value.value,
  },
};

Object? evaluateParity(Map<String, dynamic> c) {
  final random = _Indices((c['indices'] as List<dynamic>?) ?? []);
  final players = _players(c['players'] ?? []);
  switch (c['operation']) {
    case 'allJudgesVerdict':
      return {
        for (final entry in allJudgesVerdict(
          numbers: {
            for (final n in (c['numbers'] as Map<String, dynamic>).entries)
              PlayerId(n.key): n.value as int,
          },
          orders: {
            for (final o in (c['orders'] as Map<String, dynamic>).entries)
              PlayerId(o.key): _players(o.value),
          },
        ).entries)
          entry.key.value: entry.value,
      };
    case 'normalVerdict':
      final verdict = normalVerdict(
        judge: PlayerId(c['judge'] as String),
        numbers: {
          for (final entry in (c['numbers'] as Map<String, dynamic>).entries)
            PlayerId(entry.key): entry.value as int,
        },
        proposed: _players(c['proposed']),
      );
      return {
        'errors': verdict.errors,
        'incorrect': verdict.incorrect.map((id) => id.value).toList(),
        'sipCounts': {
          for (final entry in verdict.sips.entries)
            entry.key.value: entry.value,
        },
      };
    case 'cycle':
      final roles = _questions([
        {
          'id': '001-a',
          'roles': {
            'player1': {'selection': 'random'},
          },
        },
      ]).single.players;
      var counts = _counts(c['counts']);
      final chosen = <String>[];
      for (var index = 0; index < (c['entries'] as int); index++) {
        final binding = PersonAssignment(
          roles: roles,
          activePlayers: players,
          counts: counts,
        ).bind(random)!;
        chosen.add(binding['player1']!.value);
        counts = counts.record(binding.values);
      }
      return {'chosen': chosen, 'counts': _countJson(counts)};
    case 'numbers':
      final max = (players.length * (c['factorTenths'] as int) + 9) ~/ 10;
      final result = NumberAssignment.draw(
        roundId: RoundId('fixture_round'),
        roster: players,
        judgeId: PlayerId(c['judge'] as String),
        maxSecretNumber: max,
        allJudges: c['allJudges'] as bool,
        random: random,
      );
      return {
        'max': max,
        'numbers': {
          for (final entry in result.numbers.entries)
            entry.key.value: entry.value,
        },
      };
    case 'schedule':
      return EventSchedule.plan(
        targetCases: c['targetCases'] as int,
        requestedRuleEvents: c['requestedRuleEvents'] as int,
        random: random,
      ).slots;
    case 'bind':
      final roles = _questions([
        {'id': '001-a', 'roles': c['roles']},
      ]).single.players;
      final counts = _counts(c['counts']);
      final bindings = PersonAssignment(
        roles: roles,
        activePlayers: players,
        counts: counts,
      ).bind(random);
      return {
        'bindings': bindings == null
            ? null
            : {
                for (final entry in bindings.entries)
                  entry.key: entry.value.value,
              },
        'counts': _countJson(
          bindings == null ? counts : counts.record(bindings.values),
        ),
      };
    case 'join':
      var counts = _counts(c['counts']);
      for (final id in _players(c['newPlayers'])) {
        counts = counts.withParticipant(id, previouslyActive: players);
      }
      return _countJson(counts);
    case 'history':
      final history = _history(c['events'] as List<dynamic>),
          now = DateTime.parse(c['nowUtc'] as String);
      return {
        for (final id in ['001-a', '001-b'])
          id: history.recentCount(ContentKind.question, id, now),
      };
    case 'sequence':
      final now = DateTime.parse(c['nowUtc'] as String);
      final deck = QuestionDeck(
        questions: _questions(c['questions'] as List<dynamic>),
        mode: GameMode.sharedPhone,
        random: random,
        clock: () => now,
      );
      final engine = DrinkingRules(
        rules: _rules(c['rules'] as List<dynamic>),
        mode: GameMode.sharedPhone,
        random: random,
        clock: () => now,
      );
      var state = RuleState(
        selection: SelectionState(
          history: _history((c['history'] as List<dynamic>?) ?? []),
          counts: _counts(c['counts']),
        ),
      );
      final assignments = <Object?>[];
      for (final kind in c['actions'] as List<dynamic>) {
        final eventId = 'event_${state.selection.history.entries.length}';
        if (kind == 'question') {
          final selection = deck.draw(
            state: state.selection,
            eventId: eventId,
            activePlayers: players,
          );
          state = state.withSelection(selection);
          assignments.add(_assignment(selection.assignments[eventId]!));
        } else {
          state = engine.activate(
            state: state,
            eventId: eventId,
            activePlayers: players,
          );
          final assignment = state.activations[eventId];
          assignments.add(assignment == null ? null : _assignment(assignment));
        }
      }
      return {
        'assignments': assignments,
        'counts': _countJson(state.selection.counts),
        'historyLength': state.selection.history.entries.length,
      };
    case 'rebind':
      final rules = _rules(c['rules'] as List<dynamic>);
      final assignments = <String, ContentAssignment>{};
      for (final raw in c['active'] as List<dynamic>) {
        final entry = raw as Map<String, dynamic>,
            id = entry['contentId'] as String;
        assignments[id] = ContentAssignment(
          entry: rules.firstWhere((rule) => rule.id == id),
          bindings: {
            for (final e in (entry['bindings'] as Map<String, dynamic>).entries)
              e.key: PlayerId(e.value as String),
          },
          event: ContentHistoryEntry(
            eventId: id,
            kind: ContentKind.rule,
            contentId: id,
            timestampUtc: DateTime.utc(2026, 10, 27),
          ),
        );
      }
      final initial = RuleState(
        selection: SelectionState(
          history: ContentHistory([]),
          counts: _counts(c['counts']),
          assignments: assignments,
        ),
        activations: assignments,
      );
      final engine = DrinkingRules(
        rules: rules,
        mode: GameMode.sharedPhone,
        random: random,
        clock: () => DateTime.utc(2026, 10, 27),
      );
      final state = engine.rebind(state: initial, activePlayers: players);
      return {
        'activeRules': state.active.map(_assignment).toList(),
        'counts': _countJson(state.selection.counts),
      };
    default:
      throw StateError('Unknown parity operation');
  }
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) {
    return value.map(_canonical).toList();
  }
  return value;
}

String canonicalParity(Object? value) => jsonEncode(_canonical(value));
void verifyParity(Map<String, dynamic> c) {
  final actual = canonicalParity(evaluateParity(c)),
      expected = canonicalParity(c['expected']);
  if (actual != expected) {
    throw StateError('${c['id']}: expected $expected, actual $actual');
  }
}

List<Map<String, dynamic>> loadParity([String path = parityPath]) =>
    ((jsonDecode(File(path).readAsStringSync())
                as Map<String, dynamic>)['cases']
            as List<dynamic>)
        .cast<Map<String, dynamic>>();
void main(List<String> args) {
  final cases = loadParity(args.isEmpty ? parityPath : args.single);
  for (final c in cases) {
    verifyParity(c);
  }
  stdout.writeln('Dart parity: ${cases.length} shared domain fixtures passed.');
}
