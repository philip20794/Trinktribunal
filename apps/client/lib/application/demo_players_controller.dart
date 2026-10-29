import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/protocol/room_message.dart';
import '../data/room_credential_store.dart';
import '../data/room_transport.dart';
import '../domain/avatar_config.dart';
import '../domain/models/ids.dart';
import '../domain/selection/random_source.dart';
import 'room_controller.dart';

/// Test participants use regular server joins and their own private sessions.
/// No test command or synthetic player is added to the room protocol.
final class DemoPlayersController extends ChangeNotifier {
  DemoPlayersController(this.host, {required this.createTransport}) {
    _subscription = host.states.listen(_receive);
  }
  final RoomController host;
  final RoomTransport Function() createTransport;
  late final StreamSubscription<RoomSessionState> _subscription;
  final _players = <_DemoPlayer>[];
  RoomId? _roomId;
  int _nextName = 1;
  bool _disposed = false, adding = false;
  String? errorCode;

  @visibleForTesting
  int get retainedSessions => _players.length;

  bool get canAdd {
    final snapshot = host.state.snapshot;
    return !_disposed &&
        !adding &&
        host.state.status == RoomConnectionStatus.online &&
        snapshot != null &&
        snapshot.you == snapshot.public.hostId &&
        !['finished', 'closed'].contains(snapshot.public.phase) &&
        snapshot.public.players.length < 20;
  }

  void _receive(RoomSessionState state) {
    if (_disposed) return;
    final snapshot = state.snapshot;
    if (state.status == RoomConnectionStatus.closed ||
        snapshot != null &&
            (_roomId != null && snapshot.roomId != _roomId ||
                snapshot.you != snapshot.public.hostId)) {
      _clear();
    }
    if (snapshot != null) _roomId = snapshot.roomId;
    notifyListeners();
  }

