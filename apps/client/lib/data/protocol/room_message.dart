import 'dart:convert';

import 'package:characters/characters.dart';

import '../../domain/models/ids.dart';
part 'room_message.g.dart';

final Map<String, int> roomProtocolLimits = Map.unmodifiable(
  (_protocolMetadata['limits'] as Map).cast<String, int>(),
);

final class ProtocolDecodeException implements Exception {
  const ProtocolDecodeException(this.code);
  final String code;
  @override
  String toString() => code;
}

abstract class JsonDto {
  JsonDto._(this._json);
  final Map<String, Object?> _json;
  bool contains(String field) => _json.containsKey(field);
  Map<String, Object?> toJson() =>
      jsonDecode(jsonEncode(_json)) as Map<String, Object?>;
}

sealed class RoomMessage extends JsonDto {
  RoomMessage._(super.json) : super._();
  String get type;
  int get protocolVersion;
  String toWire({bool logical = false}) {
    final raw = jsonEncode(_json);
    decodeRoomMessage(raw, logical: logical);
    return raw;
  }
}

Never _fail([String code = 'INVALID_MESSAGE']) =>
    throw ProtocolDecodeException(code);

Object? _wireValue(Object? value) {
  if (value is Identifier) return value.value;
  if (value is JsonDto) return value.toJson();
  if (value is List) return value.map(_wireValue).toList();
  if (value is Map) {
    return value.map((key, child) => MapEntry(key, _wireValue(child)));
  }
  return value;
}

String _dtoWire(Map<String, Object?> json) {
  try {
    return jsonEncode(json);
  } on JsonUnsupportedObjectError {
    _fail();
  }
}

Object? _normalize(Object? value, {bool freeze = false, int depth = 0}) {
  if (depth > ((_protocolMetadata['limits'] as Map)['jsonDepth'] as int)) {
    _fail();
  }
  if (value is Map) {
    final map = <String, Object?>{
      for (final entry in value.entries)
        entry.key as String: _normalize(
          entry.value,
          freeze: freeze,
          depth: depth + 1,
        ),
    };
    return freeze ? Map<String, Object?>.unmodifiable(map) : map;
  }
  if (value is List) {
    final list = value
        .map((v) => _normalize(v, freeze: freeze, depth: depth + 1))
        .toList();
    return freeze ? List<Object?>.unmodifiable(list) : list;
  }
  if (value is double &&
      value.isFinite &&
      value.abs() <= 9007199254740991 &&
      value == value.truncateToDouble()) {
    return value.toInt();
  }
  return value;
}

void _checkProfile(Object? value) {
  if (value is! Map) return;
  final name = value['name'];
  if (name is String) {
    for (var i = 0; i < name.codeUnits.length; i++) {
      final unit = name.codeUnitAt(i);
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++i >= name.length ||
            name.codeUnitAt(i) < 0xdc00 ||
            name.codeUnitAt(i) > 0xdfff) {
          _fail('INVALID_NAME');
        }
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        _fail('INVALID_NAME');
      }
    }
    if (name != name.trim() ||
        name.characters.isEmpty ||
        name.characters.length > 24 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      _fail('INVALID_NAME');
    }
  }
  final avatar = value['avatar'];
  if (avatar is Map &&
      avatar.containsKey('version') &&
      avatar['version'] != currentAvatarVersion) {
    _fail('AVATAR_MISMATCH');
  }
}

void _checkTree(Object? value, [String key = '']) {
  if (value is List) {
    for (final item in value) {
      _checkTree(item, key);
    }
    return;
  }
  if (value is! Map) return;
  if (key == 'question' &&
      value['contentId'] is String &&
      !(_protocolMetadata['questionIds'] as List).contains(
        value['contentId'],
      )) {
    _fail();
  }
  if (key == 'activeRules' &&
      value['contentId'] is String &&
      !(_protocolMetadata['ruleIds'] as List).contains(value['contentId'])) {
    _fail();
  }
  if (value['kind'] == 'question' || value['kind'] == 'rule') {
    final known =
        _protocolMetadata[value['kind'] == 'question'
                ? 'questionIds'
                : 'ruleIds']
            as List;
    if (!known.contains(value['contentId'])) _fail();
  }
  for (final entry in value.entries) {
    final field = entry.key as String, child = entry.value;
    if ((field == 'timestampUtc' || field == 'expiresAtUtc') &&
        child is String) {
      final time = DateTime.tryParse(child);
      if (time == null || time.toUtc().toIso8601String() != child) _fail();
    }
    _checkTree(child, field);
  }
}

