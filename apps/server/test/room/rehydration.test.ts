import { runInDurableObject, evictDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import fixtures from '../../../../packages/protocol/fixtures/transitions/persistence/v1.json';
import { RoomRepository } from '../../src/room/repository';
import { migrateRoomState } from '../../src/room/migrations';
import { attachment } from '../../src/room/sockets';
import { createRoomMessage } from '../../src/protocol/room_message';
import { allJudgesRoom, result } from './all_judges_helpers';
import { roomInPhase } from './game_phase_helpers';
import { cleanupPeers, authenticated, profile, handshake, requestId } from './socket_helpers';

afterEach(cleanupPeers);
it('malformed JSON, scalars and excessive nesting produce only a fixed unavailable error', () => {
  for (const raw of [
    '{PRIVATE_MARKER',
    'null',
    '[]',
    JSON.stringify('PRIVATE_MARKER'),
    '['.repeat(40) + '"PRIVATE_MARKER"' + ']'.repeat(40),
  ]) {
    try {
      migrateRoomState(raw);
      throw new Error('EXPECTED_REJECTION');
    } catch (error) {
      expect(String(error)).toBe('Error: ROOM_UNAVAILABLE');
    }
  }
});

it('known legacy host pause at game end preserves the finished phase and every game value', async () => {
  const f = await roomInPhase(false, 'finished'),
    state = await f.read(),
    legacy = JSON.parse(JSON.stringify(state));
  legacy.phase = 'paused';
  Object.assign(legacy.game, {
    phase: 'paused',
    pausedFrom: 'case_boundary',
    pauseReason: 'host_unavailable',
    hostDisconnectedAt: 1000,
    hostPauseState: { phase: 'finished' },
  });
  const first = migrateRoomState(JSON.stringify(legacy));
  expect(first.migrated).toBe(true);
  expect(first.state.game!.pausedFrom).toBe('finished');
  expect(first.state.game!.history).toEqual(state.game!.history);
  expect(first.state.game!.personCounts).toEqual(state.game!.personCounts);
  expect(first.state.game!.completedCases).toBe(3);
  expect(first.state.revision).toBe(state.revision);
  expect(migrateRoomState(JSON.stringify(first.state)).migrated).toBe(false);
});
for (const allJudges of [false, true])
  for (const phase of fixtures.phases)
    it(`${allJudges ? 'all judges' : 'normal'} ${phase}: actual eviction restores state, allowed projection, receipts and attachments unchanged`, async () => {
      const f = await roomInPhase(allJudges, phase),
        before = await f.read();
      const members = f.members.filter((m) =>
        before.members.some((p) => p.playerId === m.credential.playerId && !p.revoked),
      );
      const views = await Promise.all(members.map((m) => f.snapshot(m.peer)));
      const rawBefore = await runInDurableObject(
        f.room.stub,
        (_room, ctx) => ctx.storage.sql.exec('SELECT state FROM room_record').one().state,
      );
      await evictDurableObject(f.room.stub);
      expect(await f.read()).toEqual(before);
      for (let index = 0; index < members.length; index++) {
        const view = await f.snapshot(members[index]!.peer);
        expect(view.public).toEqual(views[index]!.public);
        expect(view.private).toEqual(views[index]!.private);
        expect(view.revision).toBe(views[index]!.revision);
      }
      await runInDurableObject(f.room.stub, (_room, ctx) => {
        expect(ctx.storage.sql.exec('SELECT state FROM room_record').one().state).toBe(rawBefore);
        for (const socket of ctx.getWebSockets()) {
          const info = attachment(socket);
          if (info?.kind !== 'authenticated') continue;
          expect(Object.keys(info).sort()).toEqual([
            'formatVersion',
            'generation',
            'kind',
            'playerId',
            'playersHash',
            'roomId',
            'socketId',
            'viewExpiry',
            'viewRevision',
          ]);
          for (const member of f.members)
            expect(JSON.stringify(info)).not.toContain(member.credential.resumeToken);
        }
      });
    });

it('readiness migration is durable, atomic on storage failure and written exactly once without advancing anything', async () => {
  const f = await roomInPhase(false, 'answers'),
    before = await f.read();
  await runInDurableObject(f.room.stub, (_room, ctx) => {
    const raw = JSON.parse(
      ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
    );
    delete raw.game.round.answerReady;
    const legacy = JSON.stringify(raw);
    ctx.storage.sql.exec('UPDATE room_record SET state = ?', legacy);
    const fail = () =>
      ctx.storage.sql.exec(
        "CREATE TRIGGER fail_migration BEFORE INSERT ON room_record BEGIN SELECT RAISE(ABORT, 'EXPECTED_STORAGE_FAILURE'); END",
      );
    const repository = new RoomRepository(ctx.storage);
    fail();
    expect(() => repository.read()).toThrow('ROOM_UNAVAILABLE');
    expect(ctx.storage.sql.exec('SELECT state FROM room_record').one().state).toBe(legacy);
    ctx.storage.sql.exec('DROP TRIGGER fail_migration');
    expect(repository.read()).toEqual(before);
    const saved = ctx.storage.sql
      .exec<{ state: string }>('SELECT state FROM room_record')
      .one().state;
    expect(JSON.parse(saved).game.round.answerReady).toEqual([]);
    fail();
    expect(repository.read()).toEqual(before);
    ctx.storage.sql.exec('DROP TRIGGER fail_migration');
    expect(ctx.storage.sql.exec('SELECT state FROM room_record').one().state).toBe(saved);
  });
  await evictDurableObject(f.room.stub);
  expect(await f.read()).toEqual(before);
});

for (const c of fixtures.invalidCases)
  it(`persisted ${c.id} fails closed and erases private state without leaking validation paths`, async () => {
    const f = await allJudgesRoom(),
      bad = structuredClone(await f.read());
    let target: any = bad;
    for (const key of c.path.slice(0, -1)) target = target[key];
    const key = c.path[c.path.length - 1]!;
    if ('delete' in c && c.delete) delete target[key];
    else target[key] = 'value' in c ? c.value : undefined;
    expect(() => migrateRoomState(JSON.stringify(bad))).toThrow('ROOM_UNAVAILABLE');
    await runInDurableObject(f.room.stub, (_room, ctx) =>
      ctx.storage.sql.exec('UPDATE room_record SET state = ?', JSON.stringify(bad)),
    );
    await evictDurableObject(f.room.stub);
    f.host.peer.send(createRoomMessage('requestSnapshot', { requestId: requestId() }));
    expect(await result(f.host.peer)).toMatchObject({ type: 'error', code: 'ROOM_UNAVAILABLE' });
    await f.host.peer.closed();
    await runInDurableObject(f.room.stub, async (_room, ctx) => {
      expect(new RoomRepository(ctx.storage).read()).toBeNull();
      expect(ctx.storage.sql.exec('SELECT state FROM room_record').one().state).toBeNull();
      expect(await ctx.storage.getAlarm()).toBeNull();
    });
  });

it('pending seating, sealed order, host lease and duplicate receipt survive eviction and credential resume', async () => {
  const f = await allJudgesRoom();
  await f.ordering();
  const order = await f.order([...f.initial.effectiveRoster].reverse());
  await f.send(f.host.peer, order);
  const joined = await f.room.stub.join(
    createRoomMessage('join', { requestId: requestId(), profile, handshake }),
  );
  expect(joined.ok).toBe(true);
  await runInDurableObject(f.room.stub, async (room, ctx) => {
    const socket = ctx.getWebSockets().find((s) => {
      const info = attachment(s);
      return info?.kind === 'authenticated' && info.playerId === f.room.credential.playerId;
    })!;
    await room.webSocketClose(socket);
  });
  const before = await f.read();
  expect(before.game!.hostDisconnectedAt).not.toBeNull();
  expect(before.game!.pendingRoster).toHaveLength(4);
  await evictDurableObject(f.room.stub);
  expect(await f.read()).toEqual(before);
  await runInDurableObject(f.room.stub, async (room, ctx) => {
    await room.alarm();
    expect(new RoomRepository(ctx.storage).read()).toEqual(before);
    expect(await ctx.storage.getAlarm()).toBe(before.game!.hostDisconnectedAt! + 90000);
  });
  const resumed = await authenticated(f.room.code, f.room.credential);
  expect(resumed.snapshot.private.ownOrder).toEqual(order.order);
  const ready = await f.read();
  resumed.peer.send(order);
  expect(await result(resumed.peer)).toMatchObject({ type: 'ack', outcome: 'duplicate' });
  expect(await f.read()).toEqual(ready);
  expect(ready.game!.round).toEqual(before.game!.round);
  expect(ready.game!.personCounts).toEqual(before.game!.personCounts);
  expect(ready.game!.history).toEqual(before.game!.history);
});

it('unrecognized attachment versions grant no private view and are scrubbed on close', async () => {
  const f = await allJudgesRoom();
  await runInDurableObject(f.room.stub, async (room, ctx) => {
    const socket = ctx.getWebSockets().find((s) => {
      const info = attachment(s);
      return info?.kind === 'authenticated' && info.playerId === f.room.credential.playerId;
    })!;
    socket.serializeAttachment({
      formatVersion: 99,
      kind: 'authenticated',
      socketId: 'bad_metadata',
      resumeToken: 'PRIVATE_MARKER',
    });
    await room.webSocketMessage(
      socket,
      JSON.stringify(createRoomMessage('requestSnapshot', { requestId: requestId() })),
    );
    expect(attachment(socket)).toEqual({
      formatVersion: 1,
      kind: 'closed',
      socketId: 'invalid_attachment',
    });
    expect(JSON.stringify(socket.deserializeAttachment())).not.toContain('PRIVATE_MARKER');
  });
  expect(await f.host.peer.closed()).toBe(4401);
});

it('a failed durable migration closes transiently without an ACK or credential revocation and can resume after storage recovers', async () => {
  const f = await roomInPhase(false, 'answers');
  await f.snapshot(f.host.peer);
  const before = await f.read();
  const legacy = await runInDurableObject(f.room.stub, (_room, ctx) => {
    const raw = JSON.parse(
      ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
    );
    delete raw.game.round.answerReady;
    const legacy = JSON.stringify(raw);
    ctx.storage.sql.exec('UPDATE room_record SET state = ?', legacy);
    ctx.storage.sql.exec(
      "CREATE TRIGGER fail_migration BEFORE INSERT ON room_record BEGIN SELECT RAISE(ABORT, 'PRIVATE_STORAGE_MARKER'); END",
    );
    return legacy;
  });
  const start = f.host.peer.frames.length;
  f.host.peer.send(createRoomMessage('requestSnapshot', { requestId: requestId() }));
  expect(await f.host.peer.closed()).toBe(1011);
  expect(f.host.peer.frames.slice(start)).toEqual([]);
  await runInDurableObject(f.room.stub, (_room, ctx) => {
    expect(ctx.storage.sql.exec('SELECT state FROM room_record').one().state).toBe(legacy);
    ctx.storage.sql.exec('DROP TRIGGER fail_migration');
  });
  const resumed = await authenticated(f.room.code, f.room.credential),
    after = await f.read();
  expect(resumed.snapshot.public.roundId).toBe(before.game!.round!.id);
  expect(after.game!.round).toEqual(before.game!.round);
  expect(after.game!.history).toEqual(before.game!.history);
  expect(after.game!.personCounts).toEqual(before.game!.personCounts);
});
