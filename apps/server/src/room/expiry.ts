import { protocolMetadata } from '../protocol/room_message.generated';
import type { RoomState } from './repository';

export function roomExpiry(state: Pick<RoomState, 'createdAt' | 'lastDomainActivity'>): number {
  return Math.min(
    state.createdAt + protocolMetadata.limits.roomHardMs,
    state.lastDomainActivity + protocolMetadata.limits.roomIdleMs,
  );
}
/** Retain only the empty code reservation; all app-owned private rows are erased. */
export function purgeRoom(storage: DurableObjectStorage): void {
  for (const table of ['room_record', 'entry_limits', 'action_limits', 'deadlines']) {
    if (
      !storage.sql
        .exec("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?", table)
        .toArray().length
    )
      continue;
    if (table === 'room_record')
      storage.sql.exec('UPDATE room_record SET state = NULL WHERE singleton = 1');
    else storage.sql.exec(`DELETE FROM ${table}`);
  }
}
