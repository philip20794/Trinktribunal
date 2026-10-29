import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../design/court_celebration.dart';
import '../../design/court_drag_hint.dart';
import '../verdict/personal_verdict.dart';

import '../../data/protocol/room_message.dart';
import '../../domain/avatar_config.dart';
import '../../domain/models/player.dart';
import '../../domain/user_profile.dart';
import '../bench/bench_view.dart';
import 'game_progress.dart';
import 'order_view.dart';
import 'pending_profile.dart';
import '../../l10n/app_strings.dart';

class RoomCourtroom extends ConsumerStatefulWidget {
  const RoomCourtroom({
    required this.snapshot,
    this.fixedActions = false,
    this.active = true,
    super.key,
  });
  final SnapshotMessage snapshot;
  final bool fixedActions;
  final bool active;
  @override
  ConsumerState<RoomCourtroom> createState() => _RoomCourtroomState();
}

class _RoomCourtroomState extends ConsumerState<RoomCourtroom> {
  bool _checkedTutorial = false, _tutorial = false;
  String? _dismissedResult;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkTutorial();
  }

  @override
  void didUpdateWidget(RoomCourtroom oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    if (!widget.active ||
        _checkedTutorial ||
        !widget.snapshot.public.config.allJudges ||
        ![
          'numbers',
          'answers',
          'ordering',
        ].contains(widget.snapshot.public.phase)) {
      return;
    }
    _checkedTutorial = true;
    try {
      final store = ref.read(stringStoreProvider);
      final seen = await store.read('online.courtTutorialSeen.v1');
      if (!mounted || seen == 'true') return;
      await store.write('online.courtTutorialSeen.v1', 'true');
      if (mounted) setState(() => _tutorial = true);
    } catch (_) {
      /* Noncritical preferences must never interrupt the round. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot, fixedActions = widget.fixedActions;
    final players = snapshot.public.players;
    final content = ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if ([
          'numbers',
          'answers',
          'ordering',
          'revealing',
          'judged',
        ].contains(snapshot.public.phase))
          OnlineOrderView(snapshot: snapshot, showActions: !fixedActions)
        else if (['paused', 'finished'].contains(snapshot.public.phase))
          OnlineGameProgress(snapshot: snapshot, showActions: !fixedActions)
        else
          BenchView(
            compactControls: true,
            order: players.map((p) => p.playerId).toList(),
            profiles: {
              for (final player in players)
                player.playerId: UserProfile(
                  player: Player(
                    id: player.playerId,
                    name: needsRoomName(player.profile.name)
                        ? context.tr('roomUnnamedPlayer')
                        : player.profile.name,
                  ),
                  avatar: AvatarConfig.fromJson(player.profile.avatar.toJson()),
                ),
            },
          ),
      ],
    );
    final ownResult = snapshot.public.phase == 'judged'
        ? snapshot.private.ownResult
        : null;
    final round = snapshot.public.roundId?.value;
    return TickerMode(
      enabled: widget.active,
      child: Stack(
        children: [
          Positioned.fill(child: content),
          if (widget.active &&
              _tutorial &&
              [
                'numbers',
                'answers',
                'ordering',
              ].contains(snapshot.public.phase))
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: CourtDragHint(
                avatar: AvatarConfig.fromJson(
                  players.first.profile.avatar.toJson(),
                ),
                name: players.first.profile.name,
                onFinished: () {
                  if (mounted) setState(() => _tutorial = false);
                },
              ),
            ),
          if (ownResult != null && ownResult.sips == 0)
            Positioned.fill(child: CourtCelebration(key: ValueKey(round))),
          if (ownResult != null &&
              ownResult.sips > 0 &&
              _dismissedResult != round)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        PersonalVerdict(snapshot: snapshot),
                        Positioned(
                          top: 6,
                          right: 12,
                          child: IconButton(
                            tooltip: context.tr('roomToolsClose'),
                            icon: const Icon(Icons.close, color: Colors.black),
                            onPressed: () =>
                                setState(() => _dismissedResult = round),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
