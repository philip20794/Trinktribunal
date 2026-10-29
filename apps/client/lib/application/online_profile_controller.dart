import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/protocol/room_message.dart' as protocol;
import '../data/room_transport.dart';
import '../domain/avatar_config.dart';
import '../domain/models/ids.dart';
import 'room_controller.dart';

final class OnlineProfileController extends ChangeNotifier {
  OnlineProfileController(this.room, {String Function()? newId})
    : _newId = newId ?? newRoomRequestId {
    _subscription = room.states.listen(_receive);
  }
  final RoomController room;
  final String Function() _newId;
  late final StreamSubscription<RoomSessionState> _subscription;
  Timer? _debounce;
  String? _owner;
  protocol.Profile? _server;
  protocol.EditOwnProfileMessage? _inFlight;
  String name = '';
  AvatarConfig avatar = AvatarConfig();
  String? errorCode;
  bool _disposed = false,
      _awaitFresh = false,
      _paused = false,
      _finalFlush = false;
  bool get available => _server != null;
  bool get saving => _inFlight != null;
  bool get dirty =>
      _server != null &&
      (name.trim() != _server!.name ||
          avatar.seed != _server!.avatar.seed ||
          !mapEquals(avatar.selections, _server!.avatar.selections));
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void rename(String value) {
    name = value;
    _changed();
  }

  void changeAvatar(AvatarConfig value) {
    avatar = value;
    _changed();
  }

  void _changed() {
    errorCode = null;
    _paused = false;
    _schedule();
    _notify();
  }

  void _schedule() {
    _debounce?.cancel();
    if (!_disposed && dirty) {
      _debounce = Timer(const Duration(milliseconds: 350), () => _flush(false));
    }
  }

  void _receive(RoomSessionState state) {
    if (_disposed) return;
    if (state.status == RoomConnectionStatus.connecting ||
        state.status == RoomConnectionStatus.closed) {
      _owner = null;
      _server = null;
      _inFlight = null;
      _awaitFresh = false;
      _paused = false;
      _finalFlush = false;
      _debounce?.cancel();
      _notify();
      return;
    }
    if (state.errorCode != null &&
        _inFlight != null &&
        state.status != RoomConnectionStatus.reconnecting) {
      _inFlight = null;
      errorCode = state.errorCode;
      _awaitFresh = state.errorCode == 'STALE_REVISION';
      _paused = !_awaitFresh;
      _debounce?.cancel();
    }
    final snapshot = state.snapshot;
    if (snapshot == null) {
      _debounce?.cancel();
      _notify();
      return;
    }
    final matches = snapshot.public.players.where(
      (player) => player.playerId == snapshot.you,
    );
    if (matches.isEmpty) return;
    final profile = matches.first.profile,
        key = '${snapshot.roomId.value}:${snapshot.you.value}';
    if (_owner != key) {
      _owner = key;
      _server = profile;
      name = profile.name;
      avatar = AvatarConfig.fromJson(profile.avatar.toJson());
      _inFlight = null;
      errorCode = null;
    } else {
      final wasDirty = dirty;
      _server = profile;
      if (_inFlight != null &&
          _inFlight!.profile.name == profile.name &&
          mapEquals(
            _inFlight!.profile.avatar.selections,
            profile.avatar.selections,
          ) && _inFlight!.profile.avatar.seed == profile.avatar.seed) {
        _inFlight = null;
      }
      if (!wasDirty && _inFlight == null) {
        name = profile.name;
        avatar = AvatarConfig.fromJson(profile.avatar.toJson());
      }
    }
    if (_awaitFresh && state.errorCode == null) {
      _awaitFresh = false;
      errorCode = null;
    }
    if (!dirty && !saving) errorCode = null;
    if (state.status == RoomConnectionStatus.online &&
        dirty &&
        !saving &&
        !_awaitFresh &&
        !_paused) {
      if (_finalFlush) {
        _finalFlush = false;
        _flush(true);
      } else {
        _schedule();
      }
    }
    _notify();
  }

  void flush() => _flush(true);
  void _flush(bool finalFlush) {
    _debounce?.cancel();
    if (_disposed || !dirty) return;
    if (saving) {
      _finalFlush |= finalFlush;
      return;
    }
    if (finalFlush) _paused = false;
    if (_paused ||
        _awaitFresh ||
        room.state.status != RoomConnectionStatus.online ||
        room.state.snapshot == null) {
      return;
    }
    try {
      final profile = protocol.Profile.fromJson({
        'name': name.trim(),
        'avatar': avatar.toJson(),
      });
      final command = protocol.EditOwnProfileMessage.create(
        actionId: ActionId(_newId()),
        expectedRevision: room.state.snapshot!.revision,
        profile: profile,
      );
      _inFlight = command;
      errorCode = null;
      if (!room.sendAction(command)) _inFlight = null;
    } on protocol.ProtocolDecodeException catch (error) {
      errorCode = error.code;
      _paused = true;
    }
    _notify();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _debounce?.cancel();
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
