import type { PlayerId } from '../protocol/room_message.generated';
import { immutable, type GameState, type NormalScore, type Score } from './game_state';

type NumberAssignment = { readonly playerId: PlayerId; readonly number: number };
function permutation(proposed: readonly PlayerId[], ids: readonly PlayerId[]): void {
  if (
    proposed.length !== ids.length ||
    new Set(proposed).size !== proposed.length ||
    proposed.some((id) => !ids.includes(id))
  )
    throw new Error('INVALID_PERMUTATION');
}
function trueOrder(numbers: readonly NumberAssignment[]): PlayerId[] {
  if (
    new Set(numbers.map((entry) => entry.playerId)).size !== numbers.length ||
    numbers.some(
      (entry) => !Number.isInteger(entry.number) || entry.number < 1 || entry.number > 80,
    ) ||
    new Set(numbers.map((entry) => entry.number)).size !== numbers.length
  )
    throw new Error('INVALID_NUMBERS');
  return [...numbers].sort((a, b) => a.number - b.number).map((entry) => entry.playerId);
}

/** Counts wrong positions, not inversions or the number of moves used to sort. */
export function normalVerdict(
  judge: PlayerId,
  numbers: readonly NumberAssignment[],
  proposed: readonly PlayerId[],
) {
  const ids = numbers.map((entry) => entry.playerId);
  permutation(proposed, ids);
  if (ids.includes(judge)) throw new Error('INVALID_PERMUTATION');
  const truth = trueOrder(numbers);
  const incorrect = proposed.filter((id, index) => id !== truth[index]),
    errors = incorrect.length;
  const sipCounts: Record<string, number> = Object.create(null);
  sipCounts[judge] = errors;
  for (const id of proposed) sipCounts[id] = incorrect.includes(id) ? errors : 0;
  return immutable({ truth, incorrect, errors, sipCounts });
}
/** Each participant pays only their own wrong-position count, without co-drinking. */
export function allJudgesVerdict(
  numbers: readonly NumberAssignment[],
  orders: readonly { readonly playerId: PlayerId; readonly order: readonly PlayerId[] }[],
) {
  const truth = trueOrder(numbers);
  permutation(
    orders.map((entry) => entry.playerId),
    truth,
  );
  const errors: Record<string, number> = Object.create(null);
  for (const entry of orders) {
    permutation(entry.order, truth);
    errors[entry.playerId] = entry.order.filter((id, index) => id !== truth[index]).length;
  }
  return immutable(errors);
}

export function scoreNormalRound(state: GameState): NormalScore {
  const round = state.round,
    judge = state.judgeId;
  if (state.config.allJudges || !round || !judge || round.revealCursor !== round.recipients.length)
    throw new Error('INCOMPLETE_NORMAL_VERDICT');
  const order = round.orders.find((entry) => entry.playerId === judge);
  if (!order) throw new Error('MISSING_ORDER');
  const verdict = normalVerdict(judge, round.numbers, order.order);
  return {
    kind: 'normal',
    errors: verdict.errors,
    penalties: round.roster.map((playerId) => {
      const sips = verdict.sipCounts[playerId];
      if (sips === undefined) throw new Error('INVALID_ROSTER');
      return { playerId, sips };
    }),
  };
}

export function scoreRound(state: GameState): Score {
  if (!state.config.allJudges) return scoreNormalRound(state);
  const round = state.round;
  if (!round || round.revealCursor !== round.recipients.length)
    throw new Error('INCOMPLETE_PERSONAL_VERDICT');
  const errors = allJudgesVerdict(round.numbers, round.orders);
  return {
    kind: 'all_judges',
    results: round.roster.map((playerId) => {
      const count = errors[playerId];
      if (count === undefined) throw new Error('INVALID_ROSTER');
      return { playerId, errors: count, sips: count };
    }),
  };
}
