import '../../design/status_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../l10n/app_strings.dart';
import 'offline_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(settingsProvider), current = loaded.asData?.value;
    return Scaffold(
      appBar: AppBar(title: const TText('settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: loaded.hasError
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusNotice(context.tr('settingsLoadFailed')),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(settingsProvider),
                        child: const TText('retry'),
                      ),
                    ],
                  ),
                )
              : current == null
              ? const Center(child: CircularProgressIndicator())
              : ListenableBuilder(
                  listenable: current,
                  builder: (context, _) {
                    final settings = current.value;
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          context.tr('generalSettings'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: settings.language,
                          key: ValueKey(settings.language),
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.tr('appLanguage'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'de',
                              child: Text(context.tr('german')),
                            ),
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(context.tr('english')),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) current.update(language: value);
                          },
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.tr('reducedMotion')),
                          subtitle: Text(context.tr('reducedMotionHelp')),
                          value: settings.reducedMotion,
                          onChanged: (value) =>
                              current.update(reducedMotion: value),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.tr('audio')),
                          subtitle: Text(context.tr('audioHelp')),
                          value: settings.audioEnabled,
                          onChanged: (value) =>
                              current.update(audioEnabled: value),
                        ),
                        const SizedBox(height: 12),
                        Text(context.tr('localContentLanguageHelp')),
                        if (current.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: StatusNotice(context.tr(current.error!)),
                          ),
                        const SizedBox(height: 24),
                        const OfflineSettings(),
                        TextButton(
                          onPressed: () => showLicensePage(
                            context: context,
                            applicationName: 'Trinktribunal',
                          ),
                          child: Text(context.tr('licenses')),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(context.tr('back')),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
