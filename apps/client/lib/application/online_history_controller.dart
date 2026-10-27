import 'dart:async';
import 'dart:convert';

import '../data/protocol/room_message.dart';
import '../data/room_transport.dart';
import '../domain/models/ids.dart';
import 'room_controller.dart';

/// Own room draws only. A page is acknowledged after durable device persistence.
final class OnlineHistoryController {
  OnlineHistoryController(this.room, {required this.persist}) {
    _pages = room.historyPages.listen(_receive);
    _states = room.states.listen(_changed);
  }
  final RoomController room;
  final Future<bool> Function(List<HistoryEvent>) persist;
  late final StreamSubscription<HistoryEventsMessage> _pages;
  late final StreamSubscription<RoomSessionState> _states;
  int? _epoch;
  String? _drawKey;
  RequestId? _request;
  bool _saving = false, _dirty = false, _disposed = false;

  void _changed(RoomSessionState state) {
    if (state.status != RoomConnectionStatus.online || state.snapshot == null) {
      _epoch = null;
      _request = null;
      _drawKey = null;
      return;
    }
    final view = state.snapshot!;
    final changedConnection = _epoch != room.connectionEpoch;
    if (changedConnection) {
      _epoch = room.connectionEpoch;
      _request = null;
    }
    final key = jsonEncode([
      view.public.gameId?.value,
      view.public.roundId?.value,
      view.public.activeRules.map((r) => r.toJson()).toList(),
    ]);
    final changedDraw = _drawKey != key;
    _drawKey = key;
    if (changedConnection || changedDraw && view.you == view.public.hostId) {
      _dirty = true;
      _pull(null);
    }
  }

  void _pull(HistoryCursor? cursor) {
    if (_disposed || _saving || _request != null || _epoch == null) return;
    final request = RequestId(newRoomRequestId());
    _request = request;
    _dirty = false;
    if (!room.sendHistory(
      HistoryPullMessage.create(requestId: request, cursor: cursor),
      expectedEpoch: _epoch!,
    )) {
      _request = null;
    }
  }

  Future<void> _receive(HistoryEventsMessage page) async {
    if (_disposed ||
        _saving ||
        page.requestId != _request ||
        _epoch != room.connectionEpoch) {
      return;
    }
    final epoch = _epoch!;
    _request = null;
    _saving = true;
    bool saved;
    try {
      saved = await persist(page.events);
    } on Object {
      saved = false;
    }
    _saving = false;
    if (_disposed) return;
    if (saved && epoch == _epoch && room.connectionEpoch == epoch) {
      if (!room.sendHistory(
        HistoryReceiptMessage.create(
          requestId: RequestId(newRoomRequestId()),
          cursor: page.cursor,
        ),
        expectedEpoch: epoch,
      )) {
        return;
      }
      if (page.hasMore) {
        _pull(page.cursor);
        return;
      }
    }
    // Failed storage leaves the server page unreceived; retry on a later draw or reconnect.
    if (_dirty) _pull(null);
  }

  void dispose() {
    _disposed = true;
    unawaited(_pages.cancel());
    unawaited(_states.cancel());
  }
}
