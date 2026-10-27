import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../l10n/app_strings.dart';

Future<void> confirmRoomLeave(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(roomControllerProvider);
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
}
