import type { GameState } from '../domain/game_state';
import type { PublicView } from '../protocol/room_message.generated';

/** Explicit allowlist: order after confirmation, result only after full committed reveal. */
export function normalRevealFields(
  game: GameState | undefined,
): Pick<PublicView, 'judgeOrder' | 'result'> {
  if (!game?.round || game.config.allJudges || !['revealing', 'judged'].includes(game.phase))
    return {};
  const order = game.round.orders.find((entry) => entry.playerId === game.judgeId)?.order;
  const score =
    game.phase === 'judged' && game.round.revealCursor === game.round.recipients.length
      ? game.round.score
      : null;
  return {
    ...(order ? { judgeOrder: order } : {}),
    ...(score?.kind === 'normal'
      ? { result: { errors: score.errors, penalties: score.penalties } }
      : {}),
  };
}
