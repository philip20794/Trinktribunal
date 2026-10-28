import type { GameState } from '../domain/game_state';
import type { PlayerId } from '../protocol/room_message.generated';

/** An authenticated host has no additional access to another person's sealed order. */
export function ownConfirmedOrder(
  game: GameState | undefined,
  you: PlayerId,
): readonly PlayerId[] | undefined {
  const phase = game?.phase === 'paused' ? game.pausedFrom : game?.phase;
  if (!game?.round || !['ordering', 'revealing', 'judged'].includes(phase ?? '')) return undefined;
  if (!game.config.allJudges && game.judgeId !== you) return undefined;
  return game.round.orders.find((order) => order.playerId === you)?.order;
}
