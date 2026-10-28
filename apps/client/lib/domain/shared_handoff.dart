import 'models/ids.dart';

/// Stable seating order after the judge, with the previous judge first if eligible.
List<PlayerId> handoffRecipients({
  required List<PlayerId> roster,
  required PlayerId judge,
  PlayerId? previousJudge,
}) {
  if (!roster.contains(judge) || roster.toSet().length != roster.length) {
    throw const FormatException('Ungültige Übergabebesetzung');
  }
  final index = roster.indexOf(judge);
  final cyclic = [
    for (var i = 1; i < roster.length; i++) roster[(index + i) % roster.length],
  ];
  return List.unmodifiable([
    if (cyclic.contains(previousJudge)) previousJudge!,
    ...cyclic.where((id) => id != previousJudge),
  ]);
}
