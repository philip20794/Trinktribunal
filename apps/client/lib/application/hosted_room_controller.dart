import 'dart:async';

import '../domain/models/ids.dart';
import '../data/room_credential_store.dart';
import '../data/protocol/room_message.dart';
import '../data/room_transport.dart';
import 'room_controller.dart';

/// Checks persisted identities against the server, then closes only rooms whose
/// current host is this identity, and only after one explicit confirmation.
class HostedRoomController {
  HostedRoomController(
    this.current,
    this.credentials, {
    RoomTransport Function()? createProbeTransport,
  }) : _createProbeTransport =
           createProbeTransport ??
           (() => NetworkRoomTransport(current.transport.serverOrigin));
  final RoomTransport Function() _createProbeTransport;
  final RoomController current;
  final RoomCredentialStore credentials;

  Future<bool> prepareNewRoom(
    Future<bool> Function(List<String> codes) confirm,
  ) async {
    final saved = await credentials.load();
    if (saved.unavailable) {
      throw const RoomTransportException('CREDENTIAL_STORAGE_UNAVAILABLE');
    }
    final temporary = <RoomController>[];
    final owned = <({RoomController room, RoomCredential credential})>[];
    try {
      for (final credential in saved.credentials) {
        if (credential.serverOrigin != current.transport.serverOrigin ||
            credential.pendingLeaveActionId != null) {
          continue;
        }
        final active = current.state.snapshot;
        final reuse =
            active?.roomId == credential.message.roomId &&
            active?.you == credential.message.playerId;
        final room = reuse
            ? current
            : RoomController(
                transport: _createProbeTransport(),
                credentials: credentials,
              );
        if (!reuse) {
          temporary.add(room);
          await room.resume(credential);
        }
        final state = await room.states
            .firstWhere(
              (s) =>
                  s.status == RoomConnectionStatus.online ||
                  s.status == RoomConnectionStatus.error ||
                  s.status == RoomConnectionStatus.closed,
            )
            .timeout(const Duration(seconds: 12));
        final snapshot = state.snapshot;
        if (snapshot == null) {
          if ([
            'ROOM_UNAVAILABLE',
            'CREDENTIAL_INVALID',
            'LEAVE_PENDING',
          ].contains(state.errorCode)) {
            continue;
          }
          throw RoomTransportException(
            state.errorCode ?? 'NETWORK_UNAVAILABLE',
          );
        }
        if (snapshot.you == snapshot.public.hostId) {
          owned.add((room: room, credential: credential));
        }
      }
      if (owned.isEmpty) return true;
      if (!await confirm(
        owned.map((entry) => entry.credential.message.roomCode).toList(),
      )) {
        return false;
      }
      for (final entry in owned) {
        var closed = false;
        for (var attempt = 0; attempt < 3 && !closed; attempt++) {
          final snapshot = entry.room.state.snapshot;
          if (snapshot == null || snapshot.you != snapshot.public.hostId) {
            throw const RoomTransportException('UNAUTHORIZED_ACTION');
          }
          final completion = Completer<RoomSessionState>();
          final subscription = entry.room.states.skip(1).listen((state) {
            if (!completion.isCompleted && state.errorCode != null) {
              completion.complete(state);
            }
          });
          late RoomSessionState result;
          try {
            if (!entry.room.sendAction(
              CloseRoomMessage.create(
                actionId: ActionId(newRoomRequestId()),
                expectedRevision: snapshot.revision,
                confirmed: true,
              ),
            )) {
              throw const RoomTransportException('NETWORK_UNAVAILABLE');
            }
            result = await completion.future.timeout(
              const Duration(seconds: 12),
            );
          } finally {
            await subscription.cancel();
          }
          if (result.status == RoomConnectionStatus.error &&
              result.errorCode == 'ROOM_UNAVAILABLE') {
            await credentials.remove(entry.credential);
            closed = true;
          } else if (result.errorCode != 'STALE_REVISION') {
            throw RoomTransportException(
              result.errorCode ?? 'NETWORK_UNAVAILABLE',
            );
          }
        }
        if (!closed) throw const RoomTransportException('STALE_REVISION');
      }
      return true;
    } finally {
      for (final room in temporary) {
        await room.dispose();
      }
    }
  }
}
