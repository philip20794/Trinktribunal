import type { ContentEntry, RuleCategory } from '../catalogs';
import type { SelectionInput } from '../question_assignment';
import { recentCount, selectContent } from './content_selection';
import type { RandomIndex } from './random';

const categories: readonly RuleCategory[] = ['drinking_ritual', 'speech', 'behavior'];

/** Draw a weighted category on demand, then use the existing minimum counter within it. */
export function selectCategorizedRule(
  catalog: readonly ContentEntry[],
  candidates: readonly ContentEntry[],
  input: SelectionInput,
  random: RandomIndex,
): ContentEntry {
  // Existing category-free synthetic fixtures retain the previous rule-wide logic.
  if (candidates.some((rule) => !rule.category))
    return selectContent(candidates, 'rule', input.history, input.now, random);

  const drawnIds = new Set(input.drawn);
  const picked = new Map<RuleCategory, number>(categories.map((category) => [category, 0]));
  for (const rule of catalog) {
    if (drawnIds.has(rule.id) && rule.category)
      picked.set(rule.category, (picked.get(rule.category) ?? 0) + 1);
  }
  const groups = categories.map((category) => ({
    category,
    rules: candidates.filter((rule) => rule.category === category),
    picked: picked.get(category) ?? 0,
  })).filter((group) => group.rules.length > 0);
  const planned = input.plannedRuleEvents ?? 0;
  const cap = planned >= 3 ? Math.min(planned - 1, Math.ceil(planned * 0.75)) : null;
  const underCap = groups.filter((group) => cap === null || group.picked < cap);
  const allowed = underCap.length ? underCap : groups; // never skip a feasible slot
  if (allowed.length === 1)
    return selectContent(allowed[0]!.rules, 'rule', input.history, input.now, random);

  const weights = allowed.map((group) => {
    const n = group.rules.length;
    const uses = group.rules.reduce(
      (sum, rule) => sum + recentCount(input.history, 'rule', rule.id, input.now), 0,
    );
    // n^1.5 / (1 + party picks / 20) / (1 + mean six-hour uses).
    return Math.max(1, Math.floor(20000 * n * Math.sqrt(n) * n / ((20 + group.picked) * (n + uses))));
  });
  const total = weights.reduce((sum, value) => sum + value, 0);
  let ticket = random(total);
  if (!Number.isSafeInteger(ticket) || ticket < 0 || ticket >= total)
    throw new Error('INVALID_RANDOM');
  for (let i = 0; i < allowed.length; i++) {
    ticket -= weights[i]!;
    if (ticket < 0)
      return selectContent(allowed[i]!.rules, 'rule', input.history, input.now, random);
  }
  throw new Error('INVALID_RANDOM');
}
