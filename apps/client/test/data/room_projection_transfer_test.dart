import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/online_game_controller.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/protocol/room_projection.dart';
import 'package:trinktribunal/data/protocol/room_projection_transfer.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import 'room_test_support.dart';

SnapshotMessage largeView({String? you}) {
  final base = roomFixture('snapshot') as SnapshotMessage;
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'you': you ?? base.you.value,
    'public': {
      ...base.public.toJson(),
      'players': base.public.players
          .map(
            (player) => {
              ...player.toJson(),
              'profile': {
                ...player.profile.toJson(),
                'name': 'A${'\u0301' * 4500}',
              },
            },
          )
          .toList(),
    },
  });
}

List<RoomMessage> transfer(RoomMessage projection) {
  final bytes = utf8.encode(projection.toWire(logical: true));
  final json = projection.toJson();
  final request = RequestId(json['requestId'] as String);
  final id = TransferId('projection-unit');
  final size = roomProtocolLimits['projectionChunkBytes']!;
  return [
    ProjectionStartMessage.create(
      requestId: request,
      transferId: id,
      revision: json['revision'] as int,
      chunks: (bytes.length / size).ceil(),
      bytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
    ),
    for (var offset = 0; offset < bytes.length; offset += size)
      ProjectionChunkMessage.create(
        requestId: request,
        transferId: id,
        index: offset ~/ size,
        data: base64Url
            .encode(bytes.sublist(offset, min(offset + size, bytes.length)))
            .replaceAll('=', ''),
      ),
    ProjectionEndMessage.create(requestId: request, transferId: id),
  ];
}

