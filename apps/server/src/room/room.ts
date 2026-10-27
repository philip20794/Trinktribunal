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
import { consumeWindow, consumeAction, ENTRY_LIMITS } from '../security/entry-limits';
import { allowedOrigin } from '../http/rooms';
import {
  attachment,
  closeSocket,
  sendMessage,
  SOCKET_LIMITS,
  type SocketAttachment,
} from './sockets';
import { putDeadline, removeDeadline, dueDeadlines, nextDeadline } from './deadlines';
import { lobbySnapshot } from './projection';

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
  override async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (request.method !== 'GET' || !/^\/api\/rooms\/[^/]+\/socket$/.test(url.pathname))
      return roomError('ROOM_UNAVAILABLE', 404);
    if (url.search || request.headers.has('Sec-WebSocket-Protocol'))
      return roomError('INVALID_MESSAGE', 400);
    if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket')
      return roomError('INVALID_MESSAGE', 426);
    if (request.headers.has('Origin') && !allowedOrigin(request, this.env))
      return roomError('UNAUTHORIZED_ACTION', 403);
    const state = this.ctx.storage.transactionSync(() => this.live(Date.now()));
    if (!state) return roomError('ROOM_UNAVAILABLE', 410);
    const sockets = this.ctx
      .getWebSockets()
      .map((socket) => ({ socket, info: attachment(socket) }))
      .filter(({ info }) => info?.kind !== 'closed');
    if (
      sockets.length >= SOCKET_LIMITS.totalPerRoom ||
      sockets.filter(({ info }) => info?.kind === 'pending').length >= SOCKET_LIMITS.pendingPerRoom
    )
      return roomError('RATE_LIMITED', 429);
    if (
      !this.ctx.storage.transactionSync(() =>
        consumeWindow(this.ctx.storage.sql, 'socketUpgrade', SOCKET_LIMITS.authPerRoom, Date.now()),
      )
    )
      return roomError('RATE_LIMITED', 429);
    const pair = new WebSocketPair(),
      client = pair[0],
      server = pair[1];
    const info: SocketAttachment = {
      formatVersion: 1,
      kind: 'pending',
      socketId: crypto.randomUUID(),
      authDeadline: Date.now() + protocolMetadata.limits.authTimeoutMs,
    };
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment(info);
    putDeadline(this.ctx.storage.sql, { id: info.socketId, kind: 'auth', due: info.authDeadline });
    await this.planAlarm();
    return new Response(null, { status: 101, webSocket: client });
  }

  private async planAlarm(): Promise<void> {
    const state = this.read();
    const next = nextDeadline(this.ctx.storage.sql, state ? roomExpiry(state) : null);
    if (next !== null) await this.ctx.storage.setAlarm(next);
    else await this.ctx.storage.deleteAlarm();
  }
  private socketFailure(socket: WebSocket, code: ProtocolErrorCode, closeCode = 4401): void {
    const info = attachment(socket);
    if (info?.kind === 'closed') return;
    if (info) removeDeadline(this.ctx.storage.sql, info.socketId);
    try {
      sendMessage(
        socket,
        createRoomMessage('error', { requestId: RoomIds.request(crypto.randomUUID()), code }),
      );
    } catch {
      /* Client may already be gone. */
    }
    closeSocket(socket, closeCode);
  }
  private currentMember(info: SocketAttachment | null, state: RoomState): Member | undefined {
    if (info?.kind !== 'authenticated' || info.roomId !== state.roomId) return undefined;
    return state.members.find(
      (m) => m.playerId === info.playerId && !m.revoked && m.generation === info.generation,
    );
  }
  private sendSnapshot(socket: WebSocket, info: SocketAttachment, state: RoomState): void {
    if (info.kind !== 'authenticated' || !this.currentMember(info, state)) return;
    const connected = new Set<PlayerId>();
    for (const other of this.ctx.getWebSockets()) {
      const member = this.currentMember(attachment(other), state);
      if (member) connected.add(member.playerId);
    }
    sendMessage(socket, lobbySnapshot(state, info.playerId, connected, roomExpiry(state)));
  }

  override async webSocketMessage(socket: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    // Auth awaits cryptography. Serialize it with subsequent frames/alarms and generation changes.
    await this.ctx.blockConcurrencyWhile(async () => {
      try {
        const info = attachment(socket);
        if (!info || info.kind === 'closed') {
          closeSocket(socket, 4401);
          return;
        }
        const state = this.ctx.storage.transactionSync(() => this.live(Date.now()));
        if (!state) {
          this.socketFailure(socket, 'ROOM_UNAVAILABLE');
          return;
        }
        if (info.kind === 'pending') {
          if (Date.now() >= info.authDeadline) {
            this.socketFailure(socket, 'CREDENTIAL_INVALID', 4408);
            return;
          }
          if (typeof raw !== 'string') {
            this.socketFailure(socket, 'INVALID_MESSAGE', 1003);
            return;
          }
          const command = decodeRoomMessage(raw, {
            direction: 'client',
            allowedTypes: ['authenticate'],
          });
          if (command.type !== 'authenticate') {
            this.socketFailure(socket, 'CREDENTIAL_INVALID');
            return;
          }
          if (
            !this.ctx.storage.transactionSync(() =>
              consumeWindow(
                this.ctx.storage.sql,
                'authenticate',
                SOCKET_LIMITS.authPerRoom,
                Date.now(),
              ),
            )
          ) {
            this.socketFailure(socket, 'RATE_LIMITED', 4429);
            return;
          }
          const result = await this.authenticate(command, info.authDeadline);
          if (!result.ok) {
            this.socketFailure(socket, result.code);
            return;
          }
          const bound: SocketAttachment = {
            formatVersion: 1,
            kind: 'authenticated',
            socketId: info.socketId,
            roomId: result.message.roomId,
            playerId: result.message.playerId,
            generation: result.message.generation,
          };
          socket.serializeAttachment(bound);
          removeDeadline(this.ctx.storage.sql, info.socketId);
          for (const old of this.ctx.getWebSockets()) {
            const previous = attachment(old);
            if (
              old !== socket &&
              previous?.kind === 'authenticated' &&
              previous.playerId === bound.playerId
            ) {
              try {
                sendMessage(
                  old,
                  createRoomMessage('sessionReplaced', {
                    requestId: RoomIds.request(crypto.randomUUID()),
                  }),
                );
              } catch {
                /* Disconnected old tab. */
              }
              closeSocket(old, 4409);
            }
          }
          sendMessage(socket, result.message);
          const current = this.read();
          if (current) this.sendSnapshot(socket, bound, current);
          return;
        }
        if (!this.currentMember(info, state)) {
          this.socketFailure(socket, 'SESSION_REPLACED', 4409);
          return;
        }
        if (typeof raw !== 'string') {
          this.socketFailure(socket, 'INVALID_MESSAGE', 1003);
          return;
        }
        const command = decodeRoomMessage(raw, { direction: 'client' });
        if (
          !this.ctx.storage.transactionSync(() =>
            consumeAction(this.ctx.storage.sql, info.playerId, Date.now()),
          )
        ) {
          this.socketFailure(socket, 'RATE_LIMITED', 4429);
          return;
        }
        if (command.type === 'ping')
          sendMessage(socket, createRoomMessage('pong', { requestId: command.requestId }));
        else if (command.type === 'requestSnapshot') this.sendSnapshot(socket, info, state);
        else
          sendMessage(
            socket,
            createRoomMessage('error', {
              requestId: RoomIds.request(crypto.randomUUID()),
              code: 'INVALID_PHASE',
            }),
          );
      } catch (error) {
        this.socketFailure(
          socket,
          error instanceof ProtocolDecodeException && error.code !== 'INVALID_JSON'
            ? error.code
            : 'INVALID_MESSAGE',
          4400,
        );
      } finally {
        await this.planAlarm();
      }
    });
  }
  override async webSocketClose(socket: WebSocket): Promise<void> {
    const info = attachment(socket);
    if (info) removeDeadline(this.ctx.storage.sql, info.socketId);
    closeSocket(socket, 1000);
    await this.planAlarm();
  }
  override async webSocketError(socket: WebSocket): Promise<void> {
    await this.webSocketClose(socket);
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
      if (this.hasTable('action_limits')) this.ctx.storage.sql.exec('DELETE FROM action_limits');
      for (const socket of this.ctx.getWebSockets()) this.socketFailure(socket, 'ROOM_UNAVAILABLE');
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

  async consumeEntryAttempt(kind: 'create' | 'join' | 'leave' | 'socket'): Promise<boolean> {
    const limit =
      kind === 'create'
        ? ENTRY_LIMITS.createPerAddress
        : kind === 'join'
          ? ENTRY_LIMITS.joinPerAddress
          : kind === 'leave'
            ? ENTRY_LIMITS.leavePerAddress
            : SOCKET_LIMITS.upgradesPerAddress;
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
    if ('ok' in result && result.ok) await this.planAlarm();
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
    const result = this.ctx.storage.transactionSync<Result<AckMessage>>(() => {
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
    if (result.ok) {
      const owner = before.members.find((m) => sameVerifier(m.verifier, verifier));
      for (const socket of this.ctx.getWebSockets()) {
        const info = attachment(socket);
        if (info?.kind === 'authenticated' && info.playerId === owner?.playerId)
          this.socketFailure(socket, 'CREDENTIAL_INVALID');
      }
      await this.planAlarm();
    }
    return result;
  }

  // Internal binding RPC only; TT-038 connects this atomic identity check to the first WS frame.
  async authenticate(
    command: AuthenticateMessage,
    authDeadline?: number,
  ): Promise<Result<AuthenticatedMessage>> {
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
      if (authDeadline !== undefined && Date.now() >= authDeadline)
        return { ok: false, code: 'CREDENTIAL_INVALID', status: 408 };
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
    const now = Date.now();
    for (const deadline of dueDeadlines(this.ctx.storage.sql, now)) {
      for (const socket of this.ctx.getWebSockets()) {
        const info = attachment(socket);
        if (info?.kind === 'pending' && info.socketId === deadline.id)
          this.socketFailure(socket, 'CREDENTIAL_INVALID', 4408);
      }
      removeDeadline(this.ctx.storage.sql, deadline.id);
    }
    const state = this.ctx.storage.transactionSync(() => this.live(now));
    if (!state) {
      for (const socket of this.ctx.getWebSockets()) this.socketFailure(socket, 'ROOM_UNAVAILABLE');
      if (this.hasTable('entry_limits')) this.ctx.storage.sql.exec('DELETE FROM entry_limits');
    }
    await this.planAlarm();
  }
}
