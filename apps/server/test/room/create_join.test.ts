import { env } from 'cloudflare:workers';
import { runInDurableObject, runDurableObjectAlarm } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import fixtures from '../../../../packages/protocol/fixtures/messages/room-v2.json';
import vectors from '../../../../packages/protocol/fixtures/messages/resume-verifiers.json';
import worker from '../../src/index';
import { createRoomMessage, decodeRoomMessage, RoomIds } from '../../src/protocol/room_message';
import {
  protocolMetadata,
  type CredentialMessage,
  type CreateMessage,
  type JoinMessage,
} from '../../src/protocol/room_message.generated';
import { allocateRoom, normalizeRoomCode, randomRoomCode } from '../../src/http/rooms';
import { newResumeToken, resumeVerifier, sameVerifier } from '../../src/security/tokens';
import { ENTRY_LIMITS } from '../../src/security/entry-limits';
import { roomExpiry } from '../../src/room/room';

const initial = decodeRoomMessage(
  JSON.stringify(fixtures.fixtures.find((f) => f.valid.type === 'create')!.valid),
);
if (initial.type !== 'create') throw Error('create fixture required');
const profile = initial.profile,
  handshake = initial.handshake;
function create(name = profile.name): CreateMessage {
  return createRoomMessage('create', {
    requestId: RoomIds.request(crypto.randomUUID()),
    profile: { ...profile, name },
    handshake,
  });
}
function join(name = profile.name): JoinMessage {
  return createRoomMessage('join', {
    requestId: RoomIds.request(crypto.randomUUID()),
    profile: { ...profile, name },
    handshake,
  });
}
function authentication(credential: CredentialMessage) {
  return createRoomMessage('authenticate', {
    requestId: RoomIds.request(crypto.randomUUID()),
    resumeToken: credential.resumeToken,
    handshake,
  });
}
function leaving(credential: CredentialMessage) {
  return createRoomMessage('leaveHttp', {
    requestId: RoomIds.request(crypto.randomUUID()),
    actionId: RoomIds.action(crypto.randomUUID()),
    resumeToken: credential.resumeToken,
    confirmed: true,
  });
}
async function newRoom() {
  const code = randomRoomCode(),
    stub = env.ROOMS.getByName(code),
    result = await stub.createIfAbsent(code, create());
  if ('collision' in result || !result.ok) throw Error('Expected created room');
  return { code, stub, credential: result.message };
}
async function stateText(stub: ReturnType<typeof env.ROOMS.getByName>): Promise<string | null> {
  return runInDurableObject(
    stub,
    (_room, ctx) =>
      ctx.storage.sql.exec<{ state: string | null }>('SELECT state FROM room_record').one().state,
  );
}
async function post(path: string, message: unknown, extra: Record<string, string> = {}) {
  return worker.fetch(
    new Request('http://localhost' + path, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'CF-Connecting-IP': crypto.randomUUID(),
        ...extra,
      },
      body: JSON.stringify(message),
    }),
    env,
  );
}
async function credential(response: Response): Promise<CredentialMessage> {
  const message = decodeRoomMessage(await response.text(), { direction: 'server' });
  if (message.type !== 'credential') throw Error('Expected private credential');
  return message;
}

