import 'dart:convert';

import '../domain/models/ids.dart';
import 'protocol/room_message.dart';

final class CredentialStorageException implements Exception {
  const CredentialStorageException();
  @override
  String toString() => 'CREDENTIAL_STORAGE_UNAVAILABLE';
}

Uri roomServerOrigin(String value) {
  final uri = Uri.parse(value);
  final loopback = [
    'localhost',
    '127.0.0.1',
    '::1',
    '10.0.2.2',
  ].contains(uri.host);
  if (uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !['', '/'].contains(uri.path) ||
      !(uri.scheme == 'https' || uri.scheme == 'http' && loopback)) {
    throw const ProtocolDecodeException('INVALID_SERVER_ORIGIN');
  }
  return Uri.parse(uri.origin);
}

final class RoomCredential {
  RoomCredential({
    required Uri serverOrigin,
    required this.message,
    this.pendingLeaveActionId,
  }) : serverOrigin = roomServerOrigin(serverOrigin.toString());
  final Uri serverOrigin;
  final CredentialMessage message;
  final ActionId? pendingLeaveActionId;
  String get key => base64Url
      .encode(
        utf8.encode(
          '${serverOrigin.origin}\u0000${message.roomId.value}\u0000${message.playerId.value}',
        ),
      )
      .replaceAll('=', '');
  RoomCredential leaving(ActionId id) => RoomCredential(
    serverOrigin: serverOrigin,
    message: message,
    pendingLeaveActionId: id,
  );
  @override
  String toString() => 'RoomCredential(redacted)';
}

abstract interface class CredentialBackend {
  Future<Map<String, String>> readAll();
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

final class CredentialLoad {
  CredentialLoad(
    Iterable<RoomCredential> credentials, {
    this.unavailable = false,
    this.invalidRecords = false,
  }) : credentials = List.unmodifiable(credentials);
  final List<RoomCredential> credentials;
  final bool unavailable, invalidRecords;
}

final class RoomCredentialStore {
  RoomCredentialStore(this.backend);
  final CredentialBackend backend;
  String _encode(RoomCredential value) => jsonEncode({
    'formatVersion': 1,
    'serverOrigin': value.serverOrigin.origin,
    'roomId': value.message.roomId.value,
    'roomCode': value.message.roomCode,
    'playerId': value.message.playerId.value,
    'resumeToken': value.message.resumeToken,
    'expiresAtUtc': value.message.expiresAtUtc,
    if (value.pendingLeaveActionId != null)
      'pendingLeaveActionId': value.pendingLeaveActionId!.value,
  });
  RoomCredential _decode(String raw) {
    if (utf8.encode(raw).length > 4096) throw const FormatException();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    const fields = {
      'formatVersion',
      'serverOrigin',
      'roomId',
      'roomCode',
      'playerId',
      'resumeToken',
      'expiresAtUtc',
      'pendingLeaveActionId',
    };
    if (json['formatVersion'] != 1 ||
        json.keys.any((key) => !fields.contains(key))) {
      throw const FormatException();
    }
    final message = CredentialMessage.create(
      requestId: RequestId('stored'),
      roomCode: json['roomCode'] as String,
      roomId: RoomId(json['roomId'] as String),
      playerId: PlayerId(json['playerId'] as String),
      resumeToken: json['resumeToken'] as String,
      expiresAtUtc: json['expiresAtUtc'] as String,
    );
    final pending = json['pendingLeaveActionId'];
    if (pending != null &&
        (pending is! String ||
            !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(pending))) {
      throw const FormatException();
    }
    return RoomCredential(
      serverOrigin: roomServerOrigin(json['serverOrigin'] as String),
      message: message,
      pendingLeaveActionId: pending == null
          ? null
          : ActionId(pending as String),
    );
  }

  Future<CredentialLoad> load() async {
    try {
      final records = await backend.readAll(), credentials = <RoomCredential>[];
      var invalid = false;
      for (final entry in records.entries) {
        try {
          final credential = _decode(entry.value);
          if (credential.key != entry.key) throw const FormatException();
          credentials.add(credential);
        } on Object {
          invalid = true;
        }
      }
      // Local expiry is only a hint; the server may have extended an active room.
      return CredentialLoad(credentials, invalidRecords: invalid);
    } on Object {
      return CredentialLoad([], unavailable: true);
    }
  }

  Future<void> save(RoomCredential credential) async {
    try {
      await backend.write(credential.key, _encode(credential));
    } on Object {
      throw const CredentialStorageException();
    }
  }

  Future<void> remove(RoomCredential credential) async {
    try {
      await backend.remove(credential.key);
    } on Object {
      throw const CredentialStorageException();
    }
  }
}
