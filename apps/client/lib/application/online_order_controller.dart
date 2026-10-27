import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/protocol/room_message.dart';
import '../data/room_transport.dart';
import '../domain/bench_order.dart';
import '../domain/models/ids.dart';
import 'room_controller.dart';

/// Drag/tap/key changes are private local intent until one explicit confirmation.
final class OnlineOrderController extends ChangeNotifier {
  OnlineOrderController(this.room, {String Function()? newId})
    : _newId = newId ?? newRoomRequestId {
    _receive(room.state);
    _subscription = room.states.listen(_receive);
  }
  final RoomController room;
  final String Function() _newId;
  late final StreamSubscription<RoomSessionState> _subscription;
  GameId? _gameId;
  RoundId? _roundId;
  List<PlayerId> _draft = [];
  bool _pending = false, _confirmed = false;
  List<PlayerId> get order => List.unmodifiable(_draft);
  bool get pending => _pending;
  bool get confirmed => _confirmed;
  SnapshotMessage? get snapshot =>
      room.state.status == RoomConnectionStatus.online
      ? room.state.snapshot
      : null;
  bool get canEdit {
    final view = snapshot;
    return view != null &&
        view.public.gameId == _gameId &&
        view.public.roundId == _roundId &&
        !view.public.config.allJudges &&
        view.you == view.public.judgeId &&
        view.public.phase == 'ordering' &&
        !_pending &&
        !_confirmed &&
        _draft.length == view.public.frozenRoster.length - 1;
  }

  void _receive(RoomSessionState state) {
    final view = state.status == RoomConnectionStatus.online
        ? state.snapshot
        : null;
    if (view == null ||
        view.public.config.allJudges ||
        view.you != view.public.judgeId ||
        !['ordering', 'revealing', 'judged'].contains(view.public.phase)) {
      _gameId = null;
      _roundId = null;
      _draft = [];
      _pending = false;
      _confirmed = false;
      notifyListeners();
      return;
    }
    if (_gameId != view.public.gameId || _roundId != view.public.roundId) {
      _gameId = view.public.gameId;
      _roundId = view.public.roundId;
      _draft = view.public.frozenRoster
          .where((id) => id != view.public.judgeId)
          .toList();
      _pending = false;
      _confirmed = false;
    }
    final own = view.private.ownOrder;
    if (own != null) {
      _draft = List.of(own);
      _confirmed = true;
      _pending = false;
    } else if (state.errorCode != null) {
      _pending = false;
    }
    notifyListeners();
  }

  void move(int from, int to) {
    if (!canEdit ||
        from < 0 ||
        to < 0 ||
        from >= _draft.length ||
        to >= _draft.length) {
      return;
    }
    _draft = insertPlayer(_draft, from, to);
    notifyListeners();
  }

  bool confirm({
    required GameId gameId,
    required RoundId roundId,
    bool confirmed = false,
  }) {
    final view = snapshot;
    if (!confirmed ||
        !canEdit ||
        view == null ||
        view.public.gameId != gameId ||
        view.public.roundId != roundId) {
      return false;
    }
    final sent = room.sendAction(
      SubmitOrderMessage.create(
        actionId: ActionId(_newId()),
        expectedRevision: view.revision,
        gameId: gameId,
        roundId: roundId,
        order: List.of(_draft),
        confirmed: true,
      ),
    );
    if (sent) {
      _pending = true;
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
