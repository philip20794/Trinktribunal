import '../../data/catalogs/catalog.dart';
import '../models/ids.dart';
import '../models/person_selection_counts.dart';
import 'random_source.dart';

/// Solves the full constraint graph before applying per-role fairness.
final class PersonAssignment {
  PersonAssignment({
    required this.roles,
    required Iterable<PlayerId> activePlayers,
    required this.counts,
    Map<String, PlayerId> fixedBindings = const {},
  }) : activePlayers = List.unmodifiable(activePlayers.toSet()),
       fixedBindings = Map.unmodifiable(fixedBindings);

  final Map<String, PlayerRole> roles;
  final List<PlayerId> activePlayers;
  final PersonSelectionCounts counts;
  final Map<String, PlayerId> fixedBindings;

  bool _allowed(String role, PlayerId id, Map<String, PlayerId> assigned) =>
      assigned.entries.every(
        (other) =>
            other.value != id ||
            !(roles[role]!.differentFrom.contains(other.key) ||
                roles[other.key]!.differentFrom.contains(role)),
      );

  bool _canComplete(List<String> keys, Map<String, PlayerId> assigned) {
    if (assigned.length == keys.length) return true;
    final role = keys.firstWhere((key) => !assigned.containsKey(key));
    for (final id in activePlayers) {
      if (!_allowed(role, id, assigned)) continue;
      assigned[role] = id;
      final possible = _canComplete(keys, assigned);
      assigned.remove(role);
      if (possible) return true;
    }
    return false;
  }

  bool get isPossible {
    if (fixedBindings.keys.any((role) => !roles.containsKey(role)) ||
        fixedBindings.entries.any(
          (entry) =>
              !activePlayers.contains(entry.value) ||
              !_allowed(
                entry.key,
                entry.value,
                {...fixedBindings}..remove(entry.key),
              ),
        )) {
      return false;
    }
    return _canComplete(roles.keys.toList(), Map.of(fixedBindings));
  }

  Map<String, PlayerId>? bind(RandomSource random) {
    final keys = roles.keys.toList();
    final assigned = Map<String, PlayerId>.of(fixedBindings);
    if (!isPossible) return null;
    for (final role in keys) {
      if (assigned.containsKey(role)) continue;
      final feasible = activePlayers.where((id) {
        if (!_allowed(role, id, assigned)) return false;
        assigned[role] = id;
        final possible = _canComplete(keys, assigned);
        assigned.remove(role);
        return possible;
      }).toList();
      final minimum = feasible
          .map(counts.countFor)
          .reduce((a, b) => a < b ? a : b);
      assigned[role] = choose(
        feasible.where((id) => counts.countFor(id) == minimum).toList(),
        random,
      );
    }
    return Map.unmodifiable(assigned);
  }
}
