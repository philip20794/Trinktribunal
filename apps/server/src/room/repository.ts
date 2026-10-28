import type {
  Config,
  HistoryOffer,
  PlayerId,
  Profile,
  RoomId,
} from '../protocol/room_message.generated';
import type { GameState, Phase } from '../domain/game_state';
import { immutable } from '../domain/game_state';
import { migrateRoomState, StoredStateInvalid } from './migrations';
import { purgeRoom } from './expiry';
import { forgetValidatedRow, isValidatedRow, rememberValidatedRow } from './validated_row';
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
export { roomExpiry } from './expiry';
export class RoomStorageUnavailable extends Error {
  constructor() {
    super('ROOM_UNAVAILABLE');
  }
}
/** One canonical SQLite row; game, usage, counters and action receipts share its transaction. */
export class RoomRepository {
  constructor(readonly storage: DurableObjectStorage) {}
  read(): RoomState | null {
    try {
      return this.load();
    } catch {
      throw new RoomStorageUnavailable();
    }
  }
  private load(): RoomState | null {
    if (
      !this.storage.sql
        .exec('SELECT name FROM sqlite_master WHERE type = ? AND name = ?', 'table', 'room_record')
        .toArray().length
    ) {
      forgetValidatedRow(this.storage);
      return null;
    }
    return this.storage.transactionSync(() => {
      const row = this.storage.sql
        .exec<{ state: string | null }>('SELECT state FROM room_record WHERE singleton = 1')
        .toArray()[0];
      if (!row?.state) {
        forgetValidatedRow(this.storage);
        return null;
      }
      if (isValidatedRow(this.storage, row.state)) {
        // Parse a fresh copy: callers can mutate members before an atomic write.
        const state = JSON.parse(row.state) as RoomState;
        if (state.game) state.game = immutable(state.game);
        return state;
      }
      let loaded: ReturnType<typeof migrateRoomState>;
      try {
        loaded = migrateRoomState(row.state);
      } catch (error) {
        if (!(error instanceof StoredStateInvalid)) throw error;
        purgeRoom(this.storage);
        return null;
      }
      if (loaded.migrated) this.write(loaded.state);
      rememberValidatedRow(
        this.storage,
        loaded.migrated ? JSON.stringify(loaded.state) : row.state,
      );
      return loaded.state;
    });
  }
  write(state: RoomState): void {
    forgetValidatedRow(this.storage);
    this.storage.sql.exec(
      'INSERT OR REPLACE INTO room_record (singleton, state) VALUES (1, ?)',
      JSON.stringify(state),
    );
  }
}
