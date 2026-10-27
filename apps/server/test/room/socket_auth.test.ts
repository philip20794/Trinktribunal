import { env } from 'cloudflare:workers';
import { evictDurableObject, runInDurableObject } from 'cloudflare:test';
import { afterEach, describe, expect, it } from 'vitest';
import worker from '../../src/index';
import { createRoomMessage, RoomIds } from '../../src/protocol/room_message';
import { attachment, SOCKET_LIMITS } from '../../src/room/sockets';
import { newResumeToken } from '../../src/security/tokens';
import { consumeAction } from '../../src/security/entry-limits';
import {
  socketRoom,
  connect,
  authenticated,
  auth,
  upgrade,
  requestId,
  cleanupPeers,
  profile,
  handshake,
} from './socket_helpers';
afterEach(cleanupPeers);

describe('authenticated hibernation sockets', () => {
  it('enforces a persisted 20-frame burst with 10/s refill independent of socket generation', async () => {
    const room = await socketRoom();
    await runInDurableObject(room.stub, (_room, ctx) => {
      for (let i = 0; i < 20; i++)
        expect(consumeAction(ctx.storage.sql, 'player', 1000)).toBe(true);
      expect(consumeAction(ctx.storage.sql, 'player', 1000)).toBe(false);
      expect(consumeAction(ctx.storage.sql, 'player', 1099)).toBe(false);
      expect(consumeAction(ctx.storage.sql, 'player', 1100)).toBe(true);
    });
    await evictDurableObject(room.stub);
    await runInDurableObject(room.stub, (_room, ctx) =>
      expect(consumeAction(ctx.storage.sql, 'player', 1100)).toBe(false),
    );
  });
  it('rejects oversized frames and incompatible handshakes before any projection', async () => {
    const room = await socketRoom();
    for (const message of [
      ' '.repeat(16385),
      { ...auth(room.credential), handshake: { ...handshake, catalogHash: '0'.repeat(64) } },
    ]) {
      const peer = await connect(room.code);
      peer.send(message);
      const failure = await peer.next();
      expect(failure.type).toBe('error');
      await peer.closed();
      expect(peer.frames.some((raw) => raw.includes('"type":"snapshot"'))).toBe(false);
    }
  });
  it('sends no room data until token auth, then an explicit redacted lobby projection', async () => {
    const room = await socketRoom(),
      peer = await connect(room.code, { Origin: 'http://localhost:7357' });
    await runInDurableObject(room.stub, (_room, ctx) => {
      expect(ctx.getWebSockets()).toHaveLength(1);
      const info = attachment(ctx.getWebSockets()[0]!);
      expect(info?.kind).toBe('pending');
      expect(JSON.stringify(info)).not.toContain(room.credential.resumeToken);
    });
    expect(peer.frames).toHaveLength(0);
    peer.send(auth(room.credential));
    expect(await peer.next()).toMatchObject({
      type: 'authenticated',
      playerId: room.credential.playerId,
      generation: 1,
    });
    const snapshot = await peer.next();
    if (snapshot.type !== 'snapshot') throw Error('snapshot');
    expect(snapshot.you).toBe(room.credential.playerId);
    expect(snapshot.private).toEqual({});
    expect(snapshot.public.players).toHaveLength(1);
    expect(snapshot.public.players[0]!.connected).toBe(true);
    const raw = peer.frames.join('');
    expect(raw).not.toContain(room.credential.resumeToken);
    expect(raw).not.toContain('verifier');
    expect(raw).not.toContain('selectionCount');
  });
  it('rejects invalid/foreign/revoked tokens and claimed identities without any snapshot', async () => {
    const room = await socketRoom(),
      foreign = await socketRoom();
    for (const message of [
      auth({ ...room.credential, resumeToken: newResumeToken() }),
      auth(foreign.credential),
      { ...auth(room.credential), playerId: room.credential.playerId },
      { type: 'requestSnapshot', protocolVersion: 1, requestId: requestId() },
    ]) {
      const peer = await connect(room.code);
      peer.send(message);
      expect((await peer.next()).type).toBe('error');
      await peer.closed();
      expect(peer.frames.some((raw) => raw.includes('"type":"snapshot"'))).toBe(false);
    }
    await room.stub.leave(
      createRoomMessage('leaveHttp', {
        requestId: requestId(),
        actionId: RoomIds.action(crypto.randomUUID()),
        resumeToken: room.credential.resumeToken,
        confirmed: true,
      }),
    );
    const peer = await connect(room.code);
    peer.send(auth(room.credential));
    expect(await peer.next()).toMatchObject({ type: 'error', code: 'CREDENTIAL_INVALID' });
    await peer.closed();
  });
  it('replaces an older tab, closes 4409 and rejects already buffered old-generation frames', async () => {
    const room = await socketRoom(),
      old = await authenticated(room.code, room.credential);
    const next = await authenticated(room.code, room.credential);
    expect(next.identity.generation).toBe(2);
    expect(next.identity.playerId).toBe(old.identity.playerId);
    expect(await old.peer.next()).toMatchObject({ type: 'sessionReplaced' });
    expect(await old.peer.closed()).toBe(4409);
    // Reproduce an already-delivered frame carrying the persisted old generation.
    const stale = await connect(room.code);
    await runInDurableObject(room.stub, (_instance, ctx) => {
      const server = ctx.getWebSockets().find((socket) => attachment(socket)?.kind === 'pending')!;
      const pending = attachment(server)!;
      server.serializeAttachment({
        formatVersion: 1,
        kind: 'authenticated',
        socketId: pending.socketId,
        roomId: room.credential.roomId,
        playerId: room.credential.playerId,
        generation: 1,
      });
    });
    stale.send(createRoomMessage('requestSnapshot', { requestId: requestId() }));
    expect(await stale.next()).toMatchObject({ type: 'error', code: 'SESSION_REPLACED' });
    expect(await stale.closed()).toBe(4409);
    expect(stale.frames.some((raw) => raw.includes('"type":"snapshot"'))).toBe(false);
    next.peer.send(createRoomMessage('ping', { requestId: requestId() }));
    expect((await next.peer.next()).type).toBe('pong');
    await runInDurableObject(room.stub, (_room, ctx) => {
      const state = JSON.parse(
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
      );
      expect(state.members).toHaveLength(1);
      expect(state.members[0].generation).toBe(2);
    });
  });
  it('rehydrates accepted attachments and SQLite state across actual Durable Object eviction', async () => {
    const room = await socketRoom(),
      session = await authenticated(room.code, room.credential);
    const before = await runInDurableObject(
      room.stub,
      (_room, ctx) =>
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
    );
    await evictDurableObject(room.stub);
    session.peer.send(createRoomMessage('ping', { requestId: requestId() }));
    expect((await session.peer.next()).type).toBe('pong');
    session.peer.send(createRoomMessage('requestSnapshot', { requestId: requestId() }));
    expect(await session.peer.next()).toMatchObject({
      type: 'snapshot',
      you: room.credential.playerId,
      private: {},
    });
    await runInDurableObject(room.stub, (_room, ctx) => {
      expect(
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
      ).toBe(before);
      expect(attachment(ctx.getWebSockets()[0]!)?.kind).toBe('authenticated');
    });
  });
  it('closes a live socket after HTTP leave; no reactivation by stale frames', async () => {
    const room = await socketRoom(),
      session = await authenticated(room.code, room.credential);
    await room.stub.leave(
      createRoomMessage('leaveHttp', {
        requestId: requestId(),
        actionId: RoomIds.action(crypto.randomUUID()),
        resumeToken: room.credential.resumeToken,
        confirmed: true,
      }),
    );
    expect(await session.peer.next()).toMatchObject({ type: 'error', code: 'CREDENTIAL_INVALID' });
    expect(await session.peer.closed()).toBe(4401);
  });
  it('checks exact Origins, Upgrade, query/subprotocol secrets and missing rooms before accepting', async () => {
    const room = await socketRoom();
    expect((await upgrade(room.code, { Origin: 'https://attacker.example' })).status).toBe(403);
    expect(
      (await upgrade(room.code, { 'Sec-WebSocket-Protocol': 'synthetic-secret' })).status,
    ).toBe(400);
    expect((await upgrade(room.code + '?resumeToken=synthetic')).status).not.toBe(101);
    expect(
      (await worker.fetch(new Request(`http://localhost/api/rooms/${room.code}/socket`), env))
        .status,
    ).toBe(426);
    const missing = await socketRoom();
    await runInDurableObject(missing.stub, (_room, ctx) =>
      ctx.storage.sql.exec('UPDATE room_record SET state = NULL'),
    );
    expect((await upgrade(missing.code)).status).toBe(410);
  });
  it('bounds pending connections and malformed/binary frames without exposing state', async () => {
    const room = await socketRoom();
    const pending = await Promise.all(
      Array.from({ length: SOCKET_LIMITS.pendingPerRoom }, () => connect(room.code)),
    );
    expect((await upgrade(room.code)).status).toBe(429);
    pending[0]!.socket.send(new Uint8Array([1, 2, 3]));
    expect((await pending[0]!.next()).type).toBe('error');
    expect(await pending[0]!.closed()).toBe(1003);
    const next = await connect(room.code);
    next.send('{"resumeToken":"synthetic-secret"');
    expect((await next.next()).type).toBe('error');
    await next.closed();
    expect(next.frames.join('')).not.toContain('synthetic-secret');
  });
  it('uses the verified player identity for every projection even when the other participant is host', async () => {
    const room = await socketRoom();
    const joined = await room.stub.join(
      createRoomMessage('join', { requestId: requestId(), profile, handshake }),
    );
    if (!joined.ok) throw Error('join');
    const host = await authenticated(room.code, room.credential),
      guest = await authenticated(room.code, joined.message);
    expect(guest.snapshot.you).toBe(joined.message.playerId);
    expect(guest.snapshot.public.hostId).toBe(room.credential.playerId);
    expect(host.snapshot.private).toEqual({});
    expect(guest.snapshot.private).toEqual({});
    expect(guest.peer.frames.join('')).not.toContain(room.credential.resumeToken);
  });
});
