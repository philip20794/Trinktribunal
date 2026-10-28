import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../design/court_scene.dart';

import 'home_screen.dart';

class ModePreviewScreen extends StatelessWidget {
  const ModePreviewScreen({required this.mode, super.key});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return CourtScaffold(
      title: Text(
        context.tr(switch (mode) {
          GameMode.cards => 'modeCards',
          GameMode.sharedPhone => 'modePhone',
          GameMode.multiplayer => 'modeMulti',
        }),
      ),
      bodyBuilder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Icon(mode.icon, size: 72),
              const SizedBox(height: 24),
              Text(
                context.tr(switch (mode) {
                  GameMode.cards => 'modeCards',
                  GameMode.sharedPhone => 'modePhone',
                  GameMode.multiplayer => 'modeMulti',
                }),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(switch (mode) {
                  GameMode.cards => 'modeCardsDescription',
                  GameMode.sharedPhone => 'modePhoneDescription',
                  GameMode.multiplayer => 'modeMultiDescription',
                }),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Text(context.tr('modeUnavailable'), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const TText('backToSelection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
