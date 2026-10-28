import type { PlayerId, RoomId, RoomMessage } from '../protocol/room_message.generated';
import { createRoomMessage, encodeRoomMessage, RoomIds } from '../protocol/room_message';
import { protocolMetadata } from '../protocol/room_message.generated';
import { createHash } from 'node:crypto';

export const SOCKET_LIMITS = Object.freeze({
  pendingPerRoom: 10,
  totalPerRoom: 40,
  upgradesPerAddress: 60,
  authPerRoom: 120,
});
export type SocketAttachment =
  | { formatVersion: 1; kind: 'pending'; socketId: string; authDeadline: number }
  | {
      formatVersion: 1;
      kind: 'authenticated';
      socketId: string;
      roomId: RoomId;
      playerId: PlayerId;
      generation: number;
      viewRevision?: number;
      playersHash?: string;
      viewExpiry?: number;
    }
  | { formatVersion: 1; kind: 'closed'; socketId: string };
export function attachment(socket: WebSocket): SocketAttachment | null {
  let value: unknown;
  try {
    value = socket.deserializeAttachment();
  } catch {
    return null;
  }
  if (
    !value ||
    typeof value !== 'object' ||
    !('formatVersion' in value) ||
    value.formatVersion !== 1 ||
    !('kind' in value) ||
    !('socketId' in value) ||
    typeof value.socketId !== 'string' ||
    !/^[A-Za-z0-9_-]{1,64}$/.test(value.socketId)
  )
    return null;
  if (
    value.kind === 'pending' &&
    'authDeadline' in value &&
    Number.isSafeInteger(value.authDeadline) &&
    Object.keys(value).length === 4
  )
    return value as SocketAttachment;
  if (
    value.kind === 'authenticated' &&
    'roomId' in value &&
    'playerId' in value &&
    'generation' in value &&
    typeof value.roomId === 'string' &&
    typeof value.playerId === 'string' &&
    /^[A-Za-z0-9_-]{1,64}$/.test(value.roomId) &&
    /^[A-Za-z0-9_-]{1,64}$/.test(value.playerId) &&
    Number.isSafeInteger(value.generation) &&
    Number(value.generation) > 0 &&
    Object.keys(value).every((key) =>
      [
        'formatVersion',
        'kind',
        'socketId',
        'roomId',
        'playerId',
        'generation',
        'viewRevision',
        'playersHash',
        'viewExpiry',
      ].includes(key),
    ) &&
    (!('viewRevision' in value) ||
      (Number.isSafeInteger(value.viewRevision) && Number(value.viewRevision) >= 0)) &&
    (!('viewExpiry' in value) ||
      (Number.isSafeInteger(value.viewExpiry) && Number(value.viewExpiry) > 0)) &&
    (!('playersHash' in value) ||
      (typeof value.playersHash === 'string' && /^[a-f0-9]{64}$/.test(value.playersHash)))
  )
    return value as SocketAttachment;
  if (value.kind === 'closed' && Object.keys(value).length === 3) return value as SocketAttachment;
  return null;
}
export function sendMessage(socket: WebSocket, message: RoomMessage): void {
  if (message.type !== 'snapshot' && message.type !== 'delta') {
    socket.send(encodeRoomMessage(message, { direction: 'server' }));
    return;
  }
  const raw = encodeRoomMessage(message, { direction: 'server', logical: true });
  const bytes = new TextEncoder().encode(raw);
  if (bytes.length <= protocolMetadata.limits.frameBytes) {
    socket.send(raw);
    return;
  }
  const size = protocolMetadata.limits.projectionChunkBytes;
  const transferId = RoomIds.transfer(crypto.randomUUID());
  const requestId = message.requestId;
  sendMessage(
    socket,
    createRoomMessage('projectionStart', {
      requestId,
      transferId,
      revision: message.revision,
      chunks: Math.ceil(bytes.length / size),
      bytes: bytes.length,
      sha256: createHash('sha256').update(bytes).digest('hex'),
    }),
  );
  for (let offset = 0; offset < bytes.length; offset += size) {
    const data = btoa(String.fromCharCode(...bytes.subarray(offset, offset + size)))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
    sendMessage(
      socket,
      createRoomMessage('projectionChunk', {
        requestId,
        transferId,
        index: offset / size,
        data,
      }),
    );
  }
  sendMessage(socket, createRoomMessage('projectionEnd', { requestId, transferId }));
}
export function closeSocket(socket: WebSocket, code: number): void {
  const info = attachment(socket);
  socket.serializeAttachment({
    formatVersion: 1,
    kind: 'closed',
    socketId: info?.socketId ?? 'invalid_attachment',
  } satisfies SocketAttachment);
  try {
    socket.close(code, '');
  } catch {
    /* A concurrently closed client needs no further response. */
  }
}
