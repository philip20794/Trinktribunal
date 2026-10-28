import type { GameState } from '../domain/game_state';
import type { PlayerId } from '../protocol/room_message.generated';

/** An explicit private projection; a host/reader cannot request another person's result. */
export function ownPersonalVerdict(
  game: GameState | undefined,
  you: PlayerId,
): { errors: number; sips: number } | undefined {
  const round = game?.round;
  const phase = game?.phase === 'paused' ? game.pausedFrom : game?.phase;
  if (
    !game?.config.allJudges ||
    phase !== 'judged' ||
    !round ||
    round.revealCursor !== round.recipients.length ||
    round.score?.kind !== 'all_judges'
  )
    return undefined;
  const result = round.score.results.find((entry) => entry.playerId === you);
  return result ? { errors: result.errors, sips: result.sips } : undefined;
}
