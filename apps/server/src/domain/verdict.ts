import type { PlayerId } from '../protocol/room_message.generated';
import { immutable, type GameState, type NormalScore } from './game_state';

/** Counts wrong positions, not inversions or the number of moves used to sort. */
export function normalVerdict(
  judge: PlayerId,
  numbers: readonly { readonly playerId: PlayerId; readonly number: number }[],
  proposed: readonly PlayerId[],
) {
  const ids = numbers.map((entry) => entry.playerId);
  if (
    proposed.length !== ids.length ||
    new Set(proposed).size !== proposed.length ||
    proposed.some((id) => !ids.includes(id)) ||
    new Set(ids).size !== ids.length ||
    ids.includes(judge)
  )
    throw new Error('INVALID_PERMUTATION');
  if (
    numbers.some(
      (entry) => !Number.isInteger(entry.number) || entry.number < 1 || entry.number > 60,
    ) ||
    new Set(numbers.map((entry) => entry.number)).size !== numbers.length
  )
    throw new Error('INVALID_NUMBERS');
  const truth = [...numbers].sort((a, b) => a.number - b.number).map((entry) => entry.playerId);
  const incorrect = proposed.filter((id, index) => id !== truth[index]),
    errors = incorrect.length;
  const sipCounts: Record<string, number> = Object.create(null);
  sipCounts[judge] = errors;
  for (const id of proposed) sipCounts[id] = incorrect.includes(id) ? errors : 0;
  return immutable({ truth, incorrect, errors, sipCounts });
}
/** Only the normal mode is attached here. Private all-judges scoring follows TT-052. */
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
