import 'package:flutter/material.dart';

import '../../data/catalogs/catalog_diagnostics.dart';

import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import 'mode_preview_screen.dart';

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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trinktribunal'),
        actions: [
          IconButton(
            tooltip: 'Einstellungen öffnen',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _open(context, const SettingsScreen()),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: 'Profil öffnen',
              icon: const Icon(Icons.person_outline),
              onPressed: () => _open(context, const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 840;
          const gap = 16.0;
          final contentWidth = constraints.maxWidth > 1056
              ? 1056.0
              : constraints.maxWidth;
          final innerWidth = contentWidth - 40;
          final cardWidth = isWide ? (innerWidth - 2 * gap) / 3 : innerWidth;

          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1056),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Der Gerichtssaal wartet.',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Wähle, wie ihr spielen möchtet. '
                        'Die Spielabläufe werden schrittweise freigeschaltet.',
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final mode in GameMode.values)
                            SizedBox(
                              width: cardWidth,
                              child: _ModeCard(
                                mode: mode,
                                onTap: () => _open(
                                  context,
                                  ModePreviewScreen(mode: mode),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const CatalogDiagnostics(),
                      const Text(
                        'Entwicklungsvorschau',
                        style: TextStyle(color: Color(0xFF715E50)),
                      ),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 176),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(mode.icon, size: 36),
                const SizedBox(height: 18),
                Text(mode.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text(mode.description),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.arrow_forward,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
