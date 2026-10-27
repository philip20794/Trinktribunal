import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/bench_order.dart';

import 'selection_support.dart';

void main() {
  test('snake index/position roundtrip and incomplete reverse rows', () {
    for (var count = 2; count <= 20; count++) {
      for (final columns in [2, 3]) {
        for (var index = 0; index < count; index++) {
          final position = snakePosition(index, columns);
          expect(snakeIndex(position.row, position.column, columns), index);
        }
      }
    }
    expect(
      [for (var col = 0; col < 3; col++) snakeIndex(1, col, 3)],
      [5, 4, 3],
    );
    expect(snakePosition(3, 3), (row: 1, column: 2));
  });
  test('every insertion retains a complete permutation and never swaps', () {
    for (var from = 0; from < players.length; from++) {
      for (var to = 0; to < players.length; to++) {
        final moved = insertPlayer(players, from, to);
        expect(moved[to], players[from]);
        expect(moved.toSet(), players.toSet());
        expect(
          moved.where((p) => p != players[from]),
          players.where((p) => p != players[from]),
        );
      }
    }
    expect(insertPlayer(players, 0, 2), [
      players[1],
      players[2],
      players[0],
      players[3],
    ]);
  });
}
