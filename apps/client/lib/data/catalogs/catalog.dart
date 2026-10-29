import 'dart:convert';

class CatalogFormatException implements Exception {
  const CatalogFormatException(this.message);
  final String message;
  @override
  String toString() => 'Katalogformat: $message';
}

Never _invalid(String message) => throw CatalogFormatException(message);

Map<String, dynamic> _object(dynamic value, String path) {
  if (value is! Map<String, dynamic>) _invalid('$path: Objekt erwartet');
  return value;
}

String _text(dynamic value, String path) {
  if (value is! String || value.trim().isEmpty) {
    _invalid('$path: nichtleerer Text erwartet');
  }
  return value;
}

List<dynamic> _list(dynamic value, String path) {
  if (value is! List) _invalid('$path: Liste erwartet');
  return value;
}

void _keys(
  Map<String, dynamic> value,
  Set<String> required,
  Set<String> optional,
  String path,
) {
  if (!value.keys.toSet().containsAll(required) ||
      value.keys.any(
        (key) => !required.contains(key) && !optional.contains(key),
      )) {
    _invalid('$path: fehlende oder unbekannte Felder');
  }
}

Set<String> _uniqueStrings(dynamic value, String path) {
  final items = _list(value, path).map((e) => _text(e, path)).toList();
  if (items.toSet().length != items.length) _invalid('$path: doppelte Werte');
  return Set.unmodifiable(items);
}

class PlayerRole {
  const PlayerRole._(this.differentFrom);
  final Set<String> differentFrom;
}

class CatalogEntry {
  const CatalogEntry._(this.id, this.text, this.players);
  final String id;
  final String text;
  final Map<String, PlayerRole> players;

  // Bindings are supplied by the domain engine once per case, never drawn here.
  String render(String template, Map<String, String> names) {
    if (!names.keys.toSet().containsAll(players.keys)) {
      _invalid('$id: fehlende gebundene Spielernamen');
    }
    return template.replaceAllMapped(
      RegExp(r'\{(player[1-9][0-9]*)\}'),
      (match) => names[match[1]]!,
    );
  }
}

class Question extends CatalogEntry {
  const Question._(
    super.id,
    super.text,
    super.players,
    this.green,
    this.connector,
    this.red,
  ) : super._();
  final String green;
  final String connector;
  final String red;

  ({String text, String green, String connector, String red}) renderFor(
    Map<String, String> names,
  ) => (
    text: render(text, names),
    green: render(green, names),
    connector: connector,
    red: render(red, names),
  );
}

class DrinkingRule extends CatalogEntry {
  const DrinkingRule._(super.id, super.text, super.players, this.excludes)
    : super._();
  final Set<String> excludes;
}

class Catalog<T extends CatalogEntry> {
  Catalog._(this.language, List<T> entries)
    : entries = List.unmodifiable(entries);
  final String language;
  final List<T> entries;
  late final Map<String, T> byId = Map.unmodifiable({
    for (final entry in entries) entry.id: entry,
  });
  late final List<T> _withoutPlayers = List.unmodifiable(
    entries.where((e) => e.players.isEmpty),
  );
  List<T> get withoutPlayers => _withoutPlayers;
}

Map<String, PlayerRole> _roles(dynamic value, List<String> texts, String path) {
  final roles = value == null
      ? <String, dynamic>{}
      : _object(value, '$path.players');
  if (value != null && roles.isEmpty) {
    _invalid('$path: players weglassen, wenn leer');
  }
  final used = texts
      .expand(
        (text) =>
            RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}')
                .allMatches(text)
                .map((m) => m[1]!),
      )
      .toSet();
  if (used.length != roles.length || !used.containsAll(roles.keys)) {
    _invalid('$path: undefinierte oder ungenutzte Rolle');
  }
  final result = <String, PlayerRole>{};
  for (final entry in roles.entries) {
    if (!RegExp(r'^player[1-9][0-9]*$').hasMatch(entry.key)) {
      _invalid('$path: ungültige Rollen-ID');
    }
    final definition = _object(entry.value, path);
    _keys(definition, {'selection'}, {'differentFrom'}, path);
    if (definition['selection'] != 'random') {
      _invalid('$path: unbekannte Auswahl');
    }
    final different = definition.containsKey('differentFrom')
        ? _uniqueStrings(definition['differentFrom'], path)
        : <String>{};
    if (different.contains(entry.key) ||
        !roles.keys.toSet().containsAll(different)) {
      _invalid('$path: ungültiger Rollenverweis');
    }
    result[entry.key] = PlayerRole._(Set.unmodifiable(different));
  }
  return Map.unmodifiable(result);
}

Catalog<T> _parse<T extends CatalogEntry>(
  String source,
  String kind,
  T Function(Map<String, dynamic>, String) entryParser,
) {
  dynamic decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    _invalid('$kind: ungültiges JSON');
  }
  final data = _object(decoded, kind);
  _keys(data, {'version', 'language', kind}, {}, kind);
  if (data['version'] is! int || data['version'] != 1) {
    _invalid('$kind: nicht unterstützte Version');
  }
  if (!['de', 'en'].contains(data['language'])) {
    _invalid('$kind: unbekannte Sprache');
  }
  final entries = _list(data[kind], kind);
  if (entries.isEmpty) _invalid('$kind: leerer Katalog');
  final parsed = entries
      .map((e) => entryParser(_object(e, kind), data['language'] as String))
      .toList();
  if (parsed.map((e) => e.id).toSet().length != parsed.length) {
    _invalid('$kind: doppelte IDs');
  }
  return Catalog._(data['language'] as String, parsed);
}

Catalog<Question> parseQuestions(String source) => _parse(source, 'questions', (
  entry,
  language,
) {
  _keys(entry, {'id', 'text', 'scale'}, {'players'}, 'question');
  final id = _text(entry['id'], 'question.id');
  if (!RegExp(r'^[0-9]{3}-[ab]$').hasMatch(id)) _invalid('$id: ungültige ID');
  final text = _text(entry['text'], id);
  final scale = _object(entry['scale'], '$id.scale');
  _keys(scale, {'green', 'connector', 'red'}, {}, id);
  final green = _text(scale['green'], id);
  final red = _text(scale['red'], id);
  if (scale['connector'] != (language == 'de' ? 'bis' : 'to')) {
    _invalid('$id: falsches Bindewort');
  }
  final roles = _roles(
    entry.containsKey('players') ? _object(entry['players'], id) : null,
    [text, green, red],
    id,
  );
  return Question._(id, text, roles, green, scale['connector'] as String, red);
});

Catalog<DrinkingRule> parseRules(String source) {
  final catalog = _parse(source, 'rules', (entry, language) {
    _keys(entry, {'id', 'text', 'excludes'}, {'players'}, 'rule');
    final id = _text(entry['id'], 'rule.id');
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(id)) {
      _invalid('$id: ungültige ID');
    }
    final text = _text(entry['text'], id);
    return DrinkingRule._(
      id,
      text,
      _roles(
        entry.containsKey('players') ? _object(entry['players'], id) : null,
        [text],
        id,
      ),
      _uniqueStrings(entry['excludes'], id),
    );
  });
  final byId = {for (final entry in catalog.entries) entry.id: entry};
  for (final entry in catalog.entries) {
    for (final other in entry.excludes) {
      if (other == entry.id ||
          !byId.containsKey(other) ||
          !byId[other]!.excludes.contains(entry.id)) {
        _invalid(
          '${entry.id}: unbekannter, eigener oder nicht gegenseitiger Ausschluss',
        );
      }
    }
  }
  return catalog;
}
