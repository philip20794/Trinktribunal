import 'domain_error.dart';

sealed class Identifier {
  Identifier(this.value) {
    if (value.trim().isEmpty || value != value.trim()) {
      throw const DomainException(
        DomainErrorCode.invalidState,
        'Eine ID muss nichtleer sein und darf keine äußeren Leerzeichen haben.',
      );
    }
  }

  final String value;

  @override
  bool operator ==(Object other) =>
      other is Identifier &&
      runtimeType == other.runtimeType &&
      value == other.value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

final class GameId extends Identifier {
  GameId(super.value);
}

final class PlayerId extends Identifier {
  PlayerId(super.value);
}

final class RoundId extends Identifier {
  RoundId(super.value);
}

final class ActionId extends Identifier {
  ActionId(super.value);
}

final class RequestId extends Identifier {
  RequestId(super.value);
}

final class RoomId extends Identifier {
  RoomId(super.value);
}

final class EventId extends Identifier {
  EventId(super.value);
}

final class ImportId extends Identifier {
  ImportId(super.value);
}

final class TransferId extends Identifier {
  TransferId(super.value);
}

final class HistoryCursor extends Identifier {
  HistoryCursor(super.value);
}