describe('atomic room creation and bounded membership in SQLite', () => {
  it('reserves one code atomically under simultaneous creates, never overwrites its owner', async () => {
    const code = randomRoomCode(),
      stub = env.ROOMS.getByName(code);
    const results = await Promise.all(
      Array.from({ length: 8 }, () => stub.createIfAbsent(code, create())),
    );
    const wins = results.filter((r) => 'ok' in r && r.ok);
    expect(wins).toHaveLength(1);
    expect(results.filter((r) => 'collision' in r)).toHaveLength(7);
    const stored = JSON.parse((await stateText(stub))!);
    expect(stored.config.factorTenths).toBe(20);
    expect(stored.members).toHaveLength(1);
    expect(stored.hostId).toBe(stored.members[0].playerId);
    for (const result of results)
      if ('collision' in result) expect(Object.keys(result)).toEqual(['collision']);
  });
  it('retries a collision with a new code and stops after eight without leaking a room', async () => {
    const room = await newRoom(),
      next = randomRoomCode();
    const original = await stateText(room.stub);
    const candidates = [room.code, next];
    let calls = 0;
    const response = await allocateRoom(
      (code) => env.ROOMS.getByName(code).createIfAbsent(code, create()),
      () => candidates[calls++]!,
    );
    expect(response.status).toBe(201);
    expect((await credential(response)).roomCode).toBe(next);
    expect(await stateText(room.stub)).toBe(original);
    let collisions = 0;
    const failed = await allocateRoom(
      async () => {
        collisions++;
        return { collision: true };
      },
      () => room.code,
    );
    expect(collisions).toBe(8);
    expect(failed.status).toBe(503);
    expect(Object.keys((await failed.json()) as object)).toEqual([
      'type',
      'protocolVersion',
      'requestId',
      'code',
    ]);
  });
  it('handles N=3, concurrent N=20/21 and reopens exactly one seat only after confirmed leave', async () => {
    const room = await newRoom();
    const two = await Promise.all([room.stub.join(join()), room.stub.join(join())]);
    expect(two.every((r) => r.ok)).toBe(true);
    const many = await Promise.all(Array.from({ length: 18 }, () => room.stub.join(join())));
    expect(many.filter((r) => r.ok)).toHaveLength(17);
    expect(many.filter((r) => !r.ok && r.code === 'ROOM_FULL')).toHaveLength(1);
    const departing = two[0]!;
    if (!departing.ok) throw Error('join');
    const leave = leaving(departing.message);
    const before = JSON.parse((await stateText(room.stub))!);
    expect(await room.stub.leave({ ...leave, confirmed: false } as never)).toMatchObject({
      ok: false,
      code: 'INVALID_MESSAGE',
    });
    expect(
      JSON.parse((await stateText(room.stub))!).members.filter(
        (m: { revoked: boolean }) => !m.revoked,
      ),
    ).toHaveLength(20);
    const ack = await room.stub.leave(leave);
    expect(ack.ok).toBe(true);
    const joined = await room.stub.join(join());
    expect(joined.ok).toBe(true);
    if (!joined.ok) throw Error('join');
    expect(joined.message.playerId).not.toBe(departing.message.playerId);
    const retry = await room.stub.leave(leave);
    expect(retry).toEqual(ack);
    const stored = JSON.parse((await stateText(room.stub))!);
    expect(stored.members.filter((m: { revoked: boolean }) => !m.revoked)).toHaveLength(20);
    expect(stored.revision).toBe(before.revision + 2);
    expect(
      stored.members.find((m: { playerId: string }) => m.playerId === departing.message.playerId)
        .profile,
    ).toBeUndefined();
  });
  it('persists only bound verifiers, independent random IDs and each caller’s own credential', async () => {
    const room = await newRoom(),
      other = await room.stub.join(join());
    if (!other.ok) throw Error('join');
    expect(room.credential.resumeToken).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(room.credential.playerId).not.toBe(other.message.playerId);
    expect(room.credential.resumeToken).not.toBe(other.message.resumeToken);
    expect(JSON.stringify(other.message)).not.toContain(room.credential.resumeToken);
    expect(Object.keys(other.message).sort()).toEqual(
      [
        'type',
        'protocolVersion',
        'requestId',
        'roomCode',
        'roomId',
        'playerId',
        'resumeToken',
        'expiresAtUtc',
      ].sort(),
    );
    const raw = (await stateText(room.stub))!;
    expect(raw).not.toContain(room.credential.resumeToken);
    expect(raw).not.toContain(other.message.resumeToken);
    const stored = JSON.parse(raw);
    expect(stored.members[0].verifier).toBe(
      await resumeVerifier(room.credential.roomId, room.credential.resumeToken),
    );
    expect(stored.hostId).toBe(room.credential.playerId);
    expect(stored.members[1].playerId).not.toBe(stored.hostId);
  });
  it('resumes existing identity/counter without a new member or deadline extension; revocation is final', async () => {
    const room = await newRoom(),
      other = await room.stub.join(join());
    if (!other.ok) throw Error('join');
    const before = JSON.parse((await stateText(room.stub))!);
    const [a, b] = await Promise.all([
      room.stub.authenticate(authentication(other.message)),
      room.stub.authenticate(authentication(other.message)),
    ]);
    if (!a.ok || !b.ok) throw Error('authenticate');
    expect(a.message.playerId).toBe(other.message.playerId);
    expect(b.message.playerId).toBe(other.message.playerId);
    expect([a.message.generation, b.message.generation].sort()).toEqual([1, 2]);
    const after = JSON.parse((await stateText(room.stub))!);
    expect(after.members).toHaveLength(2);
    expect(after.lastDomainActivity).toBe(before.lastDomainActivity);
    expect(after.members[1].selectionCount).toBe(before.members[1].selectionCount);
    const foreign = await newRoom();
    expect(await foreign.stub.authenticate(authentication(other.message))).toMatchObject({
      ok: false,
      code: 'CREDENTIAL_INVALID',
    });
    expect(await room.stub.leave(leaving(other.message))).toMatchObject({ ok: true });
    expect(await room.stub.authenticate(authentication(other.message))).toMatchObject({
      ok: false,
      code: 'CREDENTIAL_INVALID',
    });
    expect(await room.stub.leave(leaving(other.message))).toMatchObject({
      ok: false,
      code: 'CREDENTIAL_INVALID',
    });
  });
  it('starts a fresh join at the highest active fairness count, never reuses a departed identity', async () => {
    const room = await newRoom();
    await runInDurableObject(room.stub, (_room, ctx) => {
      const state = JSON.parse(
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
      );
      state.members[0].selectionCount = 7;
      ctx.storage.sql.exec('UPDATE room_record SET state = ?', JSON.stringify(state));
    });
    const first = await room.stub.join(join());
    if (!first.ok) throw Error('join');
    expect(JSON.parse((await stateText(room.stub))!).members[1].selectionCount).toBe(7);
    await room.stub.leave(leaving(first.message));
    const second = await room.stub.join(join());
    if (!second.ok) throw Error('join');
    expect(second.message.playerId).not.toBe(first.message.playerId);
    expect(JSON.parse((await stateText(room.stub))!).members[2].selectionCount).toBe(7);
  });
  it('unknown/invalid join creates no room, rejects 25 graphemes and accepts 1/24 complex clusters', async () => {
    const code = randomRoomCode(),
      stub = env.ROOMS.getByName(code);
    expect(await stub.join(join())).toMatchObject({ ok: false, code: 'ROOM_UNAVAILABLE' });
    await runInDurableObject(stub, (_room, ctx) =>
      expect(
        ctx.storage.sql.exec("SELECT name FROM sqlite_master WHERE name = 'room_record'").toArray(),
      ).toHaveLength(0),
    );
    const invalid = { ...join(), profile: { ...profile, name: '👨‍👩‍👧‍👦'.repeat(25) } };
    expect((await post(`/api/rooms/${code}/join`, invalid)).status).toBe(400);
    const room = await newRoom();
    for (const name of ['A', '👨‍👩‍👧‍👦'.repeat(24)])
      expect((await room.stub.join(join(name))).ok).toBe(true);
    expect(await room.stub.join(invalid as JoinMessage)).toMatchObject({
      ok: false,
      code: 'INVALID_NAME',
    });
    expect(JSON.parse((await stateText(room.stub))!).members).toHaveLength(3);
  });
  it('checks expiry on every request, scrubs private data, and never reuses the code', async () => {
    const room = await newRoom();
    await runInDurableObject(room.stub, (_room, ctx) => {
      const state = JSON.parse(
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
      );
      state.lastDomainActivity = Date.now() - protocolMetadata.limits.roomIdleMs - 1;
      ctx.storage.sql.exec('UPDATE room_record SET state = ?', JSON.stringify(state));
    });
    expect(await room.stub.join(join())).toMatchObject({ ok: false, status: 410 });
    expect(await stateText(room.stub)).toBeNull();
    expect(await room.stub.authenticate(authentication(room.credential))).toMatchObject({
      ok: false,
      status: 410,
    });
    expect(await room.stub.createIfAbsent(room.code, create())).toEqual({ collision: true });
    const fresh = await newRoom();
    await runInDurableObject(fresh.stub, (_room, ctx) => {
      const state = JSON.parse(
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
      );
      state.createdAt = Date.now() - protocolMetadata.limits.roomHardMs - 1;
      ctx.storage.sql.exec('UPDATE room_record SET state = ?', JSON.stringify(state));
    });
    expect(await runDurableObjectAlarm(fresh.stub)).toBe(true);
    expect(await stateText(fresh.stub)).toBeNull();
    expect(roomExpiry({ createdAt: 100, lastDomainActivity: 200 })).toBe(
      200 + protocolMetadata.limits.roomIdleMs,
    );
  });
  it('limits parallel entry attempts persistently, resets windows, and limits churn per room', async () => {
    const gate = env.ROOMS.getByName('entry-rate:' + crypto.randomUUID());
    const attempts = await Promise.all(
      Array.from({ length: 8 }, () => gate.consumeEntryAttempt('create')),
    );
    expect(attempts.filter(Boolean)).toHaveLength(ENTRY_LIMITS.createPerAddress);
    await runInDurableObject(gate, (_room, ctx) =>
      ctx.storage.sql.exec('UPDATE entry_limits SET start = ?', Date.now() - ENTRY_LIMITS.windowMs),
    );
    expect(await gate.consumeEntryAttempt('create')).toBe(true);
    const room = await newRoom();
    const results = await Promise.all(Array.from({ length: 61 }, () => room.stub.join(join())));
    expect(results.filter((r) => r.ok)).toHaveLength(19);
    expect(results.filter((r) => !r.ok && r.code === 'RATE_LIMITED')).toHaveLength(1);
    expect(results.filter((r) => !r.ok && r.code === 'ROOM_FULL')).toHaveLength(41);
  });
});

