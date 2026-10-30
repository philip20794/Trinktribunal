import '../../design/court_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart';
import '../../data/room_transport.dart';
import '../../domain/models/ids.dart';
import '../../l10n/app_strings.dart';

Future<void> confirmRoomClose(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(roomControllerProvider),
      before = controller.state.snapshot;
  if (before == null || before.you != before.public.hostId) return;
  ref.read(onlineGameProvider).hideSecret();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => CourtDialog(
      title: const TText('roomCloseTitle'),
      content: const TText('roomCloseHelp'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const TText('roomClose'),
        ),
      ],
    ),
  );
  if (!context.mounted || confirmed != true) return;
  final latest = controller.state.snapshot;
  if (latest == null ||
      latest.roomId != before.roomId ||
      latest.public.gameId != before.public.gameId ||
      latest.you != latest.public.hostId) {
    return;
  }
  controller.sendAction(
    CloseRoomMessage.create(
      actionId: ActionId(newRoomRequestId()),
      expectedRevision: latest.revision,
      confirmed: true,
    ),
  );
}
