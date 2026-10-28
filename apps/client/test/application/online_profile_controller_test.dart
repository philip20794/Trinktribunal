import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/online_profile_controller.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import '../data/room_test_support.dart';

void echoProfile(
  RoomController room,
  FakeRoomSocket socket,
  EditOwnProfileMessage command,
) {
  final base = room.state.snapshot!;
  socket.receive(
    DeltaMessage.fromJson({
      'type': 'delta',
      'protocolVersion': 2,
      'requestId': 'echo',
      'roomId': base.roomId.value,
      'you': base.you.value,
      'baseRevision': base.revision,
      'revision': base.revision + 1,
      'publicChanges': {
        'players': base.public.players
            .map(
              (player) => {
                ...player.toJson(),
                if (player.playerId == base.you)
                  'profile': command.profile.toJson(),
              },
            )
            .toList(),
      },
      'private': base.private.toJson(),
    }),
  );
}

void main() {
  test('avatar/name bursts coalesce; final flush waits for confirmation then sends just the latest draft', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
          );
      var ids = 0;
      final editor = OnlineProfileController(
        room,
        newId: () => 'profile_${ids++}',
      );
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      final socket = transport.sockets.last;
      socket.accepted();
      clock.flushMicrotasks();
      expect(editor.available, isTrue);
      expect(editor.dirty, isFalse);
      editor.changeAvatar(editor.avatar.withOption('hair', 'long'));
      editor.rename('Alpha');
      editor.rename('Beta');
      clock.elapse(const Duration(milliseconds: 349));
      expect(socket.sent.whereType<EditOwnProfileMessage>(), isEmpty);
      clock.elapse(const Duration(milliseconds: 1));
      clock.flushMicrotasks();
      final first = socket.sent.whereType<EditOwnProfileMessage>().single;
      expect(first.profile.name, 'Beta');
      expect(first.profile.avatar.selections['hair'], 'long');
      expect(editor.saving, isTrue);
      editor.rename('Gamma');
      editor.flush();
      expect(socket.sent.whereType<EditOwnProfileMessage>(), hasLength(1));
      echoProfile(room, socket, first);
      clock.flushMicrotasks();
      final commands = socket.sent.whereType<EditOwnProfileMessage>().toList();
      expect(commands, hasLength(2));
      expect(commands.last.profile.name, 'Gamma');
      expect(commands.last.expectedRevision, 2);
      expect(commands.last.actionId, isNot(first.actionId));
      echoProfile(room, socket, commands.last);
      clock.flushMicrotasks();
      expect(editor.dirty, isFalse);
      expect(editor.saving, isFalse);
      expect(editor.errorCode, isNull);
      editor.dispose();
      unawaited(room.dispose());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
  test('stale revision refreshes the view before a new profile intention; no retry with a changed old action ID', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
          );
      var ids = 0;
      final editor = OnlineProfileController(
        room,
        newId: () => 'intent_${ids++}',
      );
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      final socket = transport.sockets.last;
      socket.accepted();
      clock.flushMicrotasks();
      editor.rename('Updated');
      editor.flush();
      final first = socket.sent.whereType<EditOwnProfileMessage>().single;
      socket.receive(
        ErrorMessage.create(
          requestId: RequestId('stale'),
          code: 'STALE_REVISION',
        ),
      );
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 1));
      expect(socket.sent.whereType<EditOwnProfileMessage>(), hasLength(1));
      expect(socket.sent.whereType<RequestSnapshotMessage>(), hasLength(1));
      socket.receive(
        SnapshotMessage.fromJson({
          ...roomFixture('snapshot').toJson(),
          'revision': 2,
        }),
      );
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 350));
      clock.flushMicrotasks();
      final next = socket.sent.whereType<EditOwnProfileMessage>().last;
      expect(next.actionId, isNot(first.actionId));
      expect(next.expectedRevision, 2);
      expect(next.profile.name, 'Updated');
      editor.dispose();
      unawaited(room.dispose());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
  test('a draft never causes new authoritative actions while offline and replacement drops stale local edits', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          room = RoomController(
            transport: transport,
            credentials: RoomCredentialStore(MemoryCredentialBackend()),
            jitter: () => 0.5,
          ),
          editor = OnlineProfileController(room);
      unawaited(room.resume(testCredential()));
      clock.flushMicrotasks();
      final socket = transport.sockets.last;
      socket.accepted();
      clock.flushMicrotasks();
      editor.rename('Draft');
      unawaited(socket.disconnect());
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 250));
      clock.flushMicrotasks();
      final replacement = transport.sockets.last;
      expect(replacement.sent.whereType<EditOwnProfileMessage>(), isEmpty);
      replacement.accepted();
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 350));
      clock.flushMicrotasks();
      expect(replacement.sent.whereType<EditOwnProfileMessage>(), hasLength(1));
      replacement.receive(roomFixture('sessionReplaced'));
      clock.flushMicrotasks();
      expect(editor.available, isFalse);
      expect(editor.saving, isFalse);
      editor.dispose();
      unawaited(room.dispose());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
}
