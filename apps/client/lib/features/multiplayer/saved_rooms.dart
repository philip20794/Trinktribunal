import '../../design/court_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../application/room_controller.dart';
import '../../data/room_credential_store.dart';
import '../../l10n/app_strings.dart';
import 'connection.dart';

Future<void> resumeSavedRoom(
  BuildContext context,
  WidgetRef ref,
  RoomCredential credential, {
  bool replaceRoute = false,
}) async {
  final controller = ref.read(roomControllerProvider);
  final active = controller.state.snapshot;
  if (controller.state.status != RoomConnectionStatus.online ||
      active?.roomId != credential.message.roomId ||
      active?.you != credential.message.playerId) {
    await controller.resume(credential);
  }
  ref.invalidate(savedRoomsProvider);
  if (context.mounted) {
    final route = MaterialPageRoute<void>(
      builder: (_) => const RoomConnectionScreen(),
    );
    if (replaceRoute) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }
}

class SavedRooms extends ConsumerWidget {
  const SavedRooms({this.code, super.key});
  final String? code;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(savedRoomsProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const TText('roomErrorStorage'),
        data: (loaded) {
          final rooms = loaded.credentials
              .where((room) => code == null || room.message.roomCode == code)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loaded.unavailable || loaded.invalidRecords)
                const TText('roomErrorStorage'),
              if (rooms.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: TText('roomContinue'),
                ),
              for (final room in rooms)
                Card(
                  child: ListTile(
                    title: Text(
                      context.tr('roomSavedLabel', {
                        'code': room.message.roomCode,
                        'player': room.message.playerId.value.substring(
                          0,
                          room.message.playerId.value.length.clamp(0, 8),
                        ),
                      }),
                    ),
                    subtitle: Text(
                      room.pendingLeaveActionId != null
                          ? context.tr('roomLeavePending')
                          : context.tr('roomSavedReady'),
                    ),
                    leading: const Icon(Icons.meeting_room_outlined),
                    onTap: () async {
                      try {
                        await resumeSavedRoom(context, ref, room);
                      } on Object {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: TText('roomErrorServer')),
                          );
                        }
                      }
                    },
                    trailing: IconButton(
                      tooltip: context.tr('roomForget'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => CourtDialog(
                            title: const TText('roomForget'),
                            content: const TText('roomForgetBody'),
                            actions: [
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const TText('roomForget'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;
                        try {
                          RoomController? active;
                          try {
                            if (ref.exists(roomControllerProvider)) {
                              active = ref.read(roomControllerProvider);
                            }
                          } on Object {
                            /* A failed transport is unnecessary for local deletion. */
                          }
                          if (active != null) {
                            await active.forgetLocally(room);
                          } else {
                            await ref
                                .read(roomCredentialStoreProvider)
                                .remove(room);
                          }
                          ref.invalidate(savedRoomsProvider);
                        } on Object {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: TText('roomErrorStorage'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

/// Resume a persisted identity rather than creating another room or player.
class CurrentRoomResumeButtons extends ConsumerWidget {
  const CurrentRoomResumeButtons({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(savedRoomsProvider)
      .maybeWhen(
        data: (loaded) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final room in loaded.credentials.where(
              (r) => r.pendingLeaveActionId == null,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton.icon(
                  key: ValueKey('resume-room-${room.message.roomCode}'),
                  icon: const Icon(Icons.meeting_room_outlined),
                  label: Text(
                    context.tr('roomReturnActive', {
                      'code': room.message.roomCode,
                    }),
                  ),
                  onPressed: () async {
                    try {
                      await resumeSavedRoom(
                        context,
                        ref,
                        room,
                        replaceRoute: true,
                      );
                    } on Object {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: TText('roomErrorServer')),
                        );
                      }
                    }
                  },
                ),
              ),
          ],
        ),
        orElse: () => const SizedBox.shrink(),
      );
}
