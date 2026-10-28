import { roomSql } from './metrics';
import { protocolMetadata } from '../protocol/room_message.generated';
import type { RoomState } from './repository';
import { forgetValidatedRow } from './validated_row';

export function roomExpiry(state: Pick<RoomState, 'createdAt' | 'lastDomainActivity'>): number {
  return Math.min(
    state.createdAt + protocolMetadata.limits.roomHardMs,
    state.lastDomainActivity + protocolMetadata.limits.roomIdleMs,
  );
}
/** Retain only the empty code reservation; all app-owned private rows are erased. */
export function purgeRoom(storage: DurableObjectStorage): void {
  forgetValidatedRow(storage);
  for (const table of ['room_record', 'entry_limits', 'action_limits', 'deadlines']) {
    if (
      !roomSql(storage)
        .exec("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?", table)
        .toArray().length
    )
      continue;
    if (table === 'room_record')
      roomSql(storage).exec('UPDATE room_record SET state = NULL WHERE singleton = 1');
    else roomSql(storage).exec(`DELETE FROM ${table}`);
  }
}
