import '../../design/status_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../design/avatar_view.dart';
import '../../domain/avatar_config.dart';
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
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: AvatarView(
                    config: editor.avatar,
                    size: 128,
                    label: editor.name,
                  ),
                ),
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
                for (final category in AvatarCatalog.options.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        'online-${category.key}:${editor.avatar[category.key]}',
                      ),
                      initialValue: editor.avatar[category.key],
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('avatarCategory${category.key}'),
                      ),
                      items: category.value
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(context.tr('avatarOption$value')),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          editor.changeAvatar(
                            editor.avatar.withOption(category.key, value),
                          );
                        }
                      },
                    ),
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
                FilledButton(
                  onPressed: editor.dirty ? editor.flush : null,
                  child: const TText('roomProfileFlush'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
