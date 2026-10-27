import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/room_credential_store.dart';

import '../data/room_test_support.dart';

void main() {
  test('Riverpod exposes actual transport views and saved-room storage failures independently', () {
    fakeAsync((clock) {
      final transport = FakeRoomTransport(),
          backend = MemoryCredentialBackend(),
          store = RoomCredentialStore(backend);
      final container = ProviderContainer(
        overrides: [
          roomTransportProvider.overrideWithValue(transport),
          roomCredentialStoreProvider.overrideWithValue(store),
        ],
      );
      final subscription = container.listen(roomSessionProvider, (_, next) {});
      final controller = container.read(roomControllerProvider);
      unawaited(controller.resume(testCredential()));
      clock.flushMicrotasks();
      expect(
        container.read(roomSessionProvider).asData?.value.status,
        RoomConnectionStatus.connecting,
      );
      transport.sockets.single.accepted();
      clock.flushMicrotasks();
      expect(
        container.read(roomSessionProvider).asData?.value.status,
        RoomConnectionStatus.online,
      );
      expect(
        container.read(roomSessionProvider).asData?.value.snapshot?.you,
        testCredential().message.playerId,
      );
      backend.fail = true;
      unawaited(container.read(savedRoomsProvider.future));
      clock.flushMicrotasks();
      expect(
        container.read(savedRoomsProvider).asData?.value.unavailable,
        isTrue,
      );
      subscription.close();
      container.dispose();
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
}
