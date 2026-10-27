import '../data/catalogs/catalog.dart';
import 'models/content_history.dart';
import 'models/ids.dart';
import 'models/person_selection_counts.dart';
import 'rules/drinking_rules.dart';
import 'selection/content_selection.dart';

Map<String, Object> encodeHistoryEntry(ContentHistoryEntry entry) => {
  'eventId': entry.eventId,
  'kind': entry.kind.name,
  'contentId': entry.contentId,
  'timestampUtc': entry.timestampUtc.toIso8601String(),
};
ContentHistoryEntry decodeHistoryEntry(Map<String, dynamic> json) =>
    ContentHistoryEntry(
      eventId: json['eventId'] as String,
      kind: ContentKind.values.byName(json['kind'] as String),
      contentId: json['contentId'] as String,
      timestampUtc: DateTime.parse(json['timestampUtc'] as String),
    );

Map<String, Object> encodeAssignment(ContentAssignment assignment) => {
  'event': encodeHistoryEntry(assignment.event),
  'bindings': {
    for (final entry in assignment.bindings.entries)
      entry.key: entry.value.value,
  },
};

ContentAssignment decodeAssignment(
  Map<String, dynamic> json,
  Map<String, Question> questions,
  Map<String, DrinkingRule> rules,
  Set<PlayerId> knownPlayers,
) {
  final event = decodeHistoryEntry(json['event'] as Map<String, dynamic>);
  final CatalogEntry? entry = event.kind == ContentKind.question
      ? questions[event.contentId]
      : rules[event.contentId];
  if (entry == null) throw const FormatException('Unbekannte Inhalts-ID');
  final bindings = (json['bindings'] as Map<String, dynamic>).map(
    (key, value) => MapEntry(key, PlayerId(value as String)),
  );
  if (bindings.length != entry.players.length ||
      !bindings.keys.toSet().containsAll(entry.players.keys) ||
      !knownPlayers.containsAll(bindings.values)) {
    throw const FormatException('Ungültige Rollenbindung');
  }
  for (final role in entry.players.entries) {
    if (role.value.differentFrom.any(
      (other) => bindings[other] == bindings[role.key],
    )) {
      throw const FormatException('Verletzte Rollenrestriktion');
    }
  }
  return ContentAssignment(entry: entry, bindings: bindings, event: event);
}

Map<String, Object> encodeRuleState(RuleState state) => {
  'counts': {
    for (final entry in state.selection.counts.values.entries)
      entry.key.value: entry.value,
  },
  'assignments': state.selection.assignments.values
      .map(encodeAssignment)
      .toList(),
  'activations': state.activations.values.map(encodeAssignment).toList(),
  'inactiveIds': state.inactiveIds.toList(),
  'skippedEvents': state.skippedEvents.toList(),
};

RuleState decodeRuleState(
  Map<String, dynamic> json, {
  required List<Question> questions,
  required List<DrinkingRule> rules,
  required ContentHistory history,
}) {
  final counts = PersonSelectionCounts(
    (json['counts'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(PlayerId(key), value as int),
    ),
  );
  final byQuestion = {for (final q in questions) q.id: q};
  final byRule = {for (final r in rules) r.id: r};
  Map<String, ContentAssignment> assignments(Object? raw) {
    final result = <String, ContentAssignment>{};
    final drawn = <String>{};
    for (final item in raw as List) {
      final parsed = decodeAssignment(
        item as Map<String, dynamic>,
        byQuestion,
        byRule,
        counts.values.keys.toSet(),
      );
      if (result.containsKey(parsed.event.eventId) ||
          !drawn.add('${parsed.event.kind.name}:${parsed.entry.id}')) {
        throw const FormatException('Doppelte Ziehung');
      }
      result[parsed.event.eventId] = parsed;
    }
    return result;
  }

  final selected = assignments(json['assignments']);
  final activated = assignments(json['activations']);
  for (final entry in activated.entries) {
    final original = selected[entry.key];
    if (original == null ||
        original.event.kind != ContentKind.rule ||
        original.entry.id != entry.value.entry.id ||
        original.event.timestampUtc != entry.value.event.timestampUtc) {
      throw const FormatException('Regel ohne passende Ziehung');
    }
  }
  final inactive = (json['inactiveIds'] as List).cast<String>().toSet();
  final skipped = (json['skippedEvents'] as List).cast<String>().toSet();
  if (!activated.values.map((a) => a.entry.id).toSet().containsAll(inactive) ||
      skipped.any(selected.containsKey)) {
    throw const FormatException('Inkonsistenter Regelstatus');
  }
  final state = RuleState(
    selection: SelectionState(
      history: history,
      counts: counts,
      assignments: selected,
    ),
    activations: activated,
    inactiveIds: inactive,
    skippedEvents: skipped,
  );
  final active = state.active;
  for (var i = 0; i < active.length; i++) {
    for (var j = i + 1; j < active.length; j++) {
      if (rulesConflict(
        active[i].entry as DrinkingRule,
        active[j].entry as DrinkingRule,
      )) {
        throw const FormatException('Widersprüchliche aktive Regeln');
      }
    }
  }
  return state;
}
