import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../design/court_scene.dart';
import '../setup/card_mode_screen.dart';
import '../setup/player_roster.dart';
import '../multiplayer/create.dart';
import 'home_screen.dart';

/// The explanation belongs before setup, never over the live playing surface.
class ModePreviewScreen extends StatelessWidget {
  const ModePreviewScreen({required this.mode, super.key});
  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    final prefix = switch (mode) {
      GameMode.cards => 'introCards',
      GameMode.sharedPhone => 'introPhone',
      GameMode.multiplayer => 'introOnline',
    };
    return CourtScaffold(
      title: TText(switch (mode) {
        GameMode.cards => 'modeCards',
        GameMode.sharedPhone => 'modePhone',
        GameMode.multiplayer => 'modeMulti',
      }),
      footer: CourtActionBar(
        primary: FilledButton(
          onPressed: () => Navigator.of(context).pushReplacement<void, void>(
            MaterialPageRoute(
              builder: (_) => switch (mode) {
                GameMode.cards => const CardModeScreen(),
                GameMode.sharedPhone => const PlayerRosterScreen(),
                GameMode.multiplayer => const MultiplayerEntryScreen(),
              },
            ),
          ),
          child: const TText('introContinue'),
        ),
      ),
      bodyBuilder: (context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CourtPaper(
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TText(
                    'introTitle',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  for (var step = 1; step <= 3; step++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$step.',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: TText('$prefix$step')),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
