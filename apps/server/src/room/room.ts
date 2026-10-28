import { roomSql, bindLocalSocket, incomingLocal, countLocal } from './metrics';
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
import { consumeWindow, consumeAuthenticatedAction, ENTRY_LIMITS } from '../security/entry-limits';
import { allowedOrigin } from '../http/rooms';
import {
  attachment,
  closeSocket,
  sendMessage,
  SOCKET_LIMITS,
  type SocketAttachment,
} from './sockets';
import { putDeadline, removeDeadline, dueDeadlines, nextDeadline } from './deadlines';
import { lobbySnapshot, playersHash } from './projection';
import { applyLobbyAction, lobbyFingerprint, type LobbyReceipt } from './profile_actions';
import {
  RoomRepository,
  RoomStorageUnavailable,
  roomExpiry,
  type RoomState,
  type Member,
} from './repository';
import { commitGameAction, isGameAction } from './actions';
import { reservedSeatIds, synchronizeRoster } from './roster';
import { reconcileHost, nextHostDeadline } from './host_lifecycle';
import { purgeRoom } from './expiry';
import { roomDiagnostic } from './logging';
import {
  commitHistoryAction,
  isHistoryAction,
  initialHistoryImport,
  ownHistoryStatus,
  expireHistory,
} from './history';
export { roomExpiry } from './repository';
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
        consumeWindow(
          roomSql(this.ctx.storage),
          'socketUpgrade',
          SOCKET_LIMITS.authPerRoom,
          Date.now(),
        ),
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
    bindLocalSocket(server, this.ctx.storage);
    server.serializeAttachment(info);
    putDeadline(roomSql(this.ctx.storage), {
      id: info.socketId,
      kind: 'auth',
      due: info.authDeadline,
    });
    await this.planAlarm();
    return new Response(null, { status: 101, webSocket: client });
  }

  private async planAlarm(): Promise<void> {
    const state = this.readIfAvailable();
    if (state === undefined) return;
    const hostDue = state ? nextHostDeadline(state) : null;
    let next = nextDeadline(
      roomSql(this.ctx.storage),
      state ? roomExpiry(state) : null,
      hostDue === null ? [] : [hostDue],
    );
    if (state?.historyImport?.status === 'receiving')
      next = Math.min(
        next ?? Infinity,
        state.historyImport.createdAt + protocolMetadata.limits.historyTimeoutMs,
      );
    const scheduled = await this.ctx.storage.getAlarm();
    if (next !== null && scheduled !== next) {
      await this.ctx.storage.setAlarm(next);
      countLocal(this.ctx.storage, 'alarmWrites');
    } else if (next === null && scheduled !== null) {
      await this.ctx.storage.deleteAlarm();
      countLocal(this.ctx.storage, 'alarmWrites');
    }
  }
  private socketFailure(socket: WebSocket, code: ProtocolErrorCode, closeCode = 4401): void {
    const info = attachment(socket);
    if (info?.kind === 'closed') return;
    const state = this.readIfAvailable();
    if (state === undefined) {
      closeSocket(socket, 1011);
      return;
    }
    const wasCurrent = state && !!this.currentMember(info, state);
    if (info) removeDeadline(roomSql(this.ctx.storage), info.socketId);
    try {
      sendMessage(
        socket,
        createRoomMessage('error', { requestId: RoomIds.request(crypto.randomUUID()), code }),
      );
    } catch {
      /* Client may already be gone. */
    }
    closeSocket(socket, closeCode);
    if (wasCurrent) {
      state.revision++;
      reconcileHost(state, this.connectedPlayers(state), Date.now(), {
        detectMissing: true,
        presenceRevision: true,
      });
      this.write(state);
    }
  }
  private currentMember(info: SocketAttachment | null, state: RoomState): Member | undefined {
    if (
      info?.kind !== 'authenticated' ||
      info.roomId !== state.roomId ||
      info.avatarVersion !== protocolMetadata.avatarVersion ||
      info.catalogHash !== protocolMetadata.catalogHash
    )
      return undefined;
    return state.members.find(
      (m) => m.playerId === info.playerId && !m.revoked && m.generation === info.generation,
    );
  }
  private connectedPlayers(state: RoomState): ReadonlySet<PlayerId> {
    return new Set(
      this.ctx.getWebSockets().flatMap((socket) => {
        const member = this.currentMember(attachment(socket), state);
        return member ? [member.playerId] : [];
      }),
    );
  }
  private sendSnapshot(socket: WebSocket, info: SocketAttachment, state: RoomState): void {
    if (info.kind !== 'authenticated' || !this.currentMember(info, state)) return;
    const connected = new Set<PlayerId>();
    for (const other of this.ctx.getWebSockets()) {
      const member = this.currentMember(attachment(other), state);
      if (member) connected.add(member.playerId);
    }
    const expiry = roomExpiry(state),
      view = lobbySnapshot(state, info.playerId, connected, expiry);
    sendMessage(socket, view);
    socket.serializeAttachment({
      ...info,
      viewRevision: state.revision,
      playersHash: playersHash(view.public.players),
      viewExpiry: expiry,
    });
  }

  private broadcastLobby(): void {
    const state = this.readIfAvailable();
    if (!state) return;
    const connected = new Set<PlayerId>();
    let closedAny = false;
    for (const socket of this.ctx.getWebSockets()) {
      const member = this.currentMember(attachment(socket), state);
      if (member) connected.add(member.playerId);
    }
    for (const socket of this.ctx.getWebSockets()) {
      const info = attachment(socket);
      if (info?.kind === 'authenticated' && info.avatarVersion !== protocolMetadata.avatarVersion) {
        this.socketFailure(socket, 'AVATAR_MISMATCH', 4400);
        continue;
      }
      if (info?.kind === 'authenticated' && info.catalogHash !== protocolMetadata.catalogHash) {
        this.socketFailure(socket, 'CATALOG_MISMATCH', 4400);
        continue;
      }
      if (
        info?.kind !== 'authenticated' ||
        !this.currentMember(info, state) ||
        info.viewRevision === state.revision
      )
        continue;
      try {
        if (
          state.game ||
          info.viewRevision === undefined ||
          info.playersHash === undefined ||
          info.viewExpiry === undefined
        ) {
          this.sendSnapshot(socket, info, state);
          continue;
        }
        const view = lobbySnapshot(state, info.playerId, connected, roomExpiry(state));
        const hash = playersHash(view.public.players),
          expiry = roomExpiry(state);
        sendMessage(
          socket,
          createRoomMessage(
            'delta',
            {
              requestId: RoomIds.request(crypto.randomUUID()),
              roomId: state.roomId,
              baseRevision: info.viewRevision,
              revision: state.revision,
              you: info.playerId,
              publicChanges: {
                ...(info.playersHash !== hash ? { players: view.public.players } : {}),
                ...(info.viewExpiry !== expiry ? { expiresAtUtc: view.public.expiresAtUtc } : {}),
              },
              private: {},
            },
            { logical: true },
          ),
        );
        socket.serializeAttachment({
          ...info,
          viewRevision: state.revision,
          playersHash: hash,
          viewExpiry: expiry,
        });
      } catch {
        this.socketFailure(socket, 'MESSAGE_TOO_LARGE', 4400);
        closedAny = true;
      }
    }
    if (closedAny) this.broadcastLobby();
  }

  override async webSocketMessage(socket: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    bindLocalSocket(socket, this.ctx.storage);
    incomingLocal(socket, raw);
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
        if (
          info.kind === 'authenticated' &&
          info.avatarVersion !== protocolMetadata.avatarVersion
        ) {
          this.socketFailure(socket, 'AVATAR_MISMATCH', 4400);
          return;
        }
        if (info.kind === 'authenticated' && info.catalogHash !== protocolMetadata.catalogHash) {
          this.socketFailure(socket, 'CATALOG_MISMATCH', 4400);
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
                roomSql(this.ctx.storage),
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
          countLocal(this.ctx.storage, 'authentications');
          if (result.message.generation > 1) countLocal(this.ctx.storage, 'reconnects');
          const wasConnected = this.ctx.getWebSockets().some((other) => {
            const previous = attachment(other);
            return (
              previous?.kind === 'authenticated' &&
              previous.playerId === result.message.playerId &&
              !!this.currentMember(previous, state)
            );
          });
          const bound: SocketAttachment = {
            formatVersion: 1,
            kind: 'authenticated',
            socketId: info.socketId,
            roomId: result.message.roomId,
            playerId: result.message.playerId,
            generation: result.message.generation,
            avatarVersion: protocolMetadata.avatarVersion,
            catalogHash: protocolMetadata.catalogHash,
          };
          socket.serializeAttachment(bound);
          removeDeadline(roomSql(this.ctx.storage), info.socketId);
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
          const current = this.ctx.storage.transactionSync(() => {
            const latest = this.read();
            if (!latest) return null;
            // Presence is a revision change, never a room-lifetime extension.
            const alreadyConnected = this.ctx.getWebSockets().some((other) => {
              const otherInfo = attachment(other);
              return (
                other !== socket &&
                otherInfo?.kind === 'authenticated' &&
                otherInfo.playerId === bound.playerId &&
                otherInfo.generation === bound.generation
              );
            });
            if (!alreadyConnected && !wasConnected) {
              latest.revision++;
              reconcileHost(latest, this.connectedPlayers(latest), Date.now(), {
                detectMissing: true,
                presenceRevision: true,
              });
              this.write(latest);
            }
            return latest;
          });
          if (current) this.sendSnapshot(socket, bound, current);
          if (current) {
            const history = ownHistoryStatus(
              current,
              bound.playerId,
              RoomIds.request(crypto.randomUUID()),
            );
            if (history) sendMessage(socket, history);
          }
          this.broadcastLobby();
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
        if ('actionId' in command) countLocal(this.ctx.storage, 'actions');
        if (
          !this.ctx.storage.transactionSync(() =>
            consumeAuthenticatedAction(roomSql(this.ctx.storage), info.playerId, Date.now()),
          )
        ) {
          this.socketFailure(socket, 'RATE_LIMITED', 4429);
          return;
        }
        if (command.type === 'closeRoom') {
          const outcome = this.ctx.storage.transactionSync(() => {
            const latest = this.live(Date.now());
            if (!latest || !this.currentMember(info, latest))
              return { ok: false as const, code: 'CREDENTIAL_INVALID' as const };
            if (info.playerId !== latest.hostId)
              return { ok: false as const, code: 'UNAUTHORIZED_ACTION' as const };
            if (command.expectedRevision !== latest.revision)
              return { ok: false as const, code: 'STALE_REVISION' as const };
            if (
              latest.game?.receipts.some((r) => r.actionId === command.actionId) ||
              latest.lobbyReceipts?.some((r) => r.actionId === command.actionId)
            )
              return { ok: false as const, code: 'ACTION_ID_CONFLICT' as const };
            purgeRoom(this.ctx.storage);
            return { ok: true as const, revision: latest.revision + 1 };
          });
          if (!outcome.ok) {
            sendMessage(
              socket,
              createRoomMessage('error', {
                requestId: RoomIds.request(crypto.randomUUID()),
                code: outcome.code,
              }),
            );
            return;
          }
          try {
            sendMessage(
              socket,
              createRoomMessage('ack', {
                requestId: RoomIds.request(crypto.randomUUID()),
                actionId: command.actionId,
                revision: outcome.revision,
                outcome: 'closed',
              }),
            );
          } finally {
            for (const other of this.ctx.getWebSockets()) {
              if (other !== socket)
                try {
                  sendMessage(
                    other,
                    attachment(other)?.kind === 'authenticated'
                      ? createRoomMessage('roomClosed', {
                          requestId: RoomIds.request(crypto.randomUUID()),
                        })
                      : createRoomMessage('error', {
                          requestId: RoomIds.request(crypto.randomUUID()),
                          code: 'ROOM_UNAVAILABLE',
                        }),
                  );
                } catch {
                  /* Already gone. */
                }
              closeSocket(other, 1000);
            }
          }
          return;
        }
        if (isHistoryAction(command)) {
          const connected = new Set<PlayerId>();
          for (const other of this.ctx.getWebSockets()) {
            const member = this.currentMember(attachment(other), state);
            if (member) connected.add(member.playerId);
          }
          const result = commitHistoryAction(
            new RoomRepository(this.ctx.storage),
            info,
            command,
            connected,
          );
          if (!result.ok && result.retryable) {
            closeSocket(socket, 1011);
            return;
          }
          sendMessage(
            socket,
            result.ok
              ? result.message
              : createRoomMessage('error', { requestId: command.requestId, code: result.code }),
          );
          return;
        }
        if (isGameAction(command)) {
          const connected = new Set<PlayerId>();
          for (const other of this.ctx.getWebSockets()) {
            const member = this.currentMember(attachment(other), state);
            if (member) connected.add(member.playerId);
          }
          const result = commitGameAction(
            new RoomRepository(this.ctx.storage),
            info,
            command,
            connected,
          );
          if (!result.ok) {
            if (result.retryable) {
              closeSocket(socket, 1011);
              return;
            }
            sendMessage(
              socket,
              createRoomMessage('error', {
                requestId: RoomIds.request(crypto.randomUUID()),
                code: result.code,
              }),
            );
            if (result.code === 'STALE_REVISION') {
              const latest = this.read();
              if (latest) this.sendSnapshot(socket, info, latest);
            }
          } else {
            sendMessage(
              socket,
              createRoomMessage('ack', {
                requestId: RoomIds.request(crypto.randomUUID()),
                actionId: command.actionId,
                revision: result.revision,
                outcome: result.duplicate ? 'duplicate' : 'committed',
              }),
            );
            if (result.duplicate) {
              const latest = this.read();
              if (latest) this.sendSnapshot(socket, info, latest);
            }
          }
          return;
        }
        if (
          command.type === 'editOwnProfile' ||
          command.type === 'kick' ||
          command.type === 'reorderRoster'
        ) {
          const fingerprint = await lobbyFingerprint(command);
          const result = this.ctx.storage.transactionSync(() => {
            const latest = this.live(Date.now());
            if (!latest || !this.currentMember(info, latest))
              return { ok: false as const, code: 'CREDENTIAL_INVALID' as const };
            if (latest.game?.receipts.some((receipt) => receipt.actionId === command.actionId))
              return { ok: false as const, code: 'ACTION_ID_CONFLICT' as const };
            if (
              (latest.game?.receipts.length ?? 0) + (latest.lobbyReceipts?.length ?? 0) >=
                protocolMetadata.limits.actionJournalEntries &&
              !latest.lobbyReceipts?.some((receipt) => receipt.actionId === command.actionId)
            )
              return { ok: false as const, code: 'RATE_LIMITED' as const };
            const outcome = applyLobbyAction(
              latest,
              info.playerId,
              command,
              fingerprint,
              Date.now(),
            );
            if (outcome.ok && !outcome.duplicate) this.write(latest);
            return outcome;
          });
          if (!result.ok) {
            sendMessage(
              socket,
              createRoomMessage('error', {
                requestId: RoomIds.request(crypto.randomUUID()),
                code: result.code,
              }),
            );
            return;
          }
          sendMessage(
            socket,
            createRoomMessage('ack', {
              requestId: RoomIds.request(crypto.randomUUID()),
              actionId: command.actionId,
              revision: result.revision,
              outcome: result.duplicate ? 'duplicate' : 'committed',
            }),
          );
          if ('removedPlayerId' in result && result.removedPlayerId) {
            for (const other of this.ctx.getWebSockets()) {
              const previous = attachment(other);
              if (
                previous?.kind === 'authenticated' &&
                previous.playerId === result.removedPlayerId
              )
                this.socketFailure(other, 'CREDENTIAL_INVALID');
            }
          }
          if (!result.duplicate) this.broadcastLobby();
        } else if (command.type === 'ping')
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
        if (error instanceof RoomStorageUnavailable) {
          closeSocket(socket, 1011);
          return;
        }
        this.socketFailure(
          socket,
          error instanceof ProtocolDecodeException && error.code !== 'INVALID_JSON'
            ? error.code
            : 'INVALID_MESSAGE',
          4400,
        );
      } finally {
        this.broadcastLobby();
        await this.planAlarm();
      }
    });
  }
  override async webSocketClose(socket: WebSocket): Promise<void> {
    const info = attachment(socket);
    const before = this.readIfAvailable();
    if (before === undefined) {
      closeSocket(socket, 1011);
      return;
    }
    const wasCurrent = before && !!this.currentMember(info, before);
    if (info) removeDeadline(roomSql(this.ctx.storage), info.socketId);
    closeSocket(socket, 1000);
    if (wasCurrent) {
      this.ctx.storage.transactionSync(() => {
        const state = this.live(Date.now(), false);
        if (state) {
          state.revision++;
          reconcileHost(state, this.connectedPlayers(state), Date.now(), {
            detectMissing: true,
            presenceRevision: true,
          });
          this.write(state);
        }
      });
      this.broadcastLobby();
    }
    await this.planAlarm();
  }
  override async webSocketError(socket: WebSocket): Promise<void> {
    await this.webSocketClose(socket);
  }

  private hasTable(name: string): boolean {
    return (
      roomSql(this.ctx.storage)
        .exec('SELECT name FROM sqlite_master WHERE type = ? AND name = ?', 'table', name)
        .toArray().length > 0
    );
  }
  private read(): RoomState | null {
    return new RoomRepository(this.ctx.storage).read();
  }
  private readIfAvailable(): RoomState | null | undefined {
    try {
      return this.read();
    } catch (error) {
      if (error instanceof RoomStorageUnavailable) return undefined;
      throw error;
    }
  }
  private write(state: RoomState): void {
    synchronizeRoster(state, Date.now());
    new RoomRepository(this.ctx.storage).write(state);
  }
  private live(now: number, refreshHost = true): RoomState | null {
    const state = this.read();
    if (!state) {
      for (const socket of this.ctx.getWebSockets()) this.socketFailure(socket, 'ROOM_UNAVAILABLE');
      return null;
    }
    if (state && now >= roomExpiry(state)) {
      // Retain only an empty reservation: old codes can never address a different party.
      purgeRoom(this.ctx.storage);
      console.info(
        JSON.stringify(roomDiagnostic({ code: 'ROOM_UNAVAILABLE', revision: state.revision })),
      );
      for (const socket of this.ctx.getWebSockets()) this.socketFailure(socket, 'ROOM_UNAVAILABLE');
      return null;
    }
    if (state) {
      const hostChanged = refreshHost && reconcileHost(state, this.connectedPlayers(state), now);
      if (expireHistory(state, now) || hostChanged) this.write(state);
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
      consumeWindow(roomSql(this.ctx.storage), kind, limit, now),
    );
    // A separate namespaced DO per address; no IP is persisted, no code registry/database.
    await this.ctx.storage.setAlarm(now + ENTRY_LIMITS.windowMs);
    countLocal(this.ctx.storage, 'alarmWrites');
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
            joinedSequence: 0,
            generation: 0,
            selectionCount: 0,
            revoked: false,
          },
        ],
        ...(command.historyOffer
          ? {
              historyOffer: command.historyOffer,
              historyImport: initialHistoryImport(playerId, command.historyOffer, now),
            }
          : {}),
      };
      roomSql(this.ctx.storage).exec(
        'CREATE TABLE room_record (singleton INTEGER PRIMARY KEY CHECK (singleton = 1), state TEXT)',
      );
      if (state.historyImport?.status === 'committed') delete state.historyOffer;
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
    const result = this.ctx.storage.transactionSync<Result<CredentialMessage>>(() => {
      const now = Date.now(),
        state = this.live(now);
      if (!state) return { ok: false, code: 'ROOM_UNAVAILABLE', status: 410 };
      if (!consumeWindow(roomSql(this.ctx.storage), 'join', ENTRY_LIMITS.joinsPerRoom, now))
        return { ok: false, code: 'RATE_LIMITED', status: 429 };
      const active = state.members.filter((m) => !m.revoked);
      if (reservedSeatIds(state).size >= ENTRY_LIMITS.maxMembers)
        return { ok: false, code: 'ROOM_FULL', status: 409 };
      if (state.members.length >= protocolMetadata.limits.actionJournalEntries)
        return { ok: false, code: 'RATE_LIMITED', status: 429 };
      state.members.push({
        playerId,
        profile: command.profile,
        verifier,
        joinedAt: now,
        joinedSequence: state.members.length,
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
    if (result.ok) this.broadcastLobby();
    await this.planAlarm();
    return result;
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
        // The transaction retains public profile data while a frozen case still refers to it.
        state.lastDomainActivity = Date.now();
        state.revision++;
        member.leaveRevision = state.revision;
        reconcileHost(state, this.connectedPlayers(state), Date.now(), {
          detectMissing: true,
          presenceRevision: true,
        });
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
      this.broadcastLobby();
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
            avatarVersion: protocolMetadata.avatarVersion,
          },
        }),
      };
    });
  }

  override async alarm(): Promise<void> {
    countLocal(this.ctx.storage, 'alarmInvocations');
    const now = Date.now();
    const state = this.ctx.storage.transactionSync(() => this.live(now));
    if (!state) {
      this.ctx.storage.transactionSync(() => purgeRoom(this.ctx.storage));
      for (const socket of this.ctx.getWebSockets()) this.socketFailure(socket, 'ROOM_UNAVAILABLE');
      await this.planAlarm();
      return;
    }
    for (const deadline of dueDeadlines(roomSql(this.ctx.storage), now)) {
      for (const socket of this.ctx.getWebSockets()) {
        const info = attachment(socket);
        if (info?.kind === 'pending' && info.socketId === deadline.id)
          this.socketFailure(socket, 'CREDENTIAL_INVALID', 4408);
      }
      removeDeadline(roomSql(this.ctx.storage), deadline.id);
    }
    this.broadcastLobby();
    await this.planAlarm();
  }
}
