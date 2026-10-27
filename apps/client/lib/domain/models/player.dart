import 'package:characters/characters.dart';

import 'domain_error.dart';
import 'ids.dart';

final class Player {
  factory Player({required PlayerId id, required String name}) {
    final trimmed = name.trim();
    final count = trimmed.characters.length;
    if (count < 1 || count > 24) {
      throw const DomainException(
        DomainErrorCode.invalidName,
        'Ein Name muss nach dem Trimmen 1 bis 24 sichtbare Zeichen enthalten.',
      );
    }
    return Player._(id, trimmed);
  }

  const Player._(this.id, this.name);
  final PlayerId id;
  final String name;

  Player renamed(String name) => Player(id: id, name: name);
}
