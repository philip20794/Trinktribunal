import { DurableObject } from 'cloudflare:workers';
import {
  createRoomMessage,
  decodeRoomMessage,
  ProtocolDecodeException,
  RoomIds,
  type ProtocolErrorCode,
} from '../protocol/room_message';
import {
  protocolMetadata,
  type CreateMessage,
  type JoinMessage,
  type LeaveHttpMessage,
  type CredentialMessage,
  type AckMessage,
  type AuthenticateMessage,
  type AuthenticatedMessage,
  type RoomId,
  type PlayerId,
  type Profile,
  type Config,
  type HistoryOffer,
} from '../protocol/room_message.generated';
import { roomError } from '../protocol/http';
import { newResumeToken, resumeVerifier, sameVerifier } from '../security/tokens';
import { consumeWindow, ENTRY_LIMITS } from '../security/entry-limits';

interface Member {
  playerId: PlayerId;
  profile?: Profile;
  verifier: string;
  joinedAt: number;
  generation: number;
  selectionCount: number;
  revoked: boolean;
  leaveActionId?: string;
  leaveRevision?: number;
}
interface RoomState {
  formatVersion: 1;
  roomId: RoomId;
  code: string;
  hostId: PlayerId;
  revision: number;
  createdAt: number;
  lastDomainActivity: number;
  phase: 'lobby';
  config: Config;
  historyOffer?: HistoryOffer;
  members: Member[];
}
type Result<T> =
  | { ok: true; message: T }
  | {
      ok: false;
      code: ProtocolErrorCode;
      status: number;
    };
export type CreateResult = Result<CredentialMessage> | { collision: true };
function invalidCommand(
  command: unknown,
  type: 'create' | 'join' | 'leaveHttp' | 'authenticate',
): { ok: false; code: ProtocolErrorCode; status: number } | null {
  try {
    decodeRoomMessage(JSON.stringify(command), { direction: 'client', allowedTypes: [type] });
    return null;
  } catch (error) {
    return {
      ok: false,
      code:
        error instanceof ProtocolDecodeException && error.code !== 'INVALID_JSON'
          ? error.code
          : 'INVALID_MESSAGE',
      status: 400,
    };
  }
}
export function roomExpiry(state: Pick<RoomState, 'createdAt' | 'lastDomainActivity'>): number {
  return Math.min(
    state.createdAt + protocolMetadata.limits.roomHardMs,
    state.lastDomainActivity + protocolMetadata.limits.roomIdleMs,
  );
}

export class Room extends DurableObject<Env> {
  override async fetch(): Promise<Response> {
    return roomError('ROOM_UNAVAILABLE', 404);
  }

  private hasTable(name: string): boolean {
    return (
      this.ctx.storage.sql
        .exec('SELECT name FROM sqlite_master WHERE type = ? AND name = ?', 'table', name)
        .toArray().length > 0
    );
  }
  private read(): RoomState | null {
    if (!this.hasTable('room_record')) return null;
    const row = this.ctx.storage.sql
      .exec<{ state: string | null }>('SELECT state FROM room_record WHERE singleton = 1')
      .toArray()[0];
    return row?.state ? (JSON.parse(row.state) as RoomState) : null;
  }
  private write(state: RoomState): void {
    this.ctx.storage.sql.exec(
      'INSERT OR REPLACE INTO room_record (singleton, state) VALUES (1, ?)',
      JSON.stringify(state),
    );
  }
  private live(now: number): RoomState | null {
    const state = this.read();
    if (state && now >= roomExpiry(state)) {
      // Retain only an empty reservation: old codes can never address a different party.
      this.ctx.storage.sql.exec('UPDATE room_record SET state = NULL WHERE singleton = 1');
      if (this.hasTable('entry_limits')) this.ctx.storage.sql.exec('DELETE FROM entry_limits');
      return null;
    }
    return state;
  }
  private credential(
    state: RoomState,
    playerId: PlayerId,
    token: string,
    requestId: CredentialMessage['requestId'],
  ): CredentialMessage {
    return createRoomMessage('credential', {
      requestId,
      roomCode: state.code,
      roomId: state.roomId,
      playerId,
      resumeToken: token,
      expiresAtUtc: new Date(roomExpiry(state)).toISOString(),
    });
  }

