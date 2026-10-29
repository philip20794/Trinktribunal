import '../../design/status_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../design/avatar_view.dart';
import '../profile/avatar_options.dart';
import '../../l10n/app_strings.dart';
import 'invitation.dart';

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
        if (_name.text != editor.name) {
          _name.value = TextEditingValue(
            text: editor.name,
            selection: TextSelection.collapsed(offset: editor.name.length),
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Center(
                  child: AvatarView(
                    config: editor.avatar,
                    size: 200,
                    label: editor.name,
                    playerName: editor.name,
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('online-name'),
                  controller: _name,
                  maxLength: 24,
                  decoration: InputDecoration(
                    labelText: context.tr('profileName'),
                  ),
                  onChanged: editor.rename,
                  onEditingComplete: editor.flush,
                ),
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
                const SizedBox(height: 12),
                SizedBox(
                  height: 380,
                  child: AvatarOptions(
                    config: editor.avatar,
                    keyPrefix: 'online-',
                    onChanged: editor.changeAvatar,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
