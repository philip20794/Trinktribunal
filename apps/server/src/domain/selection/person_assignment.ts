import type { PlayerId } from '../../protocol/room_message.generated';
import { choose, type RandomIndex } from './random';

export type Roles = Readonly<
  Record<string, { readonly selection?: string; readonly differentFrom?: readonly string[] }>
>;
export type Counts = Readonly<Record<string, number>>;

export function personAssignment(
  roles: Roles,
  players: readonly PlayerId[],
  counts: Counts,
  fixed: Readonly<Record<string, PlayerId>> = {},
) {
  const active = [...new Set(players)],
    keys = Object.keys(roles);
  const allowed = (role: string, id: PlayerId, assigned: Record<string, PlayerId>) =>
    Object.entries(assigned).every(
      ([other, person]) =>
        person !== id ||
        !(
          (roles[role]?.differentFrom ?? []).includes(other) ||
          (roles[other]?.differentFrom ?? []).includes(role)
        ),
    );
  function canComplete(assigned: Record<string, PlayerId>): boolean {
    const role = keys.find((key) => !(key in assigned));
    if (role === undefined) return true;
    for (const id of active) {
      if (!allowed(role, id, assigned)) continue;
      assigned[role] = id;
      const possible = canComplete(assigned);
      delete assigned[role];
      if (possible) return true;
    }
    return false;
  }
  const possible =
    Object.entries(fixed).every(
      ([role, id]) =>
        keys.includes(role) &&
        active.includes(id) &&
        allowed(
          role,
          id,
          Object.fromEntries(Object.entries(fixed).filter(([key]) => key !== role)),
        ),
    ) && canComplete({ ...fixed });
  return {
    possible,
    bind(random: RandomIndex): Record<string, PlayerId> | null {
      if (!possible) return null;
      const assigned = { ...fixed };
      for (const role of keys) {
        if (role in assigned) continue;
        const feasible = active.filter((id) => {
          if (!allowed(role, id, assigned)) return false;
          assigned[role] = id;
          const valid = canComplete(assigned);
          delete assigned[role];
          return valid;
        });
        const minimum = Math.min(
          ...feasible.map((id) => {
            const count = counts[id];
            if (!Number.isSafeInteger(count) || count! < 0) throw new Error('INVALID_COUNTS');
            return count!;
          }),
        );
        assigned[role] = choose(
          feasible.filter((id) => counts[id] === minimum),
          random,
        );
      }
      return assigned;
    },
  };
}
export function recordPersons(
  counts: Counts,
  selected: Iterable<PlayerId>,
): Record<string, number> {
  const next = { ...counts };
  for (const id of new Set(selected)) {
    if (!Number.isSafeInteger(next[id]) || next[id]! < 0 || next[id] === Number.MAX_SAFE_INTEGER)
      throw new Error('INVALID_COUNTS');
    next[id] = next[id]! + 1;
  }
  return next;
}
/** Resume keeps the existing value. Only a genuinely new/local reactivated participant calls this. */
export function withParticipant(
  counts: Counts,
  id: PlayerId,
  previouslyActive: readonly PlayerId[],
): Record<string, number> {
  return {
    ...counts,
    [id]: Math.max(
      counts[id] ?? 0,
      0,
      ...previouslyActive.map((active) => {
        const count = counts[active];
        if (!Number.isSafeInteger(count) || count! < 0) throw new Error('INVALID_COUNTS');
        return count!;
      }),
    ),
  };
}
