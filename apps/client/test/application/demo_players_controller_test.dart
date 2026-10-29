import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/demo_players_controller.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/data/room_transport.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import '../data/room_test_support.dart';
import 'online_settings_controller_test.dart' show settingsView;

class DemoTransport implements RoomTransport {
  final inner = FakeRoomTransport();
  bool disposed = false;
  @override
  Uri get serverOrigin => inner.serverOrigin;
  @override
  Future<CredentialMessage> create(Profile profile) => inner.create(profile);
  @override
  Future<CredentialMessage> join(String code, Profile profile) async {
    final credential = await inner.join(code, profile);
    return CredentialMessage.fromJson({
      ...credential.toJson(),
      'playerId': 'demo1',
    });
  }

  @override
  Future<RoomSocket> connect(RoomCredential credential) =>
      inner.connect(credential);
  @override
  Future<AckMessage> leave(RoomCredential credential, ActionId actionId) =>
      inner.leave(credential, actionId);
  @override
  void dispose() {
    disposed = true;
    inner.dispose();
  }
}

SnapshotMessage demoView(String phase, int revision) {
  final base = roomFixture('snapshot') as SnapshotMessage;
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'you': 'demo1',
    'revision': revision,
    'public': {
      ...base.public.toJson(),
      'phase': phase,
      'config': {...base.public.config.toJson(), 'allJudges': true},
      'judgeId': null,
      'readerId': 'p1',
      'frozenRoster': ['p1', 'p2', 'demo1'],
      'players': [
        ...base.public.players.take(2).map((p) => p.toJson()),
        {
          ...base.public.players.last.toJson(),
          'playerId': 'demo1',
          'ready': false,
          'orderSubmitted': false,
        },
      ],
    },
    'private': {'ownNumber': 3},
  });
}

void main() {
  test('one click joins a separate random-profile session, then acknowledges and submits automatically', () async {
    final hostTransport = FakeRoomTransport();
    final hostStore = MemoryCredentialBackend();
    final host = RoomController(
      transport: hostTransport,
      credentials: RoomCredentialStore(hostStore),
    );
    unawaited(host.resume(testCredential()));
    await Future<void>.delayed(Duration.zero);
    hostTransport.sockets.single.receive(roomFixture('authenticated'));
    hostTransport.sockets.single.receive(settingsView());
    await Future<void>.delayed(Duration.zero);
    final transport = DemoTransport();
    final demos = DemoPlayersController(host, createTransport: () => transport);
    final added = demos.add();
    unawaited(demos.add());
    await Future<void>.delayed(Duration.zero);
    expect(transport.inner.joins, 1);
    expect(transport.inner.lastProfile!.name, 'Demo 1');
    expect(transport.inner.lastProfile!.avatar.version, 3);
    expect(demos.adding, isTrue);
    final socket = transport.inner.sockets.single;
    socket.receive(
      AuthenticatedMessage.fromJson({
        ...roomFixture('authenticated').toJson(),
        'playerId': 'demo1',
      }),
    );
    socket.receive(demoView('lobby', 1));
    await Future<void>.delayed(Duration.zero);
    expect(demos.adding, isTrue);
    final hostView = host.state.snapshot!;
    hostTransport.sockets.single.receive(
      SnapshotMessage.fromJson({
        ...hostView.toJson(),
        'revision': 2,
        'public': {
          ...hostView.public.toJson(),
          'players': [
            ...hostView.public.players.map((p) => p.toJson()),
            {
              ...hostView.public.players.last.toJson(),
              'playerId': 'demo1',
              'connected': true,
            },
          ],
        },
      }),
    );
    await added;
    await Future<void>.delayed(Duration.zero);
    expect(demos.adding, isFalse);
    expect(demos.errorCode, isNull);
    socket.receive(demoView('numbers', 2));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(socket.sent.whereType<AcknowledgeNumberMessage>(), hasLength(1));
    socket.receive(demoView('answers', 3));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(socket.sent.whereType<ReadyForOrderingMessage>(), hasLength(1));
    socket.receive(demoView('ordering', 4));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final order = socket.sent.whereType<SubmitOrderMessage>().single;
    expect(
      order.order.map((id) => id.value),
      unorderedEquals(['p1', 'p2', 'demo1']),
    );
    expect(order.confirmed, isTrue);
    // Unrelated/repeated views cannot resubmit an identical action.
    socket.receive(demoView('ordering', 4));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(socket.sent.whereType<SubmitOrderMessage>(), hasLength(1));
    expect(hostStore.records, isEmpty);
    expect(demos.retainedSessions, 1);
    socket.receive(roomFixture('roomClosed'));
    await Future<void>.delayed(Duration.zero);
    expect(demos.retainedSessions, 0);

    demos.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(transport.inner.leaves, 0);
    expect(transport.disposed, isTrue);
    await host.dispose();
    await Future<void>.delayed(Duration.zero);
  });

  test('a failed join reports an error and releases its transport; guests cannot add', () async {
    final hostTransport = FakeRoomTransport();
    final host = RoomController(
      transport: hostTransport,
      credentials: RoomCredentialStore(MemoryCredentialBackend()),
    );
    unawaited(host.resume(testCredential()));
    await Future<void>.delayed(Duration.zero);
    final socket = hostTransport.sockets.single;
    socket.receive(roomFixture('authenticated'));
    socket.receive(settingsView());
    await Future<void>.delayed(Duration.zero);
    final transport = DemoTransport()..inner.entryError = 'ROOM_FULL';
    final demos = DemoPlayersController(host, createTransport: () => transport);
    await demos.add();
    await Future<void>.delayed(Duration.zero);
    expect(demos.errorCode, 'ROOM_FULL');
    expect(demos.adding, isFalse);
    expect(transport.disposed, isTrue);
    socket.receive(settingsView(host: false, revision: 2));
    await Future<void>.delayed(Duration.zero);
    expect(demos.canAdd, isFalse);
    unawaited(demos.add());
    await Future<void>.delayed(Duration.zero);
    expect(transport.inner.joins, 1);
    demos.dispose();
    await host.dispose();
    await Future<void>.delayed(Duration.zero);
  });
}
