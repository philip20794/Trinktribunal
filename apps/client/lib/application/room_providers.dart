import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/room_credential_backend.dart';
import '../data/room_credential_store.dart';
import '../data/room_transport.dart';
import 'room_controller.dart';
import 'online_profile_controller.dart';
import 'online_settings_controller.dart';
import 'demo_players_controller.dart';
import 'online_game_controller.dart';
import 'online_order_controller.dart';
import 'online_history_controller.dart';
import 'local_data_providers.dart';
import '../domain/models/content_history.dart';

final roomCredentialStoreProvider = Provider<RoomCredentialStore>(
  (ref) => RoomCredentialStore(createCredentialBackend()),
);
final savedRoomsProvider = FutureProvider<CredentialLoad>(
  (ref) => ref.watch(roomCredentialStoreProvider).load(),
  retry: (count, error) => null,
);
final roomTransportProvider = Provider<RoomTransport>((ref) {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isEmpty) {
    throw const RoomTransportException('SERVER_NOT_CONFIGURED');
  }
  return NetworkRoomTransport(roomServerOrigin(configured));
});
final roomControllerProvider = Provider<RoomController>((ref) {
  final controller = RoomController(
    transport: ref.watch(roomTransportProvider),
    credentials: ref.watch(roomCredentialStoreProvider),
  );
  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
});
final roomSessionProvider = StreamProvider<RoomSessionState>(
  (ref) => ref.watch(roomControllerProvider).states,
  retry: (count, error) => null,
);
final onlineProfileProvider = Provider<OnlineProfileController>((ref) {
  final controller = OnlineProfileController(ref.watch(roomControllerProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

final onlineGameProvider = Provider<OnlineGameController>((ref) {
  final controller = OnlineGameController(ref.watch(roomControllerProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

final onlineOrderProvider = Provider<OnlineOrderController>((ref) {
  final controller = OnlineOrderController(ref.watch(roomControllerProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

final onlineHistoryProvider = Provider<OnlineHistoryController>((ref) {
  final history = OnlineHistoryController(
    ref.watch(roomControllerProvider),
    persist: (events) async {
      await ref.read(localResumeProvider.future);
      ref
          .read(contentHistoryStoreProvider)
          .merge(
            ContentHistory(
              events.map(
                (event) => ContentHistoryEntry(
                  eventId: event.eventId.value,
                  kind: ContentKind.values.byName(event.kind),
                  contentId: event.contentId,
                  timestampUtc: DateTime.parse(event.timestampUtc),
                ),
              ),
            ),
          );
      final transaction = ref.read(localStateTransactionProvider);
      await transaction.save();
      return transaction.error == null;
    },
  );
  ref.onDispose(history.dispose);
  return history;
});

final onlineSettingsProvider = Provider<OnlineSettingsController>((ref) {
  final controller = OnlineSettingsController(
    ref.watch(roomControllerProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final demoPlayersProvider = Provider<DemoPlayersController>((ref) {
  final host = ref.watch(roomControllerProvider);
  final controller = DemoPlayersController(
    host,
    createTransport: () => NetworkRoomTransport(host.transport.serverOrigin),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