void main() {
  test('large Unicode projection publishes exactly once after bounded, integrity-checked frames', () {
    final view = largeView();
    expect(
      utf8.encode(view.toWire(logical: true)).length,
      greaterThan(roomProtocolLimits['frameBytes']!),
    );
    final assembler = RoomProjectionTransfer();
    final frames = transfer(view);
    for (final frame in frames.take(frames.length - 1)) {
      expect(
        utf8.encode(frame.toWire()).length,
        lessThanOrEqualTo(roomProtocolLimits['frameBytes']!),
      );
      expect(assembler.accept(frame), isNull);
    }
    expect(assembler.pending, isTrue);
    expect(assembler.accept(frames.last)!.toJson(), view.toJson());
    expect(assembler.pending, isFalse);
  });

  for (final invalid in [
    'hash',
    'transfer',
    'duplicate',
    'missing',
    'revision',
    'request',
    'size',
    'count',
    'interleaved',
  ]) {
    test(
      'invalid $invalid transfer never publishes or retains private fragments',
      () {
        final frames = transfer(largeView());
        final start = frames.first as ProjectionStartMessage;
        if (['hash', 'revision', 'size', 'count'].contains(invalid)) {
          frames[0] = ProjectionStartMessage.fromJson({
            ...start.toJson(),
            if (invalid == 'hash') 'sha256': '0' * 64,
            if (invalid == 'revision') 'revision': start.revision + 1,
            if (invalid == 'size') 'bytes': 1,
            if (invalid == 'count') 'chunks': 1,
          });
        } else if (invalid == 'transfer') {
          frames[1] = ProjectionChunkMessage.fromJson({
            ...frames[1].toJson(),
            'transferId': 'wrong',
          });
        } else if (invalid == 'request') {
          frames[1] = ProjectionChunkMessage.fromJson({
            ...frames[1].toJson(),
            'requestId': 'wrong',
          });
        } else if (invalid == 'interleaved') {
          frames.insert(2, roomFixture('pong'));
        } else if (invalid == 'duplicate') {
          frames.insert(2, frames[1]);
        } else {
          frames.removeAt(2);
        }
        final assembler = RoomProjectionTransfer();
        expect(() {
          for (final frame in frames) {
            expect(assembler.accept(frame), isNull);
          }
        }, throwsA(isA<ProtocolDecodeException>()));
        expect(assembler.pending, isFalse);
      },
    );
  }

  test('large delta replaces private values after complete assembly', () {
    final base = largeView();
    final delta = DeltaMessage.create(
      requestId: RequestId('delta'),
      roomId: base.roomId,
      you: base.you,
      revision: base.revision + 1,
      baseRevision: base.revision,
      publicChanges: PublicChanges.fromJson({
        'players': base.public.players.map((p) => p.toJson()).toList(),
      }),
      private: PrivateView.fromJson({}),
    );
    final assembler = RoomProjectionTransfer();
    RoomMessage? complete;
    for (final frame in transfer(delta)) {
      complete = assembler.accept(frame);
    }
    final next = applyRoomDelta(base, complete! as DeltaMessage);
    expect(next.private.ownNumber, isNull);
    expect(next.public.players.length, base.public.players.length);
  });

  for (final wrongRecipient in [false, true]) {
    test(
      'controller accepts complete own projection only; foreign recipient: $wrongRecipient',
      () {
        fakeAsync((clock) {
          final transport = FakeRoomTransport();
          final room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
          );
          final game = OnlineGameController(room);
          unawaited(room.resume(testCredential()));
          clock.flushMicrotasks();
          final socket = transport.sockets.last;
          socket.receive(roomFixture('authenticated'));
          final frames = transfer(largeView(you: wrongRecipient ? 'p1' : null));
          for (final frame in frames.take(frames.length - 1)) {
            socket.receive(frame);
          }
          clock.flushMicrotasks();
          expect(room.state.snapshot, isNull);
          socket.receive(frames.last);
          clock.flushMicrotasks();
          expect(
            room.state.status,
            wrongRecipient
                ? RoomConnectionStatus.error
                : RoomConnectionStatus.online,
          );
          expect(game.visibleNumber, isNull);
          if (!wrongRecipient) {
            game.revealOwnNumber();
            expect(game.visibleNumber, 2);
          }
          game.dispose();
          unawaited(room.dispose());
          clock.flushMicrotasks();
          expect(clock.pendingTimers, isEmpty);
        });
      },
    );
  }

  test('reconnect discards partial transfer bytes before accepting the new own snapshot', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport();
      final room = RoomController(
        transport: transport,
        credentials: RoomCredentialStore(MemoryCredentialBackend()),
        jitter: () => 0.5,
      );
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      final old = transport.sockets.last;
      old.receive(roomFixture('authenticated'));
      final frames = transfer(largeView());
      old.receive(frames[0]);
      old.receive(frames[1]);
      clock.flushMicrotasks();
      unawaited(old.disconnect());
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 250));
      clock.flushMicrotasks();
      final current = transport.sockets.last;
      current.receive(roomFixture('authenticated'));
      for (final frame in frames) {
        current.receive(frame);
      }
      clock.flushMicrotasks();
      expect(room.state.status, RoomConnectionStatus.online);
      expect(room.state.snapshot!.private.ownNumber, 2);
      expect(transport.joins, 0);
      unawaited(room.dispose());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });

  test('incomplete transfer expires without deleting credentials or exposing partial state', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          backend = MemoryCredentialBackend();
      final store = RoomCredentialStore(backend);
      final room = RoomController(transport: transport, credentials: store);
      unawaited(store.save(testCredential()));
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      final socket = transport.sockets.last;
      socket.receive(roomFixture('authenticated'));
      socket.receive(transfer(largeView()).first);
      clock.flushMicrotasks();
      clock.elapse(
        Duration(milliseconds: roomProtocolLimits['projectionTimeoutMs']!),
      );
      clock.flushMicrotasks();
      expect(room.state.errorCode, 'INVALID_RESPONSE');
      expect(room.state.snapshot, isNull);
      expect(backend.records, hasLength(1));
      expect(transport.joins, 0);
      unawaited(room.dispose());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
}
