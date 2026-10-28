import { runInDurableObject, runDurableObjectAlarm, evictDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { reconcileHost, nextHostDeadline } from '../../src/room/host_lifecycle';
import { RoomRepository, roomExpiry } from '../../src/room/repository';
import { immutable, type MutableGameState } from '../../src/domain/game_state';
import { lobbySnapshot } from '../../src/room/projection';
import { createRoomMessage, RoomIds } from '../../src/protocol/room_message';
import { attachment } from '../../src/room/sockets';
import { allJudgesRoom, result } from './all_judges_helpers';
import {
  authenticated,
  cleanupPeers,
  connect,
  socketRoom,
  profile,
  handshake,
  requestId,
} from './socket_helpers';

afterEach(cleanupPeers);
type Fixture = Awaited<ReturnType<typeof allJudgesRoom>>;
async function closeHost(f: Pick<Fixture, 'room' | 'host'>) {
  await runInDurableObject(f.room.stub, async (room, ctx) => {
    const socket = ctx.getWebSockets().find((s) => {
      const info = attachment(s);
      return info?.kind === 'authenticated' && info.playerId === f.host.snapshot.you;
    })!;
    await room.webSocketClose(socket);
  });
  await f.host.peer.closed();
}
async function due(f: Pick<Fixture, 'room'>) {
  await runInDurableObject(f.room.stub, (_room, ctx) => {
    const repository = new RoomRepository(ctx.storage),
      state = repository.read()!,
      game = structuredClone(state.game!) as MutableGameState;
    game.hostDisconnectedAt = Date.now() - 90001;
    state.game = immutable(game);
    repository.write(state);
  });
}

it('89/90/91 second boundaries transfer once by stable join order without changing the case or lifetime', async () => {
  const f = await allJudgesRoom(3, false),
    state = await f.read(),
    before = structuredClone(state),
    others = new Set(f.members.slice(1).map((m) => m.credential.playerId));
  expect(reconcileHost(state, others, 1000)).toBe(true);
  expect(nextHostDeadline(state)).toBe(91000);
  expect(reconcileHost(state, others, 90999)).toBe(false);
  expect(state.hostId).toBe(before.hostId);
  expect(reconcileHost(state, others, 91000)).toBe(true);
  expect(state.hostId).toBe(f.members[1]!.credential.playerId);
  expect(state.game!.hostRevision).toBe(1);
  expect(reconcileHost(state, others, 92000)).toBe(false);
  expect(reconcileHost(state, new Set(f.members.map((m) => m.credential.playerId)), 93000)).toBe(
    false,
  );
  expect(state.game!.round).toEqual(before.game!.round);
  expect(state.game!.judgeId).toBe(before.game!.judgeId);
  expect(state.game!.history).toEqual(before.game!.history);
  expect(state.game!.personCounts).toEqual(before.game!.personCounts);
  expect(roomExpiry(state)).toBe(roomExpiry(before));
});

for (const leaving of [false, true])
  it(`a lobby host ${leaving ? 'leave' : 'disconnect'} transfers without starting a game or drawing content`, async () => {
    const room = await socketRoom(),
      host = await authenticated(room.code, room.credential);
    const joined = await room.stub.join(
      createRoomMessage('join', { requestId: requestId(), profile, handshake }),
    );
    if (!joined.ok) throw new Error('JOIN');
    await authenticated(room.code, joined.message);
    const f = { room, host };
    if (leaving) {
      const left = await room.stub.leave(
        createRoomMessage('leaveHttp', {
          requestId: requestId(),
          actionId: RoomIds.action('leave_lobby'),
          resumeToken: room.credential.resumeToken,
          confirmed: true,
        }),
      );
      expect(left.ok).toBe(true);
    } else await closeHost(f);
    await due(f);
    await runDurableObjectAlarm(room.stub);
    const state = await runInDurableObject(room.stub, (_room, ctx) =>
      new RoomRepository(ctx.storage).read()!,
    );
    expect(state.hostId).toBe(joined.message.playerId);
    expect(state.phase).toBe('lobby');
    expect(state.game!.gameId).toBeNull();
    expect(state.game!.round).toBeNull();
    expect(state.game!.history).toEqual([]);
    expect(state.game!.judgeId).toBeNull();
  });

it('no candidate pauses once, schedules no past alarm, and restores the exact case on a later eligible connection', async () => {
  const f = await allJudgesRoom(),
    state = await f.read(),
    round = state.game!.round;
  reconcileHost(state, new Set(), 1000);
  reconcileHost(state, new Set(), 91000);
  expect(state.phase).toBe('paused');
  expect(state.game!.pausedFrom).toBe('numbers');
  expect(nextHostDeadline(state)).toBeNull();
  expect(reconcileHost(state, new Set(), 92000)).toBe(false);
  reconcileHost(state, new Set([f.members[2]!.credential.playerId]), 94000);
  expect(state.hostId).toBe(f.members[2]!.credential.playerId);
  expect(state.phase).toBe('numbers');
  expect(state.game!.round).toEqual(round);
  expect(state.game!.hostRevision).toBe(1);
});

it('real close persists the lease; reconnect within grace restores the same host and private number', async () => {
  const f = await allJudgesRoom(),
    before = await f.read();
  await closeHost(f);
  const lost = await f.read();
  expect(lost.game!.hostDisconnectedAt).not.toBeNull();
  await runInDurableObject(f.room.stub, async (_room, ctx) =>
    expect(await ctx.storage.getAlarm()).toBe(lost.game!.hostDisconnectedAt! + 90000),
  );
  const resumed = await authenticated(f.room.code, f.room.credential);
  expect(resumed.snapshot.public.hostId).toBe(before.hostId);
  expect(resumed.snapshot.public.hostRevision).toBe(0);
  expect((await f.read()).game!.hostDisconnectedAt).toBeNull();
  expect((await f.read()).lastDomainActivity).toBe(before.lastDomainActivity);
  expect((await f.read()).game!.round).toEqual(before.game!.round);
});

for (const alarm of [false, true])
  it(`${alarm ? 'alarm after eviction' : 'late authentication before alarm'} performs a due transfer and never lets the old host reclaim it`, async () => {
    const f = await allJudgesRoom(),
      before = await f.read();
    await closeHost(f);
    await due(f);
    if (alarm) {
      await evictDurableObject(f.room.stub);
      expect(await runDurableObjectAlarm(f.room.stub)).toBe(true);
    }
    const old = await authenticated(f.room.code, f.room.credential),
      current = await f.read();
    expect(current.hostId).toBe(f.members[1]!.credential.playerId);
    expect(old.snapshot.public.hostId).toBe(current.hostId);
    expect(current.game!.hostRevision).toBe(1);
    expect(current.game!.round).toEqual(before.game!.round);
    expect(current.lastDomainActivity).toBe(before.lastDomainActivity);
    old.peer.send(
      createRoomMessage('completeWithoutVerdict', {
        actionId: f.action(),
        expectedRevision: current.revision,
        gameId: current.game!.gameId!,
        roundId: current.game!.round!.id,
        confirmed: true,
      }),
    );
    expect(await result(old.peer)).toMatchObject({ type: 'error', code: 'UNAUTHORIZED_ACTION' });
    await f.send(
      f.members[1]!.peer,
      createRoomMessage('completeWithoutVerdict', {
        actionId: f.action(),
        expectedRevision: current.revision,
        gameId: current.game!.gameId!,
        roundId: current.game!.round!.id,
        confirmed: true,
      }),
    );
  });

it('auth deadline remains earlier than host deadline and removing it restores the host alarm', async () => {
  const f = await allJudgesRoom(),
    pending = await connect(f.room.code);
  await closeHost(f);
  await runInDurableObject(f.room.stub, async (room, ctx) => {
    const socket = ctx.getWebSockets().find((s) => attachment(s)?.kind === 'pending')!,
      info = attachment(socket);
    if (info?.kind !== 'pending') throw new Error('PENDING');
    expect(await ctx.storage.getAlarm()).toBe(info.authDeadline);
    await room.webSocketClose(socket);
    expect(await ctx.storage.getAlarm()).toBe(
      new RoomRepository(ctx.storage).read()!.game!.hostDisconnectedAt! + 90000,
    );
  });
  await pending.closed();
});

it('concurrent due socket events commit exactly one deterministic host revision', async () => {
  const f = await allJudgesRoom();
  await closeHost(f);
  await due(f);
  const views = await Promise.all(
    f.members.slice(1).map(async (member) => {
      member.peer.send(createRoomMessage('requestSnapshot', { requestId: requestId() }));
      for (let count = 0; count < 100; count++) {
        const frame = await member.peer.next();
        if (frame.type === 'snapshot' && frame.public.hostRevision === 1) return frame;
      }
      throw new Error('HOST_VIEW');
    }),
  );
  for (const view of views) expect(view.public.hostId).toBe(f.members[1]!.credential.playerId);
  expect((await f.read()).game!.hostRevision).toBe(1);
});

it('a normal reveal pause preserves the sealed public order and exact authorized prefix', async () => {
  const f = await allJudgesRoom(3, false);
  await f.ordering();
  const judge = f.members.find((m) => m.credential.playerId === f.initial.judgeId)!;
  await f.send(judge.peer, await f.order(f.initial.round!.recipients));
  const before = await f.read();
  await f.send(
    f.host.peer,
    createRoomMessage('revealNext', {
      actionId: f.action(),
      expectedRevision: before.revision,
      gameId: before.game!.gameId!,
      roundId: before.game!.round!.id,
      expectedCursor: 0,
    }),
  );
  const state = await f.read(),
    round = state.game!.round!;
  reconcileHost(state, new Set(), 1000);
  reconcileHost(state, new Set(), 91000);
  for (const member of f.members) {
    const view = lobbySnapshot(state, member.credential.playerId, new Set(), roomExpiry(state));
    expect(view.public.pausedFrom).toBe('revealing');
    expect(view.public.judgeOrder).toEqual(round.recipients);
    expect(view.public.revealed).toHaveLength(1);
    expect(view.public.result).toBeUndefined();
    expect(view.private.ownOrder).toEqual(
      member.credential.playerId === f.initial.judgeId ? round.recipients : undefined,
    );
  }
  reconcileHost(state, new Set([judge.credential.playerId]), 92000);
  expect(state.phase).toBe('revealing');
  expect(state.game!.round).toEqual(round);
});

it('host pause keeps personal verdicts private and preserves the completed phase', async () => {
  const f = await allJudgesRoom();
  await f.ordering();
  const order = f.initial.effectiveRoster;
  for (const member of f.members) await f.send(member.peer, await f.order(order));
  for (let cursor = 0; cursor < order.length; cursor++) {
    const state = await f.read();
    await f.send(
      f.host.peer,
      createRoomMessage('revealNext', {
        actionId: f.action(),
        expectedRevision: state.revision,
        gameId: state.game!.gameId!,
        roundId: state.game!.round!.id,
        expectedCursor: cursor,
      }),
    );
  }
  const state = await f.read(),
    score = state.game!.round!.score;
  if (score?.kind !== 'all_judges') throw new Error('PERSONAL_SCORE');
  reconcileHost(state, new Set(), 1000);
  reconcileHost(state, new Set(), 91000);
  for (const member of f.members) {
    const view = lobbySnapshot(state, member.credential.playerId, new Set(), roomExpiry(state));
    expect(view.public.pausedFrom).toBe('judged');
    expect(view.private.ownResult).toEqual(
      score.results.find((r) => r.playerId === member.credential.playerId) && {
        errors: score.results.find((r) => r.playerId === member.credential.playerId)!.errors,
        sips: score.results.find((r) => r.playerId === member.credential.playerId)!.sips,
      },
    );
    expect(view.public.result).toBeUndefined();
  }
});
