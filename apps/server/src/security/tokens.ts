import { ProtocolDecodeException, RoomIds } from '../protocol/room_message';
import type { RoomId } from '../protocol/room_message.generated';

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/, '');
}

export function newResumeToken(): string {
  return base64url(crypto.getRandomValues(new Uint8Array(32)));
}

export async function resumeVerifier(roomId: RoomId, token: string): Promise<string> {
  RoomIds.room(roomId);
  if (!/^[A-Za-z0-9_-]{43}$/.test(token)) throw new ProtocolDecodeException('CREDENTIAL_INVALID');
  const bytes = Uint8Array.from(atob(token.replaceAll('-', '+').replaceAll('_', '/') + '='), (c) =>
    c.charCodeAt(0),
  );
  if (bytes.length !== 32 || base64url(bytes) !== token)
    throw new ProtocolDecodeException('CREDENTIAL_INVALID');
  const prefix = new TextEncoder().encode(`trinktribunal-resume-v1\0${roomId}\0`);
  const input = new Uint8Array(prefix.length + bytes.length);
  input.set(prefix);
  input.set(bytes, prefix.length);
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', input)), (b) =>
    b.toString(16).padStart(2, '0'),
  ).join('');
}

export function sameVerifier(a: string, b: string): boolean {
  if (!/^[a-f0-9]{64}$/.test(a) || !/^[a-f0-9]{64}$/.test(b)) return false;
  return crypto.subtle.timingSafeEqual(new TextEncoder().encode(a), new TextEncoder().encode(b));
}
