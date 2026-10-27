import { createHash } from 'node:crypto';
import { canonicalJson } from '../../../../packages/protocol/schema-validation.mjs';
import { immutable } from '../domain/game_state';
import {
  createRoomMessage,
  decodeRoomMessage,
  ProtocolDecodeException,
  RoomIds,
  type ProtocolErrorCode,
} from '../protocol/room_message';
import {
  protocolMetadata,
  type HistoryEvent,
  type HistoryOffer,
  type HistoryStatusMessage,
  type PlayerId,
  type RequestId,
  type RoomMessage,
} from '../protocol/room_message.generated';
import { synchronizedGame } from './actions';
import { RoomRepository, roomExpiry, type RoomState } from './repository';

export interface HistoryImportState {
  ownerId: PlayerId;
  offer: HistoryOffer;
  createdAt: number;
  status: 'receiving' | 'committed' | 'cancelled';
  pages: HistoryEvent[][];
  receivedPages: number[];
  receivedEvents: number;
  bytes: number;
}
export interface HistoryExport {
  cursor: string;
  ownerId: PlayerId;
  previous: string | null;
  eventIds: string[];
  received: boolean;
  hasMore: boolean;
}
const types = [
  'historyBegin',
  'historyImport',
  'cancelHistoryImport',
  'historyPull',
  'historyReceipt',
] as const;
type HistoryCommand = Extract<RoomMessage, { type: (typeof types)[number] }>;
export function isHistoryAction(command: RoomMessage): command is HistoryCommand {
  return (types as readonly string[]).includes(command.type);
}
export function initialHistoryImport(
  ownerId: PlayerId,
  offer: HistoryOffer,
  now: number,
): HistoryImportState {
  return {
    ownerId,
    offer,
    createdAt: now,
    status: offer.count === 0 && offer.sha256 === hash([]) ? 'committed' : 'receiving',
    pages: [],
    receivedPages: [],
    receivedEvents: 0,
    bytes: 0,
  };
}
const hash = (value: unknown) => createHash('sha256').update(canonicalJson(value)).digest('hex');
function status(imported: HistoryImportState, requestId: RequestId): HistoryStatusMessage {
  return createRoomMessage('historyStatus', {
    requestId,
    importId: imported.offer.importId,
    status: imported.status,
    receivedPages: imported.receivedPages,
    receivedEvents: imported.receivedEvents,
    ...(imported.status === 'committed' ? { sha256: imported.offer.sha256 } : {}),
  });
}
function failure(code: ProtocolErrorCode): never {
  throw new HistoryFailure(code);
}
class HistoryFailure extends Error {
  constructor(readonly code: ProtocolErrorCode) {
    super(code);
  }
}
function validEvent(event: HistoryEvent, now: number): boolean {
  const ids = event.kind === 'question' ? protocolMetadata.questionIds : protocolMetadata.ruleIds;
  const time = Date.parse(event.timestampUtc);
  return (
    (ids as readonly string[]).includes(event.contentId) &&
    time > now - protocolMetadata.limits.historyWindowMs &&
    time <= now
  );
}
function finish(
  state: RoomState,
  imported: HistoryImportState,
  connected: ReadonlySet<PlayerId>,
  now: number,
): void {
  const events = imported.pages.flat();
  if (
    events.length !== imported.offer.count ||
    hash(events) !== imported.offer.sha256 ||
    new Set(events.map((event) => event.eventId)).size !== events.length ||
    events.some((event) => !validEvent(event, now))
  )
    failure('INVALID_MESSAGE');
  const game = synchronizedGame(state, connected, now),
    byId = new Map(game.history.map((event) => [event.eventId, event]));
  for (const event of events) {
    const old = byId.get(event.eventId);
    if (old && canonicalJson(old) !== canonicalJson(event)) failure('ACTION_ID_CONFLICT');
    byId.set(event.eventId, event);
  }
  game.history = [...byId.values()];
  state.revision++;
  game.revision = state.revision;
  state.game = immutable(game);
  state.lastDomainActivity = now;
  delete state.historyOffer;
  imported.status = 'committed';
  imported.pages = [];
  imported.bytes = 0;
}
function apply(
  state: RoomState,
  ownerId: PlayerId,
  command: HistoryCommand,
  connected: ReadonlySet<PlayerId>,
  now: number,
): { message: RoomMessage; changed: boolean } {
  if (command.type === 'historyPull' || command.type === 'historyReceipt') {
    const exports = (state.historyExports ??= []);
    if (command.type === 'historyReceipt') {
      const page = exports.find(
        (page) => page.cursor === command.cursor && page.ownerId === ownerId,
      );
      if (!page) failure('UNAUTHORIZED_ACTION');
      const changed = !page.received;
      page.received = true;
      return {
        message: createRoomMessage('ack', {
          requestId: command.requestId,
          actionId: RoomIds.action(command.cursor),
          revision: state.revision,
          outcome: changed ? 'committed' : 'duplicate',
        }),
        changed,
      };
    }
    if (
      command.cursor !== null &&
      !exports.some((page) => page.cursor === command.cursor && page.ownerId === ownerId)
    )
      failure('UNAUTHORIZED_ACTION');
    let page = exports.find(
      (page) =>
        page.ownerId === ownerId &&
        page.previous === command.cursor &&
        (command.cursor !== null || !page.received),
    );
    let changed = false;
    if (!page) {
      if (exports.length >= protocolMetadata.limits.actionJournalEntries) failure('RATE_LIMITED');
      const sent = new Set(
        exports.filter((page) => page.ownerId === ownerId).flatMap((page) => page.eventIds),
      );
      const events = (state.game?.history ?? []).filter(
        (event) =>
          state.historyOwners?.[event.eventId] === ownerId &&
          !sent.has(event.eventId) &&
          Date.parse(event.timestampUtc) > now - protocolMetadata.limits.historyWindowMs,
      );
      page = {
        cursor: crypto.randomUUID(),
        ownerId,
        previous: command.cursor,
        eventIds: events
          .slice(0, protocolMetadata.limits.historyPageEntries)
          .map((event) => event.eventId),
        received: false,
        hasMore: events.length > protocolMetadata.limits.historyPageEntries,
      };
      exports.push(page);
      changed = true;
    }
    const ids = new Set(page.eventIds);
    const events = (state.game?.history ?? [])
      .filter((event) => ids.has(event.eventId))
      .map((event) => ({ ...event, eventId: RoomIds.event(event.eventId) }));
    return {
      message: createRoomMessage('historyEvents', {
        requestId: command.requestId,
        cursor: RoomIds.historyCursor(page.cursor),
        hasMore: page.hasMore,
        events,
      }),
      changed,
    };
  }
  if (state.hostId !== ownerId) failure('UNAUTHORIZED_ACTION');
  if (state.phase !== 'lobby' || state.game?.gameId) failure('INVALID_PHASE');
  let imported = state.historyImport;
  if (command.type === 'historyBegin') {
    if (imported?.offer.importId === command.offer.importId) {
      if (
        imported.ownerId !== ownerId ||
        canonicalJson(imported.offer) !== canonicalJson(command.offer)
      )
        failure('ACTION_ID_CONFLICT');
      return { message: status(imported, command.requestId), changed: false };
    }
    if (imported && imported.status !== 'cancelled') failure('INVALID_PHASE');
    imported = initialHistoryImport(ownerId, command.offer, now);
    state.historyImport = imported;
    state.historyOffer = command.offer;
    state.historyPageHashes = {};
    if (command.offer.count === 0) finish(state, imported, connected, now);
    return { message: status(imported, command.requestId), changed: true };
  }
  if (!imported || imported.ownerId !== ownerId || imported.offer.importId !== command.importId)
    failure('UNAUTHORIZED_ACTION');
  if (command.type === 'cancelHistoryImport') {
    if (imported.status === 'committed') failure('INVALID_PHASE');
    const changed = imported.status !== 'cancelled';
    imported.status = 'cancelled';
    imported.pages = [];
    imported.bytes = 0;
    delete state.historyOffer;
    return { message: status(imported, command.requestId), changed };
  }
  if (imported.status === 'committed') {
    if (state.historyPageHashes?.[command.page] !== hash(command.events))
      failure('ACTION_ID_CONFLICT');
    return { message: status(imported, command.requestId), changed: false };
  }
  if (
    imported.status !== 'receiving' ||
    now >= imported.createdAt + protocolMetadata.limits.historyTimeoutMs
  )
    failure('INVALID_PHASE');
  const prior = imported.pages[command.page];
  if (prior) {
    if (canonicalJson(prior) !== canonicalJson(command.events)) failure('ACTION_ID_CONFLICT');
    return { message: status(imported, command.requestId), changed: false };
  }
  if (
    command.page !== imported.pages.length ||
    command.events.some((event) => !validEvent(event, now))
  )
    failure('INVALID_MESSAGE');
  const ids = new Set(imported.pages.flatMap((page) => page.map((event) => event.eventId)));
  if (
    command.events.some((event) => ids.has(event.eventId)) ||
    new Set(command.events.map((event) => event.eventId)).size !== command.events.length
  )
    failure('INVALID_MESSAGE');
  const bytes = new TextEncoder().encode(canonicalJson(command.events)).length;
  if (
    imported.bytes + bytes > protocolMetadata.limits.historyStagingBytes ||
    imported.receivedEvents + command.events.length > imported.offer.count
  )
    failure('MESSAGE_TOO_LARGE');
  imported.pages.push(structuredClone([...command.events]));
  imported.receivedPages.push(command.page);
  imported.receivedEvents += command.events.length;
  imported.bytes += bytes;
  (state.historyPageHashes ??= {})[command.page] = hash(command.events);
  if (imported.receivedEvents === imported.offer.count) finish(state, imported, connected, now);
  return { message: status(imported, command.requestId), changed: true };
}
export function commitHistoryAction(
  repository: RoomRepository,
  owner: { playerId: PlayerId; generation: number },
  command: HistoryCommand,
  connected: ReadonlySet<PlayerId>,
  now = Date.now(),
):
  { ok: true; message: RoomMessage } | { ok: false; code: ProtocolErrorCode; retryable?: boolean } {
  try {
    const decoded = decodeRoomMessage(JSON.stringify(command), {
      direction: 'client',
      allowedTypes: types,
    }) as HistoryCommand;
    return repository.storage.transactionSync(() => {
      const state = repository.read();
      if (!state || now >= roomExpiry(state)) failure('ROOM_UNAVAILABLE');
      if (
        !state.members.some(
          (member) =>
            member.playerId === owner.playerId &&
            !member.revoked &&
            member.generation === owner.generation,
        ) ||
        !connected.has(owner.playerId)
      )
        failure('CREDENTIAL_INVALID');
      const outcome = apply(state, owner.playerId, decoded, connected, now);
      if (outcome.changed) repository.write(state);
      return { ok: true as const, message: outcome.message };
    });
  } catch (error) {
    return {
      ok: false,
      retryable: !(error instanceof HistoryFailure) && !(error instanceof ProtocolDecodeException),
      code:
        error instanceof HistoryFailure
          ? error.code
          : error instanceof ProtocolDecodeException
            ? error.code === 'INVALID_JSON'
              ? 'INVALID_MESSAGE'
              : error.code
            : 'ROOM_UNAVAILABLE',
    };
  }
}
export function ownHistoryStatus(
  state: RoomState,
  ownerId: PlayerId,
  requestId: RequestId,
): HistoryStatusMessage | null {
  return state.historyImport?.ownerId === ownerId && state.phase === 'lobby'
    ? status(state.historyImport, requestId)
    : null;
}

export function expireHistory(state: RoomState, now: number): boolean {
  const imported = state.historyImport;
  if (
    !imported ||
    imported.status !== 'receiving' ||
    (imported.ownerId === state.hostId &&
      now < imported.createdAt + protocolMetadata.limits.historyTimeoutMs)
  )
    return false;
  imported.status = 'cancelled';
  imported.pages = [];
  imported.bytes = 0;
  delete state.historyOffer;
  return true;
}
