import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_controller.dart';
import '../../application/room_providers.dart';
import '../../l10n/app_strings.dart';
import 'invitation.dart';
import 'invite.dart';
import 'lobby.dart';

class RoomConnectionScreen extends ConsumerWidget {
  const RoomConnectionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(roomSessionProvider, (previous, next) {
      final status = next.asData?.value.status;
      if (status == RoomConnectionStatus.closed ||
          status == RoomConnectionStatus.error) {
        ref.invalidate(savedRoomsProvider);
      }
    });
    final session = ref.watch(roomSessionProvider),
        controller = ref.read(roomControllerProvider);
    final state = session.asData?.value ?? controller.state;
    if (state.status == RoomConnectionStatus.online && state.snapshot != null) {
      return RoomLobbyScreen(state: state);
    }
    return Scaffold(
      appBar: AppBar(title: const TText('roomTitle')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                context.tr(switch (state.status) {
                  RoomConnectionStatus.connecting => 'roomConnecting',
                  RoomConnectionStatus.online => 'roomOnline',
                  RoomConnectionStatus.reconnecting => 'roomReconnecting',
                  RoomConnectionStatus.closed => 'roomClosed',
                  RoomConnectionStatus.error => 'roomConnectionError',
                }),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (state.status == RoomConnectionStatus.connecting ||
                  state.status == RoomConnectionStatus.reconnecting)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (state.errorCode != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: TText(roomErrorKey(state.errorCode)),
                ),
              if (state.snapshot != null) ...[
                const SizedBox(height: 16),
                Text(
                  context.tr('roomJoinedCount', {
                    'count': state.snapshot!.public.players.length,
                  }),
                ),
                const SizedBox(height: 16),
                if (controller.roomCode != null)
                  RoomInvite(code: controller.roomCode!),
              ],
              if (state.status == RoomConnectionStatus.error ||
                  state.errorCode == 'SESSION_REPLACED')
                FilledButton(
                  onPressed: () async {
                    await controller.retrySavingCredential();
                    ref.invalidate(savedRoomsProvider);
                  },
                  child: const TText('roomRetry'),
                ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const TText('roomLeaveTitle'),
                      content: const TText('roomLeaveBody'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const TText('cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const TText('roomLeave'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  final left = await controller.leave();
                  ref.invalidate(savedRoomsProvider);
                  if (left && context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: const TText('roomLeave'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
