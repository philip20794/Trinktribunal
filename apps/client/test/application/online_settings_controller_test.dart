import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/online_settings_controller.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';

import '../data/room_test_support.dart';

SnapshotMessage settingsView({
  Config? config,
  int revision = 1,
  bool host = true,
  String phase = 'lobby',
}) {
  final base = roomFixture('snapshot') as SnapshotMessage;
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'revision': revision,
    'public': {
      ...base.public.toJson(),
      'phase': phase,
      'hostId': host ? base.you.value : 'p1',
      'config': (config ?? base.public.config).toJson(),
    },
  });
}

void withSettings(
  void Function(
    FakeAsync,
    RoomController,
    FakeRoomSocket,
    OnlineSettingsController,
  )
  body,
) {
  fakeAsync((clock) {
    final transport = FakeRoomTransport();
    final room = RoomController(
      transport: transport,
      credentials: RoomCredentialStore(MemoryCredentialBackend()),
    );
    final settings = OnlineSettingsController(room);
    unawaited(room.resume(testCredential()));
    clock.flushMicrotasks();
    final socket = transport.sockets.single;
    socket.receive(roomFixture('authenticated'));
    socket.receive(settingsView());
    clock.flushMicrotasks();
    body(clock, room, socket, settings);
    settings.dispose();
    unawaited(room.dispose());
    clock.flushMicrotasks();
    expect(clock.pendingTimers, isEmpty);
  });
}

void main() {
  test('coalesces slider changes and saves without a save button', () {
    withSettings((clock, room, socket, settings) {
      settings.change('targetCases', 12);
      settings.change('targetCases', 14);
      settings.change('requestedRuleEvents', 2);
      clock.elapse(const Duration(milliseconds: 349));
      expect(socket.sent.whereType<SetConfigMessage>(), isEmpty);
      clock.elapse(const Duration(milliseconds: 1));
      final sent = socket.sent.whereType<SetConfigMessage>().single;
      expect(sent.config.targetCases, 14);
      expect(sent.config.requestedRuleEvents, 2);
      expect(settings.saving, isTrue);
      socket.receive(settingsView(config: sent.config, revision: 2));
      clock.flushMicrotasks();
      expect(settings.dirty, isFalse);
      expect(settings.saving, isFalse);
    });
  });

  test('keeps a newer reversal while a previous save and unrelated snapshots arrive', () {
    withSettings((clock, room, socket, settings) {
      final initial = settings.config!.allJudges;
      settings.change('allJudges', !initial);
      settings.flush();
      final first = socket.sent.whereType<SetConfigMessage>().single;
      settings.change('allJudges', initial);
      socket.receive(settingsView(revision: 2));
      clock.flushMicrotasks();
      expect(settings.config!.allJudges, initial);
      socket.receive(settingsView(config: first.config, revision: 3));
      clock.flushMicrotasks();
      expect(settings.config!.allJudges, initial);
      clock.elapse(const Duration(milliseconds: 350));
      final second = socket.sent.whereType<SetConfigMessage>().last;
      expect(second.actionId, isNot(first.actionId));
      expect(second.config.allJudges, initial);
      expect(second.expectedRevision, 3);
      socket.receive(settingsView(config: second.config, revision: 4));
      clock.flushMicrotasks();
      expect(settings.dirty, isFalse);
    });
  });

  test('rebases a stale revision on the fresh server config without dropping local fields', () {
    withSettings((clock, room, socket, settings) {
      settings.change('targetCases', 24);
      settings.flush();
      socket.receive(
        ErrorMessage.fromJson({
          ...roomFixture('error').toJson(),
          'code': 'STALE_REVISION',
        }),
      );
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 500));
      expect(socket.sent.whereType<SetConfigMessage>(), hasLength(1));
      final config = Config.fromJson({
        ...settings.config!.toJson(),
        'factorTenths': 23,
      });
      socket.receive(
        settingsView(
          config: Config.fromJson({...config.toJson(), 'targetCases': 50}),
          revision: 3,
        ),
      );
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 350));
      final sent = socket.sent.whereType<SetConfigMessage>().last;
      expect(sent.expectedRevision, 3);
      expect(sent.config.targetCases, 24);
      expect(sent.config.factorTenths, 23);
    });
  });

  test(
    'guests and active games cannot send automatic configuration changes',
    () {
      withSettings((clock, room, socket, settings) {
        socket.receive(settingsView(host: false, revision: 2));
        clock.flushMicrotasks();
        settings.change('targetCases', 9);
        clock.elapse(const Duration(seconds: 1));
        expect(socket.sent.whereType<SetConfigMessage>(), isEmpty);
        socket.receive(settingsView(phase: 'numbers', revision: 3));
        clock.flushMicrotasks();
        settings.change('targetCases', 10);
        settings.flush();
        expect(socket.sent.whereType<SetConfigMessage>(), isEmpty);
      });
    },
  );
}
