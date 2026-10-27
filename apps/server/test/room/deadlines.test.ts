import { runInDurableObject, runDurableObjectAlarm, evictDurableObject } from 'cloudflare:test';
import { afterEach, describe, expect, it } from 'vitest';
import { putDeadline, removeDeadline, dueDeadlines, nextDeadline } from '../../src/room/deadlines';
import { attachment } from '../../src/room/sockets';
import { socketRoom, connect, auth, cleanupPeers } from './socket_helpers';
afterEach(cleanupPeers);
describe('persisted shared deadlines', () => {
  it('selects the earliest deadline with inclusive expiry, removes just the handled entry', async () => {
    const room = await socketRoom();
    await runInDurableObject(room.stub, (_room, ctx) => {
      const sql = ctx.storage.sql;
      expect(nextDeadline(sql, null)).toBeNull();
      putDeadline(sql, { id: 'later', kind: 'auth', due: 20 });
      putDeadline(sql, { id: 'first', kind: 'auth', due: 10 });
      expect(nextDeadline(sql, 15)).toBe(10);
      expect(dueDeadlines(sql, 9)).toEqual([]);
      expect(dueDeadlines(sql, 10).map((d) => d.id)).toEqual(['first']);
      removeDeadline(sql, 'first');
      expect(nextDeadline(sql, 15)).toBe(15);
      removeDeadline(sql, 'later');
      expect(nextDeadline(sql, 15)).toBe(15);
    });
  });
  it('persists an auth deadline, survives hibernation, and closes an unauthenticated socket on alarm', async () => {
    const room = await socketRoom(),
      peer = await connect(room.code);
    await evictDurableObject(room.stub);
    await runInDurableObject(room.stub, (_room, ctx) => {
      const info = attachment(ctx.getWebSockets()[0]!);
      if (info?.kind !== 'pending') throw Error('pending');
      ctx.getWebSockets()[0]!.serializeAttachment({ ...info, authDeadline: Date.now() - 1 });
      ctx.storage.sql.exec('UPDATE deadlines SET due = ?', Date.now() - 1);
    });
    expect(await runDurableObjectAlarm(room.stub)).toBe(true);
    expect(await peer.next()).toMatchObject({ type: 'error', code: 'CREDENTIAL_INVALID' });
    expect(await peer.closed()).toBe(4408);
    expect(peer.frames.some((raw) => raw.includes('snapshot'))).toBe(false);
    await runInDurableObject(room.stub, async (_room, ctx) => {
      expect(dueDeadlines(ctx.storage.sql, Number.MAX_SAFE_INTEGER)).toEqual([]);
      expect(await ctx.storage.getAlarm()).toBeGreaterThan(Date.now() + 60_000);
    });
  });
  it('rejects a late auth frame even if the alarm has not fired, without consuming a generation', async () => {
    const room = await socketRoom(),
      peer = await connect(room.code);
    await runInDurableObject(room.stub, (_room, ctx) => {
      const socket = ctx.getWebSockets()[0]!,
        info = attachment(socket);
      if (info?.kind !== 'pending') throw Error('pending');
      socket.serializeAttachment({ ...info, authDeadline: Date.now() - 1 });
    });
    peer.send(auth(room.credential));
    expect((await peer.next()).type).toBe('error');
    expect(await peer.closed()).toBe(4408);
    await runInDurableObject(room.stub, (_room, ctx) => {
      const state = JSON.parse(
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
      );
      expect(state.members[0].generation).toBe(0);
    });
  });
  it('removes successful auth deadlines and schedules the persisted room expiry without heartbeat timers', async () => {
    const room = await socketRoom(),
      peer = await connect(room.code);
    peer.send(auth(room.credential));
    await peer.next();
    await peer.next();
    await runInDurableObject(room.stub, async (_room, ctx) => {
      expect(dueDeadlines(ctx.storage.sql, Number.MAX_SAFE_INTEGER)).toEqual([]);
      expect(await ctx.storage.getAlarm()).toBeGreaterThan(Date.now() + 60_000);
    });
  });
});
