import 'domain_error.dart';
import 'ids.dart';

/// Per-game fairness state. Content history belongs to the device/room instead.
final class PersonSelectionCounts {
  PersonSelectionCounts(Map<PlayerId, int> values)
    : values = Map.unmodifiable(values) {
    if (this.values.values.any((count) => count < 0)) {
      throw const DomainException(
        DomainErrorCode.invalidState,
        'Personenzähler dürfen nicht negativ sein.',
      );
    }
  }

  factory PersonSelectionCounts.initial(Iterable<PlayerId> players) =>
      PersonSelectionCounts({for (final id in players) id: 0});

  final Map<PlayerId, int> values;

  int countFor(PlayerId id) {
    final count = values[id];
    if (count == null) {
      throw const DomainException(
        DomainErrorCode.invalidState,
        'Unbekannte Spieler-ID im Personenzähler.',
      );
    }
    return count;
  }

  /// A committed entry increments each distinct referenced person only once.
  PersonSelectionCounts record(Iterable<PlayerId> selected) {
    final next = Map<PlayerId, int>.of(values);
    for (final id in selected.toSet()) {
      next[id] = countFor(id) + 1;
    }
    return PersonSelectionCounts(next);
  }

  /// New/local reactivated IDs start at least at the active maximum.
  /// A credential-based resume must simply retain the existing instance.
  PersonSelectionCounts withParticipant(
    PlayerId id, {
    required Iterable<PlayerId> previouslyActive,
  }) {
    var maximum = 0;
    for (final active in previouslyActive) {
      final count = countFor(active);
      if (count > maximum) maximum = count;
    }
    final previous = values[id] ?? 0;
    return PersonSelectionCounts({
      ...values,
      id: previous > maximum ? previous : maximum,
    });
  }
}
