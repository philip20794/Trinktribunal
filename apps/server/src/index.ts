import { routeRooms } from './http/rooms';
export { Room } from './room/room';

export default {
  async fetch(request: Request, env?: Env): Promise<Response> {
    const headers = { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' };
    const roomResponse = await routeRooms(request, env);
    if (roomResponse) return roomResponse;
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
        : JSON.stringify({ status: 'ok', service: 'trinktribunal', protocolVersion: 2 }),
      {
        headers: { ...headers, 'Content-Type': 'application/json; charset=utf-8' },
      },
    );
  },
} satisfies ExportedHandler<Env>;
