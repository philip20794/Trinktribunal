import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/models/domain_error.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/number_assignment.dart';

import 'selection_support.dart';

void main() {
  test(
    'all N/factor/modes draw unique in-range numbers with correct recipients',
    () {
      for (var n = 3; n <= 20; n++) {
        final roster = List.generate(n, (i) => PlayerId('p$i'));
        for (var factor = 10; factor <= 30; factor++) {
          for (final all in [false, true]) {
            for (final last in [false, true]) {
              final max = (n * factor + 9) ~/ 10;
              final assignment = NumberAssignment.draw(
                roundId: RoundId('r'),
                roster: roster,
                judgeId: roster[0],
                maxSecretNumber: max,
                allJudges: all,
                random: TestRandom(last: last),
              );
              expect(assignment.numbers.length, n - (all ? 0 : 1));
              expect(assignment.numbers.containsKey(roster[0]), all);
              expect(
                assignment.numbers.values.toSet().length,
                assignment.numbers.length,
              );
              expect(
                assignment.numbers.values,
                everyElement(inInclusiveRange(1, max)),
              );
            }
          }
        }
      }
    },
  );
  test(
    'synthetic gap fixture, frozen snapshot and invalid participants/bounds',
    () {
      final roster = List.generate(8, (i) => PlayerId('p$i'));
      final random = TestRandom(indices: [0, 1, 2, 3, 4, 5, 5]);
      final assigned = NumberAssignment.draw(
        roundId: RoundId('r'),
        roster: roster,
        judgeId: roster.first,
        maxSecretNumber: 12,
        allJudges: false,
        random: random,
      );
      expect(assigned.numbers.values, [1, 3, 5, 7, 9, 11, 12]);
      final before = Map.of(assigned.numbers);
      roster.clear();
      expect(assigned.numbers, before);
      expect(() => assigned.numbers.clear(), throwsUnsupportedError);
      for (final invalid in [
        players.take(2).toList(),
        [players[0], players[0], players[1]],
      ]) {
        expect(
          () => NumberAssignment.draw(
            roundId: RoundId('bad'),
            roster: invalid,
            judgeId: players.first,
            maxSecretNumber: 12,
            allJudges: false,
            random: TestRandom(),
          ),
          throwsA(isA<DomainException>()),
        );
      }
      expect(
        () => NumberAssignment.draw(
          roundId: RoundId('bad'),
          roster: players,
          judgeId: PlayerId('unknown'),
          maxSecretNumber: 12,
          allJudges: false,
          random: TestRandom(),
        ),
        throwsA(isA<DomainException>()),
      );
      expect(
        () => NumberAssignment.draw(
          roundId: RoundId('bad'),
          roster: players,
          judgeId: players.first,
          maxSecretNumber: 2,
          allJudges: false,
          random: TestRandom(),
        ),
        throwsA(isA<DomainException>()),
      );
    },
  );
}