void _canonicalBase64(String value, int limit, String code) {
  try {
    final bytes = base64Url.decode(base64Url.normalize(value));
    if (bytes.length > limit ||
        base64Url.encode(bytes).replaceAll('=', '') != value) {
      _fail(code);
    }
  } on FormatException {
    _fail(code);
  }
}

Map<String, Object?> _validateDto(String name, Map<String, Object?> json) {
  final value = _normalize(json) as Map<String, Object?>;
  if (name == 'profile') _checkProfile(value);
  try {
    _validate(value, {r'$ref': '#/\$defs/$name'});
  } on _Mismatch {
    _fail();
  }
  _checkTree(value);
  return _normalize(value, freeze: true) as Map<String, Object?>;
}

void _checkDepth(String raw) {
  var depth = 0, quoted = false, escaped = false;
  final limit = (_protocolMetadata['limits'] as Map)['jsonDepth'] as int;
  for (final unit in raw.codeUnits) {
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (unit == 92) {
        escaped = true;
      } else if (unit == 34) {
        quoted = false;
      }
    } else if (unit == 34) {
      quoted = true;
    } else if (unit == 123 || unit == 91) {
      if (++depth > limit) _fail();
    } else if (unit == 125 || unit == 93) {
      depth--;
    }
  }
}

RoomMessage decodeRoomMessage(
  String raw, {
  String catalogHash = _currentCatalogHash,
  String? direction,
  bool logical = false,
}) {
  final limit =
      (_protocolMetadata['limits'] as Map)[logical
              ? 'projectionBytes'
              : 'frameBytes']
          as int;
  if (utf8.encode(raw).length > limit) _fail('MESSAGE_TOO_LARGE');
  _checkDepth(raw);
  Object? decoded;
  try {
    decoded = _normalize(jsonDecode(raw));
  } on FormatException {
    _fail('INVALID_JSON');
  }
  if (decoded is! Map<String, Object?>) _fail();
  if (decoded['protocolVersion'] != 2) _fail('PROTOCOL_MISMATCH');
  final handshake = decoded['handshake'];
  if (handshake is Map) {
    if (handshake['protocolVersion'] != 2) _fail('PROTOCOL_MISMATCH');
    if (handshake.containsKey('avatarVersion') &&
        handshake['avatarVersion'] != currentAvatarVersion) {
      _fail('AVATAR_MISMATCH');
    }
  }
  _checkProfile(decoded['profile']);
  for (final view in [decoded['public'], decoded['publicChanges']]) {
    if (view is Map && view['players'] is List) {
      for (final player in view['players'] as List) {
        if (player is Map) _checkProfile(player['profile']);
      }
    }
  }
  try {
    _validate(decoded, _roomSchema);
  } on _Mismatch {
    _fail();
  }
  if (handshake is Map && handshake['catalogHash'] != catalogHash) {
    _fail('CATALOG_MISMATCH');
  }
  if (decoded['resumeToken'] is String) {
    _canonicalBase64(
      decoded['resumeToken'] as String,
      32,
      'CREDENTIAL_INVALID',
    );
  }
  if (decoded['type'] == 'projectionChunk') {
    _canonicalBase64(
      decoded['data'] as String,
      (_protocolMetadata['limits'] as Map)['projectionChunkBytes'] as int,
      'INVALID_MESSAGE',
    );
  }
  const serverTypes = {
    'credential',
    'authenticated',
    'historyStatus',
    'historyEvents',
    'ack',
    'error',
    'sessionReplaced',
    'roomClosed',
    'pong',
    'snapshot',
    'delta',
    'projectionStart',
    'projectionChunk',
    'projectionEnd',
  };
  if (direction != null &&
      (serverTypes.contains(decoded['type']) ? 'server' : 'client') !=
          direction) {
    _fail();
  }
  _checkTree(decoded);
  return _messageFromValidated(
    _normalize(decoded, freeze: true) as Map<String, Object?>,
  );
}

