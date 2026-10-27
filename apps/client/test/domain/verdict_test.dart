import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/models/domain_error.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/verdict.dart';

import 'selection_support.dart';

Iterable<List<T>> permutations<T>(List<T> items) sync* {
  if (items.isEmpty) {
    yield [];
    return;
  }
  for (var i = 0; i < items.length; i++) {
    final rest = List<T>.of(items)..removeAt(i);
    for (final tail in permutations(rest)) {
      yield [items[i], ...tail];
    }
  }
}

void main() {
  test(
    'normal verdict counts wrong positions, including gaps and all rotations',
    () {
      final judge = PlayerId('judge');
      for (var n = 2; n <= 6; n++) {
        final ids = List.generate(n, (i) => PlayerId('p$i'));
        final numbers = {for (var i = 0; i < n; i++) ids[i]: 1 + i * 3};
        for (final order in permutations(ids)) {
          final result = normalVerdict(
            judge: judge,
            numbers: numbers,
            proposed: order,
          );
          final incorrect = {
            for (var i = 0; i < n; i++)
              if (order[i] != ids[i]) order[i],
          };
          expect(result.incorrect, incorrect);
          expect(result.errors, isNot(1));
          expect(result.sips[judge], incorrect.length);
          for (final id in ids) {
            expect(
              result.sips[id],
              incorrect.contains(id) ? incorrect.length : 0,
            );
          }
        }
      }
    },
  );
  test('all judges return only own errors: 2/4/0/0', () {
    final a = players[0], b = players[1], c = players[2], d = players[3];
    final result = allJudgesVerdict(
      numbers: {a: 1, b: 4, c: 9, d: 12},
      orders: {
        a: [b, a, c, d],
        b: [b, a, d, c],
        c: [a, b, c, d],
        d: [a, b, c, d],
      },
    );
    expect(result, {a: 2, b: 4, c: 0, d: 0});
    expect(() => result.clear(), throwsUnsupportedError);
  });
  test('invalid orders, duplicate numbers and judge-as-recipient fail', () {
    final numbers = {players[0]: 1, players[1]: 3, players[2]: 9};
    for (final order in [
      players.take(2).toList(),
      [players[0], players[0], players[2]],
      [players[0], players[1], players[3]],
    ]) {
      expect(
        () =>
            normalVerdict(judge: players[3], numbers: numbers, proposed: order),
        throwsA(isA<DomainException>()),
      );
    }
    expect(
      () => normalVerdict(
        judge: players[0],
        numbers: numbers,
        proposed: players.take(3).toList(),
      ),
      throwsA(isA<DomainException>()),
    );
    expect(
      () => normalVerdict(
        judge: players[3],
        numbers: {players[0]: 1, players[1]: 1},
        proposed: players.take(2).toList(),
      ),
      throwsA(isA<DomainException>()),
    );
  });
}
