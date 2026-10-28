import '../../design/status_notice.dart';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/profile_controller.dart';
import '../../design/avatar_view.dart';
import '../../design/court_scene.dart';
import '../../design/case_file.dart';
import '../../domain/avatar_config.dart';
import '../../domain/selection/random_source.dart';
import 'avatar_options.dart';

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
  Widget build(BuildContext context) => CourtScaffold(
    title: const TText('profileTitle'),
    footer: ref.watch(profileProvider).asData?.value == null
        ? null
        : CourtActionBar(
            primary: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ref.watch(profileProvider).asData?.value.error
                    case final String error)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: StatusNotice(context.feedback(error)),
                  ),
                CourtPrimaryButton(
                  onPressed: _saving
                      ? null
                      : () => _save(ref.read(profileProvider).requireValue),
                  child: TText(_saving ? 'profileSaving' : 'profileSave'),
                ),
              ],
            ),
            secondary: CourtSecondaryButton(
              onPressed: () => Navigator.pop(context),
              child: const TText('profileBack'),
            ),
          ),
    bodyBuilder: (context) => ref
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
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: AvatarView(
                        config: _avatar,
                        size: 200,
                        label: context.tr('profilePreview'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    NamePlate(
                      name: _name.text.trim().isEmpty
                          ? context.tr('profilePreview')
                          : _name.text.trim(),
                      position: 1,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _name,
                      onChanged: (_) => setState(() => controller.error = null),
                      decoration: InputDecoration(
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
                    const TText('profileHelp'),
                    const SizedBox(height: 16),
                    AvatarOptions(
                      config: _avatar,
                      onChanged: (value) => setState(() => _avatar = value),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}
