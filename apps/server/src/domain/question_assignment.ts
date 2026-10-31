import type { Assignment, PlayerId } from '../protocol/room_message.generated';
import type { ContentEntry } from './catalogs';
import type { UsageEvent } from './game_state';
import { selectContent } from './selection/content_selection';
import { personAssignment, type Counts } from './selection/person_assignment';
import type { RandomIndex } from './selection/random';

export interface SelectionInput {
  readonly players: readonly PlayerId[];
  readonly counts: Counts;
  readonly history: readonly Readonly<UsageEvent>[];
  readonly drawn: readonly string[];
  readonly now: number;
  readonly plannedRuleEvents?: number;
}
export function assignContent(
  entries: readonly ContentEntry[],
  kind: 'question' | 'rule',
  input: SelectionInput,
  random: RandomIndex,
): Assignment | null {
  const candidates = entries.filter(
    (entry) =>
      !input.drawn.includes(entry.id) &&
      personAssignment(entry.players ?? {}, input.players, input.counts).possible,
  );
  if (!candidates.length) return null;
  const entry = selectContent(candidates, kind, input.history, input.now, random);
  const bindings = personAssignment(entry.players ?? {}, input.players, input.counts).bind(random)!;
  return { contentId: entry.id, bindings };
}
