import 'models/ids.dart';

PlayerId? nextJudge({
  required List<PlayerId> oldRoster,
  required PlayerId? previous,
  required List<PlayerId> newRoster,
}) {
  if (newRoster.isEmpty) return null;
  if (newRoster.contains(previous)) {
    return newRoster[(newRoster.indexOf(previous!) + 1) % newRoster.length];
  }
  final oldIndex = oldRoster.indexOf(previous ?? newRoster.first);
  if (oldIndex >= 0) {
    for (var offset = 1; offset <= oldRoster.length; offset++) {
      final candidate = oldRoster[(oldIndex + offset) % oldRoster.length];
      if (newRoster.contains(candidate)) return candidate;
    }
  }
  return newRoster.first;
}
