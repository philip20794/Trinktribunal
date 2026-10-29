import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/protocol/room_message.dart';
import '../data/room_transport.dart';
import '../domain/models/ids.dart';
import 'room_controller.dart';

/// Keeps unsaved field changes across tab rebuilds and rebases stale revisions.
final class OnlineSettingsController extends ChangeNotifier {
  OnlineSettingsController(this.room) {
    _receive(room.state);
    _subscription = room.states.listen(_receive);
  }

  final RoomController room;
  late final StreamSubscription<RoomSessionState> _subscription;
  Timer? _debounce;
  Config? _server, _inFlight;
  String? _owner;
  final _changes = <String, Object?>{};
  bool _disposed = false, _awaitFresh = false, _paused = false;
  String? errorCode;

  Config? get config => _server == null
      ? null
      : Config.fromJson({..._server!.toJson(), ..._changes});
  bool get dirty => _changes.isNotEmpty;
  bool get saving => _inFlight != null;
  bool get editable {
    final state = room.state, snapshot = state.snapshot;
    return state.status == RoomConnectionStatus.online &&
        snapshot != null &&
        snapshot.public.phase == 'lobby' &&
        snapshot.you == snapshot.public.hostId;
  }

  void change(String field, Object value) {
    if (!editable || _server == null) return;
    Config.fromJson({...config!.toJson(), field: value});
    _changes[field] = value;
    if (!saving && _server!.toJson()[field] == value) _changes.remove(field);
    errorCode = null;
    _paused = false;
    _schedule();
    notifyListeners();
  }

  void _schedule() {
    _debounce?.cancel();
    if (dirty && !_disposed) {
      _debounce = Timer(const Duration(milliseconds: 350), flush);
    }
  }

  void _receive(RoomSessionState state) {
    if (_disposed) return;
    final snapshot = state.snapshot;
    if (state.status == RoomConnectionStatus.closed ||
        snapshot == null && state.status != RoomConnectionStatus.reconnecting) {
      _owner = null;
      _server = _inFlight = null;
      _changes.clear();
      _debounce?.cancel();
      errorCode = null;
      _awaitFresh = _paused = false;
      notifyListeners();
      return;
    }
    if (snapshot == null) return;
    final owner = '${snapshot.roomId.value}:${snapshot.you.value}';
    if (_owner != owner ||
        snapshot.public.phase != 'lobby' ||
        snapshot.you != snapshot.public.hostId) {
      _changes.clear();
      _inFlight = null;
      _debounce?.cancel();
      errorCode = null;
      _awaitFresh = _paused = false;
    }
    _owner = owner;
    _server = snapshot.public.config;
    if (state.errorCode != null && saving) {
      _inFlight = null;
      errorCode = state.errorCode;
      _awaitFresh = errorCode == 'STALE_REVISION';
      _paused = !_awaitFresh;
    }
    if (state.status == RoomConnectionStatus.online &&
        state.errorCode == null) {
      if (_inFlight != null &&
          mapEquals(_inFlight!.toJson(), _server!.toJson())) {
        _inFlight = null;
      }
      // A user may already have edited a newer value while this save was pending.
      if (!saving) {
        _changes.removeWhere(
          (field, value) => _server!.toJson()[field] == value,
        );
      }
      _awaitFresh = false;
      if (!dirty) errorCode = null;
      if (dirty && !saving && !_paused) _schedule();
    }
    notifyListeners();
  }

  void flush() {
    _debounce?.cancel();
    if (_disposed || !editable || !dirty || saving || _awaitFresh || _paused) {
      return;
    }
    final latest = room.state.snapshot!;
    final next = config!;
    final sent = room.sendAction(
      SetConfigMessage.create(
        actionId: ActionId(newRoomRequestId()),
        expectedRevision: latest.revision,
        config: next,
      ),
    );
    if (sent) _inFlight = next;
    notifyListeners();
  }

  void retry() {
    _paused = false;
    errorCode = null;
    flush();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
