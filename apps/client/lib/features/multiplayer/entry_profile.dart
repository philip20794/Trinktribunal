import '../../design/status_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart' as protocol;
import '../../data/room_transport.dart';
import '../../design/avatar_view.dart';
import '../../domain/avatar_config.dart';
import '../../l10n/app_strings.dart';
import '../../design/court_scene.dart';
import '../profile/profile_screen.dart';
import 'connection.dart';
import 'invitation.dart';
import 'saved_rooms.dart';

class RoomProfileForm extends ConsumerStatefulWidget {
  const RoomProfileForm({
    required this.create,
    this.initialCode = '',
    this.invalidInvite = false,
    super.key,
  });
  final bool create, invalidInvite;
  final String initialCode;
  @override
  ConsumerState<RoomProfileForm> createState() => _RoomProfileFormState();
}

class _RoomProfileFormState extends ConsumerState<RoomProfileForm> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _codeFocus = FocusNode();
  late final _code = TextEditingController(text: widget.initialCode);
  var _avatar = AvatarConfig();
  bool _initialized = false, _busy = false, _canRetrySave = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _nameFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  String? get _normalized {
    try {
      return normalizedRoomCode(_code.text);
    } on Object {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _canRetrySave = false;
    });
    try {
      final profile = protocol.Profile.fromJson({
        'name': _name.text.trim(),
        'avatar': _avatar.toJson(),
      });
      if (!widget.create && _normalized == null) {
        throw const protocol.ProtocolDecodeException('INVALID_ROOM_CODE');
      }
      final controller = ref.read(roomControllerProvider);
      final success = widget.create
          ? await controller.create(profile)
          : await controller.join(_normalized!, profile);
      ref.invalidate(savedRoomsProvider);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const RoomConnectionScreen()),
        );
      } else {
        setState(() {
          _error = roomErrorKey(controller.state.errorCode);
          _canRetrySave =
              controller.state.errorCode == 'CREDENTIAL_STORAGE_UNAVAILABLE' &&
              controller.roomCode != null;
        });
      }
    } on protocol.ProtocolDecodeException catch (error) {
      if (mounted) setState(() => _error = roomErrorKey(error.code));
    } on Object {
      if (mounted) setState(() => _error = 'roomErrorServer');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_error == 'roomErrorName' || _error == 'roomErrorCode') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              (_error == 'roomErrorName' ? _nameFocus : _codeFocus)
                  .requestFocus();
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).asData?.value.profile;
    if (!_initialized && profile != null) {
      _initialized = true;
      _name.text = profile.player.name;
      _avatar = profile.avatar;
    }
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (widget.invalidInvite) const TText('roomInviteInvalid'),
                if (!widget.create) ...[
                  TextField(
                    key: const ValueKey('room-code'),
                    controller: _code,
                    focusNode: _codeFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _nameFocus.requestFocus(),
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: context.tr('roomCode'),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 64,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_normalized != null) SavedRooms(code: _normalized),
                  const SizedBox(height: 16),
                ],
                AvatarView(
                  config: _avatar,
                  size: 112,
                  label: context.tr('profilePreview'),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('room-name'),
                  controller: _name,
                  focusNode: _nameFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) => _initialized = true,
                  enabled: !_busy,
                  maxLength: 24,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: context.tr('profileName'),
                    helperText: context.tr('profileLength'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                          if (!mounted) return;
                          final loaded = (await ref.read(
                            profileProvider.future,
                          )).profile;
                          if (!mounted) return;
                          if (loaded != null) {
                            setState(() {
                              _name.text = loaded.player.name;
                              _avatar = loaded.avatar;
                              _initialized = true;
                            });
                          }
                        },
                  icon: const Icon(Icons.edit_outlined),
                  label: const TText('roomEditTemplate'),
                ),
                const SizedBox(height: 16),
                if (_canRetrySave)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            final success = await ref
                                .read(roomControllerProvider)
                                .retrySavingCredential();
                            ref.invalidate(savedRoomsProvider);
                            if (!context.mounted) return;
                            setState(() => _busy = false);
                            if (success) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) => const RoomConnectionScreen(),
                                ),
                              );
                            }
                          },
                    child: const TText('roomSaveRetry'),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .6),
            child: SingleChildScrollView(
              child: CourtActionBar(
                primary: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: StatusNotice(context.tr(_error!)),
                      ),

                    FilledButton(
                      key: const ValueKey('room-submit'),
                      onPressed: _busy || _canRetrySave ? null : _submit,
                      child: TText(
                        widget.create ? 'roomCreate' : 'roomJoinNew',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