  async consumeEntryAttempt(kind: 'create' | 'join' | 'leave'): Promise<boolean> {
    const limit =
      kind === 'create'
        ? ENTRY_LIMITS.createPerAddress
        : kind === 'join'
          ? ENTRY_LIMITS.joinPerAddress
          : ENTRY_LIMITS.leavePerAddress;
    const now = Date.now();
    const allowed = this.ctx.storage.transactionSync(() =>
      consumeWindow(this.ctx.storage.sql, kind, limit, now),
    );
    // A separate namespaced DO per address; no IP is persisted, no code registry/database.
    await this.ctx.storage.setAlarm(now + ENTRY_LIMITS.windowMs);
    return allowed;
  }

  async createIfAbsent(code: string, command: CreateMessage): Promise<CreateResult> {
    if (!/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/.test(code))
      return { ok: false, code: 'ROOM_UNAVAILABLE', status: 400 };
    const invalid = invalidCommand(command, 'create');
    if (invalid) return invalid;
    const roomId = RoomIds.room(crypto.randomUUID()),
      playerId = RoomIds.player(crypto.randomUUID()),
      token = newResumeToken();
    const verifier = await resumeVerifier(roomId, token);
    const result = this.ctx.storage.transactionSync<CreateResult>(() => {
      if (this.hasTable('room_record')) return { collision: true };
      const now = Date.now();
      const state: RoomState = {
        formatVersion: 1,
        roomId,
        code,
        hostId: playerId,
        revision: 0,
        createdAt: now,
        lastDomainActivity: now,
        phase: 'lobby',
        config: {
          targetCases: 50,
          requestedRuleEvents: 7,
          factorTenths: 15,
          allJudges: false,
          contentLanguage: 'de',
        },
        members: [
          {
            playerId,
            profile: command.profile,
            verifier,
            joinedAt: now,
            generation: 0,
            selectionCount: 0,
            revoked: false,
          },
        ],
        ...(command.historyOffer ? { historyOffer: command.historyOffer } : {}),
      };
      this.ctx.storage.sql.exec(
        'CREATE TABLE room_record (singleton INTEGER PRIMARY KEY CHECK (singleton = 1), state TEXT)',
      );
      this.write(state);
      return { ok: true, message: this.credential(state, playerId, token, command.requestId) };
    });
    if ('ok' in result && result.ok)
      await this.ctx.storage.setAlarm(new Date(result.message.expiresAtUtc).getTime());
    return result;
  }

  async join(command: JoinMessage): Promise<Result<CredentialMessage>> {
    const invalid = invalidCommand(command, 'join');
    if (invalid) return invalid;
    const before = this.ctx.storage.transactionSync(() => this.live(Date.now()));
    if (!before) return { ok: false, code: 'ROOM_UNAVAILABLE', status: 410 };
    const playerId = RoomIds.player(crypto.randomUUID()),
      token = newResumeToken();
    const verifier = await resumeVerifier(before.roomId, token);
    return this.ctx.storage.transactionSync(() => {
      const now = Date.now(),
        state = this.live(now);
      if (!state) return { ok: false, code: 'ROOM_UNAVAILABLE', status: 410 };
      if (!consumeWindow(this.ctx.storage.sql, 'join', ENTRY_LIMITS.joinsPerRoom, now))
        return { ok: false, code: 'RATE_LIMITED', status: 429 };
      const active = state.members.filter((m) => !m.revoked);
      if (active.length >= ENTRY_LIMITS.maxMembers)
        return { ok: false, code: 'ROOM_FULL', status: 409 };
      if (state.members.length >= protocolMetadata.limits.actionJournalEntries)
        return { ok: false, code: 'RATE_LIMITED', status: 429 };
      state.members.push({
        playerId,
        profile: command.profile,
        verifier,
        joinedAt: now,
        generation: 0,
        selectionCount: Math.max(0, ...active.map((m) => m.selectionCount)),
        revoked: false,
      });
      state.lastDomainActivity = now;
      state.revision++;
      this.write(state);
      // An early alarm is harmless: alarm() re-evaluates the current persisted expiry.
      return { ok: true, message: this.credential(state, playerId, token, command.requestId) };
    });
  }

