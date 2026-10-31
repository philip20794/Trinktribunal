import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart';
import '../../l10n/app_strings.dart';
import 'invite.dart';
import 'invitation.dart';
import '../../design/status_notice.dart';

import 'game_settings.dart';
import 'roster_management.dart';

class RoomTools extends ConsumerWidget {
  const RoomTools({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (snapshot.you != snapshot.public.hostId) return const SizedBox.shrink();
    final code = ref.watch(roomControllerProvider).roomCode;
    final demos = ref.watch(demoPlayersProvider);
    return Material(
      color: Colors.transparent,
      child: Column(
        key: const PageStorageKey('host-room-tools'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (code != null) RoomInvite(code: code),
          const SizedBox(height: 8),
          RoomGameSettings(
            key: const PageStorageKey('room-game-settings'),
            snapshot: snapshot,
          ),
          if (snapshot.public.gameId != null &&
              !['lobby', 'finished'].contains(snapshot.public.phase))
            ListenableBuilder(
              listenable: ref.watch(onlineGameProvider),
              builder: (context, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  key: const ValueKey('stop-room-game'),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const TText('stopGame'),
                  onPressed: ref.read(onlineGameProvider).pending('setup')
                      ? null
                      : () => ref
                            .read(onlineGameProvider)
                            .returnToSetup(gameId: snapshot.public.gameId!),
                ),
              ),
            ),

          ListenableBuilder(
            listenable: demos,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('add-demo-player'),
                  onPressed: demos.canAdd ? demos.add : null,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: TText(demos.adding ? 'roomDemoAdding' : 'roomDemoAdd'),
                ),
                const TText('roomDemoHelp'),
                if (demos.errorCode != null)
                  StatusNotice(context.tr(roomErrorKey(demos.errorCode))),
                const SizedBox(height: 12),
              ],
            ),
          ),
          ExpansionTile(
            key: const PageStorageKey('room-presence'),
            title: const TText('roomConnections'),
            children: [OnlineRosterManagement(snapshot: snapshot)],
          ),
        ],
      ),
    );
  }
}
