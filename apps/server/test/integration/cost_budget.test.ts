import { runInDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { createRoomMessage } from '../../src/protocol/room_message';
import { enableLocalMetrics, localMetrics, roomSql } from '../../src/room/metrics';
import { allJudgesRoom, result } from '../room/all_judges_helpers';
import {
  authenticated,
  cleanupPeers,
  profile,
  requestId,
  socketRoom,
  framesFromServerMessage,
} from '../room/socket_helpers';

afterEach(cleanupPeers);
declare const __TT_ENFORCE_LOCAL_BUDGET__: boolean;

it('local SQL counters preserve native lazy cursor APIs and collect no query text', async () => {
  const f = await socketRoom();
  await runInDurableObject(f.stub, (_room, ctx) => {
    expect(localMetrics(ctx.storage)).toBeNull();
    ctx.storage.sql.exec('CREATE TABLE metric_sample (value INTEGER)');
    for (let i = 0; i < 5; i++) ctx.storage.sql.exec('INSERT INTO metric_sample VALUES (?)', i);
    enableLocalMetrics(ctx.storage);
    const native = ctx.storage.sql.exec('SELECT value FROM metric_sample');
    const expected = native.toArray();
    const lookup = ctx.storage.sql.exec('SELECT value FROM metric_sample WHERE value = 0');
    lookup.one();
    const sql = roomSql(ctx.storage);
    expect(sql.exec('SELECT value FROM metric_sample').toArray()).toEqual(expected);
    expect([...sql.exec('SELECT value FROM metric_sample')]).toEqual(expected);
    expect([...sql.exec('SELECT value FROM metric_sample').raw()]).toEqual(
      expected.map((r) => [r.value]),
    );
    const next = sql.exec('SELECT value FROM metric_sample');
    while (!next.next().done) {
      /* Consume through the native next API. */
    }
    expect(sql.exec('SELECT value FROM metric_sample WHERE value = 0').one()).toEqual({ value: 0 });
    const insert = sql.exec('INSERT INTO metric_sample VALUES (5)');
    expect(insert.rowsWritten).toBe(1);
    expect(() => sql.exec('SELECT PRIVATE_QUERY_MARKER FROM missing_table')).toThrow();
    const metrics = localMetrics(ctx.storage)!;
    expect(metrics.sqlCalls).toBe(7);
    expect(metrics.sqlRowsRead).toBe(native.rowsRead * 4 + lookup.rowsRead);
    expect(metrics.sqlRowsWritten).toBe(1);
    expect(metrics.sqlFailures).toBe(1);
    expect(Object.values(metrics).every((value) => typeof value === 'number')).toBe(true);
    expect(JSON.stringify(metrics)).not.toContain('PRIVATE_QUERY_MARKER');
    metrics.sqlCalls = 0;
    expect(localMetrics(ctx.storage)!.sqlCalls).toBe(7);
  });
});

it('idle and repeated unchanged alarms produce no room or alarm writes; snapshots only spend rate tokens', async () => {
  const f = await allJudgesRoom(3, true, false);
  await runInDurableObject(f.room.stub, (_room, ctx) =>
    enableLocalMetrics(ctx.storage, ctx.getWebSockets()),
  );
  // No application frame is sent during the idle interval.
  await new Promise((resolve) => setTimeout(resolve, 30));
  await runInDurableObject(f.room.stub, async (room, ctx) => {
    expect(localMetrics(ctx.storage)!.sqlCalls).toBe(0);
    await room.alarm();
    await room.alarm();
    const m = localMetrics(ctx.storage)!;
    expect(m.roomWrites).toBe(0);
    expect(m.alarmWrites).toBe(0);
    expect(m.sqlRowsWritten).toBe(0);
    expect(m.alarmInvocations).toBe(2);
  });
  // Await this request's server handler, not an already queued same-revision snapshot.
  const frames = await framesFromServerMessage(
    f.room.stub,
    f.host.identity.playerId,
    createRoomMessage('requestSnapshot', { requestId: requestId() }),
  );
  expect(frames.some((frame) => JSON.parse(frame).type === 'snapshot')).toBe(true);
  const metrics = await runInDurableObject(f.room.stub, (_room, ctx) => localMetrics(ctx.storage)!);
  expect(metrics.roomWrites).toBe(0);
  expect(metrics.alarmWrites).toBe(0);
  expect(metrics.sqlRowsWritten).toBeGreaterThan(0);
  expect(metrics.maxFrameBytes).toBeLessThanOrEqual(16384);
});

it('reconnect overhead is measurable separately and preserves the existing identity', async (context) => {
  const f = await allJudgesRoom(3, true, true);
  const before = await f.read();
  await runInDurableObject(f.room.stub, (_room, ctx) =>
    enableLocalMetrics(ctx.storage, ctx.getWebSockets()),
  );
  const resumed = await authenticated(f.room.code, f.members[1]!.credential);
  expect(resumed.identity.playerId).toBe(f.members[1]!.credential.playerId);
  expect((await f.read()).game!.round).toEqual(before.game!.round);
  const m = await runInDurableObject(f.room.stub, (_room, ctx) => localMetrics(ctx.storage)!);
  expect(m.authentications).toBe(1);
  expect(m.reconnects).toBe(1);
  expect(m.roomWrites).toBeLessThanOrEqual(3);
  expect(m.sqlRowsWritten).toBeGreaterThan(0);
  expect(m.maxFrameBytes).toBeLessThanOrEqual(16384);
  await context.annotate(
    'TT_LOCAL_METRICS ' + JSON.stringify({ scenario: 'single-reconnect', metrics: m }),
  );
});

it('ten concurrent eight-person rooms stay isolated and acknowledge below the local p95 budget', async (context) => {
  const fixtures = await Promise.all(
    Array.from({ length: 10 }, () => allJudgesRoom(8, true, false)),
  );
  const samples: number[] = [];
  await Promise.all(
    fixtures.map(async (f, index) => {
      await runInDurableObject(f.room.stub, (_room, ctx) =>
        enableLocalMetrics(ctx.storage, ctx.getWebSockets()),
      );
      for (let step = 0; step < 10; step++) {
        const state = await f.read();
        const command = createRoomMessage('editOwnProfile', {
          actionId: f.action(),
          expectedRevision: state.revision,
          profile: { ...profile, name: `Room ${index} change ${step}` },
        });
        const start = performance.now();
        f.host.peer.send(command);
        expect(await result(f.host.peer)).toMatchObject({
          type: 'ack',
          actionId: command.actionId,
        });
        samples.push(performance.now() - start);
        await runInDurableObject(f.room.stub, (_room, ctx) =>
          ctx.storage.sql.exec('UPDATE action_limits SET updated = ?', Date.now() - 1000).toArray(),
        );
      }
      const state = await f.read();
      expect(state.members.find((m) => m.playerId === state.hostId)!.profile!.name).toBe(
        `Room ${index} change 9`,
      );
      expect(state.members).toHaveLength(8);
      const metrics = await runInDurableObject(f.room.stub, (_room, ctx) =>
        localMetrics(ctx.storage)!,
      );
      expect(metrics.actions).toBe(10);
      expect(metrics.acknowledgements).toBe(10);
      expect(metrics.errors).toBe(0);
      expect(metrics.maxFrameBytes).toBeLessThanOrEqual(16384);
    }),
  );
  samples.sort((a, b) => a - b);
  const p95 = samples[Math.ceil(samples.length * 0.95) - 1]!;
  await context.annotate(
    'TT_LOCAL_METRICS ' +
      JSON.stringify({
        scenario: 'ten-parallel-eight-person-rooms',
        samples: samples.length,
        p95ActionToAckMs: p95,
        maxActionToAckMs: samples.at(-1),
      }),
  );
  expect(Number.isFinite(p95)).toBe(true);
  // The reproducible load command runs this budget without competing test files.
  if (__TT_ENFORCE_LOCAL_BUDGET__) expect(p95).toBeLessThan(250);
}, 120000);
