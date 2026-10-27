import { readRoomMessage, roomError } from '../protocol/http';
import { ProtocolDecodeException, type ProtocolErrorCode } from '../protocol/room_message';
import { protocolMetadata } from '../protocol/room_message.generated';
import type { CreateResult } from '../room/room';

export const ROOM_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export function normalizeRoomCode(raw: string): string | null {
  if (raw.length > 64) return null;
  const code = raw.trim().replace(/[ -]/g, '').toUpperCase();
  return /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/.test(code) ? code : null;
}
export function randomRoomCode(): string {
  let code = '';
  const threshold = Math.floor(256 / ROOM_ALPHABET.length) * ROOM_ALPHABET.length;
  while (code.length < 8) {
    for (const byte of crypto.getRandomValues(new Uint8Array(16))) {
      if (byte < threshold) code += ROOM_ALPHABET[byte % ROOM_ALPHABET.length];
      if (code.length === 8) break;
    }
  }
  return code;
}

// Injectable candidate source is solely for deterministic collision units, never request data.
export async function allocateRoom(
  create: (code: string) => Promise<CreateResult>,
  candidate: () => string = randomRoomCode,
): Promise<Response> {
  for (let attempt = 0; attempt < protocolMetadata.limits.createAttempts; attempt++) {
    const result = await create(candidate());
    if ('collision' in result) continue;
    return result.ok ? privateResponse(result.message, 201) : roomError(result.code, result.status);
  }
  return roomError('ROOM_UNAVAILABLE', 503);
}
function privateResponse(message: unknown, status = 200): Response {
  return Response.json(message, {
    status,
    headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
  });
}
export function allowedOrigin(request: Request, env: Env): string | null {
  const origin = request.headers.get('Origin');
  if (!origin) return null;
  return env.CLIENT_ORIGINS.split(',')
    .map((value) => value.trim())
    .includes(origin)
    ? origin
    : null;
}
function withCors(response: Response, origin: string | null): Response {
  response.headers.set('Vary', 'Origin');
  if (origin) response.headers.set('Access-Control-Allow-Origin', origin);
  return response;
}
export async function routeRooms(request: Request, env?: Env): Promise<Response | null> {
  const url = new URL(request.url);
  const match = /^\/api\/rooms\/([^/]+)\/(join|leave)$/.exec(url.pathname);
  const create = url.pathname === '/api/rooms';
  if (!create && !match) return null;
  if (!['POST', 'OPTIONS'].includes(request.method)) return null;
  const origin = env ? allowedOrigin(request, env) : null;
  if (request.headers.has('Origin') && !origin)
    return withCors(roomError('UNAUTHORIZED_ACTION', 403), null);
  const finish = (response: Response) => withCors(response, origin);
  if (request.method === 'OPTIONS') {
    if (
      !origin ||
      request.headers.get('Access-Control-Request-Method') !== 'POST' ||
      (request.headers.get('Access-Control-Request-Headers') ?? '')
        .split(',')
        .some((h) => h.trim() && h.trim().toLowerCase() !== 'content-type')
    )
      return finish(roomError('UNAUTHORIZED_ACTION', 403));
    return finish(
      new Response(null, {
        status: 204,
        headers: {
          'Access-Control-Allow-Methods': 'POST',
          'Access-Control-Allow-Headers': 'Content-Type',
          'Cache-Control': 'no-store',
        },
      }),
    );
  }
  try {
    if (url.search) return finish(roomError('INVALID_MESSAGE', 400));
    const kind = create ? 'create' : match![2] === 'join' ? 'join' : 'leave';
    if (env) {
      // Cloudflare supplies this header at its edge. Native requests without it share a bounded bucket.
      const address = request.headers.get('CF-Connecting-IP') ?? 'unknown';
      if (address.length > 64) return finish(roomError('INVALID_MESSAGE', 400));
      const gate = env.ROOMS.getByName(`entry-rate:${address}`);
      if (!(await gate.consumeEntryAttempt(kind))) return finish(roomError('RATE_LIMITED', 429));
    }
    let code: string | null = null;
    if (!create) {
      try {
        code = normalizeRoomCode(decodeURIComponent(match![1]!));
      } catch {
        return finish(roomError('INVALID_MESSAGE', 400));
      }
      if (!code) return finish(roomError('INVALID_MESSAGE', 400));
    }
    const message = await readRoomMessage(request, {
      direction: 'client',
      allowedTypes: [kind === 'leave' ? 'leaveHttp' : kind],
    });
    if (!env) return finish(roomError('ROOM_UNAVAILABLE', 503));
    if (message.type === 'create')
      return finish(
        await allocateRoom((candidate) =>
          env.ROOMS.getByName(candidate).createIfAbsent(candidate, message),
        ),
      );
    const room = env.ROOMS.getByName(code!);
    const result =
      message.type === 'join'
        ? await room.join(message)
        : message.type === 'leaveHttp'
          ? await room.leave(message)
          : null;
    if (!result) return finish(roomError('INVALID_MESSAGE', 400));
    return finish(
      result.ok ? privateResponse(result.message) : roomError(result.code, result.status),
    );
  } catch (error) {
    if (error instanceof ProtocolDecodeException)
      return finish(
        roomError(
          error.code === 'INVALID_JSON' ? 'INVALID_MESSAGE' : error.code,
          error.code === 'MESSAGE_TOO_LARGE' ? 413 : 400,
        ),
      );
    // Runtime/storage failure must never echo credentials or persisted room data.
    return finish(roomError('ROOM_UNAVAILABLE' satisfies ProtocolErrorCode, 503));
  }
}
