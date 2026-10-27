import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/online_game_controller.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';

import '../data/room_test_support.dart';

void main() {
  test('own number opens voluntarily, hides on fresh view, confirmation and reconnect', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
            jitter: () => 0.5,
          ),
          game = OnlineGameController(room);
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      transport.sockets.last.accepted();
      clock.flushMicrotasks();
      expect(game.visibleNumber, isNull);
      game.revealOwnNumber();
      expect(game.visibleNumber, 2);
      transport.sockets.last.receive(roomFixture('snapshot'));
      clock.flushMicrotasks();
      expect(game.visibleNumber, isNull);
      expect(game.acknowledgeNumber(), isFalse);
      expect(
        transport.sockets.last.sent.whereType<AcknowledgeNumberMessage>(),
        isEmpty,
      );
      game.revealOwnNumber();
      expect(game.acknowledgeNumber(), isTrue);
      expect(game.visibleNumber, isNull);
      expect(game.ackPending, isTrue);
      expect(game.acknowledgeNumber(), isFalse);
      expect(
        transport.sockets.last.sent.whereType<AcknowledgeNumberMessage>(),
        hasLength(1),
      );
      final action = transport.sockets.last.sent
          .whereType<AcknowledgeNumberMessage>()
          .single;
      expect(action.expectedRevision, room.state.snapshot!.revision);
      expect(action.roundId, room.state.snapshot!.public.roundId);
      unawaited(transport.sockets.last.disconnect());
      clock.flushMicrotasks();
      expect(game.visibleNumber, isNull);
      expect(game.snapshot, isNull);
      clock.elapse(const Duration(milliseconds: 250));
      clock.flushMicrotasks();
      transport.sockets.last.accepted();
      clock.flushMicrotasks();
      expect(game.visibleNumber, isNull);
      game.dispose();
      unawaited(room.dispose());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
  test('normal judge without private assignment cannot reveal or acknowledge another number', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
          ),
          game = OnlineGameController(room);
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      transport.sockets.last.accepted();
      clock.flushMicrotasks();
      final fixture = roomFixture('snapshot') as SnapshotMessage;
      transport.sockets.last.receive(
        SnapshotMessage.fromJson({
          ...fixture.toJson(),
          'public': {...fixture.public.toJson(), 'judgeId': 'p2'},
          'private': {},
        }),
      );
      clock.flushMicrotasks();
      game.revealOwnNumber();
      expect(game.visibleNumber, isNull);
      expect(game.acknowledgeNumber(), isFalse);
      expect(
        transport.sockets.last.sent.whereType<AcknowledgeNumberMessage>(),
        isEmpty,
      );
      game.dispose();
      unawaited(room.dispose());
      clock.flushMicrotasks();
    });
  });
}