describe('HTTP entry and credentials', () => {
  it('creates and joins via the real Worker binding, CORS and no-store; no public room data', async () => {
    const response = await post('/api/rooms', create(), { Origin: 'http://localhost:7357' });
    expect(response.status).toBe(201);
    expect(response.headers.get('Cache-Control')).toBe('no-store');
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('http://localhost:7357');
    const host = await credential(response);
    const participant = await credential(
      await post(`/api/rooms/${host.roomCode.toLowerCase()}/join`, join()),
    );
    expect(participant.roomId).toBe(host.roomId);
    const left = await post(`/api/rooms/${host.roomCode}/leave`, leaving(participant));
    expect(left.status).toBe(200);
    expect(await left.json()).toMatchObject({ type: 'ack', outcome: 'left' });
    expect(
      (await worker.fetch(new Request(`http://localhost/api/rooms/${host.roomCode}`), env)).status,
    ).toBe(404);
  });
  it('requires an allowlisted exact Origin and preflight while supporting native clients', async () => {
    for (const origin of [
      'https://attacker.example',
      'http://localhost:7357.attacker.example',
      'null',
    ])
      expect((await post('/api/rooms', create(), { Origin: origin })).status).toBe(403);
    const preflight = await worker.fetch(
      new Request('http://localhost/api/rooms', {
        method: 'OPTIONS',
        headers: {
          Origin: 'http://localhost:7357',
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'content-type',
        },
      }),
      env,
    );
    expect(preflight.status).toBe(204);
    expect(preflight.headers.get('Access-Control-Allow-Credentials')).toBeNull();
    expect((await post('/api/rooms?resumeToken=synthetic', create())).status).toBe(400);
    expect((await post('/api/rooms/invalid/join', join())).status).toBe(400);
  });
  it('counts malformed HTTP attempts and never reissues credentials based on requestId', async () => {
    const ip = crypto.randomUUID(),
      command = create();
    const first = await credential(await post('/api/rooms', command, { 'CF-Connecting-IP': ip }));
    const second = await credential(await post('/api/rooms', command, { 'CF-Connecting-IP': ip }));
    expect(second.roomId).not.toBe(first.roomId);
    expect(second.resumeToken).not.toBe(first.resumeToken);
    for (let i = 0; i < 3; i++)
      expect((await post('/api/rooms', { broken: true }, { 'CF-Connecting-IP': ip })).status).toBe(
        400,
      );
    const limited = await post('/api/rooms', command, { 'CF-Connecting-IP': ip });
    expect(limited.status).toBe(429);
    const text = await limited.text();
    expect(text).not.toContain(first.resumeToken);
    expect(text).not.toContain(first.playerId);
  });
});

