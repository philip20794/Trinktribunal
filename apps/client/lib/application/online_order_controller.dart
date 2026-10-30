import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/protocol/room_message.dart';
import '../data/room_transport.dart';
import '../domain/bench_order.dart';
import '../domain/models/ids.dart';
import 'room_controller.dart';

/// All-judge placements submit automatically once complete and ordering opens.
/// A single judge keeps their draft private until explicit confirmation.
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
  RoomId? _roomId;
  PlayerId? _playerId;
  List<PlayerId> _draft = [];
  List<PlayerId?> _slots = [];
  List<PlayerId?> get slots => List.unmodifiable(_slots);
  List<PlayerId> get unplaced =>
      _draft.where((id) => !_slots.contains(id)).toList();
  bool get complete => _slots.isNotEmpty && !_slots.contains(null);
  bool _pending = false, _confirmed = false, _disposed = false;
  List<PlayerId> get order =>
      snapshot == null ? const [] : List.unmodifiable(_draft);
  bool get pending => _pending;
  bool get confirmed => _confirmed;
  SnapshotMessage? get snapshot =>
      !_disposed && room.state.status == RoomConnectionStatus.online
      ? room.state.snapshot
      : null;
  bool get canEdit {
    final view = snapshot;
    return view != null &&
        view.public.gameId == _gameId &&
        view.public.roundId == _roundId &&
        view.public.frozenRoster.contains(view.you) &&
        (view.public.config.allJudges || view.you == view.public.judgeId) &&
        (view.public.phase == 'ordering' ||
            view.public.config.allJudges &&
                ['numbers', 'answers'].contains(view.public.phase)) &&
        !_pending &&
        !_confirmed &&
        _draft.length ==
            view.public.frozenRoster.length -
                (view.public.config.allJudges ? 0 : 1);
  }

  void _receive(RoomSessionState state) {
    if (_disposed) return;
    // Keep an unconfirmed intention during a transient outage, hidden and
    // uneditable until an authoritative snapshot confirms the same scope.
    if (state.status == RoomConnectionStatus.reconnecting) {
      notifyListeners();
      return;
    }
    final view = state.status == RoomConnectionStatus.online
        ? state.snapshot
        : null;
    if (view == null ||
        !view.public.frozenRoster.contains(view.you) ||
        (!view.public.config.allJudges && view.you != view.public.judgeId) ||
        ![
          'numbers',
          'answers',
          'ordering',
          'revealing',
          'judged',
        ].contains(view.public.phase)) {
      _gameId = null;
      _roundId = null;
      _roomId = null;
      _playerId = null;
      _draft = [];
      _slots = [];
      _pending = false;
      _confirmed = false;
      notifyListeners();
      return;
    }
    if (_roomId != view.roomId ||
        _playerId != view.you ||
        _gameId != view.public.gameId ||
        _roundId != view.public.roundId) {
      _roomId = view.roomId;
      _playerId = view.you;
      _gameId = view.public.gameId;
      _roundId = view.public.roundId;
      _draft = view.public.frozenRoster
          .where(
            (id) => view.public.config.allJudges || id != view.public.judgeId,
          )
          .toList();
      _slots = List<PlayerId?>.filled(_draft.length, null);
      _pending = false;
      _confirmed = false;
    }
    final own = view.private.ownOrder;
    if (own != null) {
      _draft = List.of(own);
      _slots = List.of(own);
      _confirmed = true;
      _pending = false;
    } else if (state.errorCode != null) {
      _pending = false;
    }
    // Defer sending when the controller is created while widgets are building.
    // On a stale revision, wait for the refreshed authoritative snapshot.
    if (state.errorCode == null) scheduleMicrotask(_confirmCompleteOrder);
    notifyListeners();
  }

  void _confirmCompleteOrder() {
    final view = snapshot;
    if (view == null ||
        room.state.errorCode != null ||
        !view.public.config.allJudges ||
        !complete ||
        view.public.gameId == null ||
        view.public.roundId == null) {
      return;
    }
    confirm(
      gameId: view.public.gameId!,
      roundId: view.public.roundId!,
      confirmed: true,
    );
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

  void place(PlayerId id, int index) {
    if (!canEdit ||
        !_draft.contains(id) ||
        index < 0 ||
        index >= _slots.length) {
      return;
    }
    _slots = placePlayer(_slots, id, index);
    _draft = [
      ..._slots.whereType<PlayerId>(),
      ..._draft.where((p) => !_slots.contains(p)),
    ];
    _confirmCompleteOrder();
    notifyListeners();
  }

  void unplace(PlayerId id) {
    if (!canEdit) return;
    final index = _slots.indexOf(id);
    if (index < 0) return;
    _slots[index] = null;
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
        view?.public.phase != 'ordering' ||
        view != null && view.public.config.allJudges && !complete ||
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
        order: view.public.config.allJudges
            ? _slots.whereType<PlayerId>().toList()
            : List.of(_draft),
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
    if (_disposed) return;
    _disposed = true;
    _draft = [];
    _slots = [];
    _pending = false;
    _confirmed = false;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
