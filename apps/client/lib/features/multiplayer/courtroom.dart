import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart';
import '../../data/room_transport.dart';
import '../../domain/avatar_config.dart';
import '../../domain/models/ids.dart';
import '../../domain/models/player.dart';
import '../../domain/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../bench/bench_view.dart';
import 'game_settings.dart';
import 'game_screen.dart';
import 'game_progress.dart';
import 'order_view.dart';
import 'roster_management.dart';

class RoomCourtroom extends ConsumerWidget {
  const RoomCourtroom({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(onlineHistoryProvider);
    final host = snapshot.you == snapshot.public.hostId,
        players = snapshot.public.players;
    final controller = ref.read(roomControllerProvider);
    void reorder(int from, int to) {
      final current = controller.state.snapshot;
      if (current == null) return;
      final ids = current.public.players
          .map((player) => player.playerId)
          .toList();
      if (from < 0 || to < 0 || from >= ids.length || to >= ids.length) return;
      ids.insert(to, ids.removeAt(from));
      controller.sendAction(
        ReorderRosterMessage.create(
          actionId: ActionId(newRoomRequestId()),
          expectedRevision: current.revision,
          playerIds: ids,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (snapshot.public.phase == 'lobby')
          RoomGameSettings(snapshot: snapshot)
        else
          RoomGameScreen(snapshot: snapshot),
        if (snapshot.public.phase != 'lobby')
          OnlineGameProgress(snapshot: snapshot),
        const SizedBox(height: 16),
        Text(
          context.tr('roomJoinedCount', {
            'count': players.where((p) => p.active != false).length,
          }),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (host)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: TText('roomHostControls'),
          ),
        const SizedBox(height: 12),
        if (['ordering', 'revealing', 'judged'].contains(snapshot.public.phase))
          OnlineOrderView(snapshot: snapshot)
        else if (snapshot.public.frozenRoster.any(
          (id) => !players.any((p) => p.playerId == id),
        ))
          const TText('onlineOrderMissing')
        else
          BenchView(
            order: snapshot.public.frozenRoster.isNotEmpty
                ? snapshot.public.frozenRoster
                : players.map((player) => player.playerId).toList(),
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
            onMove: host && snapshot.public.phase == 'lobby' ? reorder : null,
          ),
        const SizedBox(height: 12),
        if (snapshot.public.phase != 'lobby')
          OnlineRosterManagement(snapshot: snapshot),
        if (snapshot.public.phase == 'lobby')
          for (var index = 0; index < players.length; index++)
            Builder(
              builder: (context) {
                final player = players[index];
                return ListTile(
                  key: ValueKey('presence-${player.playerId.value}'),
                  title: Text(player.profile.name),
                  subtitle: Text(
                    context.tr(
                      player.connected ? 'roomPresent' : 'roomDisconnected',
                    ),
                  ),
                  leading: player.playerId == snapshot.public.hostId
                      ? const Chip(label: TText('roomHost'))
                      : null,
                  trailing: host && snapshot.public.phase == 'lobby'
                      ? PopupMenuButton<String>(
                          tooltip: context.tr('roomManagePlayer', {
                            'name': player.profile.name,
                          }),
                          itemBuilder: (_) => [
                            if (index > 0)
                              const PopupMenuItem(
                                value: 'up',
                                child: TText('roomMoveUp'),
                              ),
                            if (index < players.length - 1)
                              const PopupMenuItem(
                                value: 'down',
                                child: TText('roomMoveDown'),
                              ),
                            if (player.playerId != snapshot.public.hostId)
                              const PopupMenuItem(
                                value: 'kick',
                                child: TText('roomKick'),
                              ),
                          ],
                          onSelected: (action) async {
                            if (action == 'up') {
                              reorder(index, index - 1);
                              return;
                            }
                            if (action == 'down') {
                              reorder(index, index + 1);
                              return;
                            }
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const TText('roomKickTitle'),
                                content: Text(
                                  context.tr('roomKickBody', {
                                    'name': player.profile.name,
                                  }),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const TText('cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const TText('roomKick'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            final current = controller.state.snapshot;
                            if (current == null) return;
                            controller.sendAction(
                              KickMessage.create(
                                actionId: ActionId(newRoomRequestId()),
                                expectedRevision: current.revision,
                                targetPlayerId: player.playerId,
                                confirmed: true,
                              ),
                            );
                          },
                        )
                      : null,
                );
              },
            ),
      ],
    );
  }
}
