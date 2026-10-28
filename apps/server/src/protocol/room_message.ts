import schema from '../../../../packages/protocol/schemas/room-message.schema.json';
import {
  assertJsonDepth,
  validateSchema,
} from '../../../../packages/protocol/schema-validation.mjs';
import { protocolMetadata } from './room_message.generated';
import type {
  RoomMessage,
  ActionId,
  RequestId,
  GameId,
  RoundId,
  RoomId,
  PlayerId,
  EventId,
  HistoryCursor,
  TransferId,
  ErrorMessage,
} from './room_message.generated';
export type * from './room_message.generated';
export const currentProtocolCatalogHash = protocolMetadata.catalogHash;

export type ProtocolErrorCode = ErrorMessage['code'];
export type ProtocolDecodeCode = ProtocolErrorCode | 'INVALID_JSON';
export class ProtocolDecodeException extends Error {
  constructor(readonly code: ProtocolDecodeCode) {
    super(code); // Never include a received payload, token or validation path.
  }
}
export interface DecodeOptions {
  catalogHash?: string;
  direction?: 'client' | 'server';
  allowedTypes?: ReadonlyArray<RoomMessage['type']>;
  logical?: boolean;
}
function fail(code: ProtocolDecodeCode = 'INVALID_MESSAGE'): never {
  throw new ProtocolDecodeException(code);
}
const record = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object' && !Array.isArray(value);
const questionIds = new Set<string>(protocolMetadata.questionIds);
const ruleIds = new Set<string>(protocolMetadata.ruleIds);

function checkProfile(value: unknown): void {
  if (!record(value)) return;
  if (typeof value.name === 'string') {
    const name = value.name;
    if (
      !name.isWellFormed() ||
      name !== name.trim() ||
      /[\u0000-\u001f\u007f]/u.test(name) ||
      [...new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(name)].length < 1 ||
      [...new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(name)].length > 24
    )
      fail('INVALID_NAME');
  }
  if (record(value.avatar) && value.avatar.version !== undefined && value.avatar.version !== 1)
    fail('AVATAR_MISMATCH');
}
function canonicalBase64(value: string, max: number, error: ProtocolErrorCode): void {
  try {
    const binary = atob(
      value.replaceAll('-', '+').replaceAll('_', '/') + '='.repeat((4 - (value.length % 4)) % 4),
    );
    const canonical = btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
    if (binary.length > max || canonical !== value) fail(error);
  } catch {
    fail(error);
  }
}
function checkTree(value: unknown, key = ''): void {
  if (Array.isArray(value)) {
    for (const item of value) checkTree(item, key);
    return;
  }
  if (!record(value)) return;
  if (
    key === 'question' &&
    typeof value.contentId === 'string' &&
    !questionIds.has(value.contentId)
  )
    fail();
  if (key === 'activeRules' && typeof value.contentId === 'string' && !ruleIds.has(value.contentId))
    fail();
  if (value.kind === 'question' || value.kind === 'rule') {
    if (!(value.kind === 'question' ? questionIds : ruleIds).has(value.contentId as string)) fail();
  }
  for (const [field, child] of Object.entries(value)) {
    if ((field === 'timestampUtc' || field === 'expiresAtUtc') && typeof child === 'string') {
      const date = new Date(child);
      if (!Number.isFinite(date.getTime()) || date.toISOString() !== child) fail();
    }
    checkTree(child, field);
  }
}
function freeze<T>(value: T): T {
  if (value !== null && typeof value === 'object') {
    for (const child of Object.values(value)) freeze(child);
    Object.freeze(value);
  }
  return value;
}

export function decodeRoomMessage(raw: string, options: DecodeOptions = {}): RoomMessage {
  if (typeof raw !== 'string') fail();
  const limit = options.logical
    ? protocolMetadata.limits.projectionBytes
    : protocolMetadata.limits.frameBytes;
  if (new TextEncoder().encode(raw).byteLength > limit) fail('MESSAGE_TOO_LARGE');
  try {
    assertJsonDepth(raw, protocolMetadata.limits.jsonDepth);
  } catch {
    fail();
  }
  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    fail('INVALID_JSON');
  }
  if (!record(value)) fail();
  if (value.protocolVersion !== 1) fail('PROTOCOL_MISMATCH');
  const handshake = value.handshake;
  if (record(handshake)) {
    if (handshake.protocolVersion !== 1) fail('PROTOCOL_MISMATCH');
    if (handshake.avatarVersion !== undefined && handshake.avatarVersion !== 1)
      fail('AVATAR_MISMATCH');
  }
  checkProfile(value.profile);
  for (const view of [value.public, value.publicChanges]) {
    if (record(view) && Array.isArray(view.players))
      for (const player of view.players) if (record(player)) checkProfile(player.profile);
  }
  try {
    validateSchema(value, schema);
  } catch {
    fail();
  }
  if (
    record(handshake) &&
    handshake.catalogHash !== (options.catalogHash ?? protocolMetadata.catalogHash)
  )
    fail('CATALOG_MISMATCH');
  if (typeof value.resumeToken === 'string')
    canonicalBase64(value.resumeToken, 32, 'CREDENTIAL_INVALID');
  if (value.type === 'projectionChunk')
    canonicalBase64(
      value.data as string,
      protocolMetadata.limits.projectionChunkBytes,
      'INVALID_MESSAGE',
    );
  if (options.allowedTypes && !options.allowedTypes.includes(value.type as RoomMessage['type']))
    fail();
  const serverTypes = new Set([
    'credential',
    'authenticated',
    'historyStatus',
    'historyEvents',
    'ack',
    'error',
    'sessionReplaced',
    'roomClosed',
    'pong',
    'snapshot',
    'delta',
    'projectionStart',
    'projectionChunk',
    'projectionEnd',
  ]);
  if (
    options.direction &&
    (serverTypes.has(value.type as string) ? 'server' : 'client') !== options.direction
  )
    fail();
  checkTree(value);
  // The cast follows structural AND semantic validation, not a trusted client assertion.
  return freeze(value) as unknown as RoomMessage;
}

export function encodeRoomMessage(message: RoomMessage, options: DecodeOptions = {}): string {
  const raw = JSON.stringify(message);
  decodeRoomMessage(raw, options);
  return raw;
}

export function createRoomMessage<T extends RoomMessage['type']>(
  type: T,
  fields: NoInfer<Omit<Extract<RoomMessage, { type: T }>, 'type' | 'protocolVersion'>>,
  options: DecodeOptions = {},
): Extract<RoomMessage, { type: T }> {
  if (Object.hasOwn(fields, 'type') || Object.hasOwn(fields, 'protocolVersion')) fail();
  return decodeRoomMessage(
    JSON.stringify({ type, protocolVersion: 1, ...fields }),
    options,
  ) as Extract<RoomMessage, { type: T }>;
}

function identifier<T extends string>(value: string): T {
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(value)) fail();
  return value as T;
}
export const RoomIds = Object.freeze({
  action: (value: string): ActionId => identifier<ActionId>(value),
  request: (value: string): RequestId => identifier<RequestId>(value),
  game: (value: string): GameId => identifier<GameId>(value),
  round: (value: string): RoundId => identifier<RoundId>(value),
  room: (value: string): RoomId => identifier<RoomId>(value),
  player: (value: string): PlayerId => identifier<PlayerId>(value),
  event: (value: string): EventId => identifier<EventId>(value),
  historyCursor: (value: string): HistoryCursor => identifier<HistoryCursor>(value),
  transfer: (value: string): TransferId => identifier<TransferId>(value),
});
