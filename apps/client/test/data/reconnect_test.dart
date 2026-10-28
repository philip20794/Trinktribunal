import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/online_order_controller.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import '../application/online_order_controller_test.dart' show orderingView;
import 'room_test_support.dart';

void main() {
  test('catalog mismatch stops retry without discarding the saved identity for an update', () {
    fakeAsync((clock) {
      final backend = MemoryCredentialBackend(),
          transport = FakeRoomTransport();
      final store = RoomCredentialStore(backend);
      final room = RoomController(transport: transport, credentials: store);
      unawaited(store.save(testCredential()));
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      transport.sockets.last.receive(
        ErrorMessage.create(
          requestId: RequestId('catalog'),
          code: 'CATALOG_MISMATCH',
        ),
      );
      clock.flushMicrotasks();
      clock.elapse(const Duration(minutes: 1));
      clock.flushMicrotasks();
      expect(room.state.errorCode, 'CATALOG_MISMATCH');
      expect(room.state.snapshot, isNull);
      expect(backend.records, hasLength(1));
      expect(transport.connections, 1);
      expect(transport.joins, 0);
      unawaited(room.dispose());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
  for (final sameRound in [true, false]) {
    test('outage restores a draft only for the same round: $sameRound', () {
      fakeAsync((clock) {
        final transport = FakeRoomTransport();
        final room = RoomController(
          transport: transport,
          credentials: RoomCredentialStore(MemoryCredentialBackend()),
          jitter: () => 0.5,
        );
        final order = OnlineOrderController(room);
        unawaited(room.resume(testCredential()));
        clock.flushMicrotasks();
        transport.sockets.last.receive(roomFixture('authenticated'));
        transport.sockets.last.receive(orderingView());
        clock.flushMicrotasks();
        order.move(0, 2);
        expect(order.order.map((id) => id.value), ['p3', 'p4', 'p1']);
        unawaited(transport.sockets.last.disconnect());
        clock.flushMicrotasks();
        expect(order.order, isEmpty);
        expect(order.canEdit, isFalse);
        clock.elapse(const Duration(milliseconds: 250));
        clock.flushMicrotasks();
        final next = transport.sockets.last;
        next.receive(roomFixture('authenticated'));
        final original = orderingView(revision: 20);
        next.receive(
          SnapshotMessage.fromJson({
            ...original.toJson(),
            'public': {
              ...original.public.toJson(),
              if (!sameRound) 'roundId': 'new-round',
            },
          }),
        );
        clock.flushMicrotasks();
        expect(
          order.order.map((id) => id.value),
          sameRound ? ['p3', 'p4', 'p1'] : ['p1', 'p3', 'p4'],
        );
        expect(order.canEdit, isTrue);
        expect(next.sent.whereType<SubmitOrderMessage>(), isEmpty);
        order.dispose();
        unawaited(room.dispose());
        clock.flushMicrotasks();
        expect(clock.pendingTimers, isEmpty);
      });
    });
  }

  test(
    'fresh store/controller resumes the persisted identity without a join',
    () async {
      final backend = MemoryCredentialBackend();
      final initial = RoomCredentialStore(backend);
      final credential = testCredential();
      await initial.save(credential);
      final reloaded = await RoomCredentialStore(
        backend,
        clock: () => DateTime.parse(credential.message.expiresAtUtc),
      ).load();
      expect(
        reloaded.credentials.single.message.playerId,
        credential.message.playerId,
      );
      final transport = FakeRoomTransport();
      final room = RoomController(
        transport: transport,
        credentials: RoomCredentialStore(backend),
      );
      await room.resume(reloaded.credentials.single);
      await Future<void>.delayed(Duration.zero);
      transport.sockets.last.accepted();
      await Future<void>.delayed(Duration.zero);
      expect(room.state.status, RoomConnectionStatus.online);
      expect(room.state.snapshot!.you, credential.message.playerId);
      expect(room.state.ownNumberRevealed, isFalse);
      expect(transport.joins + transport.creates, 0);
      await room.dispose();
      expect(backend.records, hasLength(1));
    },
  );

  test(
    'an unrelated late close ACK cannot delete the active stored identity',
    () {
      fakeAsync((clock) {
        final backend = MemoryCredentialBackend();
        final store = RoomCredentialStore(backend);
        final transport = FakeRoomTransport();
        final room = RoomController(transport: transport, credentials: store);
        unawaited(store.save(testCredential()));
        unawaited(room.resume(testCredential()));
        clock.flushMicrotasks();
        transport.sockets.last.accepted();
        clock.flushMicrotasks();
        transport.sockets.last.receive(
          AckMessage.create(
            requestId: RequestId('old-ack'),
            actionId: ActionId('forgotten-close'),
            revision: 0,
            outcome: 'closed',
          ),
        );
        clock.flushMicrotasks();
        expect(room.state.status, RoomConnectionStatus.online);
        expect(backend.records, hasLength(1));
        unawaited(room.dispose());
        clock.flushMicrotasks();
      });
    },
  );
}
