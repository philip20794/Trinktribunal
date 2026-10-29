import 'package:flutter/material.dart';

import '../../data/protocol/room_message.dart';
import '../../domain/avatar_config.dart';
import '../../domain/models/player.dart';
import '../../domain/user_profile.dart';
import '../bench/bench_view.dart';
import 'game_progress.dart';
import 'order_view.dart';

class RoomCourtroom extends StatelessWidget {
  const RoomCourtroom({
    required this.snapshot,
    this.fixedActions = false,
    super.key,
  });
  final SnapshotMessage snapshot;
  final bool fixedActions;
  @override
  Widget build(BuildContext context) {
    final players = snapshot.public.players;
    return ListView(
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
                    name: player.profile.name,
                  ),
                  avatar: AvatarConfig.fromJson(player.profile.avatar.toJson()),
                ),
            },
          ),
      ],
    );
  }
}