describe('cryptographic credentials and code normalization', () => {
  it('matches independent room-bound SHA-256 vectors with constant-time comparison', async () => {
    for (const vector of vectors.vectors)
      expect(await resumeVerifier(RoomIds.room(vector.roomId), vector.resumeToken)).toBe(
        vector.expectedVerifier,
      );
    expect(
      sameVerifier(vectors.vectors[0]!.expectedVerifier, vectors.vectors[1]!.expectedVerifier),
    ).toBe(false);
    expect(
      sameVerifier(vectors.vectors[0]!.expectedVerifier, vectors.vectors[0]!.expectedVerifier),
    ).toBe(true);
    await expect(resumeVerifier(RoomIds.room('room'), 'A'.repeat(42) + 'B')).rejects.toThrow();
    const tokens = new Set(Array.from({ length: 256 }, newResumeToken));
    expect(tokens.size).toBe(256);
    expect(
      [...tokens].every(
        (token) =>
          token.length === 43 &&
          atob(token.replaceAll('-', '+').replaceAll('_', '/') + '=').length === 32,
      ),
    ).toBe(true);
  });
  it('normalizes only the documented bounded code form and generates the allowed alphabet', () => {
    expect(normalizeRoomCode(' abcd-23 45 ')).toBe('ABCD2345');
    for (const invalid of [
      'ABCD234I',
      'https://example/join?room=ABCD2345',
      'ABCD\t2345',
      'X'.repeat(65),
      'ABCD_2345',
    ])
      expect(normalizeRoomCode(invalid)).toBeNull();
    const codes = new Set(Array.from({ length: 256 }, randomRoomCode));
    expect(codes.size).toBe(256);
    expect([...codes].every((code) => /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/.test(code))).toBe(
      true,
    );
  });
});
