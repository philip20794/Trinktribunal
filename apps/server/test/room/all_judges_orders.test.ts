import { evictDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { createRoomMessage, RoomIds } from '../../src/protocol/room_message';
import { cleanupPeers, authenticated } from './socket_helpers';
import { allJudgesRoom, result } from './all_judges_helpers';

afterEach(cleanupPeers);

it('each participant including host/reader gets one number and confirms only their own full immutable order', async () => {
  const f = await allJudgesRoom(),
    { initial, members, host, read, snapshot, send, order, action } = f;
  expect(initial.judgeId).toBeNull();
  expect(initial.readerId).toBe(initial.effectiveRoster[0]);
  expect(initial.readerId).not.toBe(host.snapshot.you);
  for (const member of members) {
    const view = await snapshot(member.peer);
    expect(view.private.ownNumber).toBe(
      initial.round!.numbers.find((n) => n.playerId === member.credential.playerId)!.number,
    );
    expect(view.private.ownOrder).toBeUndefined();
    expect(view.public.revealed).toEqual([]);
  }
  for (const member of members) await send(member.peer, await f.command('acknowledgeNumber'));
  for (const member of members) await send(member.peer, await f.command('readyForOrdering'));
  const reader = members.find((m) => m.credential.playerId === initial.readerId)!;
  const unrelated = members.find(
    (m) =>
      m.credential.playerId !== initial.readerId && m.credential.playerId !== host.snapshot.you,
  )!;
  unrelated.peer.send(await f.command('beginOrdering'));
  expect(await result(unrelated.peer)).toMatchObject({
    type: 'error',
    code: 'UNAUTHORIZED_ACTION',
  });
  await send(reader.peer, await f.command('beginOrdering'));
  const ids = initial.effectiveRoster;
  host.peer.send(await order(ids.slice(0, 2)));
  expect(await result(host.peer)).toMatchObject({ type: 'error', code: 'INVALID_PERMUTATION' });
  host.peer.send(await order([ids[0]!, ids[1]!, RoomIds.player('foreign')]));
  expect(await result(host.peer)).toMatchObject({ type: 'error', code: 'INVALID_PERMUTATION' });
  expect((await read()).game!.round!.orders).toEqual([]);
  const confirmed = [];
  for (let index = 0; index < members.length; index++) {
    const member = members[index]!,
      proposed = [...ids.slice(index), ...ids.slice(0, index)],
      command = await order(proposed);
    const ack = await send(member.peer, command);
    expect(Object.keys(ack).sort()).toEqual([
      'actionId',
      'outcome',
      'protocolVersion',
      'requestId',
      'revision',
      'type',
    ]);
    confirmed.push({ playerId: member.credential.playerId, order: proposed });
    const committed = await read();
    expect(committed.game!.phase).toBe(index === members.length - 1 ? 'revealing' : 'ordering');
    expect(committed.game!.round!.orders).toEqual(confirmed);
    for (const viewer of members) {
      const view = await snapshot(viewer.peer);
      expect(view.private.ownOrder).toEqual(
        confirmed.find((o) => o.playerId === viewer.credential.playerId)?.order,
      );
      expect(view.public).not.toHaveProperty('judgeOrder');
      expect(view.public).not.toHaveProperty('orders');
      expect(view.public).not.toHaveProperty('result');
      expect(view.public.revealed).toEqual([]);
      expect(
        view.public.players
          .filter((p) => p.orderSubmitted)
          .map((p) => p.playerId)
          .sort(),
      ).toEqual(confirmed.map((o) => o.playerId).sort());
    }
    await evictDurableObject(f.room.stub);
    expect(await send(member.peer, command)).toMatchObject({ outcome: 'duplicate' });
    expect(await read()).toEqual(committed);
    member.peer.send(await order([...proposed].reverse()));
    expect(await result(member.peer)).toMatchObject({ type: 'error', code: 'INVALID_PHASE' });
    if (index === 0) {
      host.peer.send(
        createRoomMessage('revealNext', {
          actionId: action(),
          expectedRevision: (await read()).revision,
          gameId: initial.gameId!,
          roundId: initial.round!.id,
          expectedCursor: 0,
        }),
      );
      expect(await result(host.peer)).toMatchObject({ type: 'error', code: 'INVALID_PHASE' });
    }
  }
  const resumed = await authenticated(f.room.code, reader.credential);
  expect(resumed.snapshot.private.ownOrder).toEqual(
    confirmed.find((o) => o.playerId === reader.credential.playerId)!.order,
  );
  expect((await read()).game!.round!.revealOrder).toEqual(ids);
});

it('host explicitly completes a case with missing orders once without inventing results', async () => {
  const f = await allJudgesRoom();
  await f.ordering();
  await f.send(f.members[1]!.peer, await f.order([...f.initial.effectiveRoster].reverse()));
  const before = await f.read(),
    command = createRoomMessage('completeWithoutVerdict', {
      actionId: f.action(),
      expectedRevision: before.revision,
      gameId: f.initial.gameId!,
      roundId: f.initial.round!.id,
      confirmed: true,
    });
  await f.send(f.host.peer, command);
  await f.send(f.host.peer, command);
  const state = (await f.read()).game!;
  expect(state.completedCases).toBe(1);
  expect(state.phase).toBe('rule_event');
  expect(state.lastCompletion).toMatchObject({ kind: 'completed_without_verdict', score: null });
  expect(state.readerId).toBe(f.initial.effectiveRoster[1]);
  for (const member of f.members) expect((await f.snapshot(member.peer)).private).toEqual({});
});
