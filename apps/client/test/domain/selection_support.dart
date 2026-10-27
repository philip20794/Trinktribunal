import 'dart:convert';
import 'dart:io';

import 'package:trinktribunal/data/catalogs/catalog.dart';
import 'package:trinktribunal/domain/models/content_history.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/person_selection_counts.dart';
import 'package:trinktribunal/domain/selection/content_selection.dart';
import 'package:trinktribunal/domain/selection/random_source.dart';

final class TestRandom implements RandomSource {
  TestRandom({this.last = false, List<int> indices = const []})
    : indices = List.of(indices);
  final bool last;
  final List<int> indices;
  int calls = 0;
  @override
  int nextInt(int upperBound) {
    calls++;
    return indices.isNotEmpty
        ? indices.removeAt(0)
        : (last ? upperBound - 1 : 0);
  }
}

final now = DateTime.utc(2026, 10, 27, 12);
final players = ['A', 'B', 'C', 'D'].map(PlayerId.new).toList();
SelectionState selection({
  Map<PlayerId, int>? counts,
  ContentHistory? history,
}) => SelectionState(
  history: history ?? ContentHistory([]),
  counts: PersonSelectionCounts(counts ?? {for (final p in players) p: 0}),
);

Map<String, dynamic> questionJson(String id, {Map<String, Object>? roles}) => {
  'id': id,
  'text': roles == null
      ? 'Frage $id'
      : '${roles.keys.map((key) => '{$key}').join(' ')} {player1}',
  'scale': {
    'green': roles == null ? 'grün' : '{player1}',
    'connector': 'bis',
    'red': 'rot',
  },
  'players': ?roles,
};
List<Question> questions(List<Map<String, dynamic>> entries) => parseQuestions(
  jsonEncode({'version': 1, 'language': 'de', 'questions': entries}),
).entries;
List<DrinkingRule> rules(List<Map<String, dynamic>> entries) =>
    parseRules(jsonEncode({'version': 1, 'language': 'de', 'rules': entries}))
        .entries;
Map<String, dynamic> ruleJson(
  String id, {
  Map<String, Object>? roles,
  List<String> excludes = const [],
}) => {
  'id': id,
  'text': roles == null
      ? 'Regel $id'
      : '${roles.keys.map((key) => '{$key}').join(' ')} {player1}',
  'excludes': excludes,
  'players': ?roles,
};
List<Question> actualQuestions([String language = 'de']) => parseQuestions(
  File('assets/catalogs/questions/$language.json').readAsStringSync(),
).entries;
List<DrinkingRule> actualRules() =>
    parseRules(File('assets/catalogs/rules/de.json').readAsStringSync())
        .entries;
