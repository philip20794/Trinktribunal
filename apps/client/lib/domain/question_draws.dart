import 'models/content_history.dart';
import 'selection/content_selection.dart';

/// Explicit case-to-question history: a reroll consumes a draw, never a case.
Map<String, List<String>> freezeQuestionDraws(
  Map<String, List<String>> source,
) => Map.unmodifiable(
  source.map((key, value) => MapEntry(key, List<String>.unmodifiable(value))),
);

Map<String, List<String>> appendQuestionDraw(
  Map<String, List<String>> source,
  String caseId,
  String drawId,
) => freezeQuestionDraws({
  ...source,
  caseId: [...?source[caseId], drawId],
});

bool wasRerolled(Map<String, List<String>> draws, String id) =>
    draws.values.any((ids) => ids.take(ids.length - 1).contains(id));

bool isCompletedQuestion(
  Map<String, List<String>> draws,
  Set<String> completedCases,
  String id,
) => completedCases.any((caseId) => draws[caseId]?.last == id);

Map<String, List<String>> decodeQuestionDraws(
  Object? raw, {
  required String gameId,
  required int completedCases,
  required bool activeCase,
  required SelectionState selection,
}) {
  final expected = {
    for (var i = 1; i <= completedCases + (activeCase ? 1 : 0); i++)
      '$gameId:case:$i',
  };
  final questions = {
    for (final entry in selection.assignments.entries)
      if (entry.value.event.kind == ContentKind.question) entry.key,
  };
  final Map<String, List<String>> draws;
  if (raw == null) {
    // Only the known pre-reroll one-question-per-case shape is additive migration.
    if (questions.length != expected.length ||
        !questions.containsAll(expected)) {
      throw const FormatException('Fragenverbrauch ohne Instanznachweis');
    }
    draws = {
      for (final id in expected) id: [id],
    };
  } else {
    if (raw is! Map<String, dynamic> ||
        raw.length != expected.length ||
        !raw.keys.toSet().containsAll(expected)) {
      throw const FormatException('Ungültige Fall-/Fragenzuordnung');
    }
    draws = {};
    final seen = <String>{};
    for (final entry in raw.entries) {
      final ids = entry.value;
      if (ids is! List || ids.isEmpty || ids.first != entry.key) {
        throw const FormatException('Ungültige Frageninstanzen');
      }
      draws[entry.key] = [];
      for (final id in ids) {
        if (id is! String || !questions.contains(id) || !seen.add(id)) {
          throw const FormatException('Doppelte oder fehlende Frageninstanz');
        }
        draws[entry.key]!.add(id);
      }
    }
    if (seen.length != questions.length) {
      throw const FormatException('Frageninstanz nicht zugeordnet');
    }
  }
  return freezeQuestionDraws(draws);
}
