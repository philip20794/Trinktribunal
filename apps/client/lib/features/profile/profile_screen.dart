import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/profile_controller.dart';
import '../../design/court_scene.dart';
import '../../design/status_notice.dart';
import '../../domain/avatar_config.dart';
import '../../domain/selection/random_source.dart';
import '../../l10n/app_strings.dart';
import 'avatar_editor.dart';
import '../../design/saved_notice.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  AvatarConfig _avatar = AvatarConfig();
  bool _initialized = false, _saving = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(ProfileController controller) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final saved = await controller.save(name: _name.text, avatar: _avatar);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      ref.invalidate(profileProvider);
      showSavedNotice(context);
      Navigator.of(context).maybePop();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
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
                  ? null
                  : () => _save(state.requireValue),
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
          return AvatarEditor(
            config: _avatar,
            nameController: _name,
            onNameChanged: (_) => setState(() => controller.error = null),
            onChanged: (next) => setState(() => _avatar = next),
            onRandomize: () => setState(
              () => _avatar = AvatarConfig.random(SecureRandomSource()),
            ),
          );
        },
      ),
    );
  }
}
