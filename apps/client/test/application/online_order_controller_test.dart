import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/online_order_controller.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';

import '../data/room_test_support.dart';

import 'package:trinktribunal/domain/models/ids.dart';

SnapshotMessage orderingView({
  bool judge = true,
  bool allJudges = false,
  String phase = 'ordering',
  int revision = 1,
  List<String>? ownOrder,
}) {
  final base = roomFixture('snapshot') as SnapshotMessage;
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'revision': revision,
    'public': {
      ...base.public.toJson(),
      'phase': phase,
      'config': {...base.public.config.toJson(), 'allJudges': allJudges},
      'judgeId': judge ? 'p2' : 'p1',
      'hostId': judge ? 'p1' : 'p2',
      'frozenRoster': ['p1', 'p2', 'p3', 'p4'],
      'players': [
        ...base.public.players.map((p) => p.toJson()),
        {...base.public.players.last.toJson(), 'playerId': 'p4'},
      ],
    },
    'private': ownOrder == null ? <String, Object?>{} : {'ownOrder': ownOrder},
  });
}

void main() {
  for (final preparationPhase in ['numbers', 'answers', 'ordering']) {
    test(
      'complete all-judge placement automatically submits from $preparationPhase and recovers stale revisions',
      () {
        fakeAsync((clock) {
          final transport = FakeRoomTransport();
          final room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
          );
          final order = OnlineOrderController(room);
          unawaited(room.resume(testCredential()));
          clock.flushMicrotasks();
          final socket = transport.sockets.single;
          socket.receive(roomFixture('authenticated'));
          socket.receive(
            orderingView(allJudges: true, phase: preparationPhase),
          );
          clock.flushMicrotasks();
          final pool = List<PlayerId>.of(order.unplaced);
          for (var i = 0; i < pool.length - 1; i++) {
            order.place(pool[i], i);
          }
          expect(socket.sent.whereType<SubmitOrderMessage>(), isEmpty);
          order.place(pool.last, pool.length - 1);
          if (preparationPhase != 'ordering') {
            expect(socket.sent.whereType<SubmitOrderMessage>(), isEmpty);
            socket.receive(orderingView(allJudges: true, revision: 2));
            clock.flushMicrotasks();
          }
          expect(order.pending, isTrue);
          expect(order.canEdit, isFalse);
          expect(
            socket.sent.whereType<SubmitOrderMessage>().single.order,
            pool,
          );
          // Another player's simultaneous submission can invalidate our revision.
          socket.receive(
            ErrorMessage.fromJson({
              'type': 'error',
              'protocolVersion': 2,
              'code': 'STALE_REVISION',
              'requestId': 'stale_order',
            }),
          );
          clock.flushMicrotasks();
          expect(socket.sent.whereType<SubmitOrderMessage>(), hasLength(1));
          socket.receive(orderingView(allJudges: true, revision: 3));
          clock.flushMicrotasks();
          expect(socket.sent.whereType<SubmitOrderMessage>(), hasLength(2));
          expect(
            socket.sent.whereType<SubmitOrderMessage>().last.expectedRevision,
            3,
          );
          socket.receive(
            orderingView(
              allJudges: true,
              revision: 4,
              ownOrder: pool.map((p) => p.value).toList(),
            ),
          );
          clock.flushMicrotasks();
          expect(order.confirmed, isTrue);
          expect(order.pending, isFalse);
          socket.receive(
            orderingView(
              allJudges: true,
              revision: 5,
              phase: 'revealing',
              ownOrder: pool.map((p) => p.value).toList(),
            ),
          );
          clock.flushMicrotasks();
          expect(socket.sent.whereType<SubmitOrderMessage>(), hasLength(2));
          order.dispose();
          unawaited(room.dispose());
          clock.flushMicrotasks();
        });
      },
    );
  }
  test('credential reconnect restores only the server-confirmed order and keeps it locked', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
            jitter: () => 0.5,
          ),
          order = OnlineOrderController(room);
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      final snapshot = orderingView(
        phase: 'revealing',
        ownOrder: ['p4', 'p1', 'p3'],
      );
      transport.sockets.last.receive(roomFixture('authenticated'));
      transport.sockets.last.receive(snapshot);
      clock.flushMicrotasks();
      expect(order.confirmed, isTrue);
      unawaited(transport.sockets.last.disconnect(1011));
      clock.flushMicrotasks();
      expect(order.order, isEmpty);
      clock.elapse(const Duration(milliseconds: 250));
      clock.flushMicrotasks();
      transport.sockets.last.receive(roomFixture('authenticated'));
      transport.sockets.last.receive(snapshot);
      clock.flushMicrotasks();
      expect(order.order.map((id) => id.value), ['p4', 'p1', 'p3']);
      expect(order.confirmed, isTrue);
      expect(order.canEdit, isFalse);
      expect(
        transport.sockets.last.sent.whereType<SubmitOrderMessage>(),
        isEmpty,
      );
      order.dispose();
      unawaited(room.dispose());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
  test('100 insertion moves emit no frames; confirmation sends one frozen permutation and locks until echo', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
          ),
          order = OnlineOrderController(room);
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      final socket = transport.sockets.single;
      socket.receive(roomFixture('authenticated'));
      socket.receive(orderingView());
      clock.flushMicrotasks();
      final frames = socket.sent.length;
      for (var i = 0; i < 100; i++) {
        order.move(0, 2);
      }
      expect(socket.sent.length, frames);
      expect(socket.sent.whereType<SubmitOrderMessage>(), isEmpty);
      expect(order.order.map((id) => id.value), ['p3', 'p4', 'p1']);
      socket.receive(orderingView(revision: 2));
      clock.flushMicrotasks();
      expect(order.order.map((id) => id.value), ['p3', 'p4', 'p1']);
      final view = room.state.snapshot!;
      expect(
        order.confirm(
          gameId: view.public.gameId!,
          roundId: view.public.roundId!,
        ),
        isFalse,
      );
      expect(
        order.confirm(
          gameId: view.public.gameId!,
          roundId: view.public.roundId!,
          confirmed: true,
        ),
        isTrue,
      );
      expect(order.canEdit, isFalse);
      expect(order.confirmed, isFalse);
      expect(order.pending, isTrue);
      final sent = socket.sent.whereType<SubmitOrderMessage>().single;
      expect(sent.order.map((id) => id.value), ['p3', 'p4', 'p1']);
      expect(sent.expectedRevision, 2);
      expect(sent.order, isNot(contains(view.public.judgeId)));
      order.move(0, 1);
      expect(order.order, sent.order);
      socket.receive(
        orderingView(
          phase: 'revealing',
          revision: 3,
          ownOrder: ['p3', 'p4', 'p1'],
        ),
      );
      clock.flushMicrotasks();
      expect(order.confirmed, isTrue);
      expect(order.pending, isFalse);
      expect(order.canEdit, isFalse);
      expect(
        order.confirm(
          gameId: view.public.gameId!,
          roundId: view.public.roundId!,
          confirmed: true,
        ),
        isFalse,
      );
      expect(socket.sent.whereType<SubmitOrderMessage>(), hasLength(1));
      order.dispose();
      unawaited(room.dispose());
      clock.flushMicrotasks();
    });
  });
  test('host role alone cannot sort or confirm; a different round invalidates an open confirmation', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
          ),
          order = OnlineOrderController(room);
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      final socket = transport.sockets.single;
      socket.receive(roomFixture('authenticated'));
      socket.receive(orderingView(judge: false));
      clock.flushMicrotasks();
      final old = room.state.snapshot!;
      order.move(0, 1);
      expect(order.order, isEmpty);
      expect(
        order.confirm(
          gameId: old.public.gameId!,
          roundId: old.public.roundId!,
          confirmed: true,
        ),
        isFalse,
      );
      final next = orderingView(revision: 2);
      socket.receive(
        SnapshotMessage.fromJson({
          ...next.toJson(),
          'public': {...next.public.toJson(), 'roundId': 'round_new'},
        }),
      );
      clock.flushMicrotasks();
      expect(order.canEdit, isTrue);
      expect(
        order.confirm(
          gameId: old.public.gameId!,
          roundId: old.public.roundId!,
          confirmed: true,
        ),
        isFalse,
      );
      expect(socket.sent.whereType<SubmitOrderMessage>(), isEmpty);
      order.dispose();
      unawaited(room.dispose());
      clock.flushMicrotasks();
    });
  });
}
