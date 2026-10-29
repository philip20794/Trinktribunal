import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../design/court_scene.dart';

import '../../domain/local_game_reducer.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../../data/catalogs/localized_catalog.dart';
import '../../data/catalogs/catalog.dart';

Future<void> showActiveRules(
  BuildContext context,
  CardGameState state,
  Catalogs catalogs,
) => showActiveRuleList(
  context,
  emptyKey: 'rulesNone',
  rules: [
    for (final rule in state.rules.active)
      localizedRule(
        catalogs,
        AppLanguageScope.of(context).language,
        rule.entry as DrinkingRule,
      ).text,
  ],
  note: state.rules.skippedEvents.isEmpty
      ? null
      : context.tr('ruleSkipping', {
          'count': state.rules.skippedEvents.length,
          'max': state.effectiveRuleTarget,
        }),
);

Future<void> showActiveRuleList(
  BuildContext context, {
  required List<String> rules,
  String? note,
  String emptyKey = 'phoneRulesEmpty',
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: CourtSceneTokens.night,
  builder: (context) => Theme(
    data: courtSceneTheme().copyWith(
      bottomSheetTheme: const BottomSheetThemeData(
        dragHandleColor: CourtSceneTokens.gold,
      ),
    ),
    child: DefaultTextStyle(
      style: courtSceneTheme().textTheme.bodyLarge!.copyWith(height: 1.45),
      child: FractionallySizedBox(
        heightFactor: .8,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_outlined,
                      color: CourtSceneTokens.gold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('activeRulesCount', {'count': rules.length}),
                        style: courtSceneTheme().textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (rules.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: TText(emptyKey),
                      ),
                    for (var i = 0; i < rules.length; i++)
                      Container(
                        key: ValueKey('active-rule-$i'),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CourtSceneTokens.panel,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: CourtSceneTokens.gold.withValues(alpha: .3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}.',
                              style: const TextStyle(
                                color: CourtSceneTokens.gold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(rules[i])),
                          ],
                        ),
                      ),
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(note),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const TText('backToCase'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
