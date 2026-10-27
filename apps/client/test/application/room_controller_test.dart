import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import '../data/room_test_support.dart';

void main() {
  test(
    'stale round requests current snapshot and drops obsolete pending actions',
    () {
      fakeAsync((clock) {
        final transport = FakeRoomTransport(),
            room = RoomController(
              transport: transport,
              credentials: RoomCredentialStore(MemoryCredentialBackend()),
              jitter: () => 0.5,
            );
        unawaited(room.resume(testCredential()));
        clock.flushMicrotasks();
        final socket = transport.sockets.single;
        socket.accepted();
        clock.flushMicrotasks();
        expect(room.sendAction(roomFixture('submitOrder')), isTrue);
        socket.receive(
          ErrorMessage.create(
            requestId: RequestId('stale'),
            code: 'STALE_ROUND',
          ),
        );
        clock.flushMicrotasks();
        expect(socket.sent.last, isA<RequestSnapshotMessage>());
        expect(room.state.errorCode, 'STALE_ROUND');
        unawaited(socket.disconnect());
        clock.flushMicrotasks();
        clock.elapse(const Duration(milliseconds: 250));
        clock.flushMicrotasks();
        transport.sockets.last.accepted();
        clock.flushMicrotasks();
        expect(transport.sockets.last.sent.map((m) => m.type), [
          'authenticate',
        ]);
        unawaited(room.dispose());
        clock.flushMicrotasks();
        expect(clock.pendingTimers, isEmpty);
      });
    },
  );
  test(
    'a send/close race retains an accepted intention for the same-ID retry',
    () {
      fakeAsync((clock) {
        final transport = FakeRoomTransport(),
            room = RoomController(
              transport: transport,
              credentials: RoomCredentialStore(MemoryCredentialBackend()),
              jitter: () => 0.5,
            );
        unawaited(room.resume(testCredential()));
        clock.flushMicrotasks();
        final socket = transport.sockets.last;
        socket.accepted();
        clock.flushMicrotasks();
        unawaited(socket.disconnect());
        final action = roomFixture('submitOrder');
        expect(room.sendAction(action), isTrue);
        clock.flushMicrotasks();
        expect(room.state.status, RoomConnectionStatus.reconnecting);
        clock.elapse(const Duration(milliseconds: 250));
        clock.flushMicrotasks();
        transport.sockets.last.accepted();
        clock.flushMicrotasks();
        expect(transport.sockets.last.sent.last.toWire(), action.toWire());
        unawaited(room.dispose());
        clock.flushMicrotasks();
        expect(clock.pendingTimers, isEmpty);
      });
    },
  );
  test('resume authenticates existing identity; online requires its own snapshot and numbers stay hidden', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          store = RoomCredentialStore(MemoryCredentialBackend()),
          room = RoomController(
            transport: transport,
            credentials: store,
            jitter: () => 0.5,
          );
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      expect(room.state.status, RoomConnectionStatus.connecting);
      expect(transport.joins, 0);
      final socket = transport.sockets.single;
      expect(socket.sent.single, isA<AuthenticateMessage>());
      socket.receive(roomFixture('authenticated'));
      clock.flushMicrotasks();
      expect(room.state.status, RoomConnectionStatus.connecting);
      socket.receive(roomFixture('snapshot'));
      clock.flushMicrotasks();
      expect(room.state.status, RoomConnectionStatus.online);
      expect(room.state.ownNumberRevealed, isFalse);
      unawaited(room.dispose());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
  test('lost ACK retries the identical action ID only after reconnect auth and snapshot', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
            jitter: () => 0.5,
          );
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      transport.sockets.last.accepted();
      clock.flushMicrotasks();
      final action = roomFixture('submitOrder');
      expect(room.sendAction(action), isTrue);
      final original = action.toWire();
      unawaited(transport.sockets.last.disconnect(1011));
      clock.flushMicrotasks();
      expect(room.state.status, RoomConnectionStatus.reconnecting);
      expect(room.state.snapshot, isNull);
      expect(room.sendAction(action), isFalse);
      clock.elapse(const Duration(milliseconds: 250));
      clock.flushMicrotasks();
      final next = transport.sockets.last;
      expect(next.sent.map((m) => m.type), ['authenticate']);
      next.accepted();
      clock.flushMicrotasks();
      expect(next.sent.last.toWire(), original);
      next.receive(
        AckMessage.create(
          requestId: RequestId('ack'),
          actionId: (action as SubmitOrderMessage).actionId,
          revision: 1,
          outcome: 'committed',
        ),
      );
      clock.flushMicrotasks();
      unawaited(next.disconnect());
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 250));
      clock.flushMicrotasks();
      transport.sockets.last.accepted();
      clock.flushMicrotasks();
      expect(transport.sockets.last.sent.map((m) => m.type), ['authenticate']);
      expect(transport.joins, 0);
      unawaited(room.dispose());
      clock.flushMicrotasks();
    });
  });
  test('reconnect is bounded and disposing cancels pending backoff', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport()..failConnect = true,
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
            jitter: () => 0.5,
          );
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      clock.elapse(const Duration(minutes: 2));
      clock.flushMicrotasks();
      expect(transport.connections, 7);
      expect(room.state.errorCode, 'RECONNECT_EXHAUSTED');
      expect(clock.pendingTimers, isEmpty);
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      unawaited(room.dispose());
      clock.flushMicrotasks();
      clock.elapse(const Duration(minutes: 2));
      expect(transport.connections, 8);
    });
  });
  test('parser errors or foreign projection stop safely and retain the stored credential', () {
    fakeAsync((clock) {
      final backend = MemoryCredentialBackend(),
          transport = FakeRoomTransport(),
          store = RoomCredentialStore(backend),
          room = RoomController(transport: transport, credentials: store);
      unawaited(store.save(testCredential()));
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      final socket = transport.sockets.last;
      socket.receive(roomFixture('authenticated'));
      socket.incoming.add('{"private":"synthetic-secret"');
      clock.flushMicrotasks();
      expect(room.state.status, RoomConnectionStatus.error);
      expect(room.state.errorCode, 'INVALID_RESPONSE');
      expect(backend.records, hasLength(1));
      expect(clock.pendingTimers, isEmpty);
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      transport.sockets.last.receive(roomFixture('authenticated'));
      final snapshot = roomFixture('snapshot') as SnapshotMessage;
      transport.sockets.last.receive(
        SnapshotMessage.fromJson({...snapshot.toJson(), 'you': 'foreign'}),
      );
      clock.flushMicrotasks();
      expect(room.state.errorCode, 'INVALID_RESPONSE');
      unawaited(room.dispose());
      clock.flushMicrotasks();
    });
  });
  test('session replacement stops reconnect without forgetting an otherwise valid identity', () {
    fakeAsync((clock) {
      final backend = MemoryCredentialBackend(),
          transport = FakeRoomTransport(),
          store = RoomCredentialStore(backend),
          room = RoomController(transport: transport, credentials: store);
      unawaited(store.save(testCredential()));
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      transport.sockets.last.accepted();
      clock.flushMicrotasks();
      transport.sockets.last.receive(roomFixture('sessionReplaced'));
      clock.flushMicrotasks();
      clock.elapse(const Duration(minutes: 1));
      expect(room.state.status, RoomConnectionStatus.closed);
      expect(room.state.errorCode, 'SESSION_REPLACED');
      expect(transport.connections, 1);
      expect(backend.records, hasLength(1));
      unawaited(room.dispose());
      clock.flushMicrotasks();
    });
  });
  test('confirmed invalid credential removes only that identity; auth timeout keeps it for retry', () {
    fakeAsync((clock) {
      final backend = MemoryCredentialBackend(),
          transport = FakeRoomTransport(),
          store = RoomCredentialStore(backend),
          room = RoomController(
            transport: transport,
            credentials: store,
            jitter: () => 0.5,
          );
      unawaited(store.save(testCredential()));
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      transport.sockets.last.receive(
        ErrorMessage.create(
          requestId: RequestId('error'),
          code: 'CREDENTIAL_INVALID',
        ),
      );
      unawaited(transport.sockets.last.disconnect(4408));
      clock.flushMicrotasks();
      expect(backend.records, hasLength(1));
      clock.elapse(const Duration(milliseconds: 250));
      clock.flushMicrotasks();
      transport.sockets.last.receive(
        ErrorMessage.create(
          requestId: RequestId('error'),
          code: 'CREDENTIAL_INVALID',
        ),
      );
      unawaited(transport.sockets.last.disconnect(4401));
      clock.flushMicrotasks();
      expect(backend.records, isEmpty);
      expect(clock.pendingTimers, isEmpty);
      unawaited(room.dispose());
      clock.flushMicrotasks();
    });
  });
  test('failed leave persists the same intent; a reopened controller revokes without another join', () {
    fakeAsync((clock) {
      final backend = MemoryCredentialBackend(),
          store = RoomCredentialStore(backend),
          transport = FakeRoomTransport()..failLeave = true,
          room = RoomController(
            transport: transport,
            credentials: store,
            newId: () => 'leave_once',
          );
      unawaited(store.save(testCredential()));
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      unawaited(room.leave());
      clock.flushMicrotasks();
      expect(room.state.errorCode, 'LEAVE_PENDING');
      RoomCredential? pending;
      unawaited(
        store.load().then((value) => pending = value.credentials.single),
      );
      clock.flushMicrotasks();
      expect(pending!.pendingLeaveActionId, ActionId('leave_once'));
      unawaited(room.dispose());
      clock.flushMicrotasks();
      transport.failLeave = false;
      final reopened = RoomController(transport: transport, credentials: store);
      unawaited(reopened.resume(pending!));
      clock.flushMicrotasks();
      expect(transport.leaveIds, [
        ActionId('leave_once'),
        ActionId('leave_once'),
      ]);
      expect(transport.joins, 0);
      expect(backend.records, isEmpty);
      expect(reopened.state.status, RoomConnectionStatus.closed);
      unawaited(reopened.dispose());
      clock.flushMicrotasks();
    });
  });
  test('storage failure preserves the newly issued credential in memory and retries saving without HTTP create', () {
    fakeAsync((clock) {
      final backend = MemoryCredentialBackend()..fail = true,
          transport = FakeRoomTransport(),
          store = RoomCredentialStore(backend),
          room = RoomController(transport: transport, credentials: store);
      unawaited(room.create(testProfile()));
      clock.flushMicrotasks();
      expect(room.state.errorCode, 'CREDENTIAL_STORAGE_UNAVAILABLE');
      expect(transport.creates, 1);
      expect(transport.connections, 0);
      backend.fail = false;
      unawaited(room.retrySavingCredential());
      clock.flushMicrotasks();
      expect(transport.creates, 1);
      expect(backend.records, hasLength(1));
      expect(transport.connections, 1);
      unawaited(room.dispose());
      clock.flushMicrotasks();
    });
  });
  test('a late HTTP response cannot reconnect after dispose', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport()
            ..deferredCreate = Completer<CredentialMessage>(),
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
          );
      unawaited(room.create(testProfile()));
      clock.flushMicrotasks();
      unawaited(room.dispose());
      clock.flushMicrotasks();
      transport.deferredCreate!.complete(testCredential().message);
      clock.flushMicrotasks();
      expect(transport.connections, 0);
      expect(clock.pendingTimers, isEmpty);
    });
  });
}
