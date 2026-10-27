import { DurableObject } from 'cloudflare:workers';
import { readRoomMessage, roomError } from './protocol/http';
import { ProtocolDecodeException } from './protocol/room_message';

// Deliberately no public room creation/lookup route before TT-037.
export class Room extends DurableObject<Env> {
  override async fetch(): Promise<Response> {
    return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
  }
}

export default {
  async fetch(request: Request): Promise<Response> {
    const headers = { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' };
    if (request.method === 'POST' && new URL(request.url).pathname === '/api/rooms') {
      try {
        await readRoomMessage(request, { direction: 'client', allowedTypes: ['create'] });
        // Validation is live; atomic creation is added in TT-037.
        return roomError('ROOM_UNAVAILABLE', 503);
      } catch (error) {
        if (!(error instanceof ProtocolDecodeException)) throw error;
        return roomError(
          error.code === 'INVALID_JSON' ? 'INVALID_MESSAGE' : error.code,
          error.code === 'MESSAGE_TOO_LARGE' ? 413 : 400,
        );
      }
    }
    if (new URL(request.url).pathname !== '/health') {
      return Response.json({ error: 'NOT_FOUND' }, { status: 404, headers });
    }
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return Response.json(
        { error: 'METHOD_NOT_ALLOWED' },
        {
          status: 405,
          headers: { ...headers, Allow: 'GET, HEAD' },
        },
      );
    }
    return new Response(
      request.method === 'HEAD'
        ? null
        : JSON.stringify({ status: 'ok', service: 'trinktribunal', protocolVersion: 1 }),
      {
        headers: { ...headers, 'Content-Type': 'application/json; charset=utf-8' },
      },
    );
  },
} satisfies ExportedHandler<Env>;
