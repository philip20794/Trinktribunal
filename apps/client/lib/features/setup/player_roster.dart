import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/roster_controller.dart';
import '../../design/avatar_view.dart';
import '../../domain/avatar_config.dart';
import '../../domain/user_profile.dart';
import '../profile/avatar_options.dart';

class PlayerRosterScreen extends ConsumerStatefulWidget {
  const PlayerRosterScreen({super.key});
  @override
  ConsumerState<PlayerRosterScreen> createState() => _PlayerRosterScreenState();
}

class _PlayerRosterScreenState extends ConsumerState<PlayerRosterScreen> {
  bool _busy = false;
  Future<void> _act(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit(RosterController controller, [UserProfile? member]) async {
    final result = await showDialog<({String name, AvatarConfig avatar})>(
      context: context,
      builder: (context) => _RosterEditDialog(member: member),
    );
    if (!mounted || result == null) return;
    await _act(
      () => member == null
          ? controller.add(result.name, avatar: result.avatar)
          : controller.update(member.player.id, result.name, result.avatar),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ein Handy')),
    body: ref
        .watch(rosterProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(rosterProvider),
              child: const Text('Gruppe erneut laden'),
            ),
          ),
          data: (controller) {
            final own = ref.watch(profileProvider).asData?.value.profile;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Eure Sitzreihenfolge',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${controller.members.length} von 20 Personen · mindestens 3 benötigt',
                    ),
                    const Text(
                      'Die erste Person richtet zuerst. Verschiebt die Gruppe mit dem Griff oder den Pfeilen. Gleiche Namen werden durch den Sitzplatz unterschieden.',
                    ),
                    const SizedBox(height: 16),
                    if (controller.error != null)
                      Text(
                        controller.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (controller.members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Noch keine Personen. Fügt eure Gruppe hinzu.',
                        ),
                      ),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: controller.members.length,
                      onReorderItem: (oldIndex, newIndex) =>
                          _act(() => controller.move(oldIndex, newIndex)),
                      itemBuilder: (context, index) {
                        final member = controller.members[index];
                        return Card(
                          key: ValueKey(member.player.id.value),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    AvatarView(config: member.avatar, size: 48),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${index + 1}. ${controller.displayName(member)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                    ReorderableDragStartListener(
                                      index: index,
                                      enabled: !_busy,
                                      child: const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Icon(Icons.drag_handle),
                                      ),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    IconButton(
                                      tooltip: 'Person nach oben',
                                      onPressed: !_busy && index > 0
                                          ? () => _act(
                                              () => controller.move(
                                                index,
                                                index - 1,
                                              ),
                                            )
                                          : null,
                                      icon: const Icon(Icons.arrow_upward),
                                    ),
                                    IconButton(
                                      tooltip: 'Person nach unten',
                                      onPressed:
                                          !_busy &&
                                              index <
                                                  controller.members.length - 1
                                          ? () => _act(
                                              () => controller.move(
                                                index,
                                                index + 1,
                                              ),
                                            )
                                          : null,
                                      icon: const Icon(Icons.arrow_downward),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _edit(controller, member),
                                      child: const Text('Bearbeiten'),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _act(
                                              () => controller.remove(
                                                member.player.id,
                                              ),
                                            ),
                                      child: const Text('Entfernen'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: !_busy && controller.members.length < 20
                          ? () => _edit(controller)
                          : null,
                      child: const Text('Person hinzufügen'),
                    ),
                    if (own != null)
                      OutlinedButton(
                        onPressed: !_busy && controller.members.length < 20
                            ? () => _act(
                                () => controller.add(
                                  own.player.name,
                                  avatar: own.avatar,
                                ),
                              )
                            : null,
                        child: const Text(
                          'Eigenes Profil als neue Person übernehmen',
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (controller.canStart)
                      const Text(
                        'Die Gruppe ist bereit. Name und Aussehen können weiter angepasst werden.',
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Zurück zur Auswahl'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}

class _RosterEditDialog extends StatefulWidget {
  const _RosterEditDialog({this.member});
  final UserProfile? member;
  @override
  State<_RosterEditDialog> createState() => _RosterEditDialogState();
}

class _RosterEditDialogState extends State<_RosterEditDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.member?.player.name ?? '',
  );
  late AvatarConfig _avatar = widget.member?.avatar ?? AvatarConfig();
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.member == null ? 'Person hinzufügen' : 'Person bearbeiten',
    ),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarView(config: _avatar, size: 96),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 24,
              decoration: InputDecoration(labelText: 'Name', errorText: _error),
            ),
            AvatarOptions(
              config: _avatar,
              onChanged: (next) => setState(() => _avatar = next),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () {
          if (_name.text.trim().isEmpty) {
            setState(() => _error = 'Bitte einen Namen eingeben.');
            return;
          }
          Navigator.pop(context, (name: _name.text, avatar: _avatar));
        },
        child: const Text('Übernehmen'),
      ),
    ],
  );
}
