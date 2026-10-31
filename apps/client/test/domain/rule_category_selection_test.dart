import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/models/content_history.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/domain/rules/drinking_rules.dart';
import 'package:trinktribunal/domain/selection/rule_category_selection.dart';

import 'selection_support.dart';

ContentHistoryEntry used(String id, String eventId, [DateTime? at]) =>
    ContentHistoryEntry(
      eventId: eventId, kind: ContentKind.rule,
      contentId: id, timestampUtc: at ?? now,
    );

void main() {
  test('DE/EN production catalogs use the same categories (15/7/3)', () {
    final de = actualRules();
    final en = rulesFromEnglish();
    expect(
      [for (final rule in de) [rule.id, rule.category]],
      [for (final rule in en) [rule.id, rule.category]],
    );
    for (final category in ['drinking_ritual', 'speech', 'behavior']) {
      expect(
        de.where((r) => r.category == category).length,
        {'drinking_ritual': 15, 'speech': 7, 'behavior': 3}[category],
      );
    }
  });

  test('nine rules cap a category at seven; behavior is not mandatory', () {
    final catalog = rules([
      for (var i = 0; i < 15; i++) ruleJson('r$i', category: 'drinking_ritual'),
      for (var i = 0; i < 7; i++) ruleJson('s$i', category: 'speech'),
      for (var i = 0; i < 3; i++) ruleJson('b$i', category: 'behavior'),
    ]);
    final drawn = <String>{};
    var history = ContentHistory([]);
    for (var i = 0; i < 9; i++) {
      final chosen = selectCategorizedRule(
        catalog: catalog,
        candidates: catalog.where((r) => !drawn.contains(r.id)).toList(),
        drawnIds: drawn,
        history: history, nowUtc: now, random: TestRandom(),
        plannedRuleEvents: 9,
      );
      expect(drawn.add(chosen.id), true);
      history = history.record(used(chosen.id, 'e$i'));
    }
    final picked = [
      for (final category in ['drinking_ritual', 'speech', 'behavior'])
        catalog.where((r) => r.category == category && drawn.contains(r.id)).length,
    ];
    expect(picked, [7, 2, 0]);
  });

  test('existing minimum-counter choice applies within the category', () {
    final catalog = rules([
      ruleJson('used', category: 'drinking_ritual'),
      ruleJson('fresh', category: 'drinking_ritual'),
      ruleJson('spoken', category: 'speech'),
    ]);
    final chosen = selectCategorizedRule(
      catalog: catalog, candidates: catalog, drawnIds: {},
      history: ContentHistory([used('used', 'old')]), nowUtc: now,
      random: TestRandom(), plannedRuleEvents: 9,
    );
    expect(chosen.id, 'fresh');
  });

  test('recent category use reduces its odds; expired use does not', () {
    final catalog = rules([
      ruleJson('r', category: 'drinking_ritual'),
      ruleJson('s', category: 'speech'),
    ]);
    String chosen(ContentHistory history) => selectCategorizedRule(
      catalog: catalog, candidates: catalog, drawnIds: {},
      history: history, nowUtc: now,
      random: TestRandom(indices: [300, 0]), plannedRuleEvents: 9,
    ).id;
    expect(chosen(ContentHistory([])), 'r');
    expect(chosen(ContentHistory([
      used('r', 'old1'), used('r', 'old2'), used('r', 'old3'),
    ])), 's');
    expect(chosen(ContentHistory([
      used('r', 'expired', now.subtract(const Duration(hours: 6))),
    ])), 'r');
  });

  test('active conflicts are filtered before choosing categories', () {
    final catalog = rules([
      ruleJson('r1', category: 'drinking_ritual', excludes: ['r2']),
      ruleJson('r2', category: 'drinking_ritual', excludes: ['r1']),
      ruleJson('s1', category: 'speech'),
    ]);
    final engine = DrinkingRules(
      rules: catalog, mode: GameMode.physicalCards,
      random: TestRandom(), clock: () => now,
    );
    final first = engine.activate(
      state: RuleState(selection: selection()),
      eventId: 'e1', activePlayers: [], plannedRuleEvents: 3,
    );
    expect(first.active.single.entry.id, 'r1');
    final second = engine.activate(
      state: first, eventId: 'e2', activePlayers: [],
      plannedRuleEvents: 3,
    );
    expect(second.active.map((entry) => entry.entry.id), ['r1', 's1']);
    final third = engine.activate(
      state: second, eventId: 'e3', activePlayers: [],
      plannedRuleEvents: 3,
    );
    expect(third.skippedEvents, {'e3'});
  });

  test('a single remaining category can fill its slot despite the cap', () {
    final catalog = rules([
      for (var i = 0; i < 4; i++) ruleJson('r$i', category: 'drinking_ritual'),
    ]);
    final chosen = selectCategorizedRule(
      catalog: catalog, candidates: catalog.skip(2).toList(),
      drawnIds: {'r0', 'r1'}, history: ContentHistory([]),
      nowUtc: now, random: TestRandom(), plannedRuleEvents: 3,
    );
    expect(chosen.id, 'r2');
  });

  test('two planned rule events need not span two categories', () {
    final catalog = rules([
      ruleJson('r1', category: 'drinking_ritual'),
      ruleJson('r2', category: 'drinking_ritual'),
      ruleJson('s1', category: 'speech'),
    ]);
    final first = selectCategorizedRule(
      catalog: catalog, candidates: catalog, drawnIds: {},
      history: ContentHistory([]), nowUtc: now,
      random: TestRandom(), plannedRuleEvents: 2,
    );
    final second = selectCategorizedRule(
      catalog: catalog,
      candidates: catalog.where((r) => r.id != first.id).toList(),
      drawnIds: {first.id}, history: ContentHistory([]),
      nowUtc: now, random: TestRandom(), plannedRuleEvents: 2,
    );
    expect(first.category, 'drinking_ritual');
    expect(second.category, 'drinking_ritual');
  });
}
