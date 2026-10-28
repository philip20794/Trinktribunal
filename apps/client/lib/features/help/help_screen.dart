import 'package:flutter/material.dart';

import '../../data/room_credential_store.dart';
import '../../design/court_scene.dart';
import '../../l10n/app_strings.dart';
import '../rules/game_rules_screen.dart';

const helpSections = [
  'Cards',
  'Shared',
  'Online',
  'Verdict',
  'Refresh',
  'People',
  'Offline',
  'Resume',
  'Troubleshooting',
];
const privacySections = [
  'Local',
  'Online',
  'Credentials',
  'Retention',
  'Deletion',
  'Operations',
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({this.privacy = false, super.key});
  final bool privacy;
  String? get _server {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isEmpty) return null;
    try {
      return roomServerOrigin(configured).origin;
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: TText(privacy ? 'privacyTitle' : 'helpTitle'),
    bodyBuilder: (context) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (privacy)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              context.tr('privacyEndpoint', {
                'origin': _server ?? context.tr('privacyNoServer'),
              }),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton.icon(
              onPressed: () => showGameRules(context),
              icon: const Icon(Icons.menu_book_outlined),
              label: const TText('gameRules'),
            ),
          ),
        for (final section in privacy ? privacySections : helpSections)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CourtPaper(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: TText(
                        '${privacy ? 'privacy' : 'help'}${section}Title',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TText('${privacy ? 'privacy' : 'help'}${section}Body'),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
