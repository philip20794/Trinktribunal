import { protocolMetadata } from './room_message.generated';
import {
  createRoomMessage,
  decodeRoomMessage,
  ProtocolDecodeException,
  RoomIds,
  type DecodeOptions,
  type ProtocolErrorCode,
  type RoomMessage,
} from './room_message';

export async function readRoomMessage(
  request: Request,
  options: DecodeOptions = {},
): Promise<RoomMessage> {
  const limit = protocolMetadata.limits.frameBytes;
  if (Number(request.headers.get('Content-Length')) > limit)
    throw new ProtocolDecodeException('MESSAGE_TOO_LARGE');
  if (
    request.headers.get('Content-Type')?.toLowerCase().split(';', 1)[0]?.trim() !==
    'application/json'
  )
    throw new ProtocolDecodeException('INVALID_MESSAGE');
  if (!request.body) throw new ProtocolDecodeException('INVALID_JSON');
  const reader = request.body.getReader(),
    chunks: Uint8Array[] = [];
  let bytes = 0;
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      bytes += chunk.value.byteLength;
      if (bytes > limit) {
        await reader.cancel();
        throw new ProtocolDecodeException('MESSAGE_TOO_LARGE');
      }
      chunks.push(chunk.value);
    }
    const data = new Uint8Array(bytes);
    let offset = 0;
    for (const chunk of chunks) {
      data.set(chunk, offset);
      offset += chunk.length;
    }
    let raw: string;
    try {
      raw = new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(data);
    } catch {
      throw new ProtocolDecodeException('INVALID_JSON');
    }
    return decodeRoomMessage(raw, options);
  } catch (error) {
    if (error instanceof ProtocolDecodeException) throw error;
    throw new ProtocolDecodeException('INVALID_JSON');
  } finally {
    reader.releaseLock();
  }
}

export function roomError(code: ProtocolErrorCode, status = 400): Response {
  const message = createRoomMessage('error', {
    requestId: RoomIds.request(crypto.randomUUID()),
    code,
  });
  return Response.json(message, {
    status,
    headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
  });
}
