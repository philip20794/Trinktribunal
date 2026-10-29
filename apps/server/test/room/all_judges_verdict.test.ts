import { evictDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { createRoomMessage } from '../../src/protocol/room_message';
import { cleanupPeers, authenticated } from './socket_helpers';
import { allJudgesRoom, result } from './all_judges_helpers';

afterEach(cleanupPeers);

it('four private verdicts 2/4/0/0 share only the authorized prefix, persist over eviction, and rotate readers only on cases', async () => {
  const f = await allJudgesRoom(4);
  await f.ordering();
  const { round } = f.initial;
  const truth = [...round!.numbers].sort((a, b) => a.number - b.number).map((n) => n.playerId),
    [a, b, c, d] = truth as [
      (typeof truth)[number],
      (typeof truth)[number],
      (typeof truth)[number],
      (typeof truth)[number],
    ];
  const proposals = [
    { playerId: a, order: [b, a, c, d], errors: 2 },
    { playerId: b, order: [b, a, d, c], errors: 4 },
    { playerId: c, order: [a, b, c, d], errors: 0 },
    { playerId: d, order: [a, b, c, d], errors: 0 },
  ];
  for (const entry of proposals)
    await f.send(
      f.members.find((m) => m.credential.playerId === entry.playerId)!.peer,
      await f.order(entry.order),
    );
  const reveal = async (cursor: number) => {
    const state = await f.read();
    return createRoomMessage('revealNext', {
      actionId: f.action(),
      expectedRevision: state.revision,
      gameId: state.game!.gameId!,
      roundId: state.game!.round!.id,
      expectedCursor: cursor,
    });
  };
  const history = f.initial.history;
  for (let cursor = 0; cursor <= 4; cursor++) {
    const current = await f.read();
    expect(current.game!.round!.revealCursor).toBe(cursor);
    expect(current.game!.readerId).toBe(f.initial.readerId);
    for (const member of f.members) {
      const view = await f.snapshot(member.peer),
        personal = proposals.find((p) => p.playerId === member.credential.playerId)!;
      expect(view.public.revealed).toEqual(
        f.initial.effectiveRoster.slice(0, cursor).map((playerId) => ({
          playerId,
          number: round!.numbers.find((n) => n.playerId === playerId)!.number,
        })),
      );
      for (const field of ['result', 'judgeOrder', 'orders', 'results', 'sipCounts', 'truth'])
        expect(view.public).not.toHaveProperty(field);
      expect(view.private.ownOrder).toEqual(personal.order);
      expect(view.private.ownNumber).toBe(
        round!.numbers.find((n) => n.playerId === member.credential.playerId)!.number,
      );
      if (cursor < 4) expect(view.private.ownResult).toBeUndefined();
      else
        expect(view.private.ownResult).toEqual({ errors: personal.errors, sips: personal.errors });
      expect(Object.keys(view.private).sort()).toEqual(
        cursor < 4 ? ['ownNumber', 'ownOrder'] : ['ownNumber', 'ownOrder', 'ownResult'],
      );
    }
    if (cursor < 4) {
      const command = await reveal(cursor);
      const reader = f.members.find((m) => m.credential.playerId === f.initial.readerId)!;
      const unrelated = f.members.find(
        (m) =>
          m.credential.playerId !== f.initial.readerId &&
          m.credential.playerId !== f.host.snapshot.you,
      )!;
      unrelated.peer.send(command);
      expect(await result(unrelated.peer)).toMatchObject({
        type: 'error',
        code: 'UNAUTHORIZED_ACTION',
      });
      await f.send(reader.peer, command);
      if (cursor === 1) await evictDurableObject(f.room.stub);
      expect(await f.send(reader.peer, command)).toMatchObject({ outcome: 'duplicate' });
      f.host.peer.send(await reveal(cursor));
      expect(await result(f.host.peer)).toMatchObject({
        type: 'error',
        code: cursor === 3 ? 'INVALID_PHASE' : 'STALE_REVISION',
      });
    }
  }
  const judged = await f.read();
  expect(judged.game!.history).toEqual(history);
  expect(judged.game!.personCounts).toEqual(f.initial.personCounts);
  const reconnecting = f.members[2]!;
  Object.assign(reconnecting, await authenticated(f.room.code, reconnecting.credential));
  expect(reconnecting.snapshot.private.ownResult).toEqual({
    errors: proposals.find((p) => p.playerId === reconnecting.credential.playerId)!.errors,
    sips: proposals.find((p) => p.playerId === reconnecting.credential.playerId)!.errors,
  });
  const complete = async (without = false) => {
    const state = await f.read();
    return createRoomMessage(without ? 'completeWithoutVerdict' : 'completeCase', {
      actionId: f.action(),
      expectedRevision: state.revision,
      gameId: state.game!.gameId!,
      roundId: state.game!.round!.id,
      ...(without ? { confirmed: true as const } : {}),
    });
  };
  const command = await complete();
  await f.send(f.host.peer, command);
  await f.send(f.host.peer, command);
  expect((await f.read()).game!.readerId).toBe(f.initial.effectiveRoster[1]);
  for (let count = 1; count <= 2; count++) {
    const boundary = await f.read(),
      reader = boundary.game!.readerId;
    expect(boundary.game!.phase).toBe('rule_event');
    expect(boundary.game!.judgeId).toBeNull();
    for (const member of f.members) {
      const view = await f.snapshot(member.peer);
      expect(view.private).toEqual({});
      expect(view.public.result).toBeUndefined();
    }
    const rule = createRoomMessage('continueRule', {
      actionId: f.action(),
      expectedRevision: boundary.revision,
      gameId: boundary.game!.gameId!,
      afterCase: count,
    });
    await f.send(f.host.peer, rule);
    await f.send(f.host.peer, rule);
    expect((await f.read()).game!.readerId).toBe(reader);
    if (count === 1) {
      const skip = await complete(true);
      await f.send(f.host.peer, skip);
      await f.send(f.host.peer, skip);
      const skipped = (await f.read()).game!;
      expect(skipped.readerId).toBe(f.initial.effectiveRoster[2]);
      expect(skipped.lastCompletion).toMatchObject({
        kind: 'completed_without_verdict',
        score: null,
      });
    } else {
      await f.ordering();
      const last = (await f.read()).game!.round!,
        order = [...last.numbers].sort((a, b) => a.number - b.number).map((n) => n.playerId);
      for (const member of f.members) await f.send(member.peer, await f.order(order));
      for (let cursor = 0; cursor < 4; cursor++) await f.send(f.host.peer, await reveal(cursor));
      for (const member of f.members)
        expect((await f.snapshot(member.peer)).private.ownResult).toEqual({ errors: 0, sips: 0 });
      const finish = await complete();
      await f.send(f.host.peer, finish);
      await f.send(f.host.peer, finish);
    }
  }
  const end = (await f.read()).game!;
  expect(end.phase).toBe('finished');
  expect(end.completedCases).toBe(3);
  expect(end.completedRoundIds).toHaveLength(3);
  expect(end.readerId).toBe(f.initial.effectiveRoster[3]);
  expect(end.judgeId).toBeNull();
  expect(end.round).toBeNull();
  expect(end.drawnRuleIds).toHaveLength(2);
});
