import type { Assignment } from '../protocol/room_message.generated';
import type { ContentEntry } from './catalogs';
import type { SelectionInput } from './question_assignment';
import { personAssignment, recordPersons } from './selection/person_assignment';
import { selectCategorizedRule } from './selection/rule_category_selection';
import type { RandomIndex } from './selection/random';

export function rulesConflict(a: ContentEntry, b: ContentEntry): boolean {
  return (a.excludes ?? []).includes(b.id) || (b.excludes ?? []).includes(a.id);
}
export function activateRule(
  entries: readonly ContentEntry[],
  active: readonly Assignment[],
  input: SelectionInput,
  random: RandomIndex,
): Assignment | null {
  const byId = new Map(entries.map((entry) => [entry.id, entry]));
  const candidates = entries.filter(
    (entry) =>
      !input.drawn.includes(entry.id) &&
      personAssignment(entry.players ?? {}, input.players, input.counts).possible &&
      !active.some((rule) => {
        const existing = byId.get(rule.contentId);
        if (!existing) throw new Error('UNKNOWN_RULE');
        return rulesConflict(entry, existing);
      }),
  );
  if (!candidates.length) return null;
  const chosen = selectCategorizedRule(entries, candidates, input, random);
  const bindings = personAssignment(chosen.players ?? {}, input.players, input.counts).bind(random)!;
  return { contentId: chosen.id, bindings };
}
export function rebindRules(
  entries: readonly ContentEntry[],
  active: readonly Assignment[],
  input: SelectionInput,
  random: RandomIndex,
) {
  let counts = { ...input.counts };
  const rules: Assignment[] = [];
  for (const assignment of active) {
    const entry = entries.find((rule) => rule.id === assignment.contentId);
    if (!entry) throw new Error('UNKNOWN_RULE');
    const fixed = Object.fromEntries(
      Object.entries(assignment.bindings).filter(([, id]) => input.players.includes(id)),
    );
    if (Object.keys(fixed).length === Object.keys(assignment.bindings).length) {
      rules.push(assignment);
      continue;
    }
    const bindings = personAssignment(entry.players ?? {}, input.players, counts, fixed).bind(
      random,
    );
    if (!bindings) continue; // Inactive for the rest of this game; drawn IDs remain consumed.
    counts = recordPersons(
      counts,
      Object.entries(bindings)
        .filter(([role]) => !(role in fixed))
        .map(([, id]) => id),
    );
    rules.push({ contentId: assignment.contentId, bindings });
  }
  return {
    activeRules: rules,
    personCounts: Object.entries(counts).map(([playerId, count]) => ({
      playerId: playerId as import('../protocol/room_message.generated').PlayerId,
      count,
    })),
  };
}
