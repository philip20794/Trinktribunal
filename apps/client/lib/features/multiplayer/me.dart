import '../../design/status_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../profile/avatar_editor.dart';
import '../../l10n/app_strings.dart';
import 'invitation.dart';
import 'pending_profile.dart';
import '../../design/court_scene.dart';

class RoomProfileScreen extends ConsumerWidget {
  const RoomProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(onlineProfileProvider);
    return CourtScaffold(
      title: const TText('profileTitle'),
      body: const RoomMe(),
      footer: CourtActionBar(
        primary: ListenableBuilder(
          listenable: editor,
          builder: (context, _) => FilledButton(
            onPressed: editor.available && editor.dirty && !editor.saving
                ? editor.flush
                : null,
            child: TText(
              editor.saving ? 'roomProfileSaving' : 'roomProfileFlush',
            ),
          ),
        ),
      ),
    );
  }
}

class RoomMe extends ConsumerStatefulWidget {
  const RoomMe({super.key});
  @override
  ConsumerState<RoomMe> createState() => _RoomMeState();
}

class _RoomMeState extends ConsumerState<RoomMe> {
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(onlineProfileProvider);
    return ListenableBuilder(
      listenable: editor,
      builder: (context, _) {
        if (!editor.available) {
          return const Center(child: CircularProgressIndicator());
        }
        final pending = needsRoomName(editor.name);
        final displayName = pending ? '' : editor.name;
        if (_name.text != displayName) {
          _name.value = TextEditingValue(
            text: displayName,
            selection: TextSelection.collapsed(offset: displayName.length),
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AvatarEditor(
              config: editor.avatar,
              nameController: _name,
              nameKey: const ValueKey('online-name'),
              previewKey: const ValueKey('online-avatar-preview'),
              keyPrefix: 'online-',
              onNameChanged: editor.rename,
              onNameEditingComplete: editor.flush,
              onChanged: editor.changeAvatar,
              notice: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pending && _name.text.trim().isEmpty)
                    StatusNotice(context.tr('roomNameRequired')),
                  Text(
                    context.tr(
                      editor.saving
                          ? 'roomProfileSaving'
                          : editor.dirty
                          ? 'roomProfilePending'
                          : 'roomProfileConfirmed',
                    ),
                  ),
                  if (editor.errorCode != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: StatusNotice(
                        context.tr(roomErrorKey(editor.errorCode)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
