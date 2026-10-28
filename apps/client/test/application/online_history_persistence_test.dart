import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/atomic_state_storage.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';

import '../data/room_test_support.dart';
import '../support/memory_atomic_state_storage.dart';

class DelayedStorage implements AtomicStateStorage {
  final storage = MemoryAtomicStateStorage(), read = Completer<void>();
  @override
  Future<List<String>> readCandidates() async {
    await read.future;
    return storage.readCandidates();
  }

  @override
  Future<void> commit(
    String envelope, {
    String? previousValid,
    bool resetBackup = false,
  }) => storage.commit(
    envelope,
    previousValid: previousValid,
    resetBackup: resetBackup,
  );
}

void main() {
  test('provider waits for local restore and durable commit, merges by event ID, and preserves both local modes', () async {
    final catalogs = await CatalogRepository(
          read: (path) => File(path).readAsString(),
        ).load(),
        storage = DelayedStorage(),
        transport = FakeRoomTransport(),
        room = RoomController(
          transport: transport,
          credentials: RoomCredentialStore(MemoryCredentialBackend()),
        ),
        commitStarted = Completer<void>(),
        allowCommit = Completer<void>();
    final time = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();
    storage.storage.primary = jsonEncode({
      'formatVersion': 1,
      'catalogSignature': catalogs.signature,
      'history': [
        {
          'eventId': 'old_draw',
          'kind': 'question',
          'contentId': '003-b',
          'timestampUtc': time,
        },
      ],
      'cards': null,
      'shared': null,
    });
    storage.storage.beforeCommit = () async {
      if (!commitStarted.isCompleted) commitStarted.complete();
      await allowCommit.future;
    };
    final container = ProviderContainer(
      overrides: [
        catalogsProvider.overrideWith((_) async => catalogs),
        atomicStateStorageProvider.overrideWithValue(storage),
        roomControllerProvider.overrideWithValue(room),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await room.dispose();
    });
    container.read(onlineHistoryProvider);
    await room.resume(testCredential());
    final socket = transport.sockets.last;
    socket.accepted();
    await Future<void>.delayed(Duration.zero);
    final source = roomFixture('historyEvents') as HistoryEventsMessage,
        pull = socket.sent.whereType<HistoryPullMessage>().single;
    socket.receive(
      HistoryEventsMessage.fromJson({
        ...source.toJson(),
        'requestId': pull.requestId.value,
        'hasMore': false,
        'events': [
          {
            'eventId': 'online_draw',
            'kind': 'rule',
            'contentId': 'swear_penalty',
            'timestampUtc': time,
          },
        ],
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(socket.sent.whereType<HistoryReceiptMessage>(), isEmpty);
    expect(
      container.read(contentHistoryStoreProvider).history.entries,
      isEmpty,
    );
    storage.read.complete();
    await commitStarted.future;
    expect(socket.sent.whereType<HistoryReceiptMessage>(), isEmpty);
    allowCommit.complete();
    await Future<void>.delayed(Duration.zero);
    expect(socket.sent.whereType<HistoryReceiptMessage>(), hasLength(1));
    final envelope = jsonDecode(storage.storage.primary!) as Map;
    expect((envelope['history'] as List).map((e) => e['eventId']).toSet(), {
      'old_draw',
      'online_draw',
    });
    expect(envelope['cards'], isNull);
    expect(envelope['shared'], isNull);
    // A lost receipt replays the same event after explicit credential resume.
    await room.resume(testCredential());
    final retry = transport.sockets.last;
    retry.accepted();
    await Future<void>.delayed(Duration.zero);
    final next = retry.sent.whereType<HistoryPullMessage>().single;
    retry.receive(
      HistoryEventsMessage.fromJson({
        ...source.toJson(),
        'requestId': next.requestId.value,
        'hasMore': false,
        'events': [
          {
            'eventId': 'online_draw',
            'kind': 'rule',
            'contentId': 'swear_penalty',
            'timestampUtc': time,
          },
        ],
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(retry.sent.whereType<HistoryReceiptMessage>(), hasLength(1));
    expect(
      container.read(contentHistoryStoreProvider).history.entries,
      hasLength(2),
    );
  });
}
