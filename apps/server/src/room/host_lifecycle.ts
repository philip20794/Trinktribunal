import {
  hostDeadline,
  initialGameState,
  presenceChanged,
  stageRoster,
} from '../domain/game_reducer';
import { immutable, type MutableGameState } from '../domain/game_state';
import type { PlayerId } from '../protocol/room_message.generated';
import { protocolMetadata } from '../protocol/room_message.generated';
import type { RoomState } from './repository';

/** A handled no-candidate deadline waits for a presence event, never another past alarm. */
export function nextHostDeadline(state: RoomState): number | null {
  const game = state.game;
  return !game || game.hostDisconnectedAt === null || game.pauseReason === 'host_unavailable'
    ? null
    : game.hostDisconnectedAt + protocolMetadata.limits.hostGraceMs;
}

/** Trusted current-generation socket presence. Does not extend the domain activity clock. */
export function reconcileHost(
  state: RoomState,
  connected: ReadonlySet<PlayerId>,
  now: number,
  { detectMissing = false, presenceRevision = false } = {},
): boolean {
  const original = state.game,
    online = connected.has(state.hostId);
  if (!original && (!detectMissing || online)) return false;
  if (original && online && original.hostDisconnectedAt === null && !original.hostPauseState)
    return false;
  const roster = state.members.filter((m) => !m.revoked).map((m) => m.playerId);
  let game =
    original ??
    initialGameState({
      hostId: state.hostId,
      roster: state.members
        .filter((m) => !m.revoked || m.playerId === state.hostId)
        .map((m) => m.playerId),
      config: state.config,
      now: state.lastDomainActivity,
    });
  if (!original) {
    const initial = structuredClone(game) as MutableGameState;
    initial.joinOrder = [...state.members]
      .sort((a, b) => a.joinedAt - b.joinedAt || (a.joinedSequence ?? 0) - (b.joinedSequence ?? 0))
      .map((m) => m.playerId);
    game = immutable(initial);
    if (roster.length !== game.roster.length) game = stageRoster(game, roster, now);
  }
  const draft = structuredClone(game) as MutableGameState;
  draft.revision = state.revision;
  draft.hostId = state.hostId;
  draft.connected = roster.filter((id) => connected.has(id));
  if (online && draft.hostDisconnectedAt !== null) {
    draft.connected = draft.connected.filter((id) => id !== state.hostId);
    game = presenceChanged(immutable(draft), state.hostId, true, now);
  } else {
    if (!online && draft.hostDisconnectedAt === null) draft.hostDisconnectedAt = now;
    game = immutable(draft);
  }
  game = hostDeadline(game, now);
  const changed =
    !original ||
    game.hostId !== original.hostId ||
    game.hostRevision !== original.hostRevision ||
    game.hostDisconnectedAt !== original.hostDisconnectedAt ||
    game.phase !== original.phase ||
    game.pausedFrom !== original.pausedFrom ||
    game.pauseReason !== original.pauseReason ||
    JSON.stringify(game.connected) !== JSON.stringify(original.connected) ||
    JSON.stringify(game.hostPauseState) !== JSON.stringify(original.hostPauseState);
  if (!changed) return false;
  if (!presenceRevision) state.revision++;
  const committed = structuredClone(game) as MutableGameState;
  committed.revision = state.revision;
  state.game = immutable(committed);
  state.hostId = game.hostId;
  state.phase = game.phase;
  return true;
}
