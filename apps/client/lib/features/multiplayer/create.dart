import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../design/court_scene.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart' as protocol;
import '../../domain/avatar_config.dart';
import '../../domain/selection/random_source.dart';
import '../../design/status_notice.dart';
import 'connection.dart';
import 'invitation.dart';
import 'join.dart';
import 'saved_rooms.dart';
import '../../application/hosted_room_controller.dart';
import '../../data/room_transport.dart';

class MultiplayerEntryScreen extends StatefulWidget {
  const MultiplayerEntryScreen({super.key});
  @override
  State<MultiplayerEntryScreen> createState() => _MultiplayerEntryScreenState();
}

class _MultiplayerEntryScreenState extends State<MultiplayerEntryScreen> {
  bool _creating = false;
  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const CreateRoomScreen()));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: const TText('modeMulti'),
    bodyBuilder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const TText('roomEntryIntro'),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const TText('roomCreate'),
              onPressed: _creating ? null : _create,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.login),
              label: const TText('roomJoin'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const JoinRoomScreen()),
              ),
            ),
            const SizedBox(height: 20),
            const SavedRooms(),
          ],
        ),
      ),
    ),
  );
}

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  bool _busy = true, _retrySave = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  Future<void> _create({bool retry = false}) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(roomControllerProvider);
      bool success;
      if (retry && _retrySave) {
        success = await controller.retrySavingCredential();
      } else {
        final permitted =
            await HostedRoomController(
              controller,
              ref.read(roomCredentialStoreProvider),
            ).prepareNewRoom((codes) async {
              if (!mounted) return false;
              return await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const TText('replaceHostedRoomTitle'),
                      content: Text(
                        context.tr('replaceHostedRoomHelp', {
                          'codes': codes.join(', '),
                        }),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const TText('cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const TText('replaceHostedRoomConfirm'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
            });
        if (!mounted) return;
        if (!permitted) {
          if (Navigator.of(context).canPop()) Navigator.pop(context);
          return;
        }
        final saved = (await ref.read(profileProvider.future)).profile;
        if (!mounted) return;
        success = await controller.create(
          protocol.Profile.fromJson({
            'name': saved?.player.name ?? context.tr('roomDefaultName'),
            'avatar':
                (saved?.avatar ?? AvatarConfig.random(SecureRandomSource()))
                    .toJson(),
          }),
        );
      }
      ref.invalidate(savedRoomsProvider);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const RoomConnectionScreen(newRoom: true),
          ),
        );
      } else {
        setState(() {
          _error = roomErrorKey(controller.state.errorCode);
          _retrySave =
              controller.state.errorCode == 'CREDENTIAL_STORAGE_UNAVAILABLE' &&
              controller.roomCode != null;
        });
      }
    } on RoomTransportException catch (error) {
      if (mounted) setState(() => _error = roomErrorKey(error.code));
    } on Object {
      if (mounted) setState(() => _error = 'roomErrorServer');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: const TText('roomCreate'),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _busy
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) StatusNotice(context.tr(_error!)),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('room-create-retry'),
                    onPressed: () => _create(retry: true),
                    child: TText(_retrySave ? 'roomSaveRetry' : 'roomRetry'),
                  ),
                ],
              ),
      ),
    ),
  );
}
