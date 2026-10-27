import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import '../../domain/local_game_reducer.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../../data/catalogs/localized_catalog.dart';
import '../../data/catalogs/catalog.dart';

Future<void> showActiveRules(
  BuildContext context,
  CardGameState state,
  Catalogs catalogs,
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
          context.tr('activeRulesCount', {'count': state.rules.active.length}),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const TText('rulesHelp'),
        const SizedBox(height: 16),
        if (state.rules.active.isEmpty) const TText('rulesNone'),
        for (final rule in state.rules.active)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                localizedRule(
                  catalogs,
                  AppLanguageScope.of(context).language,
                  rule.entry as DrinkingRule,
                ).text,
              ),
            ),
          ),
        if (state.rules.skippedEvents.isNotEmpty)
          Text(
            context.tr('ruleSkipping', {
              'count': state.rules.skippedEvents.length,
              'max': state.effectiveRuleTarget,
            }),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const TText('backToCase'),
        ),
      ],
    ),
  ),
);
