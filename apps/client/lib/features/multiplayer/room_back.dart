import '../../design/court_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart';
import '../../data/room_transport.dart';
import '../../domain/models/ids.dart';
import '../../l10n/app_strings.dart';

class RoomBackGuard extends ConsumerStatefulWidget {
  const RoomBackGuard({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<RoomBackGuard> createState() => _RoomBackGuardState();
}

class _RoomBackGuardState extends ConsumerState<RoomBackGuard> {
  bool _allowPop = false, _dialogOpen = false, _closing = false;

  Future<void> _back() async {
    if (_dialogOpen || _closing) return;
    _dialogOpen = true;
    ref.read(onlineGameProvider).hideSecret();
    final controller = ref.read(roomControllerProvider);
    final before = controller.state.snapshot;
    if (before == null) {
      _dialogOpen = false;
      _pop();
      return;
    }
    final host = before.you == before.public.hostId;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => CourtDialog(
        title: TText(host ? 'roomCloseTitle' : 'roomLeaveTitle'),
        content: TText(host ? 'roomBackHostHelp' : 'roomBackHelp'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'back'),
            child: const TText('roomBackOnly'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'leave'),
            child: TText(host ? 'roomClose' : 'roomLeave'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted || choice == null) return;
    if (choice == 'leave') {
      if (host) {
        final latest = controller.state.snapshot;
        if (latest == null ||
            latest.roomId != before.roomId ||
            latest.you != latest.public.hostId) {
          return;
        }
        _closing = controller.sendAction(
          CloseRoomMessage.create(
            actionId: ActionId(newRoomRequestId()),
            expectedRevision: latest.revision,
            confirmed: true,
          ),
        );
        return;
      } else if (!await controller.leave()) {
        return;
      }
      if (!mounted) return;
      ref.invalidate(savedRoomsProvider);
    }
    _pop();
  }

  void _pop() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(roomSessionProvider, (previous, next) {
      if (!_closing) return;
      final state = next.asData?.value;
      if (state == null) return;
      if (state.snapshot == null && state.errorCode == 'ROOM_UNAVAILABLE') {
        _closing = false;
        ref.invalidate(savedRoomsProvider);
        _pop();
      } else if (state.errorCode != null) {
        _closing = false;
      }
    });
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: widget.child,
    );
  }
}
