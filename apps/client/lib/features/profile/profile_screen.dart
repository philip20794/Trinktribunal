import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';
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
          .showSnackBar(const SnackBar(content: TText('profileSaved')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const TText('profileTitle')),
    body: ref
        .watch(profileProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(profileProvider),
              child: const TText('profileReload'),
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
                        label: context.tr('profilePreview'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: context.tr('profileName'),
                        helperText: context.tr('profileLength'),
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
                          child: const TText('profileMale'),
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _avatar = AvatarConfig.feminine()),
                          child: const TText('profileFemale'),
                        ),
                        OutlinedButton(
                          onPressed: () => setState(
                            () => _avatar = AvatarConfig.random(
                              SecureRandomSource(),
                            ),
                          ),
                          child: const TText('profileRandom'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const TText('profileHelp',
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
                            labelText: context.tr('avatarCategory' + category.key),
                          ),
                          items: category.value
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option,
                                  child: Text(context.tr('avatarOption' + option)),
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
                        context.tr(_saving ? 'profileSaving' : 'profileSave'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const TText('profileBack',
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
