import 'package:flutter/material.dart';

import 'home_screen.dart';

class ModePreviewScreen extends StatelessWidget {
  const ModePreviewScreen({required this.mode, super.key});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(mode.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Icon(mode.icon, size: 72),
              const SizedBox(height: 24),
              Text(
                mode.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(mode.description, textAlign: TextAlign.center),
              const SizedBox(height: 28),
              Text(
                'Diese Spielvariante ist noch nicht verfügbar. '
                'Der spielbare Ablauf folgt mit ${mode.milestone}.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Zurück zur Auswahl'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