  async leave(command: LeaveHttpMessage): Promise<Result<AckMessage>> {
    const invalid = invalidCommand(command, 'leaveHttp');
    if (invalid) return invalid;
    const before = this.ctx.storage.transactionSync(() => this.live(Date.now()));
    if (!before) return { ok: false, code: 'ROOM_UNAVAILABLE', status: 410 };
    const verifier = await resumeVerifier(before.roomId, command.resumeToken);
    return this.ctx.storage.transactionSync(() => {
      const state = this.live(Date.now());
      if (!state) return { ok: false, code: 'ROOM_UNAVAILABLE', status: 410 };
      const member = state.members.find((m) => sameVerifier(m.verifier, verifier));
      if (!member || (member.revoked && member.leaveActionId !== command.actionId))
        return { ok: false, code: 'CREDENTIAL_INVALID', status: 401 };
      if (!member.revoked) {
        if (state.members.some((m) => m.leaveActionId === command.actionId))
          return { ok: false, code: 'ACTION_ID_CONFLICT', status: 409 };
        member.revoked = true;
        member.leaveActionId = command.actionId;
        // Profile is no longer needed for a revoked lobby seat; retain only the bounded receipt.
        delete member.profile;
        state.lastDomainActivity = Date.now();
        state.revision++;
        member.leaveRevision = state.revision;
        this.write(state);
      }
      return {
        ok: true,
        message: createRoomMessage('ack', {
          requestId: command.requestId,
          actionId: command.actionId,
          revision: member.leaveRevision!,
          outcome: 'left',
        }),
      };
    });
  }

  // Internal binding RPC only; TT-038 connects this atomic identity check to the first WS frame.
  async authenticate(command: AuthenticateMessage): Promise<Result<AuthenticatedMessage>> {
    const invalid = invalidCommand(command, 'authenticate');
    if (invalid) return invalid;
    const before = this.ctx.storage.transactionSync(() => this.live(Date.now()));
    if (!before) return { ok: false, code: 'ROOM_UNAVAILABLE', status: 410 };
    const verifier = await resumeVerifier(before.roomId, command.resumeToken);
    return this.ctx.storage.transactionSync(() => {
      const state = this.live(Date.now());
      if (!state) return { ok: false, code: 'ROOM_UNAVAILABLE', status: 410 };
      const member = state.members.find((m) => sameVerifier(m.verifier, verifier));
      if (!member || member.revoked) return { ok: false, code: 'CREDENTIAL_INVALID', status: 401 };
      member.generation++;
      this.write(state);
      return {
        ok: true,
        message: createRoomMessage('authenticated', {
          requestId: command.requestId,
          roomId: state.roomId,
          playerId: member.playerId,
          generation: member.generation,
          expiresAtUtc: new Date(roomExpiry(state)).toISOString(),
          handshake: {
            protocolVersion: 1,
            catalogHash: protocolMetadata.catalogHash,
            avatarVersion: 1,
          },
        }),
      };
    });
  }

  override async alarm(): Promise<void> {
    const state = this.ctx.storage.transactionSync(() => this.live(Date.now()));
    if (state) await this.ctx.storage.setAlarm(roomExpiry(state));
    else if (this.hasTable('entry_limits')) this.ctx.storage.sql.exec('DELETE FROM entry_limits');
  }
}
