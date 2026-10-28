import { env } from 'cloudflare:workers';
import { evictDurableObject, runInDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { consumeAuthenticatedAction, ROOM_ACTION_LIMITS } from '../../src/security/entry-limits';
import { createRoomMessage } from '../../src/protocol/room_message';
import { allJudgesRoom } from '../room/all_judges_helpers';
import {
  authenticated,
  cleanupPeers,
  handshake,
  profile,
  requestId,
  socketRoom,
} from '../room/socket_helpers';
import { randomRoomCode } from '../../src/http/rooms';
import worker from '../../src/index';

afterEach(cleanupPeers);

it('aggregate room budget survives eviction and rejected attempts spend neither bucket', async () => {
  const room = await socketRoom();
  await runInDurableObject(room.stub, (_room, ctx) => {
    for (let index = 0; index < ROOM_ACTION_LIMITS.burst; index++)
      expect(consumeAuthenticatedAction(ctx.storage.sql, `p${Math.floor(index / 20)}`, 1000)).toBe(
        true,
      );
    const before = ctx.storage.sql.exec('SELECT * FROM action_limits ORDER BY key').toArray();
    for (let attempt = 0; attempt < 30; attempt++)
      expect(consumeAuthenticatedAction(ctx.storage.sql, 'fresh', 1000)).toBe(false);
    expect(ctx.storage.sql.exec('SELECT * FROM action_limits ORDER BY key').toArray()).toEqual(
      before,
    );
  });
  await evictDurableObject(room.stub);
  await runInDurableObject(room.stub, (_room, ctx) => {
    expect(consumeAuthenticatedAction(ctx.storage.sql, 'fresh', 1019)).toBe(false);
    expect(consumeAuthenticatedAction(ctx.storage.sql, 'fresh', 1020)).toBe(true);
    expect(consumeAuthenticatedAction(ctx.storage.sql, 'other', 1020)).toBe(false);
  });
});

it('a depleted player cannot spend the shared room budget; backwards clocks cannot create refill', async () => {
  const room = await socketRoom();
  await runInDurableObject(room.stub, (_room, ctx) => {
    for (let index = 0; index < 20; index++)
      expect(consumeAuthenticatedAction(ctx.storage.sql, 'p', 1000)).toBe(true);
    const before = ctx.storage.sql.exec('SELECT * FROM action_limits ORDER BY key').toArray();
    expect(consumeAuthenticatedAction(ctx.storage.sql, 'p', 1000)).toBe(false);
    expect(ctx.storage.sql.exec('SELECT * FROM action_limits ORDER BY key').toArray()).toEqual(
      before,
    );
    expect(consumeAuthenticatedAction(ctx.storage.sql, 'fresh', 500)).toBe(true);
    expect(
      ctx.storage.sql
        .exec<{ updated: number }>('SELECT updated FROM action_limits WHERE key = ?', '@room')
        .one().updated,
    ).toBe(1000);
    expect(consumeAuthenticatedAction(ctx.storage.sql, 'p', 1099)).toBe(false);
    expect(consumeAuthenticatedAction(ctx.storage.sql, 'p', 1100)).toBe(true);
  });
});

it('room throttling closes a current socket without changing the game or another room', async () => {
  const f = await allJudgesRoom(),
    other = await socketRoom();
  const before = await f.read();
  await runInDurableObject(f.room.stub, (_room, ctx) => {
    ctx.storage.sql.exec(
      'INSERT OR REPLACE INTO action_limits (key,tokens,updated) VALUES (?,?,?)',
      '@room',
      0,
      Date.now() + 60000,
    );
  });
  f.host.peer.send(createRoomMessage('ping', { requestId: requestId() }));
  for (let index = 0; index < 100; index++) {
    const frame = await f.host.peer.next();
    if (frame.type === 'error') {
      expect(frame.code).toBe('RATE_LIMITED');
      break;
    }
  }
  expect(await f.host.peer.closed()).toBe(4429);
  expect((await f.read()).game!.round).toEqual(before.game!.round);
  expect((await f.read()).game!.personCounts).toEqual(before.game!.personCounts);
  const session = await authenticated(other.code, other.credential);
  session.peer.send(createRoomMessage('ping', { requestId: requestId() }));
  expect(await session.peer.next()).toMatchObject({ type: 'pong' });
});

it('invalid frames expose no private payload and do not disturb a regular participant', async () => {
  const f = await allJudgesRoom();
  const marker = 'PRIVATE_PAYLOAD_MARKER';
  const invalid = [
    `{"${marker}":`,
    ' '.repeat(16385),
    '['.repeat(33) + '0' + ']'.repeat(33),
    JSON.stringify({ protocolVersion: 2, type: 'ping', requestId: 'x', playerId: marker }),
    JSON.stringify({ protocolVersion: 2, type: 'snapshot', roomId: marker }),
  ];
  const before = await f.read();
  for (const raw of invalid) {
    const session = await authenticated(f.room.code, f.members[2]!.credential);
    const start = session.peer.frames.length;
    session.peer.send(raw);
    await session.peer.closed();
    const frames = session.peer.frames.slice(start).map((frame) => JSON.parse(frame));
    expect(frames).toHaveLength(1);
    expect(frames[0].type).toBe('error');
    expect(JSON.stringify(frames)).not.toContain(marker);
    expect(frames[0]).not.toHaveProperty('private');
  }
  const after = await f.read();
  expect(after.game!.round).toEqual(before.game!.round);
  expect(after.game!.history).toEqual(before.game!.history);
  expect((await f.snapshot(f.members[1]!.peer)).you).toBe(f.members[1]!.credential.playerId);
});

it('unknown room probes create no app-owned room rows or alarm', async () => {
  const code = randomRoomCode();
  for (const endpoint of ['join', 'socket']) {
    const request =
      endpoint === 'join'
        ? new Request(`http://localhost/api/rooms/${code}/join`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(
              createRoomMessage('join', { requestId: requestId(), profile, handshake }),
            ),
          })
        : new Request(`http://localhost/api/rooms/${code}/socket`, {
            headers: { Upgrade: 'websocket' },
          });
    expect((await worker.fetch(request, env)).status).toBe(410);
  }
  await runInDurableObject(env.ROOMS.getByName(code), async (_room, ctx) => {
    const tables = ctx.storage.sql
      .exec<{ name: string }>("SELECT name FROM sqlite_master WHERE type='table'")
      .toArray();
    expect(
      tables.filter((t) =>
        ['room_record', 'entry_limits', 'action_limits', 'deadlines'].includes(t.name),
      ),
    ).toEqual([]);
    expect(await ctx.storage.getAlarm()).toBeNull();
  });
});
