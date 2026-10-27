import '../../data/catalogs/catalog.dart';
import '../models/content_history.dart';
import '../models/domain_error.dart';
import '../models/ids.dart';
import '../models/person_selection_counts.dart';
import 'random_source.dart';

T selectContent<T extends CatalogEntry>({
  required List<T> candidates,
  required ContentKind kind,
  required ContentHistory history,
  required DateTime nowUtc,
  required RandomSource random,
}) {
  if (candidates.isEmpty) {
    throw const DomainException(
      DomainErrorCode.contentExhausted,
      'Der geeignete Katalog ist erschöpft.',
    );
  }
  final uses = {
    for (final entry in candidates)
      entry.id: history.recentCount(kind, entry.id, nowUtc),
  };
  final minimum = uses.values.reduce((a, b) => a < b ? a : b);
  return choose(
    candidates.where((entry) => uses[entry.id] == minimum).toList(),
    random,
  );
}

final class ContentAssignment {
  ContentAssignment({
    required this.entry,
    required Map<String, PlayerId> bindings,
    required this.event,
  }) : bindings = Map.unmodifiable(bindings);
  final CatalogEntry entry;
  final Map<String, PlayerId> bindings;
  final ContentHistoryEntry event;

  Map<String, String> names(Map<PlayerId, String> profiles) =>
      Map.unmodifiable({
        for (final binding in bindings.entries)
          binding.key:
              profiles[binding.value] ??
              (throw const DomainException(
                DomainErrorCode.invalidState,
                'Gebundenes Spielerprofil fehlt.',
              )),
      });
}

/// Selection and history form one immutable transaction result. Persistence of
/// this aggregate is added by TT-027; rendering never invokes a draw.
final class SelectionState {
  SelectionState({
    required this.history,
    required this.counts,
    Map<String, ContentAssignment> assignments = const {},
  }) : assignments = Map.unmodifiable(assignments);
  final ContentHistory history;
  final PersonSelectionCounts counts;
  final Map<String, ContentAssignment> assignments;

  Set<String> drawnIds(ContentKind kind) => Set.unmodifiable(
    assignments.values
        .where((a) => a.event.kind == kind)
        .map((a) => a.entry.id),
  );

  SelectionState commit(ContentAssignment assignment) {
    if (assignments.containsKey(assignment.event.eventId) ||
        drawnIds(assignment.event.kind).contains(assignment.entry.id)) {
      throw const DomainException(
        DomainErrorCode.invalidState,
        'Inhalt oder Ereignis bereits gezogen.',
      );
    }
    return SelectionState(
      history: history.record(assignment.event),
      counts: counts.record(assignment.bindings.values),
      assignments: {...assignments, assignment.event.eventId: assignment},
    );
  }

  bool alreadyCommitted(String eventId, ContentKind kind) {
    final previous = assignments[eventId];
    if (previous == null) return false;
    if (previous.event.kind != kind) {
      throw const DomainException(
        DomainErrorCode.invalidState,
        'Ereignis-ID für anderen Aktionstyp verwendet.',
      );
    }
    return true;
  }
}
