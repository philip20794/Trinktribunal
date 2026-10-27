import type { UsageEvent } from '../game_state';
import { choose, type RandomIndex } from './random';

export function recentCount(
  history: readonly Readonly<UsageEvent>[],
  kind: 'question' | 'rule',
  id: string,
  now: number,
): number {
  return history.filter(
    (event) =>
      event.kind === kind &&
      event.contentId === id &&
      Date.parse(event.timestampUtc) > now - 6 * 60 * 60 * 1000,
  ).length;
}
export function selectContent<T extends { readonly id: string }>(
  candidates: readonly T[],
  kind: 'question' | 'rule',
  history: readonly Readonly<UsageEvent>[],
  now: number,
  random: RandomIndex,
): T {
  const uses = new Map(
    candidates.map((entry) => [entry.id, recentCount(history, kind, entry.id, now)]),
  );
  const minimum = Math.min(...uses.values());
  return choose(
    candidates.filter((entry) => uses.get(entry.id) === minimum),
    random,
  );
}
