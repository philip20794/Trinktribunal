import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/profile_controller.dart';
import '../../design/avatar_view.dart';
import '../../domain/avatar_config.dart';
import '../../domain/selection/random_source.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  AvatarConfig _avatar = AvatarConfig();
  bool _initialized = false;
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(ProfileController controller) async {
    setState(() => _saving = true);
    final saved = await controller.save(name: _name.text, avatar: _avatar);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      ref.invalidate(profileProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profil gespeichert.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mein Profil')),
    body: ref
        .watch(profileProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(profileProvider),
              child: const Text('Profil erneut laden'),
            ),
          ),
          data: (controller) {
            if (!_initialized) {
              _name.text = controller.profile?.player.name ?? '';
              _avatar = controller.profile?.avatar ?? AvatarConfig();
              _initialized = true;
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: AvatarView(
                        config: _avatar,
                        size: 160,
                        label: 'Vorschau deiner Figur',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Dein Name',
                        helperText: '1 bis 24 sichtbare Zeichen',
                      ),
                      maxLength: 24,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(
                            () => _avatar = AvatarConfig.masculine(),
                          ),
                          child: const Text('Männlicher Start'),
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _avatar = AvatarConfig.feminine()),
                          child: const Text('Weiblicher Start'),
                        ),
                        OutlinedButton(
                          onPressed: () => setState(
                            () => _avatar = AvatarConfig.random(
                              SecureRandomSource(),
                            ),
                          ),
                          child: const Text('Zufällige Figur'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Jeder Start bleibt frei veränderbar. Gespeichert wird erst mit „Profil speichern“.',
                    ),
                    const SizedBox(height: 16),
                    for (final category in AvatarCatalog.options.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(
                            '${category.key}:${_avatar[category.key]}',
                          ),
                          initialValue: _avatar[category.key],
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _categoryLabels[category.key],
                          ),
                          items: category.value
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option,
                                  child: Text(_optionLabels[option] ?? option),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(
                                () => _avatar = _avatar.withOption(
                                  category.key,
                                  value,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    if (controller.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          controller.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    FilledButton(
                      onPressed: _saving ? null : () => _save(controller),
                      child: Text(
                        _saving ? 'Wird gespeichert …' : 'Profil speichern',
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Zurück ohne weitere Änderungen zu speichern',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}

const _categoryLabels = {
  'face': 'Kopfform',
  'skin': 'Hautton',
  'eyes': 'Augen',
  'brows': 'Augenbrauen',
  'nose': 'Nase',
  'mouth': 'Mund / Ausdruck',
  'hair': 'Frisur',
  'hairColor': 'Haarfarbe',
  'beard': 'Bart',
  'top': 'Oberteil',
  'topColor': 'Kleidungsfarbe',
  'glasses': 'Brille',
  'hat': 'Hut',
  'extra': 'Extra',
};
const _optionLabels = {
  'round': 'Rund',
  'square': 'Kantig',
  'long': 'Lang',
  'light': 'Hell',
  'medium': 'Mittel',
  'brown': 'Braun',
  'dark': 'Dunkel',
  'open': 'Offen',
  'sleepy': 'Entspannt',
  'calm': 'Ruhig',
  'raised': 'Angehoben',
  'smile': 'Lächeln',
  'neutral': 'Neutral',
  'surprised': 'Überrascht',
  'short': 'Kurz',
  'curly': 'Lockig',
  'bald': 'Keine Haare',
  'black': 'Schwarz',
  'gold': 'Goldblond',
  'gray': 'Grau',
  'none': 'Ohne',
  'stubble': 'Stoppeln',
  'full': 'Vollbart',
  'shirt': 'Shirt',
  'jacket': 'Jacke',
  'blue': 'Graublau',
  'red': 'Rot',
  'green': 'Grün',
  'cap': 'Kappe',
  'bowtie': 'Fliege',
};
