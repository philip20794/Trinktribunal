import '../../design/status_notice.dart';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../design/avatar_view.dart';
import '../../design/home_layout.dart';
import '../../design/court_scene.dart';
import '../../design/court_assets.dart';

import '../../data/catalogs/catalog_diagnostics.dart';

import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../setup/card_mode_screen.dart';
import '../setup/player_roster.dart';
import '../design_gallery/design_gallery_screen.dart';
import '../multiplayer/create.dart';
import '../multiplayer/saved_rooms.dart';
import '../rules/game_rules_screen.dart';

enum GameMode {
  cards(
    title: 'Handy + Karten',
    description: 'Eine digitale Fallakte und echte Zahlenkarten am Tisch.',
    icon: Icons.style_outlined,
  ),
  sharedPhone(
    title: 'Ein Handy',
    description:
        'Geheime Zahlen weiterreichen und Figuren gemeinsam sortieren.',
    icon: Icons.phone_android,
  ),
  multiplayer(
    title: 'Jeder ein Handy',
    description: 'Im selben Gerichtssaal auf mehreren Geräten spielen.',
    icon: Icons.groups_outlined,
  );

  const GameMode({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).asData?.value.profile;
    final resume = ref.watch(localResumeProvider);
    final transaction = resume.hasValue
        ? ref.read(localStateTransactionProvider)
        : null;
    return CourtScaffold(
      background: CourtAssets.home,
      maxWidth: 1056,
      title: const Text('Trinktribunal'),
      actions: [
        const GameRulesButton(),
        if (kDebugMode)
          IconButton(
            tooltip: context.tr('openDesign'),
            onPressed: () => _open(context, const DesignGalleryScreen()),
            icon: const Icon(Icons.palette_outlined),
          ),
        IconButton(
          tooltip: context.tr('openSettings'),
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => _open(context, const SettingsScreen()),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton.filledTonal(
            tooltip: context.tr('openProfile'),
            icon: profile == null
                ? const Icon(Icons.person_outline)
                : AvatarView(
                    config: profile.avatar,
                    size: 28,
                    label: profile.player.name,
                  ),
            onPressed: () => _open(context, const ProfileScreen()),
          ),
        ),
      ],
      bodyBuilder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 40) return const SizedBox.shrink();
          const gap = 12.0;
          final cardWidth = homeCardWidth(constraints.maxWidth);

          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1056),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CourtBrandMark(
                          width: constraints.maxWidth < 600 ? 190 : 250,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('homeIntro'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (transaction?.restored == true)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: const TText('homeResume'),
                        ),
                      if (transaction?.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: StatusNotice(
                            context.feedback(transaction!.error!),
                          ),
                        ),
                      if (transaction?.needsReset == true)
                        TextButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const TText('homeDiscardTitle'),
                                content: const TText('homeKeepProfile'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const TText('cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const TText('discard'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await transaction!.discardGames();
                              ref.invalidate(localResumeProvider);
                            }
                          },
                          child: const TText('homeDiscardAction'),
                        ),
                      Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final mode in GameMode.values)
                            SizedBox(
                              width: cardWidth,
                              child: _ModeCard(
                                mode: mode,
                                onTap: () async {
                                  try {
                                    await ref.read(localResumeProvider.future);
                                  } on Object {
                                    /* The destination shows catalog/load errors. */
                                  }
                                  if (!context.mounted ||
                                      ModalRoute.of(context)?.isCurrent !=
                                          true) {
                                    return;
                                  }
                                  _open(
                                    context,
                                    mode == GameMode.cards
                                        ? const CardModeScreen()
                                        : mode == GameMode.sharedPhone
                                        ? const PlayerRosterScreen()
                                        : const MultiplayerEntryScreen(),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SavedRooms(),
                      const CatalogDiagnostics(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.onTap});

  final GameMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = context.tr(switch (mode) {
      GameMode.cards => 'modeCards',
      GameMode.sharedPhone => 'modePhone',
      GameMode.multiplayer => 'modeMulti',
    });
    final description = context.tr(switch (mode) {
      GameMode.cards => 'modeCardsDescription',
      GameMode.sharedPhone => 'modePhoneDescription',
      GameMode.multiplayer => 'modeMultiDescription',
    });
    return Semantics(
      button: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CourtArt(
                  switch (mode) {
                    GameMode.cards => CourtAssets.cards,
                    GameMode.sharedPhone => CourtAssets.phone,
                    GameMode.multiplayer => CourtAssets.people,
                  },
                  width: 48,
                  height: 48,
                  fallback: Icon(mode.icon, size: 36),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
