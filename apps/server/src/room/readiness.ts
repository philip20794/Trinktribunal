import type { GameState } from '../domain/game_state';
import type { PlayerId } from '../protocol/room_message.generated';

/** Public, phase-specific status only. Oral answer content never enters the state. */
export function readyInPhase(game: GameState | undefined, playerId: PlayerId): boolean {
  if (game?.phase === 'numbers') return game.round?.acknowledged.includes(playerId) ?? false;
  if (game?.phase === 'answers') return game.round?.answerReady.includes(playerId) ?? false;
  return false;
}
