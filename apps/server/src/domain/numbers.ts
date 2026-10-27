import type { PlayerId } from '../protocol/room_message.generated';
import { choose, type RandomIndex } from './selection/random';

export function numberLimit(playerCount: number, factorTenths: number): number {
  if (
    !Number.isInteger(playerCount) ||
    playerCount < 3 ||
    playerCount > 20 ||
    !Number.isInteger(factorTenths) ||
    factorTenths < 10 ||
    factorTenths > 30
  )
    throw new Error('INVALID_CONFIG');
  return Math.floor((playerCount * factorTenths + 9) / 10);
}
export function assignNumbers(
  roster: readonly PlayerId[],
  judgeId: PlayerId,
  max: number,
  allJudges: boolean,
  random: RandomIndex,
): Array<{ playerId: PlayerId; number: number }> {
  if (
    roster.length < 3 ||
    roster.length > 20 ||
    new Set(roster).size !== roster.length ||
    !roster.includes(judgeId)
  )
    throw new Error('INVALID_ROSTER');
  const recipients = roster.filter((id) => allJudges || id !== judgeId);
  if (!Number.isInteger(max) || max < recipients.length || max > 60)
    throw new Error('INVALID_CONFIG');
  const remaining = Array.from({ length: max }, (_, index) => index + 1);
  return recipients.map((playerId) => {
    const number = choose(remaining, random);
    remaining.splice(remaining.indexOf(number), 1);
    return { playerId, number };
  });
}
