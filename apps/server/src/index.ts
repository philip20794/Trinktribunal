import { DurableObject } from 'cloudflare:workers';

// Deliberately no public room creation/lookup route before TT-037.
export class Room extends DurableObject<Env> {
  override async fetch(): Promise<Response> {
    return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
  }
}

export default {
  async fetch(request: Request): Promise<Response> {
    const headers = { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' };
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
