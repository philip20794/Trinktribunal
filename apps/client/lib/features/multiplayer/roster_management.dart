import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart';
import '../../data/room_transport.dart';
import '../../domain/models/ids.dart';
import '../../l10n/app_strings.dart';
import 'pending_profile.dart';

List<PlayerId> nextRoomRoster(PublicView view) => view.pendingRoster.isNotEmpty
    ? view.pendingRoster
    : view.players
          .where((p) => p.active != false)
          .map((p) => p.playerId)
          .toList();

/// Seating changes target the next case; the current bench remains frozen.
class OnlineRosterManagement extends ConsumerWidget {
  const OnlineRosterManagement({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = snapshot.public,
        next = nextRoomRoster(view),
        controller = ref.read(roomControllerProvider),
        host = snapshot.you == view.hostId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view.pendingRoster.isNotEmpty) const TText('phoneRosterNotice'),
        for (final player in view.players)
          ListTile(
            key: ValueKey('presence-${player.playerId.value}'),
            title: Text(
              needsRoomName(player.profile.name)
                  ? context.tr('roomUnnamedPlayer')
                  : player.profile.name,
            ),
            subtitle: TText(
              !next.contains(player.playerId)
                  ? 'onlineRosterLeaving'
                  : view.frozenRoster.isNotEmpty &&
                        !view.frozenRoster.contains(player.playerId)
                  ? 'onlineRosterJoining'
                  : player.connected
                  ? 'roomPresent'
                  : 'roomDisconnected',
            ),
            leading: player.playerId == view.hostId
                ? const Chip(label: TText('roomHost'))
                : null,
            trailing: host && next.contains(player.playerId)
                ? PopupMenuButton<String>(
                    tooltip: context.tr('roomManagePlayer', {
                      'name': needsRoomName(player.profile.name)
                          ? context.tr('roomUnnamedPlayer')
                          : player.profile.name,
                    }),
                    itemBuilder: (_) => [
                      if (next.indexOf(player.playerId) > 0)
                        const PopupMenuItem(
                          value: 'up',
                          child: TText('roomMoveUp'),
                        ),
                      if (next.indexOf(player.playerId) < next.length - 1)
                        const PopupMenuItem(
                          value: 'down',
                          child: TText('roomMoveDown'),
                        ),
                      if (player.playerId != view.hostId)
                        const PopupMenuItem(
                          value: 'kick',
                          child: TText('roomKick'),
                        ),
                    ],
                    onSelected: (action) async {
                      if (action == 'kick') {
                        ref.read(onlineGameProvider).hideSecret();
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const TText('roomKickTitle'),
                            content: Text(
                              context.tr('roomKickBody', {
                                'name': needsRoomName(player.profile.name)
                                    ? context.tr('roomUnnamedPlayer')
                                    : player.profile.name,
                              }),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const TText('cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const TText('roomKick'),
                              ),
                            ],
                          ),
                        );
                        if (!context.mounted || confirmed != true) return;
                      }
                      final latest = controller.state.snapshot;
                      if (latest == null ||
                          latest.public.gameId != view.gameId ||
                          latest.you != latest.public.hostId) {
                        return;
                      }
                      final roster = List<PlayerId>.of(
                            nextRoomRoster(latest.public),
                          ),
                          index = roster.indexOf(player.playerId);
                      if (index < 0) return;
                      if (action == 'kick') {
                        controller.sendAction(
                          KickMessage.create(
                            actionId: ActionId(newRoomRequestId()),
                            expectedRevision: latest.revision,
                            targetPlayerId: player.playerId,
                            confirmed: true,
                          ),
                        );
                      } else {
                        final target = index + (action == 'up' ? -1 : 1);
                        if (target < 0 || target >= roster.length) return;
                        roster.insert(target, roster.removeAt(index));
                        controller.sendAction(
                          ReorderRosterMessage.create(
                            actionId: ActionId(newRoomRequestId()),
                            expectedRevision: latest.revision,
                            playerIds: roster,
                          ),
                        );
                      }
                    },
                  )
                : null,
          ),
      ],
    );
  }
}
