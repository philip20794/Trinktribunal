import 'package:flutter/material.dart';

import '../../domain/local_game_reducer.dart';

Future<void> showActiveRules(
  BuildContext context,
  CardGameState state,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.8,
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Aktive Regeln · ${state.rules.active.length}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Ein eigenständiger Regelverstoß: ein zusätzlicher Strafschluck. Keine Strafketten. Erforderliches Vorlesen und reguläres Zahlenaufdecken sind von Sprachverboten ausgenommen.',
        ),
        const SizedBox(height: 16),
        if (state.rules.active.isEmpty)
          const Text('Es sind noch keine Regeln aktiv.'),
        for (final rule in state.rules.active)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(rule.entry.text),
            ),
          ),
        if (state.rules.skippedEvents.isNotEmpty)
          Text(
            'Keine passende Regel in ${state.rules.skippedEvents.length} Ereignissen. Ziel reduziert auf höchstens ${state.effectiveRuleTarget}.',
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zurück zur Fallakte'),
        ),
      ],
    ),
  ),
);
