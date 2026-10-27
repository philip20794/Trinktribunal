import { createHash } from 'node:crypto';
import { runInDurableObject, evictDurableObject, runDurableObjectAlarm } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { canonicalJson } from '../../../../packages/protocol/schema-validation.mjs';
import { createRoomMessage, RoomIds } from '../../src/protocol/room_message';
import { commitHistoryAction, expireHistory } from '../../src/room/history';
import { commitGameAction } from '../../src/room/actions';
import { RoomRepository } from '../../src/room/repository';
import type { HistoryEvent, RoomMessage } from '../../src/protocol/room_message.generated';
import { socketRoom, profile, handshake, requestId, auth } from './socket_helpers';

const hash = (value: unknown) => createHash('sha256').update(canonicalJson(value)).digest('hex');
async function setup() {
  const room = await socketRoom();
  const identity = await room.stub.authenticate(auth(room.credential));
  if (!identity.ok) throw new Error('AUTH');
  const owner = { playerId: room.credential.playerId, generation: identity.message.generation },
    connected = new Set([owner.playerId]);
  for (let i = 0; i < 2; i++) {
    const joined = await room.stub.join(
      createRoomMessage('join', { requestId: requestId(), profile, handshake }),
    );
    if (!joined.ok) throw new Error('JOIN');
    connected.add(joined.message.playerId);
  }
  const read = () =>
    runInDurableObject(room.stub, (_room, ctx) => new RoomRepository(ctx.storage).read()!);
  const send = (command: RoomMessage, now = Date.now()) =>
    runInDurableObject(room.stub, (_room, ctx) => {
      if (
        ![
          'historyBegin',
          'historyImport',
          'cancelHistoryImport',
          'historyPull',
          'historyReceipt',
        ].includes(command.type)
      )
        throw new Error('COMMAND');
      return commitHistoryAction(
        new RoomRepository(ctx.storage),
        owner,
        command as Parameters<typeof commitHistoryAction>[2],
        connected,
        now,
      );
    });
  return { room, owner, connected, read, send };
}
const event = (index: number, time = Date.now()): HistoryEvent => ({
  eventId: RoomIds.event(`history_${index}`),
  kind: 'question',
  contentId: '001-a',
  timestampUtc: new Date(time).toISOString(),
});
const offer = (events: HistoryEvent[]) => ({
  importId: 'import_one' as import('../../src/protocol/room_message.generated').ImportId,
  count: events.length,
  sha256: hash(events),
});
describe('private atomic room usage history', () => {
  it('rolls back the complete final-page transaction on actual SQLite failure', async () => {
    const { room, send, read } = await setup(),
      now = Date.now(),
      events = [event(1, now - 1000)],
      importOffer = offer(events);
    await send(
      createRoomMessage('historyBegin', { requestId: requestId(), offer: importOffer }),
      now,
    );
    const before = await read(),
      page = createRoomMessage('historyImport', {
        requestId: requestId(),
        importId: importOffer.importId,
        page: 0,
        events,
      });
    await runInDurableObject(room.stub, (_room, ctx) => {
      ctx.storage.sql.exec(
        "CREATE TRIGGER fail_history BEFORE INSERT ON room_record BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
      );
    });
    expect(await send(page, now)).toMatchObject({ ok: false, retryable: true });
    expect(await read()).toEqual(before);
    await runInDurableObject(room.stub, (_room, ctx) => {
      ctx.storage.sql.exec('DROP TRIGGER fail_history');
    });
    expect(await send(page, now)).toMatchObject({ ok: true, message: { status: 'committed' } });
    expect((await read()).game!.history).toEqual(events);
  });

  it('uses the actual room alarm to erase timed-out staging after eviction', async () => {
    const { room, send, read } = await setup(),
      now = Date.now(),
      importOffer = offer([event(1, now - 1000)]);
    await send(
      createRoomMessage('historyBegin', { requestId: requestId(), offer: importOffer }),
      now,
    );
    await runInDurableObject(room.stub, (_room, ctx) => {
      const repository = new RoomRepository(ctx.storage),
        state = repository.read()!;
      state.historyImport!.createdAt = Date.now() - 60001;
      repository.write(state);
    });
    const before = await read();
    await evictDurableObject(room.stub);
    await runDurableObjectAlarm(room.stub);
    const after = await read();
    expect(after.historyImport!.status).toBe('cancelled');
    expect(after.historyOffer).toBeUndefined();
    expect(after.lastDomainActivity).toBe(before.lastDomainActivity);
  });
  it('stages pages without influencing counters, commits once, and replays after eviction', async () => {
    const { room, read, send } = await setup(),
      now = Date.now(),
      events = [event(1, now - 1000), event(2, now - 500)],
      importOffer = offer(events);
    expect(
      await send(
        createRoomMessage('historyBegin', { requestId: requestId(), offer: importOffer }),
        now,
      ),
    ).toMatchObject({ ok: true, message: { status: 'receiving' } });
    const before = await read();
    const page0 = createRoomMessage('historyImport', {
      requestId: requestId(),
      importId: importOffer.importId,
      page: 0,
      events: events.slice(0, 1),
    });
    expect(await send(page0, now)).toMatchObject({
      ok: true,
      message: { status: 'receiving', receivedEvents: 1 },
    });
    const staged = await read();
    expect(staged.game).toBeUndefined();
    expect(staged.revision).toBe(before.revision);
    expect(staged.lastDomainActivity).toBe(before.lastDomainActivity);
    expect(await send(page0, now)).toMatchObject({ ok: true, message: { receivedEvents: 1 } });
    expect(await read()).toEqual(staged);
    const page1 = createRoomMessage('historyImport', {
      requestId: requestId(),
      importId: importOffer.importId,
      page: 1,
      events: events.slice(1),
    });
    expect(await send(page1, now)).toMatchObject({
      ok: true,
      message: { status: 'committed', receivedEvents: 2, sha256: importOffer.sha256 },
    });
    const committed = await read();
    expect(committed.game!.history).toEqual(events);
    expect(committed.game!.personCounts.every((entry) => entry.count === 0)).toBe(true);
    expect(committed.historyOffer).toBeUndefined();
    expect(committed.historyImport!.pages).toEqual([]);
    await evictDurableObject(room.stub);
    expect(await send(page1, now)).toMatchObject({ ok: true, message: { status: 'committed' } });
    expect(await read()).toEqual(committed);
    expect(
      await send({ ...page1, events: [{ ...events[1]!, contentId: '001-b' }] }, now),
    ).toMatchObject({ ok: false, code: 'ACTION_ID_CONFLICT' });
    expect(await read()).toEqual(committed);
  });

  it('rejects missing pages, invalid hashes and expired/future/unknown events without partial import', async () => {
    for (const invalid of ['hash', 'cutoff', 'future', 'unknown'] as const) {
      const { read, send } = await setup(),
        now = Date.now();
      let item = event(1, now - 1000);
      if (invalid === 'cutoff')
        item = { ...item, timestampUtc: new Date(now - 21600000).toISOString() };
      if (invalid === 'future') item = { ...item, timestampUtc: new Date(now + 1).toISOString() };
      if (invalid === 'unknown') item = { ...item, contentId: 'unknown' };
      const imported = offer([item]);
      if (invalid === 'hash') imported.sha256 = '0'.repeat(64);
      await send(
        createRoomMessage('historyBegin', { requestId: requestId(), offer: imported }),
        now,
      );
      const before = await read();
      for (const page of [1, 0]) {
        const command = {
          ...createRoomMessage('historyImport', {
            requestId: requestId(),
            importId: imported.importId,
            page,
            events: [event(99, now - 1000)],
          }),
          events: [item],
        };
        expect(await send(command, now)).toMatchObject({ ok: false, code: 'INVALID_MESSAGE' });
      }
      expect(await read()).toEqual(before);
    }
  });

  it('blocks start during staging, cancels on timeout without extending room lifetime', async () => {
    const { room, owner, connected, read, send } = await setup(),
      now = Date.now(),
      importOffer = offer([event(1, now - 1000), event(2, now - 500)]);
    await send(
      createRoomMessage('historyBegin', { requestId: requestId(), offer: importOffer }),
      now,
    );
    await send(
      createRoomMessage('historyImport', {
        requestId: requestId(),
        importId: importOffer.importId,
        page: 0,
        events: [event(1, now - 1000)],
      }),
      now,
    );
    const before = await read();
    const start = createRoomMessage('startGame', {
      actionId: RoomIds.action('start'),
      expectedRevision: before.revision,
    });
    expect(
      await runInDurableObject(room.stub, (_room, ctx) =>
        commitGameAction(new RoomRepository(ctx.storage), owner, start, connected),
      ),
    ).toMatchObject({ ok: false, code: 'INVALID_PHASE' });
    await runInDurableObject(room.stub, (_room, ctx) => {
      const repository = new RoomRepository(ctx.storage),
        state = repository.read()!;
      expect(expireHistory(state, now + 59999)).toBe(false);
      expect(expireHistory(state, now + 60000)).toBe(true);
      repository.write(state);
    });
    const after = await read();
    expect(after.historyImport).toMatchObject({ status: 'cancelled', pages: [] });
    expect(after.game).toBeUndefined();
    expect(after.historyOffer).toBeUndefined();
    expect(after.lastDomainActivity).toBe(before.lastDomainActivity);
  });

  it('allows an explicitly cancelled import and validates an empty import', async () => {
    const { read, send } = await setup(),
      now = Date.now(),
      importOffer = offer([event(1, now - 500)]);
    await send(
      createRoomMessage('historyBegin', { requestId: requestId(), offer: importOffer }),
      now,
    );
    expect(
      await send(
        createRoomMessage('cancelHistoryImport', {
          requestId: requestId(),
          importId: importOffer.importId,
        }),
        now,
      ),
    ).toMatchObject({ ok: true, message: { status: 'cancelled' } });
    const before = await read();
    expect(
      await send(
        createRoomMessage('cancelHistoryImport', {
          requestId: requestId(),
          importId: importOffer.importId,
        }),
        now,
      ),
    ).toMatchObject({ ok: true });
    expect(await read()).toEqual(before);
    const empty = { ...offer([]), importId: 'empty' as typeof importOffer.importId };
    expect(
      await send(createRoomMessage('historyBegin', { requestId: requestId(), offer: empty }), now),
    ).toMatchObject({ ok: true, message: { status: 'committed' } });
    expect((await read()).game!.history).toEqual([]);
  });

  it('exports only the original host own draw events, retains opaque cursor and receipts across eviction', async () => {
    const { room, owner, connected, read, send } = await setup();
    await runInDurableObject(room.stub, (_room, ctx) => {
      const repository = new RoomRepository(ctx.storage),
        state = repository.read()!;
      const command = createRoomMessage('startGame', {
        actionId: RoomIds.action('start'),
        expectedRevision: state.revision,
      });
      expect(commitGameAction(repository, owner, command, connected)).toMatchObject({ ok: true });
    });
    const before = await read(),
      pull = createRoomMessage('historyPull', { requestId: requestId(), cursor: null });
    const first = await send(pull);
    expect(first).toMatchObject({ ok: true, message: { type: 'historyEvents', hasMore: false } });
    if (!first.ok || first.message.type !== 'historyEvents') throw new Error('HISTORY');
    expect(first.message.events).toEqual(before.game!.history);
    await evictDurableObject(room.stub);
    expect(await send(pull)).toEqual(first);
    const other = [...connected].find((id) => id !== owner.playerId)!;
    const stolen = await runInDurableObject(room.stub, (_room, ctx) =>
      commitHistoryAction(
        new RoomRepository(ctx.storage),
        { playerId: other, generation: 0 },
        createRoomMessage('historyPull', {
          requestId: requestId(),
          cursor: first.message.type === 'historyEvents' ? first.message.cursor : null,
        }),
        connected,
      ),
    );
    expect(stolen).toMatchObject({ ok: false, code: 'UNAUTHORIZED_ACTION' });
    const receipt = createRoomMessage('historyReceipt', {
      requestId: requestId(),
      cursor: first.message.cursor,
    });
    expect(await send(receipt)).toMatchObject({ ok: true, message: { outcome: 'committed' } });
    expect(await send(receipt)).toMatchObject({ ok: true, message: { outcome: 'duplicate' } });
    const next = await send(
      createRoomMessage('historyPull', { requestId: requestId(), cursor: null }),
    );
    expect(next).toMatchObject({ ok: true, message: { events: [] } });
    expect((await read()).lastDomainActivity).toBe(before.lastDomainActivity);
  });
});
