import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import 'room_test_support.dart';

void main() {
  test('reopening retains multiple room/player/origin keys and removes just the selected identity', () async {
    final backend = MemoryCredentialBackend(),
        store = RoomCredentialStore(backend),
        first = testCredential();
    final second = RoomCredential(
      serverOrigin: first.serverOrigin,
      message: CredentialMessage.fromJson({
        ...first.message.toJson(),
        'playerId': 'another',
      }),
    );
    final third = RoomCredential(
      serverOrigin: Uri.parse('https://another.example'),
      message: first.message,
    );
    await Future.wait([
      store.save(first),
      store.save(second),
      store.save(third),
    ]);
    final reopened = RoomCredentialStore(backend);
    expect((await reopened.load()).credentials, hasLength(3));
    await reopened.remove(second);
    final remaining = (await reopened.load()).credentials;
    expect(
      remaining.map((c) => c.key),
      unorderedEquals([first.key, third.key]),
    );
    expect(first.toString(), isNot(contains(first.message.resumeToken)));
  });
  test('old local expiry remains resumable; pending leave survives a process restart with its action ID', () async {
    final backend = MemoryCredentialBackend(),
        store = RoomCredentialStore(backend),
        credential = testCredential().leaving(ActionId('leave_intent'));
    await store.save(credential);
    final saved = (await RoomCredentialStore(
      backend,
    ).load()).credentials.single;
    expect(
      DateTime.parse(saved.message.expiresAtUtc).isBefore(DateTime(2030)),
      isTrue,
    );
    expect(saved.message.playerId, credential.message.playerId);
    expect(saved.pendingLeaveActionId, ActionId('leave_intent'));
    expect(saved.message.resumeToken, credential.message.resumeToken);
  });
  test('corrupt/foreign-key records are skipped; blocked storage masks platform errors', () async {
    final backend = MemoryCredentialBackend(),
        store = RoomCredentialStore(backend);
    await store.save(testCredential());
    backend.records['corrupt'] = '{';
    backend.records['mismatched'] = backend.records.values.first;
    final loaded = await store.load();
    expect(loaded.credentials, hasLength(1));
    expect(loaded.invalidRecords, isTrue);
    backend.fail = true;
    expect((await store.load()).unavailable, isTrue);
    await expectLater(
      store.save(testCredential()),
      throwsA(isA<CredentialStorageException>()),
    );
    await expectLater(
      store.remove(testCredential()),
      throwsA(isA<CredentialStorageException>()),
    );
  });
  test('storage format is closed and remains separate from profiles and offline state', () async {
    final backend = MemoryCredentialBackend(),
        store = RoomCredentialStore(backend);
    await store.save(testCredential());
    final key = backend.records.keys.single,
        json =
            jsonDecode(backend.records.values.single) as Map<String, dynamic>;
    expect(
      json.keys,
      containsAll([
        'formatVersion',
        'serverOrigin',
        'roomId',
        'roomCode',
        'playerId',
        'resumeToken',
        'expiresAtUtc',
      ]),
    );
    backend.records[key] = jsonEncode({
      ...json,
      'profile': {'name': 'untrusted'},
    });
    expect((await store.load()).credentials, isEmpty);
    expect((await store.load()).invalidRecords, isTrue);
  });
  test('origin cannot contain credentials, paths, query tokens or insecure remote hosts', () {
    for (final value in [
      'https://user:pass@example.com',
      'https://example.com/api',
      'https://example.com?token=x',
      'https://example.com#x',
      'http://example.com',
    ]) {
      expect(
        () => roomServerOrigin(value),
        throwsA(isA<ProtocolDecodeException>()),
      );
    }
    expect(
      roomServerOrigin('https://EXAMPLE.com/').origin,
      'https://example.com',
    );
    expect(roomServerOrigin('http://10.0.2.2:8787').host, '10.0.2.2');
  });
}
