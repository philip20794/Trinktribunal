import type { GameState, MutableGameState } from '../domain/game_state';
import { immutable } from '../domain/game_state';
import { stageRoster } from '../domain/game_reducer';
import type { PlayerId } from '../protocol/room_message.generated';
import type { RoomState } from './repository';

/** Retired identities remain displayable only while the current public case/rules need them. */
export function retainedProfileIds(state: {
  hostId: PlayerId;
  game?: GameState;
}): ReadonlySet<PlayerId> {
  const game = state.game;
  return new Set([
    state.hostId,
    ...(game?.round?.roster ?? []),
    ...(game?.activeRules.flatMap((rule) => Object.values(rule.bindings)) ?? []),
    ...(game?.judgeId ? [game.judgeId] : []),
    ...(game?.readerId ? [game.readerId] : []),
  ]);
}
export function reservedSeatIds(
  state: Pick<RoomState, 'hostId' | 'game' | 'members'>,
): ReadonlySet<PlayerId> {
  const retained = retainedProfileIds(state);
  return new Set(
    state.members
      .filter((member) => !member.revoked || retained.has(member.playerId))
      .map((member) => member.playerId),
  );
}
/** Called in the same transaction as admission, revocation, reorder or case commit. */
export function synchronizeRoster(state: RoomState, now: number): void {
  if (state.game) {
    const ids = state.members.filter((member) => !member.revoked).map((member) => member.playerId),
      old = state.game.roster;
    if (ids.length !== old.length || ids.some((id, index) => id !== old[index])) {
      const game = structuredClone(stageRoster(state.game, ids, now)) as MutableGameState;
      game.revision = state.revision;
      state.game = immutable(game);
    }
  }
  const retained = retainedProfileIds(state);
  for (const member of state.members)
    if (member.revoked && !retained.has(member.playerId)) delete member.profile;
}
