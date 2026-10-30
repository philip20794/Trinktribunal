import 'models/domain_error.dart';
import 'models/ids.dart';

/// Insert into a numbered seat without swapping away the person at that seat.
/// An unplaced person consumes an empty seat; existing people shift in order.
List<PlayerId?> placePlayer(List<PlayerId?> slots, PlayerId id, int index) {
  if (index < 0 ||
      index >= slots.length ||
      slots.whereType<PlayerId>().toSet().length !=
          slots.whereType<PlayerId>().length) {
    throw const DomainException(
      DomainErrorCode.invalidState,
      'Ungültige Sitzposition.',
    );
  }
  final next = List<PlayerId?>.of(slots);
  final previous = next.indexOf(id);
  if (previous >= 0) {
    next.removeAt(previous);
  } else {
    var empty = next.indexOf(null, index);
    if (empty < 0) empty = next.lastIndexOf(null);
    if (empty < 0) return List.unmodifiable(slots);
    next.removeAt(empty);
  }
  next.insert(index, id);
  return List.unmodifiable(next);
}

List<PlayerId> insertPlayer(List<PlayerId> order, int oldIndex, int newIndex) {
  if (oldIndex < 0 ||
      newIndex < 0 ||
      oldIndex >= order.length ||
      newIndex >= order.length ||
      order.toSet().length != order.length) {
    throw const DomainException(
      DomainErrorCode.invalidState,
      'Ungültige Sortierposition.',
    );
  }
  final next = List<PlayerId>.of(order);
  final id = next.removeAt(oldIndex);
  next.insert(newIndex, id);
  return List.unmodifiable(next);
}

/// Positions are zero-based internally; the UI labels them with index+1.
({int row, int column}) snakePosition(int index, int columns) {
  if (index < 0 || (columns != 2 && columns != 3)) {
    throw ArgumentError('Ungültige Bankposition');
  }
  final row = index ~/ columns;
  final column = index % columns;
  return (row: row, column: row.isEven ? column : columns - 1 - column);
}

int snakeIndex(int row, int column, int columns) {
  if (row < 0 ||
      column < 0 ||
      column >= columns ||
      (columns != 2 && columns != 3)) {
    throw ArgumentError('Ungültige Bankposition');
  }
  return row * columns + (row.isEven ? column : columns - 1 - column);
}
