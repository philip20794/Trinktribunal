import { runInDurableObject, runDurableObjectAlarm, evictDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { roomExpiry } from '../../src/room/expiry';
import { roomDiagnostic } from '../../src/room/logging';
import { RoomRepository } from '../../src/room/repository';
import { immutable, type MutableGameState } from '../../src/domain/game_state';
import { createRoomMessage, RoomIds } from '../../src/protocol/room_message';
import { allJudgesRoom, result } from './all_judges_helpers';
import { cleanupPeers, connect, profile, handshake, requestId } from './socket_helpers';

afterEach(cleanupPeers);
it('24h idle and 48h hard limits use the earlier deadline even in an active room', () => {
  const hour = 3600000;
  expect(roomExpiry({ createdAt: 0, lastDomainActivity: 0 })).toBe(24 * hour);
  expect(roomExpiry({ createdAt: 0, lastDomainActivity: 30 * hour })).toBe(48 * hour);
  expect(roomExpiry({ createdAt: 0, lastDomainActivity: 23 * hour })).toBe(47 * hour);
});
it('diagnostics allow only a validated code and integer revision, never embedded secrets', () => {
  const secret = 'LOG_SECRET_SENTINEL',
    input = {
      code: 'ROOM_UNAVAILABLE',
      revision: 7,
      name: secret,
      token: secret,
      numbers: [secret],
      orders: [secret],
      stack: secret,
    };
  expect(roomDiagnostic(input)).toEqual({ code: 'ROOM_UNAVAILABLE', revision: 7 });
  expect(
    JSON.stringify(roomDiagnostic({ ...input, code: secret, revision: secret })),
  ).not.toContain(secret);
  expect(roomDiagnostic({ code: 'INVALID_MESSAGE', revision: Infinity })).toEqual({
    code: 'INVALID_MESSAGE',
    revision: 0,
  });
});

for (const hard of [false, true])
  it(`${hard ? 'hard' : 'idle'} expiry wins over auth and host deadlines, erases all private rows and survives eviction/retry`, async () => {
    const f = await allJudgesRoom(),
      pending = await connect(f.room.code);
    await runInDurableObject(f.room.stub, (_room, ctx) => {
      const repository = new RoomRepository(ctx.storage),
        state = repository.read()!,
        game = structuredClone(state.game!) as MutableGameState,
        now = Date.now();
      state.members[0]!.profile = { ...profile, name: 'LOG_SECRET_SENTINEL' };
      if (hard) {
        state.createdAt = now - 48 * 3600000;
        state.lastDomainActivity = now;
      } else state.lastDomainActivity = now - 24 * 3600000;
      game.hostDisconnectedAt = now - 90001;
      state.game = immutable(game);
      repository.write(state);
      ctx.storage.sql.exec('UPDATE deadlines SET due = ?', now - 1);
    });
    expect(await runDurableObjectAlarm(f.room.stub)).toBe(true);
    expect(await pending.next()).toMatchObject({ type: 'error', code: 'ROOM_UNAVAILABLE' });
    expect(await pending.closed()).toBe(4401);
    await evictDurableObject(f.room.stub);
    await runInDurableObject(f.room.stub, async (room, ctx) => {
      await room.alarm();
      expect(new RoomRepository(ctx.storage).read()).toBeNull();
      expect(ctx.storage.sql.exec('SELECT state FROM room_record').one().state).toBeNull();
      for (const table of ['entry_limits', 'action_limits', 'deadlines'])
        expect(ctx.storage.sql.exec(`SELECT COUNT(*) AS n FROM ${table}`).one().n).toBe(0);
      expect(await ctx.storage.getAlarm()).toBeNull();
    });
    expect(
      await f.room.stub.join(
        createRoomMessage('join', { requestId: requestId(), profile, handshake }),
      ),
    ).toMatchObject({ ok: false, code: 'ROOM_UNAVAILABLE', status: 410 });
    expect(
      await f.room.stub.createIfAbsent(
        f.room.code,
        createRoomMessage('create', { requestId: requestId(), profile, handshake }),
      ),
    ).toEqual({ collision: true });
  });

it('only the current host can close; conflicting IDs cannot delete a room; commit closes every socket and removes the alarm', async () => {
  const f = await allJudgesRoom(),
    state = await f.read();
  const command = (actionId = f.action()) =>
    createRoomMessage('closeRoom', { actionId, expectedRevision: state.revision, confirmed: true });
  f.members[1]!.peer.send(command());
  expect(await result(f.members[1]!.peer)).toMatchObject({
    type: 'error',
    code: 'UNAUTHORIZED_ACTION',
  });
  f.host.peer.send(command(RoomIds.action(state.game!.receipts[0]!.actionId)));
  expect(await result(f.host.peer)).toMatchObject({ type: 'error', code: 'ACTION_ID_CONFLICT' });
  f.host.peer.send(command());
  expect(await result(f.host.peer)).toMatchObject({ type: 'ack', outcome: 'closed' });
  for (const member of f.members) await member.peer.closed();
  await runInDurableObject(f.room.stub, async (_room, ctx) => {
    expect(new RoomRepository(ctx.storage).read()).toBeNull();
    expect(await ctx.storage.getAlarm()).toBeNull();
  });
});
