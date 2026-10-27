import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/online_history_controller.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import '../data/room_test_support.dart';

void main() {
  test('pages are private, matched to pull, persisted before receipt, and not polled on profiles', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
          ),
          saved = Completer<bool>(),
          pages = <List<HistoryEvent>>[];
      final history = OnlineHistoryController(
        room,
        persist: (events) {
          pages.add(events);
          return saved.future;
        },
      );
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      final socket = transport.sockets.single;
      socket.accepted();
      clock.flushMicrotasks();
      final pull = socket.sent.whereType<HistoryPullMessage>().single;
      final source = roomFixture('historyEvents') as HistoryEventsMessage;
      HistoryEventsMessage page(RequestId request) =>
          HistoryEventsMessage.fromJson({
            ...source.toJson(),
            'requestId': request.value,
            'hasMore': false,
          });
      socket.receive(page(RequestId('unrelated')));
      clock.flushMicrotasks();
      expect(pages, isEmpty);
      socket.receive(page(pull.requestId));
      clock.flushMicrotasks();
      expect(pages, hasLength(1));
      expect(socket.sent.whereType<HistoryReceiptMessage>(), isEmpty);
      expect(
        room.state.snapshot!.private.toJson(),
        (roomFixture('snapshot') as SnapshotMessage).private.toJson(),
      );
      saved.complete(true);
      clock.flushMicrotasks();
      expect(
        socket.sent.whereType<HistoryReceiptMessage>().single.cursor,
        source.cursor,
      );
      socket.receive(page(pull.requestId));
      socket.receive(roomFixture('snapshot'));
      clock.flushMicrotasks();
      expect(pages, hasLength(1));
      expect(socket.sent.whereType<HistoryPullMessage>(), hasLength(1));
      history.dispose();
      unawaited(room.dispose());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });

  test('storage failure leaves page unreceived; reconnect retries and stale save cannot acknowledge another connection', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
            jitter: () => 0.5,
          ),
          lateSave = Completer<bool>();
      var calls = 0;
      final history = OnlineHistoryController(
        room,
        persist: (_) {
          calls++;
          return calls == 1 ? Future.value(false) : lateSave.future;
        },
      );
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      var socket = transport.sockets.last;
      socket.accepted();
      clock.flushMicrotasks();
      final source = roomFixture('historyEvents') as HistoryEventsMessage;
      void receive() {
        final pull = socket.sent.whereType<HistoryPullMessage>().last;
        socket.receive(
          HistoryEventsMessage.fromJson({
            ...source.toJson(),
            'requestId': pull.requestId.value,
            'hasMore': false,
          }),
        );
        clock.flushMicrotasks();
      }

      receive();
      expect(socket.sent.whereType<HistoryReceiptMessage>(), isEmpty);
      unawaited(socket.disconnect());
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 250));
      clock.flushMicrotasks();
      socket = transport.sockets.last;
      socket.accepted();
      clock.flushMicrotasks();
      receive();
      expect(calls, 2);
      unawaited(socket.disconnect());
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 250));
      clock.flushMicrotasks();
      socket = transport.sockets.last;
      socket.accepted();
      clock.flushMicrotasks();
      lateSave.complete(true);
      clock.flushMicrotasks();
      expect(socket.sent.whereType<HistoryReceiptMessage>(), isEmpty);
      expect(socket.sent.whereType<HistoryPullMessage>(), hasLength(1));
      receive();
      expect(socket.sent.whereType<HistoryReceiptMessage>(), hasLength(1));
      expect(calls, 3);
      history.dispose();
      unawaited(room.dispose());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
}
