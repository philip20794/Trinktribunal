import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/models/ids.dart';
import 'protocol/room_message.dart';
import 'room_credential_store.dart';

String newRoomRequestId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

Handshake get currentRoomHandshake => Handshake.fromJson({
  'protocolVersion': 2,
  'catalogHash': currentProtocolCatalogHash,
  'avatarVersion': currentAvatarVersion,
});
String normalizedRoomCode(String raw) {
  if (raw.length > 64) throw const ProtocolDecodeException('INVALID_ROOM_CODE');
  final code = raw.trim().replaceAll(RegExp('[ -]'), '').toUpperCase();
  if (!RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$').hasMatch(code)) {
    throw const ProtocolDecodeException('INVALID_ROOM_CODE');
  }
  return code;
}

final class RoomTransportException implements Exception {
  const RoomTransportException(this.code, {this.status});
  final String code;
  final int? status;
  @override
  String toString() => code;
}

abstract interface class RoomSocket {
  Future<void> get ready;
  Stream<Object?> get messages;
  int? get closeCode;
  void send(RoomMessage message);
  Future<void> close();
}

abstract interface class RoomTransport {
  Uri get serverOrigin;
  Future<CredentialMessage> create(Profile profile);
  Future<CredentialMessage> join(String code, Profile profile);
  Future<AckMessage> leave(RoomCredential credential, ActionId actionId);
  Future<RoomSocket> connect(RoomCredential credential);
  void dispose();
}

final class NetworkRoomTransport implements RoomTransport {
  NetworkRoomTransport(Uri origin, {http.Client? client})
    : serverOrigin = roomServerOrigin(origin.toString()),
      _client = client ?? http.Client();
  @override
  final Uri serverOrigin;
  final http.Client _client;
  Future<RoomMessage> _post(String path, RoomMessage message) async {
    try {
      final request = http.Request('POST', serverOrigin.resolve(path))
        ..headers['Content-Type'] = 'application/json'
        ..body = message.toWire();
      // Credentials may not follow a redirect to another server.
      request.followRedirects = false;
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 10));
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 10),
      )) {
        if (bytes.length + chunk.length > 16384) {
          throw const RoomTransportException('MESSAGE_TOO_LARGE');
        }
        bytes.addAll(chunk);
      }
      final decoded = decodeRoomMessage(
        utf8.decode(bytes),
        direction: 'server',
      );
      if (decoded is ErrorMessage) {
        throw RoomTransportException(decoded.code, status: response.statusCode);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const RoomTransportException('INVALID_RESPONSE');
      }
      return decoded;
    } on RoomTransportException {
      rethrow;
    } on ProtocolDecodeException {
      throw const RoomTransportException('INVALID_RESPONSE');
    } on Object {
      throw const RoomTransportException('NETWORK_UNAVAILABLE');
    }
  }

  @override
  Future<CredentialMessage> create(Profile profile) async {
    final result = await _post(
      '/api/rooms',
      CreateMessage.create(
        requestId: RequestId(newRoomRequestId()),
        profile: profile,
        handshake: currentRoomHandshake,
      ),
    );
    if (result is! CredentialMessage) {
      throw const RoomTransportException('INVALID_RESPONSE');
    }
    return result;
  }

  @override
  Future<CredentialMessage> join(String code, Profile profile) async {
    final normalized = normalizedRoomCode(code);
    final result = await _post(
      '/api/rooms/$normalized/join',
      JoinMessage.create(
        requestId: RequestId(newRoomRequestId()),
        profile: profile,
        handshake: currentRoomHandshake,
      ),
    );
    if (result is! CredentialMessage || result.roomCode != normalized) {
      throw const RoomTransportException('INVALID_RESPONSE');
    }
    return result;
  }

  void _bound(RoomCredential credential) {
    if (credential.serverOrigin != serverOrigin) {
      throw const RoomTransportException('WRONG_SERVER');
    }
  }

  @override
  Future<AckMessage> leave(RoomCredential credential, ActionId actionId) async {
    _bound(credential);
    final result = await _post(
      '/api/rooms/${credential.message.roomCode}/leave',
      LeaveHttpMessage.create(
        requestId: RequestId(newRoomRequestId()),
        resumeToken: credential.message.resumeToken,
        actionId: actionId,
        confirmed: true,
      ),
    );
    if (result is! AckMessage ||
        result.actionId != actionId ||
        result.outcome != 'left') {
      throw const RoomTransportException('INVALID_RESPONSE');
    }
    return result;
  }

  @override
  Future<RoomSocket> connect(RoomCredential credential) async {
    _bound(credential);
    final uri = serverOrigin.replace(
      scheme: serverOrigin.scheme == 'https' ? 'wss' : 'ws',
      path: '/api/rooms/${credential.message.roomCode}/socket',
    );
    return _ChannelSocket(WebSocketChannel.connect(uri));
  }

  @override
  void dispose() => _client.close();
}

final class _ChannelSocket implements RoomSocket {
  _ChannelSocket(this.channel);
  final WebSocketChannel channel;
  @override
  Future<void> get ready => channel.ready;
  @override
  Stream<Object?> get messages => channel.stream;
  @override
  int? get closeCode => channel.closeCode;
  @override
  void send(RoomMessage message) => channel.sink.add(message.toWire());
  @override
  Future<void> close() async {
    await channel.sink.close(1000);
  }
}
