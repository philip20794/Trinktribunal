import 'models/domain_error.dart';
import 'models/ids.dart';
import 'selection/random_source.dart';

/// An immutable per-case assignment. Rebuild/resume reads it without drawing.
final class NumberAssignment {
  NumberAssignment._(this.roundId, Map<PlayerId, int> numbers)
    : numbers = Map.unmodifiable(numbers);
  final RoundId roundId;
  final Map<PlayerId, int> numbers;

  factory NumberAssignment.draw({
    required RoundId roundId,
    required List<PlayerId> roster,
    required PlayerId judgeId,
    required int maxSecretNumber,
    required bool allJudges,
    required RandomSource random,
  }) {
    if (roster.length < 3 ||
        roster.length > 20 ||
        roster.toSet().length != roster.length ||
        !roster.contains(judgeId)) {
      throw const DomainException(
        DomainErrorCode.invalidState,
        'Ungültiger Teilnehmerstand oder Richter.',
      );
    }
    final recipients = roster
        .where((id) => allJudges || id != judgeId)
        .toList();
    if (maxSecretNumber < recipients.length || maxSecretNumber > 60) {
      throw const DomainException(
        DomainErrorCode.invalidConfig,
        'Der Zahlenbereich reicht nicht für alle Empfänger.',
      );
    }
    final remaining = List.generate(maxSecretNumber, (index) => index + 1);
    final numbers = <PlayerId, int>{};
    for (final id in recipients) {
      final value = choose(remaining, random);
      numbers[id] = value;
      remaining.remove(value);
    }
    return NumberAssignment._(roundId, numbers);
  }
}
