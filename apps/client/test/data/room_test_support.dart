import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/data/room_transport.dart';
import 'package:trinktribunal/domain/models/ids.dart';

final _credentialExpiry = DateTime.fromMillisecondsSinceEpoch(
  DateTime.now().toUtc().add(const Duration(hours: 6)).millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();
final _fixtures =
    (jsonDecode(
          File('../../packages/protocol/fixtures/messages/room-v2.json')
              .readAsStringSync(),
        ) as Map)['fixtures']
        as List;
RoomMessage roomFixture(String type) {
  final message = decodeRoomMessage(
    jsonEncode(
      (_fixtures.cast<Map>().firstWhere(
        (row) => (row['valid'] as Map)['type'] == type,
      ))['valid'],
    ),
  );
  if (message is CredentialMessage) {
    return CredentialMessage.fromJson({
      ...message.toJson(),
      'expiresAtUtc': _credentialExpiry,
    });
  }
  return message;
}

RoomCredential testCredential() => RoomCredential(
  serverOrigin: Uri.parse('http://localhost:8787'),
  message: roomFixture('credential') as CredentialMessage,
);
Profile testProfile() => (roomFixture('create') as CreateMessage).profile;

final class MemoryCredentialBackend implements CredentialBackend {
  final records = <String, String>{};
  bool fail = false;
  @override
  Future<Map<String, String>> readAll() async {
    if (fail) throw StateError('private-platform-detail');
    return Map.of(records);
  }

  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('private-platform-detail');
    records[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (fail) throw StateError('private-platform-detail');
    records.remove(key);
  }
}

final class FakeRoomSocket implements RoomSocket {
  final incoming = StreamController<Object?>();
  final sent = <RoomMessage>[];
  bool ended = false;
  @override
  int? closeCode;
  @override
  Future<void> get ready => Future.value();
  @override
  Stream<Object?> get messages => incoming.stream;
  @override
  void send(RoomMessage message) {
    if (ended) throw StateError('closed');
    sent.add(message);
  }

  void receive(RoomMessage message) => incoming.add(message.toWire());
  void accepted() {
    receive(roomFixture('authenticated'));
    receive(roomFixture('snapshot'));
  }

  Future<void> disconnect([int code = 1006]) async {
    closeCode = code;
    ended = true;
    await incoming.close();
  }

  @override
  Future<void> close() async {
    if (ended) return;
    ended = true;
    await incoming.close();
  }
}

final class FakeRoomTransport implements RoomTransport {
  final sockets = <FakeRoomSocket>[];
  int creates = 0, joins = 0, leaves = 0, connections = 0;
  final leaveIds = <ActionId>[];
  bool failConnect = false, failLeave = false;
  String? entryError;
  Profile? lastProfile;
  Completer<CredentialMessage>? deferredCreate;
  @override
  Uri get serverOrigin => Uri.parse('http://localhost:8787');
  @override
  Future<CredentialMessage> create(Profile profile) async {
    creates++;
    lastProfile = profile;
    if (entryError != null) throw RoomTransportException(entryError!);
    return deferredCreate == null
        ? testCredential().message
        : await deferredCreate!.future;
  }

  @override
  Future<CredentialMessage> join(String code, Profile profile) async {
    joins++;
    lastProfile = profile;
    if (entryError != null) throw RoomTransportException(entryError!);
    return testCredential().message;
  }

  @override
  Future<AckMessage> leave(RoomCredential credential, ActionId actionId) async {
    leaves++;
    leaveIds.add(actionId);
    if (failLeave) throw const RoomTransportException('NETWORK_UNAVAILABLE');
    return AckMessage.create(
      requestId: RequestId('leave'),
      actionId: actionId,
      revision: 1,
      outcome: 'left',
    );
  }

  @override
  Future<RoomSocket> connect(RoomCredential credential) async {
    connections++;
    if (failConnect) throw const RoomTransportException('NETWORK_UNAVAILABLE');
    final socket = FakeRoomSocket();
    sockets.add(socket);
    return socket;
  }

  @override
  void dispose() {}
}
