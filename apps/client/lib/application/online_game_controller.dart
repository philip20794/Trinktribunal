import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/protocol/room_message.dart';
import '../data/room_transport.dart';
import '../domain/models/ids.dart';
import 'room_controller.dart';

/// Session facade: network state is authoritative; opening a number is local and voluntary.
final class OnlineGameController extends ChangeNotifier {
  OnlineGameController(this.room, {String Function()? newId})
    : _newId = newId ?? newRoomRequestId {
    _subscription = room.states.listen((_) {
      _visible = false;
      _ackPending = false;
      notifyListeners();
    });
  }
  final RoomController room;
  final String Function() _newId;
  late final StreamSubscription<RoomSessionState> _subscription;
  bool _visible = false, _ackPending = false;
  SnapshotMessage? get snapshot =>
      room.state.status == RoomConnectionStatus.online
      ? room.state.snapshot
      : null;
  int? get visibleNumber => _visible ? snapshot?.private.ownNumber : null;
  bool get ackPending => _ackPending;
  bool get acknowledged =>
      snapshot?.public.players.any(
        (player) => player.playerId == snapshot!.you && player.ready,
      ) ??
      false;
  void revealOwnNumber() {
    if (snapshot?.private.ownNumber == null) return;
    _visible = true;
    notifyListeners();
  }

  void hideSecret() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  bool acknowledgeNumber() {
    final view = snapshot;
    hideSecret();
    if (view == null ||
        view.public.phase != 'numbers' ||
        view.private.ownNumber == null ||
        view.public.gameId == null ||
        view.public.roundId == null ||
        acknowledged ||
        _ackPending) {
      return false;
    }
    final sent = room.sendAction(
      AcknowledgeNumberMessage.create(
        actionId: ActionId(_newId()),
        expectedRevision: view.revision,
        gameId: view.public.gameId!,
        roundId: view.public.roundId!,
      ),
    );
    if (sent) {
      _ackPending = true;
      notifyListeners();
    }
    return sent;
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
