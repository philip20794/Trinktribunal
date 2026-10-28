import '../../design/status_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_controller.dart';
import '../../application/room_providers.dart';
import '../../l10n/app_strings.dart';
import 'courtroom.dart';
import 'me.dart';
import 'invite.dart';
import 'invitation.dart';
import 'room_actions.dart';
import 'game_privacy.dart';
import 'close_room.dart';

class RoomLobbyScreen extends ConsumerWidget {
  const RoomLobbyScreen({required this.state, super.key});
  final RoomSessionState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 2,
    initialIndex: 1,
    child: RoomGamePrivacy(
      child: Scaffold(
        appBar: AppBar(
          title: const TText('roomTitle'),
          actions: [
            if (state.snapshot!.you == state.snapshot!.public.hostId)
              IconButton(
                tooltip: context.tr('roomClose'),
                icon: const Icon(Icons.gavel),
                onPressed: () => confirmRoomClose(context, ref),
              ),
            IconButton(
              tooltip: context.tr('roomInviteTitle'),
              icon: const Icon(Icons.qr_code),
              onPressed: () {
                ref.read(onlineGameProvider).hideSecret();
                final code = ref.read(roomControllerProvider).roomCode;
                if (code == null) return;
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const TText('roomInviteTitle'),
                    content: SingleChildScrollView(
                      child: RoomInvite(code: code),
                    ),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: context.tr('roomLeave'),
              icon: const Icon(Icons.logout),
              onPressed: () {
                ref.read(onlineGameProvider).hideSecret();
                confirmRoomLeave(context, ref);
              },
            ),
          ],
          bottom: TabBar(
            onTap: (_) {
              ref.read(onlineGameProvider).hideSecret();
              ref.read(onlineProfileProvider).flush();
            },
            tabs: [
              Tab(text: context.tr('roomMeTab')),
              Tab(text: context.tr('roomTitle')),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TText(
                'roomOnline',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            if (state.errorCode != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: StatusNotice(context.tr(roomErrorKey(state.errorCode))),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  const RoomMe(),
                  RoomCourtroom(snapshot: state.snapshot!),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
