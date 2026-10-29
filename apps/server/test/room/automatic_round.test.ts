import { runInDurableObject, evictDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { allJudgesRoom } from './all_judges_helpers';
import { cleanupPeers } from './socket_helpers';
import { automaticRoundId, scheduleAutomaticRound } from '../../src/room/automatic_round';
import { attachment } from '../../src/room/sockets';
import { RoomRepository } from '../../src/room/repository';

afterEach(cleanupPeers);
it('skips readiness and reveals at a persistent 500 ms cadence, preserving personal verdicts', async () => {
  const f = await allJudgesRoom(3, true, true, true);
  for (const member of f.members) await f.send(member.peer, await f.command('acknowledgeNumber'));
  expect((await f.read()).phase).toBe('answers');
  async function fire() {
    await runInDurableObject(f.room.stub, async (room, ctx) => {
      ctx.storage.sql.exec("UPDATE deadlines SET due = ? WHERE kind = 'game'", Date.now() - 1);
      await room.alarm();
    });
  }
  await fire();
  expect((await f.read()).phase).toBe('ordering');
  const round = (await f.read()).game!.round!;
  const truth = [...round.numbers].sort((a, b) => a.number - b.number).map((n) => n.playerId);
  for (let i = 0; i < f.members.length; i++)
    await f.send(f.members[i]!.peer, await f.order(i === 0 ? truth : [...truth].reverse()));
  expect((await f.read()).phase).toBe('revealing');
  // The alarm uses the connected host if the reader loses their connection.
  await runInDurableObject(f.room.stub, async (room, ctx) => {
    const reader = new RoomRepository(ctx.storage).read()!.game!.readerId;
    const socket = ctx.getWebSockets().find((s) => {
      const info = attachment(s);
      return info?.kind === 'authenticated' && info.playerId === reader;
    })!;
    await room.webSocketClose(socket);
  });
  await f.members[1]!.peer.closed();
  await evictDurableObject(f.room.stub);
  for (let cursor = 0; cursor < f.members.length; cursor++) {
    await runInDurableObject(f.room.stub, async (room, ctx) => {
      const repository = new RoomRepository(ctx.storage),
        state = repository.read()!;
      const deadline = ctx.storage.sql
        .exec<{ id: string; due: number }>("SELECT id, due FROM deadlines WHERE kind = 'game'")
        .one();
      scheduleAutomaticRound(ctx.storage.sql, state, Date.now() + 100);
      expect(
        ctx.storage.sql
          .exec<{ due: number }>('SELECT due FROM deadlines WHERE id = ?', deadline.id)
          .one().due,
      ).toBe(deadline.due);
      // Early/duplicate alarms do not expose another number.
      await room.alarm();
      expect(repository.read()!.game!.round!.revealCursor).toBe(cursor);
    });
    const before = Date.now();
    await fire();
    expect((await f.read()).game!.round!.revealCursor).toBe(cursor + 1);
    if (cursor < f.members.length - 1)
      await runInDurableObject(f.room.stub, (_room, ctx) => {
        expect(
          ctx.storage.sql
            .exec<{ due: number }>("SELECT due FROM deadlines WHERE kind = 'game'")
            .one().due,
        ).toBeGreaterThanOrEqual(before + 500);
      });
  }
  const judged = await f.read();
  expect(judged.phase).toBe('judged');
  expect(automaticRoundId(judged)).toBeNull();
  const correct = await f.snapshot(f.members[0]!.peer),
    wrong = await f.snapshot(f.members[2]!.peer);
  expect(correct.private.ownResult?.errors).toBe(0);
  expect(wrong.private.ownResult?.errors).toBe(2);
  expect('result' in correct.public).toBe(false);
});