  Future<void> add() async {
    if (!canAdd || host.roomCode == null) return;
    final roomId = host.state.snapshot!.roomId;
    final code = host.roomCode!;
    _roomId = roomId;
    adding = true;
    errorCode = null;
    notifyListeners();
    _DemoPlayer? player;
    try {
      final client = RoomController(
        transport: createTransport(),
        credentials: RoomCredentialStore(_EphemeralCredentials()),
      );
      player = _DemoPlayer(client, onEnded: _retire);
      _players.add(player);
      final existing = host.state.snapshot!.public.players
          .map((p) => p.profile.name)
          .toSet();
      while (existing.contains('Demo $_nextName')) {
        _nextName++;
      }
      final name = 'Demo ${_nextName++}';
      final joined = await client.join(
        code,
        Profile.fromJson({
          'name': name,
          'avatar': AvatarConfig.random(SecureRandomSource()).toJson(),
        }),
      );
      if (!joined) {
        throw RoomTransportException(
          client.state.errorCode ?? 'NETWORK_UNAVAILABLE',
        );
      }
      if (_disposed || _roomId != roomId) {
        await player.dispose(leave: true);
        return;
      }
      // A successful HTTP join alone is insufficient: keep the button busy until
      // the participant has authenticated and received its own server snapshot.
      final connected = await client.states
          .firstWhere(
            (state) =>
                state.status == RoomConnectionStatus.online ||
                state.status == RoomConnectionStatus.error ||
                state.status == RoomConnectionStatus.closed,
          )
          .timeout(const Duration(seconds: 10));
      if (connected.status != RoomConnectionStatus.online) {
        throw RoomTransportException(
          connected.errorCode ?? 'NETWORK_UNAVAILABLE',
        );
      }
      final playerId = connected.snapshot!.you;
      // The participant's first view can arrive before the host's broadcast.
      // Keep start/add controls pending until the host has the matching revision.
      await host.states
          .firstWhere(
            (state) =>
                state.status == RoomConnectionStatus.closed ||
                state.snapshot != null && state.snapshot!.roomId != roomId ||
                state.status == RoomConnectionStatus.online &&
                    state.snapshot!.public.players.any(
                      (p) => p.playerId == playerId && p.connected,
                    ),
          )
          .timeout(const Duration(seconds: 10));
      if (_disposed || _roomId != roomId) {
        _players.remove(player);
        await player.dispose(leave: true);
      }
    } on Object catch (error) {
      if (player != null && _players.remove(player)) {
        await player.dispose(leave: true);
      }
      if (!_disposed && _roomId == roomId) {
        errorCode = error is RoomTransportException
            ? error.code
            : 'NETWORK_UNAVAILABLE';
      }
    } finally {
      adding = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _retire(_DemoPlayer player) {
    if (!_players.remove(player)) return;
    unawaited(player.dispose());
    if (!_disposed) notifyListeners();
  }

  void _clear() {
    final players = List<_DemoPlayer>.of(_players);
    _players.clear();
    _roomId = null;
    for (final player in players) {
      unawaited(player.dispose(leave: true));
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription.cancel());
    _clear();
    super.dispose();
  }
}

final class _DemoPlayer {
  _DemoPlayer(this.room, {required void Function(_DemoPlayer) onEnded}) {
    _subscription = room.states.listen((state) {
      _timer?.cancel();
      if (state.status == RoomConnectionStatus.online &&
          state.errorCode == null) {
        _connected = true;
        _timer = Timer(const Duration(milliseconds: 450), _act);
      } else if (_connected &&
          (state.status == RoomConnectionStatus.closed ||
              state.status == RoomConnectionStatus.error)) {
        // Release kicked or closed sessions instead of retaining their private data.
        onEnded(this);
      }
    });
  }
  final RoomController room;
  late final StreamSubscription<RoomSessionState> _subscription;
  Timer? _timer;
  String? _lastAction;
  bool _disposed = false, _connected = false;

  void _act() {
    if (_disposed || room.state.status != RoomConnectionStatus.online) return;
    final snapshot = room.state.snapshot;
    if (snapshot == null) return;
    final view = snapshot.public, game = view.gameId, round = view.roundId;
    if (game == null ||
        round == null ||
        !view.frozenRoster.contains(snapshot.you)) {
      return;
    }
    final own = view.players
        .where((p) => p.playerId == snapshot.you)
        .firstOrNull;
    final guide =
        snapshot.you == (view.config.allJudges ? view.readerId : view.judgeId);
    final actionId = ActionId(newRoomRequestId());
    RoomMessage? action;
    if (view.phase == 'numbers' &&
        snapshot.private.ownNumber != null &&
        own?.ready == false) {
      action = AcknowledgeNumberMessage.create(
        actionId: actionId,
        expectedRevision: snapshot.revision,
        gameId: game,
        roundId: round,
      );
    } else if (view.phase == 'answers' && own?.ready == false) {
      action = ReadyForOrderingMessage.create(
        actionId: actionId,
        expectedRevision: snapshot.revision,
        gameId: game,
        roundId: round,
      );
    } else if (view.phase == 'answers' &&
        guide &&
        view.players
            .where((p) => view.frozenRoster.contains(p.playerId))
            .every((p) => p.ready)) {
      action = BeginOrderingMessage.create(
        actionId: actionId,
        expectedRevision: snapshot.revision,
        gameId: game,
        roundId: round,
      );
    } else if (view.phase == 'ordering' &&
        snapshot.private.ownOrder == null &&
        (view.config.allJudges || guide)) {
      final order =
          view.frozenRoster
              .where((id) => view.config.allJudges || id != snapshot.you)
              .toList()
            ..shuffle(Random());
      action = SubmitOrderMessage.create(
        actionId: actionId,
        expectedRevision: snapshot.revision,
        gameId: game,
        roundId: round,
        order: order,
        confirmed: true,
      );
    } else if (view.phase == 'revealing' && guide) {
      action = RevealNextMessage.create(
        actionId: actionId,
        expectedRevision: snapshot.revision,
        gameId: game,
        roundId: round,
        expectedCursor: view.revealCursor,
      );
    }
    final key =
        '${snapshot.roomId}:${view.roundId}:${snapshot.revision}:${action?.type}';
    if (action != null && _lastAction != key && room.sendAction(action)) {
      _lastAction = key;
    }
  }

  Future<void> dispose({bool leave = false}) async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    await _subscription.cancel();
    try {
      if (leave && room.roomCode != null) await room.leave();
    } finally {
      await room.dispose();
    }
  }
}

/// Demo credentials stay in memory and never appear in saved real sessions.
final class _EphemeralCredentials implements CredentialBackend {
  final _records = <String, String>{};
  @override
  Future<Map<String, String>> readAll() async => Map.of(_records);
  @override
  Future<void> write(String key, String value) async {
    _records[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _records.remove(key);
  }
}
