import { createRoomMessage, RoomIds, type ProtocolErrorCode } from '../protocol/room_message';

/** Unknown properties and exception/payload text never enter diagnostics. */
export function roomDiagnostic(input: { code?: unknown; revision?: unknown }) {
  let code: ProtocolErrorCode = 'INVALID_MESSAGE';
  try {
    const message = createRoomMessage('error', {
      requestId: RoomIds.request('diagnostic'),
      code: input.code as ProtocolErrorCode,
    });
    code = message.code;
  } catch {
    /* Fixed fallback, no error text. */
  }
  return {
    code,
    revision:
      typeof input.revision === 'number' &&
      Number.isSafeInteger(input.revision) &&
      input.revision >= 0
        ? input.revision
        : 0,
  };
}
