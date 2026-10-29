import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart' as protocol;
import '../../design/court_scene.dart';
import '../../design/status_notice.dart';
import '../../domain/avatar_config.dart';
import '../../domain/selection/random_source.dart';
import '../../l10n/app_strings.dart';
import 'connection.dart';
import 'invitation.dart';
import 'pending_profile.dart';

/// An invitation is consent to join. No second join confirmation is required.
class DirectJoinRoomScreen extends ConsumerStatefulWidget {
  const DirectJoinRoomScreen({required this.code, super.key});
  final String code;

  @override
  ConsumerState<DirectJoinRoomScreen> createState() =>
      _DirectJoinRoomScreenState();
}

class _DirectJoinRoomScreenState extends ConsumerState<DirectJoinRoomScreen> {
  bool _busy = false;
  bool _started = false;
  bool _retrySave = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enter();
    });
  }

  Future<void> _enter({bool retry = false}) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _started = true;
      _error = null;
    });
    try {
      final controller = ref.read(roomControllerProvider);
      bool success;
      if (retry && _retrySave) {
        success = await controller.retrySavingCredential();
      } else {
        final saved = await ref.read(roomCredentialStoreProvider).load();
        if (!mounted) return;
        final existing = saved.credentials.where(
          (credential) =>
              credential.message.roomCode == widget.code &&
              credential.serverOrigin == controller.transport.serverOrigin &&
              credential.pendingLeaveActionId == null,
        );
        if (existing.isNotEmpty) {
          await controller.resume(existing.first);
          success = true;
        } else {
          // The profile is deliberately incomplete until edited inside the room.
          final local = (await ref.read(profileProvider.future)).profile;
          if (!mounted) return;
          success = await controller.join(
            widget.code,
            protocol.Profile.fromJson({
              'name': pendingRoomProfileName,
              'avatar': (local?.avatar ??
                      AvatarConfig.random(SecureRandomSource()))
                  .toJson(),
            }),
          );
        }
      }
      ref.invalidate(savedRoomsProvider);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const RoomConnectionScreen(),
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
    } on Object {
      if (mounted) setState(() => _error = 'roomErrorServer');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: const TText('roomJoin'),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _busy || !_started
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) StatusNotice(context.tr(_error!)),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('direct-join-retry'),
                    onPressed: () => _enter(retry: true),
                    child: TText(_retrySave ? 'roomSaveRetry' : 'roomRetry'),
                  ),
                ],
              ),
      ),
    ),
  );
}
