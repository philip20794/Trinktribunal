import '../../design/court_dialog.dart';

import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../design/status_notice.dart';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/local_maintenance_controller.dart';
import '../../design/avatar_view.dart';
import '../../design/court_scene.dart';
import '../../design/court_assets.dart';

import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../rules/game_rules_screen.dart';
import '../multiplayer/join.dart';
import '../setup/player_roster.dart';
import '../multiplayer/create.dart';
import '../setup/card_mode_screen.dart';
import '../handoff/shared_game_screen.dart';
import '../../domain/models/game_mode.dart' as domain;

enum GameMode {
  cards(
    title: 'Karten ziehen',
    description:
        'Jeder sieht seine geheime Zahl auf einer gezogenen Spielkarte.',
    icon: Icons.style_outlined,
  ),
  sharedPhone(
    title: 'Handy herumreichen',
    description:
        'Jeder sieht seine geheime Zahl auf dem herumgereichten Handy.',
    icon: Icons.phone_android,
  ),
  multiplayer(
    title: 'Jeder ein eigenes Handy',
    description: 'Jeder sieht seine geheime Zahl auf dem eigenen Handy.',
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

  Future<void> _enterMode(
    BuildContext context,
    WidgetRef ref,
    GameMode mode,
  ) async {
    if (mode != GameMode.multiplayer) {
      final cards = mode == GameMode.cards;
      final cardGame = ref.read(localSessionProvider).state;
      final phoneGame = ref.read(sharedPhoneControllerProvider).view;
      final phase = cards ? cardGame?.phase : phoneGame?.phase;
      if (phase != null && phase != domain.GamePhase.finished) {
        final choice = await showDialog<bool>(
          context: context,
          builder: (context) => CourtDialog(
            scrollable: true,
            title: const TText('resumeGameTitle'),
            content: const TText('resumeGameBody'),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const TText('resumeGame'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const TText('newGame'),
              ),
            ],
          ),
        );
        if (!context.mounted || choice == null) return;
        if (!choice) {
          _open(
            context,
            cards
                ? const CardModeScreen()
                : SharedGameScreen(
                    config: phoneGame!.config,
                    roster: phoneGame.pendingRoster ?? phoneGame.roster,
                  ),
          );
          return;
        }
      }
      if (phase != null) {
        final success = await ref
            .read(localMaintenanceProvider.notifier)
            .resetGame(cardMode: cards);
        if (!context.mounted) return;
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('maintenanceFailed'))),
          );
          return;
        }
      }
    }
    if (context.mounted) {
      _open(context, switch (mode) {
        GameMode.cards => const PlayerRosterScreen(cardMode: true),
        GameMode.sharedPhone => const PlayerRosterScreen(),
        GameMode.multiplayer => const CreateRoomScreen(),
      });
    }
  }

  Future<void> _selectMode(
    BuildContext context,
    WidgetRef ref,
    GameMode mode,
  ) async {
    try {
      await ref.read(localResumeProvider.future);
    } on Object {
      /* The destination shows catalog/load errors. */
    }
    if (ref.read(localMaintenanceProvider).busy ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    await _enterMode(context, ref, mode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localMaintenanceProvider);
    final profile = ref.watch(profileProvider).asData?.value.profile;
    final resume = ref.watch(localResumeProvider);
    final transaction = resume.hasValue
        ? ref.read(localStateTransactionProvider)
        : null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
      ),
      child: CourtScaffold(
        background: CourtAssets.home,
        maxWidth: 1056,
        bodyBuilder: (context) => Column(
          children: [
            _FloatingHomeHeader(
              avatar: profile == null
                  ? const Icon(Icons.person_outline, size: 28)
                  : AvatarHeadView(
                      config: profile.avatar,
                      size: 32,
                      filledBackground: false,
                      label: profile.player.name,
                    ),
              onSettings: () => _open(context, const SettingsScreen()),
              onProfile: () => _open(context, const ProfileScreen()),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) => SingleChildScrollView(
                  key: const ValueKey('home-scroll'),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: bounds.maxHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _HomeHero(),
                              const SizedBox(height: 12),
                              if (transaction?.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: StatusNotice(
                                    context.feedback(transaction!.error!),
                                  ),
                                ),
                              if (transaction?.needsReset == true)
                                TextButton(
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => CourtDialog(
                                        title: const TText('homeDiscardTitle'),
                                        content: const TText('homeKeepProfile'),
                                        actions: [
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
                              _HomeAction(
                                buttonKey: const ValueKey('home-new-game'),
                                title: 'homeNewGame',
                                icon: Icons.play_arrow_rounded,
                                colors: const [
                                  Color(0xFFFFE89B),
                                  Color(0xFFF6BA4B),
                                  Color(0xFFD98A26),
                                ],
                                foreground: const Color(0xFF3A1909),
                                onPressed: () => _open(
                                  context,
                                  GameModeSelectionScreen(
                                    onSelected: (selectionContext, mode) =>
                                        _selectMode(
                                          selectionContext,
                                          ref,
                                          mode,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _HomeAction(
                                buttonKey: const ValueKey('home-join-game'),
                                title: 'homeJoinGame',
                                icon: Icons.groups_rounded,
                                colors: const [
                                  Color(0xFFA92D30),
                                  Color(0xFF8F1E25),
                                  Color(0xFF64131D),
                                ],
                                onPressed: () =>
                                    _open(context, const JoinRoomScreen()),
                              ),
                              const SizedBox(height: 12),
                              _HomeAction(
                                buttonKey: const ValueKey('home-game-rules'),
                                title: 'gameRules',
                                icon: Icons.menu_book_outlined,
                                colors: const [
                                  Color(0xFF69402B),
                                  Color(0xFF4A291D),
                                  Color(0xFF301B15),
                                ],
                                onPressed: () =>
                                    _open(context, const GameRulesScreen()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingHomeHeader extends StatelessWidget {
  const _FloatingHomeHeader({
    required this.avatar,
    required this.onSettings,
    required this.onProfile,
  });
  final Widget avatar;
  final VoidCallback onSettings, onProfile;
  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('home-floating-header'),
    height: 64,
    child: LayoutBuilder(
      builder: (context, bounds) => Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: SizedBox(
              width: math.max(70, bounds.maxWidth - 208),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  'Trinktribunal',
                  style: TextStyle(
                    fontFamily: 'CourtRoboto',
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                    color: Color(0xFFFFE7AA),
                    shadows: [
                      Shadow(
                        color: Colors.black87,
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 8,
            child: Row(
              children: [
                IconButton(
                  tooltip: context.tr('openSettings'),
                  onPressed: onSettings,
                  icon: const Icon(
                    Icons.settings,
                    color: Color(0xFFFFE7AA),
                    size: 27,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('openProfile'),
                  onPressed: onProfile,
                  color: const Color(0xFFFFE7AA),
                  icon: avatar,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _HomeHero extends StatelessWidget {
  const _HomeHero();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = bounds.maxWidth;
      final height = width * 1018 / 1495;
      return SizedBox(
        key: const ValueKey('home-hero'),
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CourtArt(CourtAssets.homeHero, fit: BoxFit.contain),
            ),
            Positioned(
              left: width * .12,
              right: width * .12,
              top: height * .657,
              height: height * .225,
              child: Semantics(
                container: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TText(
                        'homeHearingReady',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'CourtRoboto',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF351C0A),
                        ),
                      ),
                      const SizedBox(height: 5),
                      TText(
                        'homeHearingQuestion',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'CourtRoboto',
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF351C0A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.buttonKey,
    required this.title,
    required this.icon,
    required this.colors,
    required this.onPressed,
    this.foreground = const Color(0xFFFFF0CE),
  });
  final Key buttonKey;
  final String title;
  final IconData icon;
  final List<Color> colors;
  final Color foreground;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ),
      border: Border.all(color: const Color(0xFF37190D), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0xB3000000),
          offset: Offset(0, 4),
          blurRadius: 5,
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD87F), width: 1.6),
        ),
        child: FilledButton(
          key: buttonKey,
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: foreground,
            shadowColor: Colors.transparent,
            minimumSize: const Size.fromHeight(72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: TText(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'CourtRoboto',
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 26),
            ],
          ),
        ),
      ),
    ),
  );
}

class GameModeSelectionScreen extends StatelessWidget {
  const GameModeSelectionScreen({required this.onSelected, super.key});
  final Future<void> Function(BuildContext, GameMode) onSelected;
  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: const TText('chooseGameMode'),
    maxWidth: 680,
    body: ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: GameMode.values.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ModeCard(
        mode: GameMode.values[index],
        onTap: () => onSelected(context, GameMode.values[index]),
      ),
    ),
  );
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
                    GameMode.cards => CourtAssets.modeCards,
                    GameMode.sharedPhone => CourtAssets.modePhone,
                    GameMode.multiplayer => CourtAssets.modePhones,
                  },
                  width: 76,
                  height: 88,
                  fit: BoxFit.contain,
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
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: CourtSceneTokens.gold.withValues(
                                alpha: .4,
                              ),
                            ),
                          ),
                        ),
                        child: TText(
                          switch (mode) {
                            GameMode.cards => 'modeCardsRequirement',
                            GameMode.sharedPhone => 'modePhoneRequirement',
                            GameMode.multiplayer => 'modeMultiRequirement',
                          },
                          style: const TextStyle(
                            fontSize: 12,
                            color: CourtSceneTokens.cream,
                          ),
                        ),
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
