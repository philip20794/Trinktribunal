import type { PlayerId, RoomId, RoomMessage } from '../protocol/room_message.generated';
import { encodeRoomMessage } from '../protocol/room_message';

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
    }
  | { formatVersion: 1; kind: 'closed'; socketId: string };
export function attachment(socket: WebSocket): SocketAttachment | null {
  const value: unknown = socket.deserializeAttachment();
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
    Object.keys(value).length === 6
  )
    return value as SocketAttachment;
  if (value.kind === 'closed' && Object.keys(value).length === 3) return value as SocketAttachment;
  return null;
}
export function sendMessage(socket: WebSocket, message: RoomMessage): void {
  socket.send(encodeRoomMessage(message, { direction: 'server' }));
}
export function closeSocket(socket: WebSocket, code: number): void {
  const info = attachment(socket);
  if (info)
    socket.serializeAttachment({
      formatVersion: 1,
      kind: 'closed',
      socketId: info.socketId,
    } satisfies SocketAttachment);
  try {
    socket.close(code, '');
  } catch {
    /* A concurrently closed client needs no further response. */
  }
}
