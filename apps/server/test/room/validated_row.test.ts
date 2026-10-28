import { runInDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { RoomRepository } from '../../src/room/repository';
import { purgeRoom } from '../../src/room/expiry';
import { isValidatedRow } from '../../src/room/validated_row';
import { allJudgesRoom } from './all_judges_helpers';
import { cleanupPeers } from './socket_helpers';

afterEach(cleanupPeers);

it('repeated validated reads return independent roots and keep the immutable core', async () => {
  const f = await allJudgesRoom();
  await runInDurableObject(f.room.stub, (_room, ctx) => {
    const repository = new RoomRepository(ctx.storage),
      before = repository.read()!;
    before.members[0]!.generation += 100;
    before.members[0]!.profile = { ...before.members[0]!.profile!, name: 'Uncommitted' };
    const next = repository.read()!;
    expect(next.members[0]!.generation).not.toBe(before.members[0]!.generation);
    expect(next.members[0]!.profile!.name).not.toBe('Uncommitted');
    expect(Object.isFrozen(next.game)).toBe(true);
    expect(next.game!.round).toEqual(before.game!.round);
  });
});

it('warm validation cannot hide SQL corruption with the same revision', async () => {
  const f = await allJudgesRoom();
  await runInDurableObject(f.room.stub, (_room, ctx) => {
    const repository = new RoomRepository(ctx.storage),
      state = repository.read()!;
    expect(repository.read()!.revision).toBe(state.revision);
    const corrupt = { ...state, formatVersion: 99 };
    ctx.storage.sql.exec('UPDATE room_record SET state = ?', JSON.stringify(corrupt));
    expect(repository.read()).toBeNull();
    expect(ctx.storage.sql.exec('SELECT state FROM room_record').one().state).toBeNull();
  });
});

it('an outer transaction rollback cannot turn a validated intermediate row into committed state', async () => {
  const f = await allJudgesRoom();
  await runInDurableObject(f.room.stub, (_room, ctx) => {
    const repository = new RoomRepository(ctx.storage),
      before = repository.read()!;
    expect(() =>
      ctx.storage.transactionSync(() => {
        const transient = repository.read()!;
        transient.revision++;
        repository.write(transient);
        expect(repository.read()!.revision).toBe(transient.revision);
        throw new Error('ROLLBACK');
      }),
    ).toThrow('ROLLBACK');
    expect(repository.read()).toEqual(before);
  });
});

it('validation is scoped to storage and purge removes its private raw bytes', async () => {
  const first = await allJudgesRoom(),
    second = await allJudgesRoom();
  const before = await first.read();
  await runInDurableObject(second.room.stub, (_room, ctx) => {
    const repository = new RoomRepository(ctx.storage);
    const own = repository.read()!;
    expect(own.roomId).not.toBe(before.roomId);
    const raw = ctx.storage.sql
      .exec<{ state: string }>('SELECT state FROM room_record')
      .one().state;
    expect(isValidatedRow(ctx.storage, raw)).toBe(true);
    purgeRoom(ctx.storage);
    expect(isValidatedRow(ctx.storage, raw)).toBe(false);
    expect(repository.read()).toBeNull();
  });
  expect(await first.read()).toEqual(before);
});
