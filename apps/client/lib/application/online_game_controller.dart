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
      if (_disposed) return;
      _visible = false;
      _ackPending = false;
      _pending.clear();
      notifyListeners();
    });
  }
  final RoomController room;
  final String Function() _newId;
  late final StreamSubscription<RoomSessionState> _subscription;
  bool _visible = false, _ackPending = false, _disposed = false;
  final Set<String> _pending = {};
  bool pending(String action) => _pending.contains(action);
  SnapshotMessage? get snapshot =>
      !_disposed && room.state.status == RoomConnectionStatus.online
      ? room.state.snapshot
      : null;
  int? get visibleNumber => _visible ? snapshot?.private.ownNumber : null;
  bool get ackPending => _ackPending;
  bool get canGuideRound {
    final view = snapshot;
    return view != null &&
        (view.you == view.public.hostId ||
            view.you ==
                (view.public.config.allJudges
                    ? view.public.readerId
                    : view.public.judgeId));
  }

  bool get canReroll {
    final view = snapshot;
    if (view == null ||
        view.public.gameId == null ||
        view.public.roundId == null) {
      return false;
    }
    final state = view.public;
    return view.you ==
            (state.config.allJudges ? state.readerId : state.judgeId) &&
        ['numbers', 'answers', 'ordering', 'revealing'].contains(state.phase) &&
        state.revealCursor == 0 &&
        !pending('reroll');
  }

  bool rerollCurrentQuestion({
    required GameId gameId,
    required RoundId roundId,
  }) {
    final view = snapshot;
    if (!canReroll || !_sameRound(gameId, roundId) || view == null) {
      return false;
    }
    return _send(
      'reroll',
      RerollCurrentQuestionMessage.create(
        actionId: ActionId(_newId()),
        expectedRevision: view.revision,
        gameId: gameId,
        roundId: roundId,
      ),
    );
  }

  int get activeCount =>
      snapshot?.public.players.where((p) => p.active != false).length ?? 0;
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
    final wasVisible = _visible;
    hideSecret();
    if (!wasVisible ||
        view == null ||
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

  bool _sameRound(GameId gameId, RoundId roundId) =>
      snapshot?.public.gameId == gameId && snapshot?.public.roundId == roundId;
  bool _send(String action, RoomMessage command) {
    hideSecret();
    if (pending(action)) return false;
    final sent = room.sendAction(command);
    if (sent) {
      _pending.add(action);
      notifyListeners();
    }
    return sent;
  }

  bool readyForOrdering({required GameId gameId, required RoundId roundId}) {
    final view = snapshot;
    if (view == null ||
        !_sameRound(gameId, roundId) ||
        view.public.phase != 'answers' ||
        !view.public.frozenRoster.contains(view.you) ||
        view.public.players.any(
          (player) => player.playerId == view.you && player.ready,
        )) {
      return false;
    }
    return _send(
      'ready',
      ReadyForOrderingMessage.create(
        actionId: ActionId(_newId()),
        expectedRevision: view.revision,
        gameId: gameId,
        roundId: roundId,
      ),
    );
  }

  bool get canBeginOrdering {
    final view = snapshot;
    if (view == null ||
        view.public.phase != 'answers' ||
        !canGuideRound ||
        view.public.frozenRoster.length < 3) {
      return false;
    }
    return view.public.frozenRoster.every(
      (id) => view.public.players.any(
        (player) => player.playerId == id && player.ready && player.connected,
      ),
    );
  }

  bool beginOrdering({required GameId gameId, required RoundId roundId}) {
    final view = snapshot;
    if (view == null || !_sameRound(gameId, roundId) || !canBeginOrdering) {
      return false;
    }
    return _send(
      'begin',
      BeginOrderingMessage.create(
        actionId: ActionId(_newId()),
        expectedRevision: view.revision,
        gameId: gameId,
        roundId: roundId,
      ),
    );
  }

  bool revealNext({
    required GameId gameId,
    required RoundId roundId,
    required int expectedCursor,
  }) {
    final view = snapshot;
    if (view == null ||
        !_sameRound(gameId, roundId) ||
        view.public.phase != 'revealing' ||
        !canGuideRound ||
        view.public.revealCursor != expectedCursor) {
      return false;
    }
    return _send(
      'reveal',
      RevealNextMessage.create(
        actionId: ActionId(_newId()),
        expectedRevision: view.revision,
        gameId: gameId,
        roundId: roundId,
        expectedCursor: expectedCursor,
      ),
    );
  }

  bool completeCase({required GameId gameId, required RoundId roundId}) {
    final view = snapshot;
    if (view == null ||
        !_sameRound(gameId, roundId) ||
        !canGuideRound ||
        view.public.phase != 'judged') {
      return false;
    }
    return _send(
      'complete',
      CompleteCaseMessage.create(
        actionId: ActionId(_newId()),
        expectedRevision: view.revision,
        gameId: gameId,
        roundId: roundId,
      ),
    );
  }

  bool continueRule({required GameId gameId, required int afterCase}) {
    final view = snapshot;
    if (view == null ||
        view.public.gameId != gameId ||
        !canGuideRound ||
        view.public.phase != 'rule_event' ||
        view.public.completedCases != afterCase) {
      return false;
    }
    return _send(
      'continue',
      ContinueRuleMessage.create(
        actionId: ActionId(_newId()),
        expectedRevision: view.revision,
        gameId: gameId,
        afterCase: afterCase,
      ),
    );
  }

  bool resumePaused({required GameId gameId}) {
    final view = snapshot;
    if (view == null ||
        view.public.gameId != gameId ||
        view.you != view.public.hostId ||
        view.public.phase != 'paused' ||
        view.public.pauseReason == 'insufficient_players' && activeCount < 3) {
      return false;
    }
    return _send(
      'resume',
      ResumePausedMessage.create(
        actionId: ActionId(_newId()),
        expectedRevision: view.revision,
        gameId: gameId,
      ),
    );
  }

  bool restartGame({required GameId gameId, bool confirmed = false}) {
    final view = snapshot;
    if (!confirmed ||
        view == null ||
        view.public.gameId != gameId ||
        view.you != view.public.hostId ||
        activeCount < 3) {
      return false;
    }
    return _send(
      'restart',
      RestartGameMessage.create(
        actionId: ActionId(_newId()),
        expectedRevision: view.revision,
        gameId: gameId,
        config: view.public.config,
        confirmed: true,
      ),
    );
  }

  bool completeWithoutVerdict({
    required GameId gameId,
    required RoundId roundId,
    bool confirmed = false,
  }) {
    final view = snapshot;
    if (!confirmed ||
        view == null ||
        !_sameRound(gameId, roundId) ||
        !(view.you == view.public.hostId ||
            !view.public.config.allJudges && canGuideRound) ||
        ![
          'numbers',
          'answers',
          'ordering',
          'revealing',
          'judged',
          'paused',
        ].contains(view.public.phase)) {
      return false;
    }
    return _send(
      'complete',
      CompleteWithoutVerdictMessage.create(
        actionId: ActionId(_newId()),
        expectedRevision: view.revision,
        gameId: gameId,
        roundId: roundId,
        confirmed: true,
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _visible = false;
    _ackPending = false;
    _pending.clear();
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
