import { createHash } from 'node:crypto';
import { canonicalJson } from '../../../../packages/protocol/schema-validation.mjs';
import {
  initialGameState,
  stageRoster,
  transition,
  gameActions,
  decodeRerollCommand,
  rerollCurrentQuestion,
  type RerollCommand,
} from '../domain/game_reducer';
import { gamePorts } from '../domain/game_ports';
import { scoreRound } from '../domain/verdict';
import { synchronizeRoster } from './roster';
import { immutable, type GamePorts, type MutableGameState } from '../domain/game_state';
import {
  decodeRoomMessage,
  ProtocolDecodeException,
  type ProtocolErrorCode,
} from '../protocol/room_message';
import type { PlayerId, RoomMessage } from '../protocol/room_message.generated';
import { protocolMetadata } from '../protocol/room_message.generated';
import { RoomRepository, roomExpiry, type RoomState } from './repository';

const types = gameActions;
type GameCommand = Extract<RoomMessage, { type: (typeof types)[number] }>;
export function isGameAction(command: RoomMessage): command is GameCommand {
  return (types as readonly string[]).includes(command.type);
}
export type GameActionResult =
  | { ok: true; revision: number; duplicate: boolean }
  | { ok: false; code: ProtocolErrorCode; retryable?: boolean };
export const productionGamePorts = () => gamePorts(scoreRound);

export function synchronizedGame(
  state: RoomState,
  connected: ReadonlySet<PlayerId>,
  now: number,
): MutableGameState {
  const roster = state.members.filter((member) => !member.revoked).map((member) => member.playerId);
  let game =
    state.game ??
    initialGameState({
      hostId: state.hostId,
      roster,
      config: state.config,
      now: state.lastDomainActivity,
    });
  if (canonicalJson(game.roster) !== canonicalJson(roster)) game = stageRoster(game, roster, now);
  const next = structuredClone(game) as MutableGameState;
  next.revision = state.revision;
  next.hostId = state.hostId;
  next.connected = roster.filter((id) => connected.has(id));
  if (!state.game)
    next.joinOrder = [...state.members]
      .sort((a, b) => a.joinedAt - b.joinedAt || (a.joinedSequence ?? 0) - (b.joinedSequence ?? 0))
      .map((member) => member.playerId);
  return next;
}
/** No side effects or socket writes are allowed inside this function. */
function mutate(
  state: RoomState,
  actor: { playerId: PlayerId; generation: number },
  input: unknown,
  connected: ReadonlySet<PlayerId>,
  ports: GamePorts,
  internalReroll = false,
): { state: RoomState; result: GameActionResult } {
  const now = ports.now();
  if (now >= roomExpiry(state)) return { state, result: { ok: false, code: 'ROOM_UNAVAILABLE' } };
  if (
    !state.members.some(
      (member) =>
        member.playerId === actor.playerId &&
        !member.revoked &&
        member.generation === actor.generation,
    ) ||
    !connected.has(actor.playerId)
  )
    return { state, result: { ok: false, code: 'CREDENTIAL_INVALID' } };
  const command: GameCommand | RerollCommand = internalReroll
    ? decodeRerollCommand(input)
    : (decodeRoomMessage(JSON.stringify(input), {
        direction: 'client',
        allowedTypes: types,
      }) as GameCommand);
  const lobbyReceipt = state.lobbyReceipts?.find(
    (receipt) => receipt.actionId === command.actionId,
  );
  if (lobbyReceipt) return { state, result: { ok: false, code: 'ACTION_ID_CONFLICT' } };
  if (
    (state.lobbyReceipts?.length ?? 0) + (state.game?.receipts.length ?? 0) >=
      protocolMetadata.limits.actionJournalEntries &&
    !state.game?.receipts.some((receipt) => receipt.actionId === command.actionId)
  )
    return { state, result: { ok: false, code: 'RATE_LIMITED' } };
  if ((command.type === 'startGame' || command.type === 'restartGame') && state.historyOffer)
    return { state, result: { ok: false, code: 'INVALID_PHASE' } };
  const game = synchronizedGame(state, connected, now);
  const outcome = (internalReroll ? rerollCurrentQuestion : transition)(
    immutable(game),
    actor.playerId,
    command,
    {
      ...ports,
      now: () => now,
    },
  );
  if (!outcome.ok)
    return {
      state,
      result: {
        ok: false,
        code: outcome.code,
        ...(outcome.code === 'ROOM_UNAVAILABLE' ? { retryable: true } : {}),
      },
    };
  const receipt = outcome.state.receipts.find((receipt) => receipt.actionId === command.actionId)!;
  if (outcome.duplicate)
    return { state, result: { ok: true, revision: receipt.revision, duplicate: true } };
  const next: RoomState = {
    ...state,
    game: outcome.state,
    revision: outcome.state.revision,
    phase: outcome.state.phase,
    config: outcome.state.config,
    lastDomainActivity: now,
  };
  for (const member of next.members)
    member.selectionCount =
      outcome.state.personCounts.find((entry) => entry.playerId === member.playerId)?.count ??
      member.selectionCount;
  const previousIds = new Set(state.game?.history.map((event) => event.eventId) ?? []);
  next.historyOwners = { ...state.historyOwners };
  for (const event of outcome.state.history)
    if (!previousIds.has(event.eventId)) next.historyOwners[event.eventId] = state.hostId;
  synchronizeRoster(next, now);
  return { state: next, result: { ok: true, revision: receipt.revision, duplicate: false } };
}
/** Validate → transition → durable commit. The caller sends ACK/projection only after return. */
export function commitGameAction(
  repository: RoomRepository,
  actor: { playerId: PlayerId; generation: number },
  command: unknown,
  connected: ReadonlySet<PlayerId>,
  ports: GamePorts = productionGamePorts(),
): GameActionResult {
  return commitDomainAction(repository, actor, command, connected, ports, false);
}
/** Module entry for the same versioned reroll intent used by the socket route. */
export function commitRerollAction(
  repository: RoomRepository,
  actor: { playerId: PlayerId; generation: number },
  command: unknown,
  connected: ReadonlySet<PlayerId>,
  ports: GamePorts = productionGamePorts(),
): GameActionResult {
  return commitDomainAction(repository, actor, command, connected, ports, true);
}
function commitDomainAction(
  repository: RoomRepository,
  actor: { playerId: PlayerId; generation: number },
  command: unknown,
  connected: ReadonlySet<PlayerId>,
  ports: GamePorts,
  internalReroll: boolean,
): GameActionResult {
  try {
    return repository.storage.transactionSync(() => {
      const state = repository.read();
      if (!state) return { ok: false as const, code: 'ROOM_UNAVAILABLE' as const };
      const result = mutate(state, actor, command, connected, ports, internalReroll);
      if (result.result.ok && !result.result.duplicate) repository.write(result.state);
      return result.result;
    });
  } catch (error) {
    return {
      ok: false,
      retryable: !(error instanceof ProtocolDecodeException),
      code:
        error instanceof ProtocolDecodeException && error.code !== 'INVALID_JSON'
          ? error.code
          : 'ROOM_UNAVAILABLE',
    };
  }
}
export function actionFingerprint(input: unknown): string {
  return createHash('sha256').update(canonicalJson(input)).digest('hex');
}
