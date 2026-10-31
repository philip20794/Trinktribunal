import '../../design/status_notice.dart';
import '../../design/court_scene.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/local_maintenance_controller.dart';
import '../help/data_maintenance.dart';
import '../help/help_screen.dart';
import '../../l10n/app_strings.dart';
import 'offline_settings.dart';
import '../../app/install_options.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(settingsProvider), current = loaded.asData?.value;
    final maintenance = ref.watch(localMaintenanceProvider);
    return PopScope(
      canPop: !maintenance.busy,
      child: CourtScaffold(
        title: const TText('settings'),
        bodyBuilder: (context) => Center(
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
                              if (value != null) {
                                current.update(language: value);
                              }
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
                          if (current.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: StatusNotice(context.tr(current.error!)),
                            ),
                          const SizedBox(height: 24),
                          Text(
                            context.tr('installTitle'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const InstallOptions(),
                          const SizedBox(height: 24),
                          TextButton.icon(
                            onPressed: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HelpScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.help_outline),
                            label: const TText('helpTitle'),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HelpScreen(privacy: true),
                              ),
                            ),
                            icon: const Icon(Icons.privacy_tip_outlined),
                            label: const TText('privacyTitle'),
                          ),
                          const Divider(height: 32),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const TText('advancedSettings'),
                            subtitle: const TText('advancedSettingsHelp'),
                            children: const [
                              DataMaintenance(),
                              OfflineSettings(),
                            ],
                          ),
                          TextButton(
                            onPressed: () => showLicensePage(
                              context: context,
                              applicationName: 'Trinktribunal',
                            ),
                            child: Text(context.tr('licenses')),
                          ),
                          OutlinedButton(
                            onPressed: maintenance.busy
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Text(context.tr('back')),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
