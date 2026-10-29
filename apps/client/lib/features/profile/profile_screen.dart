import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/profile_controller.dart';
import '../../design/avatar_view.dart';
import '../../design/court_scene.dart';
import '../../design/status_notice.dart';
import '../../domain/avatar_config.dart';
import '../../domain/selection/random_source.dart';
import '../../l10n/app_strings.dart';
import 'avatar_options.dart';

/// Portrait stays in view while the controls scroll independently underneath.
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
    if (_saving) return;
    setState(() => _saving = true);
    final saved = await controller.save(name: _name.text, avatar: _avatar);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      ref.invalidate(profileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('profileSaved'))),
      );
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state=ref.watch(profileProvider);
    return CourtScaffold(
      title: const TText('profileTitle'),
      footer: CourtActionBar(
        primary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.asData?.value.error case final String error)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: StatusNotice(context.feedback(error)),
              ),
            CourtPrimaryButton(
              onPressed: _saving || state.asData == null
                  ? null : () => _save(state.requireValue),
              child: TText(_saving ? 'profileSaving' : 'profileSave'),
            ),
          ],
        ),
      ),
      bodyBuilder: (context) => state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
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
          return LayoutBuilder(
            builder: (context, constraints) {
              final scale=MediaQuery.textScalerOf(context).scale(16) / 16;
              final available=constraints.maxHeight;
              // Keep the portrait visible without consuming the whole phone.
              final portraitHeight=math.min(270.0,math.max(130.0,
                  available * (scale > 1.5 ? .29 : .41)));
              final portraitWidth=portraitHeight*762/1080;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        SizedBox(
                          height: portraitHeight,
                          width: portraitWidth,
                          child: AvatarView(
                            key: const ValueKey('profile-avatar-preview'),
                            config: _avatar,
                            size: portraitWidth,
                            playerName: _name.text,
                            label: context.tr('profilePreview'),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              key: const ValueKey('avatar-randomize'),
                              tooltip: context.tr('profileRandom'),
                              icon: const Icon(Icons.casino_outlined),
                              onPressed: () => setState(() {
                                _avatar=AvatarConfig.random(SecureRandomSource());
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 9),
                    child: TextField(
                      key: const ValueKey('profile-name'),
                      controller: _name,
                      maxLength: 24,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() => controller.error = null),
                      decoration: InputDecoration(
                        labelText: context.tr('profileName'),
                        hintText: context.tr('profileName'),
                        prefixIcon: const Icon(Icons.edit_outlined, size: 19),
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AvatarOptions(
                      config: _avatar,
                      onChanged: (next) => setState(() => _avatar = next),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
