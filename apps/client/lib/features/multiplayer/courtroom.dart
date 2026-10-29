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
import 'invite.dart';
import '../../design/court_scene.dart';
import 'game_progress.dart';
import 'order_view.dart';
import 'roster_management.dart';
import 'host_status.dart';

class RoomCourtroom extends ConsumerStatefulWidget {
  const RoomCourtroom({
    required this.snapshot,
    this.fixedActions = false,
    super.key,
  });
  final SnapshotMessage snapshot;
  final bool fixedActions;
  @override
  ConsumerState<RoomCourtroom> createState() => _RoomCourtroomState();
}

class _RoomCourtroomState extends ConsumerState<RoomCourtroom> {
  bool _expanded = true;
  final _scroll = ScrollController(keepScrollOffset: false);
  final _toggleFocus = FocusNode();
  @override
  void dispose() {
    _scroll.dispose();
    _toggleFocus.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _toggleFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot, fixedActions = widget.fixedActions;
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

    return Stack(
      children: [
        ListView(
          key: ValueKey('room-contents-$_expanded'),
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          children: [
            if (snapshot.public.phase == 'lobby' && _expanded) _tools(context),
            if (snapshot.public.hostRevision > 0 ||
                players.any(
                  (p) => p.playerId == snapshot.public.hostId && !p.connected,
                ))
              OnlineHostStatus(snapshot: snapshot),
            if (['paused', 'finished'].contains(snapshot.public.phase))
              OnlineGameProgress(
                snapshot: snapshot,
                showActions: !fixedActions,
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(right: 48),
              child: Text(
                context.tr('roomJoinedCount', {
                  'count': players.where((p) => p.active != false).length,
                }),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            if ([
              'ordering',
              'revealing',
              'judged',
            ].contains(snapshot.public.phase))
              OnlineOrderView(snapshot: snapshot, showActions: !fixedActions)
            else if (snapshot.public.frozenRoster.any(
              (id) => !players.any((p) => p.playerId == id),
            ))
              const TText('onlineOrderMissing')
            else
              BenchView(
                compactControls: snapshot.public.phase == 'lobby',
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
                      avatar: AvatarConfig.fromJson(
                        player.profile.avatar.toJson(),
                      ),
                    ),
                },
                onMove: host && snapshot.public.phase == 'lobby'
                    ? reorder
                    : null,
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
        ),
        if (snapshot.public.phase == 'lobby')
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: CourtSceneTokens.panel,
              shape: const CircleBorder(),
              elevation: 4,
              child: IconButton(
                key: const ValueKey('room-tools-toggle'),
                focusNode: _toggleFocus,
                tooltip: context.tr(
                  _expanded ? 'roomToolsCollapse' : 'roomToolsExpand',
                ),
                onPressed: _toggle,
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tools(BuildContext context) {
    final code = ref.read(roomControllerProvider).roomCode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CourtPaper(
        child: Padding(
          padding: const EdgeInsets.only(top: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(onlineGameProvider).hideSecret();
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoomSettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.tune),
                label: const TText('localGameOptions'),
              ),
              const SizedBox(height: 16),
              if (code != null) RoomInvite(code: code),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('room-tools-close'),
                onPressed: _toggle,
                child: const TText('roomToolsClose'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
