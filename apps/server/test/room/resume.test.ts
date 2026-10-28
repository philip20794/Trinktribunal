import { evictDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { createRoomMessage } from '../../src/protocol/room_message';
import { roomInPhase } from './game_phase_helpers';
import { result } from './all_judges_helpers';
import { authenticated, cleanupPeers, connect, handshake, requestId } from './socket_helpers';

afterEach(cleanupPeers);

for (const allJudges of [false, true]) {
  for (const phase of ['numbers', 'ordering', 'revealing', 'judged']) {
    it(`${allJudges ? 'all judges' : 'normal'} ${phase}: full reconnect after eviction preserves identity and authorized private state`, async () => {
      const f = await roomInPhase(allJudges, phase);
      const member = f.members[1]!;
      const prior = await f.snapshot(member.peer);
      const before = await f.read();
      const resumed = await authenticated(f.room.code, member.credential);
      expect(await member.peer.closed()).toBe(4409);
      expect(resumed.identity.playerId).toBe(member.credential.playerId);
      expect(resumed.snapshot.private).toEqual(prior.private);
      expect(resumed.snapshot.public.roundId).toBe(prior.public.roundId);
      await evictDurableObject(f.room.stub);
      const view = await f.snapshot(resumed.peer);
      expect(view.private).toEqual(prior.private);
      const after = await f.read();
      expect(after.members).toHaveLength(before.members.length);
      expect(after.game!.personCounts).toEqual(before.game!.personCounts);
      expect(after.game!.history).toEqual(before.game!.history);
      expect(after.game!.round).toEqual(before.game!.round);
      expect(after.members.find((m) => m.playerId === member.credential.playerId)!.generation).toBe(
        before.members.find((m) => m.playerId === member.credential.playerId)!.generation + 1,
      );
    });
  }

  it(`${allJudges ? 'all judges' : 'normal'}: commit before disconnect is deduplicated after resume`, async () => {
    const f = await roomInPhase(allJudges, 'numbers');
    const before = await f.read();
    const member = f.members.find((m) =>
      before.game!.round!.recipients.includes(m.credential.playerId),
    )!;
    const action = await f.command('acknowledgeNumber');
    // Discard the original ACK at the client boundary, then resend its exact intention.
    await f.send(member.peer, action);
    const committed = await f.read();
    const resumed = await authenticated(f.room.code, member.credential);
    await evictDurableObject(f.room.stub);
    resumed.peer.send(action);
    expect(await result(resumed.peer)).toMatchObject({ type: 'ack', outcome: 'duplicate' });
    const after = await f.read();
    expect(after.game!.round).toEqual(committed.game!.round);
    expect(after.game!.personCounts).toEqual(committed.game!.personCounts);
    expect(after.game!.history).toEqual(committed.game!.history);
    expect(after.game!.receipts).toEqual(committed.game!.receipts);
  });

  it(`${allJudges ? 'all judges' : 'normal'}: reconnect repeats an unreceived own-history page without exposing it to another role`, async () => {
    const f = await roomInPhase(allJudges, 'numbers');
    async function page(peer: typeof f.host.peer, cursor: null = null) {
      const id = requestId();
      peer.send(createRoomMessage('historyPull', { requestId: id, cursor }));
      for (let index = 0; index < 100; index++) {
        const frame = await peer.next();
        if (frame.type === 'historyEvents' && frame.requestId === id) return frame;
      }
      throw new Error('NO_HISTORY_PAGE');
    }
    const original = await page(f.host.peer);
    const before = await f.read();
    expect(original.events).toEqual(before.game!.history);
    expect(original.events.length).toBeGreaterThan(0);
    const restored = await authenticated(f.room.code, f.room.credential);
    await evictDurableObject(f.room.stub);
    const repeated = await page(restored.peer);
    expect(repeated.events).toEqual(original.events);
    expect(repeated.cursor).toBe(original.cursor);
    const other = await page(f.members[1]!.peer);
    expect(other.events).toEqual([]);
    restored.peer.send(
      createRoomMessage('historyReceipt', {
        requestId: requestId(),
        cursor: repeated.cursor,
      }),
    );
    expect(await result(restored.peer)).toMatchObject({ type: 'ack', outcome: 'committed' });
    expect((await page(restored.peer)).events).toEqual([]);
    const after = await f.read();
    expect(after.game!.history).toEqual(before.game!.history);
    expect(after.game!.personCounts).toEqual(before.game!.personCounts);
  });
}

it('an offline participant returns to the advanced round; obsolete intentions cannot change it', async () => {
  const f = await roomInPhase(true, 'numbers');
  const member = f.members[2]!;
  const obsolete = await f.command('acknowledgeNumber');
  member.peer.socket.close(1000);
  await member.peer.closed();
  let state = await f.read();
  const originalRound = state.game!.round!.id;
  await f.send(
    f.host.peer,
    createRoomMessage('completeWithoutVerdict', {
      actionId: f.action(),
      expectedRevision: state.revision,
      gameId: state.game!.gameId!,
      roundId: originalRound,
      confirmed: true,
    }),
  );
  state = await f.read();
  if (state.phase === 'rule_event') {
    await f.send(
      f.host.peer,
      createRoomMessage('continueRule', {
        actionId: f.action(),
        expectedRevision: state.revision,
        gameId: state.game!.gameId!,
        afterCase: state.game!.completedCases,
      }),
    );
  }
  const before = await f.read();
  const resumed = await authenticated(f.room.code, member.credential);
  expect(resumed.snapshot.public.roundId).not.toBe(originalRound);
  expect(resumed.snapshot.private.ownNumber).toBe(
    before.game!.round!.numbers.find((n) => n.playerId === member.credential.playerId)!.number,
  );
  resumed.peer.send(obsolete);
  expect(await result(resumed.peer)).toMatchObject({ type: 'error', code: 'STALE_REVISION' });
  resumed.peer.send({ ...obsolete, expectedRevision: resumed.snapshot.revision });
  expect(await result(resumed.peer)).toMatchObject({ type: 'error', code: 'STALE_ROUND' });
  const after = await f.read();
  expect(after.game!.round).toEqual(before.game!.round);
  expect(after.game!.personCounts).toEqual(before.game!.personCounts);
  expect(after.game!.history).toEqual(before.game!.history);
});

it('a lost or revoked token cannot assume an existing identity', async () => {
  const f = await roomInPhase(false, 'numbers');
  const member = f.members[2]!;
  await f.room.stub.leave(
    createRoomMessage('leaveHttp', {
      requestId: requestId(),
      actionId: f.action(),
      resumeToken: member.credential.resumeToken,
      confirmed: true,
    }),
  );
  const before = await f.read();
  for (const token of [member.credential.resumeToken, 'A'.repeat(43)]) {
    const peer = await connect(f.room.code);
    peer.send(
      createRoomMessage('authenticate', {
        requestId: requestId(),
        handshake,
        resumeToken: token,
      }),
    );
    expect(await peer.next()).toMatchObject({ type: 'error', code: 'CREDENTIAL_INVALID' });
    expect(await peer.closed()).toBe(4401);
  }
  const after = await f.read();
  expect(after.members).toEqual(before.members);
  expect(after.game!.personCounts).toEqual(before.game!.personCounts);
});
