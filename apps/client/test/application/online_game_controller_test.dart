import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/online_game_controller.dart';
import 'package:trinktribunal/application/online_order_controller.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';

import '../data/room_test_support.dart';
import 'online_order_controller_test.dart' show orderingView;

void main() {
  for (final allJudges in [false, true]) {
    test(
      'reroll hides own value, blocks duplicates and discards old order scope; allJudges=$allJudges',
      () {
        fakeAsync((clock) {
          final transport = FakeRoomTransport(),
              room = RoomController(
                transport: transport,
                credentials: RoomCredentialStore(MemoryCredentialBackend()),
              );
          final game = OnlineGameController(room),
              order = OnlineOrderController(room);
          unawaited(room.resume(testCredential()));
          clock.flushMicrotasks();
          final socket = transport.sockets.last;
          socket.receive(roomFixture('authenticated'));
          final initial = orderingView();
          final snapshot = SnapshotMessage.fromJson({
            ...initial.toJson(),
            'public': {
              ...initial.public.toJson(),
              'config': {
                ...initial.public.config.toJson(),
                'allJudges': allJudges,
              },
              'judgeId': allJudges ? null : 'p2',
              'readerId': allJudges ? 'p2' : null,
            },
            'private': allJudges ? {'ownNumber': 2} : <String, Object?>{},
          });
          socket.receive(snapshot);
          clock.flushMicrotasks();
          expect(order.order, isNotEmpty);
          game.revealOwnNumber();
          expect(game.visibleNumber, allJudges ? 2 : null);
          expect(game.canReroll, isTrue);
          expect(
            game.rerollCurrentQuestion(
              gameId: snapshot.public.gameId!,
              roundId: snapshot.public.roundId!,
            ),
            isTrue,
          );
          expect(game.visibleNumber, isNull);
          expect(
            game.rerollCurrentQuestion(
              gameId: snapshot.public.gameId!,
              roundId: snapshot.public.roundId!,
            ),
            isFalse,
          );
          expect(
            socket.sent.whereType<RerollCurrentQuestionMessage>(),
            hasLength(1),
          );
          final next = SnapshotMessage.fromJson({
            ...snapshot.toJson(),
            'revision': snapshot.revision + 1,
            'public': {
              ...snapshot.public.toJson(),
              'roundId': 'replacement',
              'phase': 'numbers',
            },
            'private': allJudges ? {'ownNumber': 2} : <String, Object?>{},
          });
          socket.receive(next);
          clock.flushMicrotasks();
          expect(order.order, isEmpty);
          expect(game.visibleNumber, isNull);
          expect(
            game.rerollCurrentQuestion(
              gameId: snapshot.public.gameId!,
              roundId: snapshot.public.roundId!,
            ),
            isFalse,
          );
          socket.receive(
            SnapshotMessage.fromJson({
              ...next.toJson(),
              'revision': next.revision + 1,
              'public': {
                ...next.public.toJson(),
                'judgeId': allJudges ? null : 'p3',
                'readerId': allJudges ? 'p3' : null,
              },
            }),
          );
          clock.flushMicrotasks();
          expect(game.canReroll, isFalse);
          order.dispose();
          game.dispose();
          unawaited(room.dispose());
          clock.flushMicrotasks();
        });
      },
    );
  }
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
