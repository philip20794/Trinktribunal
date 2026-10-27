import type {
  Config,
  HistoryOffer,
  PlayerId,
  Profile,
  RoomId,
} from '../protocol/room_message.generated';
import { protocolMetadata } from '../protocol/room_message.generated';
import type { GameState, Phase } from '../domain/game_state';
import type { LobbyReceipt } from './profile_actions';
import type { HistoryImportState, HistoryExport } from './history';

export interface Member {
  playerId: PlayerId;
  profile?: Profile;
  verifier: string;
  joinedAt: number;
  joinedSequence?: number;
  generation: number;
  selectionCount: number;
  revoked: boolean;
  leaveActionId?: string;
  leaveRevision?: number;
}
export interface RoomState {
  formatVersion: 1;
  roomId: RoomId;
  code: string;
  hostId: PlayerId;
  revision: number;
  createdAt: number;
  lastDomainActivity: number;
  phase: Phase;
  config: Config;
  historyOffer?: HistoryOffer;
  members: Member[];
  lobbyReceipts?: LobbyReceipt[];
  game?: GameState;
  historyImport?: HistoryImportState;
  historyOwners?: Record<string, PlayerId>;
  historyExports?: HistoryExport[];
  historyPageHashes?: Record<number, string>;
}
export function roomExpiry(state: Pick<RoomState, 'createdAt' | 'lastDomainActivity'>): number {
  return Math.min(
    state.createdAt + protocolMetadata.limits.roomHardMs,
    state.lastDomainActivity + protocolMetadata.limits.roomIdleMs,
  );
}
/** One canonical SQLite row; game, usage, counters and action receipts share its transaction. */
export class RoomRepository {
  constructor(readonly storage: DurableObjectStorage) {}
  read(): RoomState | null {
    if (
      !this.storage.sql
        .exec('SELECT name FROM sqlite_master WHERE type = ? AND name = ?', 'table', 'room_record')
        .toArray().length
    )
      return null;
    const row = this.storage.sql
      .exec<{ state: string | null }>('SELECT state FROM room_record WHERE singleton = 1')
      .toArray()[0];
    return row?.state ? (JSON.parse(row.state) as RoomState) : null;
  }
  write(state: RoomState): void {
    this.storage.sql.exec(
      'INSERT OR REPLACE INTO room_record (singleton, state) VALUES (1, ?)',
      JSON.stringify(state),
    );
  }
}