final class _Mismatch implements Exception {}

Never _mismatch() => throw _Mismatch();
void _validate(Object? value, Map schema) {
  const supported = {
    r'$schema',
    r'$id',
    r'$defs',
    r'$ref',
    'title',
    'description',
    'type',
    'const',
    'enum',
    'required',
    'properties',
    'additionalProperties',
    'propertyNames',
    'items',
    'minItems',
    'maxItems',
    'uniqueItems',
    'minLength',
    'maxLength',
    'pattern',
    'minimum',
    'maximum',
    'maxProperties',
    'oneOf',
  };
  if (schema.keys.any((key) => !supported.contains(key))) {
    throw StateError('Unsupported schema keyword');
  }
  if (schema[r'$ref'] is String) {
    final ref = schema[r'$ref'] as String;
    if (!ref.startsWith(r'#/$defs/')) {
      throw StateError('Unsupported schema reference');
    }
    final target = (_roomSchema[r'$defs'] as Map)[ref.substring(8)];
    if (target is! Map) throw StateError('Unknown schema reference');
    _validate(value, target);
  }
  if (schema['oneOf'] is List) {
    var matches = 0;
    for (final alternative in schema['oneOf'] as List) {
      try {
        _validate(value, alternative as Map);
        matches++;
      } on _Mismatch {
        /* Try the next alternative. */
      }
    }
    if (matches != 1) _mismatch();
  }
  if (schema.containsKey('const') && value != schema['const']) _mismatch();
  if (schema['enum'] is List && !(schema['enum'] as List).contains(value)) {
    _mismatch();
  }
  final valid = switch (schema['type']) {
    null => true,
    'object' => value is Map,
    'array' => value is List,
    'string' => value is String,
    'integer' => value is int && value.abs() <= 9007199254740991,
    'boolean' => value is bool,
    _ => throw StateError('Unsupported schema type'),
  };
  if (!valid) _mismatch();
  if (value is String) {
    if (schema['minLength'] is int &&
        value.runes.length < (schema['minLength'] as int)) {
      _mismatch();
    }
    if (schema['maxLength'] is int &&
        value.runes.length > (schema['maxLength'] as int)) {
      _mismatch();
    }
    if (schema['pattern'] is String &&
        !RegExp(schema['pattern'] as String, unicode: true).hasMatch(value)) {
      _mismatch();
    }
  }
  if (value is num) {
    if (schema['minimum'] is num && value < (schema['minimum'] as num)) {
      _mismatch();
    }
    if (schema['maximum'] is num && value > (schema['maximum'] as num)) {
      _mismatch();
    }
  }
  if (value is List) {
    if (schema['minItems'] is int &&
        value.length < (schema['minItems'] as int)) {
      _mismatch();
    }
    if (schema['maxItems'] is int &&
        value.length > (schema['maxItems'] as int)) {
      _mismatch();
    }
    if (schema['uniqueItems'] == true &&
        value.map(_canonical).toSet().length != value.length) {
      _mismatch();
    }
    if (schema['items'] is Map) {
      for (final child in value) {
        _validate(child, schema['items'] as Map);
      }
    }
  }
  if (value is Map) {
    if (schema['maxProperties'] is int &&
        value.length > (schema['maxProperties'] as int)) {
      _mismatch();
    }
    for (final field in (schema['required'] as List? ?? const [])) {
      if (!value.containsKey(field)) _mismatch();
    }
    final properties = schema['properties'] as Map? ?? const {};
    for (final entry in value.entries) {
      if (schema['propertyNames'] is Map) {
        _validate(entry.key, schema['propertyNames'] as Map);
      }
      if (properties.containsKey(entry.key)) {
        _validate(entry.value, properties[entry.key] as Map);
      } else if (schema['additionalProperties'] == false) {
        _mismatch();
      } else if (schema['additionalProperties'] is Map) {
        _validate(entry.value, schema['additionalProperties'] as Map);
      }
    }
  }
}

String _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
  }
  if (value is List) return '[${value.map(_canonical).join(',')}]';
  return jsonEncode(value);
}
