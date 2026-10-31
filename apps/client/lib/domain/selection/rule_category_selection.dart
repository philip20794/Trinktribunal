import 'dart:math' as math;

import '../../data/catalogs/catalog.dart';
import '../models/content_history.dart';
import '../models/domain_error.dart';
import 'content_selection.dart';
import 'random_source.dart';

const _categories = ['drinking_ritual', 'speech', 'behavior'];

/// Category is chosen at each slot; the six-hour minimum-counter rule stays intact.
DrinkingRule selectCategorizedRule({
  required List<DrinkingRule> catalog,
  required List<DrinkingRule> candidates,
  required Set<String> drawnIds,
  required ContentHistory history,
  required DateTime nowUtc,
  required RandomSource random,
  required int plannedRuleEvents,
}) {
  if (candidates.any((rule) => rule.category == null)) {
    return selectContent(
      candidates: candidates, kind: ContentKind.rule,
      history: history, nowUtc: nowUtc, random: random,
    );
  }
  final picked = <String, int>{for (final category in _categories) category: 0};
  for (final rule in catalog) {
    if (drawnIds.contains(rule.id) && rule.category != null) {
      picked[rule.category!] = (picked[rule.category!] ?? 0) + 1;
    }
  }
  final groups = <({String category, List<DrinkingRule> rules, int picked})>[];
  for (final category in _categories) {
    final rules = candidates.where((rule) => rule.category == category).toList();
    if (rules.isNotEmpty) {
      groups.add((category: category, rules: rules, picked: picked[category] ?? 0));
    }
  }
  final cap = plannedRuleEvents >= 3
      ? math.min(plannedRuleEvents - 1, (plannedRuleEvents * 0.75).ceil())
      : null;
  final underCap = groups.where((group) => cap == null || group.picked < cap).toList();
  final allowed = underCap.isNotEmpty ? underCap : groups;

  DrinkingRule pickFrom(List<DrinkingRule> rules) => selectContent(
    candidates: rules, kind: ContentKind.rule,
    history: history, nowUtc: nowUtc, random: random,
  );
  if (allowed.length == 1) return pickFrom(allowed.single.rules);

  final weights = <int>[];
  for (final group in allowed) {
    final n = group.rules.length;
    final uses = group.rules.fold<int>(
      0, (sum, rule) => sum + history.recentCount(ContentKind.rule, rule.id, nowUtc),
    );
    // n^1.5 / (1 + party picks / 20) / (1 + mean six-hour uses).
    weights.add(
      math.max(
        1,
        (20000 * n * math.sqrt(n) * n / ((20 + group.picked) * (n + uses))).floor(),
      ),
    );
  }
  final total = weights.fold<int>(0, (sum, weight) => sum + weight);
  var ticket = random.nextInt(total);
  if (ticket < 0 || ticket >= total) {
    throw const DomainException(
      DomainErrorCode.invalidState, 'Ungültiger injizierter Zufallsindex.',
    );
  }
  for (var index = 0; index < allowed.length; index++) {
    ticket -= weights[index];
    if (ticket < 0) return pickFrom(allowed[index].rules);
  }
  throw const DomainException(
    DomainErrorCode.invalidState, 'Ungültiger injizierter Zufallsindex.',
  );
}
