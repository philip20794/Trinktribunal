import { runInDurableObject, evictDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { createRoomMessage, RoomIds } from '../../src/protocol/room_message';
import type { RoomMessage } from '../../src/protocol/room_message.generated';
import { RoomRepository } from '../../src/room/repository';
import {
  socketRoom,
  authenticated,
  cleanupPeers,
  profile,
  handshake,
  requestId,
  type Peer,
} from './socket_helpers';

afterEach(cleanupPeers);
async function response(peer: Peer) {
  for (let i = 0; i < 100; i++) {
    const message = await peer.next();
    if (message.type === 'ack' || message.type === 'error' || message.type === 'historyEvents')
      return message;
  }
  throw new Error('NO_RESPONSE');
}

it('three normal cases and two rule events rotate once; restart retains owned history and invalidates old actions', async () => {
  const room = await socketRoom(),
    host = await authenticated(room.code, room.credential);
  const members = [{ ...host, credential: room.credential }];
  for (let i = 0; i < 2; i++) {
    const joined = await room.stub.join(
      createRoomMessage('join', {
        requestId: requestId(),
        profile: { ...profile, name: `Player ${i}` },
        handshake,
      }),
    );
    if (!joined.ok) throw new Error('JOIN');
    members.push({
      ...(await authenticated(room.code, joined.message)),
      credential: joined.message,
    });
  }
  const read = () =>
    runInDurableObject(room.stub, (_room, ctx) => new RoomRepository(ctx.storage).read()!);
  async function send(peer: Peer, message: RoomMessage) {
    peer.send(message);
    const result = await response(peer);
    expect(result, JSON.stringify({ command: message.type, result })).toMatchObject({
      type: 'ack',
    });
    // Model time spent reading/answering between intents without real sleeps.
    // Rate-limit behavior is tested separately in socket_auth.test.ts.
    await runInDurableObject(room.stub, (_room, ctx) => {
      ctx.storage.sql.exec('UPDATE action_limits SET updated = ?', Date.now() - 1000);
    });
    return result;
  }
  const action = () => RoomIds.action(crypto.randomUUID());
  await send(
    host.peer,
    createRoomMessage('reorderRoster', {
      actionId: action(),
      expectedRevision: (await read()).revision,
      playerIds: members
        .slice(1)
        .concat(members[0]!)
        .map((m) => m.credential.playerId),
    }),
  );
  await send(
    host.peer,
    createRoomMessage('setConfig', {
      actionId: action(),
      expectedRevision: (await read()).revision,
      config: { ...(await read()).config, targetCases: 3, requestedRuleEvents: 2 },
    }),
  );
  await send(
    host.peer,
    createRoomMessage('startGame', {
      actionId: action(),
      expectedRevision: (await read()).revision,
    }),
  );
  const initial = (await read()).game!,
    gameId = initial.gameId!,
    judges = initial.effectiveRoster;
  expect(initial.judgeId).not.toBe(room.credential.playerId);
  let oldCompletion: RoomMessage | undefined;
  for (let index = 0; index < 3; index++) {
    const before = (await read()).game!,
      round = before.round!;
    expect(before.judgeId).toBe(judges[index]);
    expect(before.completedCases).toBe(index);
    if (index === 1) {
      // D-07 is a counted case with no synthetic verdict or extra rotation.
      const command = createRoomMessage('completeWithoutVerdict', {
        actionId: action(),
        expectedRevision: (await read()).revision,
        gameId,
        roundId: round.id,
        confirmed: true,
      });
      await send(host.peer, command);
      await send(host.peer, command);
      expect((await read()).game!.lastCompletion).toMatchObject({
        kind: 'completed_without_verdict',
        score: null,
      });
    } else {
      const command = async (type: 'acknowledgeNumber' | 'readyForOrdering' | 'beginOrdering') =>
        createRoomMessage(type, {
          actionId: action(),
          expectedRevision: (await read()).revision,
          gameId,
          roundId: round.id,
        });
      for (const member of members.filter((m) => round.recipients.includes(m.credential.playerId)))
        await send(member.peer, await command('acknowledgeNumber'));
      for (const member of members) await send(member.peer, await command('readyForOrdering'));
      await send(host.peer, await command('beginOrdering'));
      const judge = members.find((m) => m.credential.playerId === before.judgeId)!;
      const order = [...round.numbers].sort((a, b) => a.number - b.number).map((n) => n.playerId);
      await send(
        judge.peer,
        createRoomMessage('submitOrder', {
          actionId: action(),
          expectedRevision: (await read()).revision,
          gameId,
          roundId: round.id,
          order,
          confirmed: true,
        }),
      );
      for (let cursor = 0; cursor < order.length; cursor++)
        await send(
          host.peer,
          createRoomMessage('revealNext', {
            actionId: action(),
            expectedRevision: (await read()).revision,
            gameId,
            roundId: round.id,
            expectedCursor: cursor,
          }),
        );
      expect((await read()).game!.round!.score).toMatchObject({ kind: 'normal', errors: 0 });
      oldCompletion = createRoomMessage('completeCase', {
        actionId: action(),
        expectedRevision: (await read()).revision,
        gameId,
        roundId: round.id,
      });
      await send(host.peer, oldCompletion);
      await send(host.peer, oldCompletion);
    }
    const completed = (await read()).game!;
    expect(completed.completedCases).toBe(index + 1);
    expect(completed.completedRoundIds).toHaveLength(index + 1);
    expect(completed.round).toBeNull();
    if (index < 2) {
      expect(completed.phase).toBe('rule_event');
      expect(completed.activeRules).toHaveLength(index + 1);
      const nextJudge = completed.judgeId;
      for (const member of members) {
        member.peer.send(createRoomMessage('requestSnapshot', { requestId: requestId() }));
        for (let count = 0; count < 100; count++) {
          const view = await member.peer.next();
          if (view.type === 'snapshot' && view.revision === (await read()).revision) {
            expect(view.public).toMatchObject({
              phase: 'rule_event',
              gameId,
              roundId: null,
              question: null,
              frozenRoster: [],
              completedCases: index + 1,
              revealed: [],
              revealCursor: 0,
            });
            expect(view.private).toEqual({});
            break;
          }
        }
      }
      const rule = createRoomMessage('continueRule', {
        actionId: action(),
        expectedRevision: (await read()).revision,
        gameId,
        afterCase: index + 1,
      });
      await send(host.peer, rule);
      await send(host.peer, rule);
      expect((await read()).game!.judgeId).toBe(nextJudge);
    } else expect(completed.phase).toBe('finished');
  }
  const end = await read();
  expect(end.game!.drawnQuestionIds).toHaveLength(3);
  expect(end.game!.drawnRuleIds).toHaveLength(2);
  expect(end.game!.history).toHaveLength(5);
  expect(end.game!.ruleSlots.map((s) => s.status)).toEqual(['activated', 'activated']);
  for (const member of members) {
    member.peer.send(createRoomMessage('requestSnapshot', { requestId: requestId() }));
    let found = false;
    for (let count = 0; count < 100; count++) {
      const view = await member.peer.next();
      if (view.type === 'snapshot' && view.revision === end.revision) {
        expect(view.public).toMatchObject({
          phase: 'finished',
          gameId,
          completedCases: 3,
          roundId: null,
          question: null,
          frozenRoster: [],
          revealed: [],
          revealCursor: 0,
        });
        expect(view.public.result).toBeUndefined();
        expect(view.private).toEqual({});
        expect(view.public.players.map((p) => p.playerId)).toEqual(end.game!.effectiveRoster);
        found = true;
        break;
      }
    }
    expect(found).toBe(true);
  }
  await evictDurableObject(room.stub);
  const restart = createRoomMessage('restartGame', {
    actionId: action(),
    expectedRevision: end.revision,
    gameId,
    config: end.config,
    confirmed: true,
  });
  await send(host.peer, restart);
  await send(host.peer, restart);
  const restarted = await read();
  expect(restarted.game!.gameId).not.toBe(gameId);
  expect(restarted.game!.completedCases).toBe(0);
  expect(restarted.game!.activeRules).toEqual([]);
  expect(restarted.game!.history).toHaveLength(6);
  expect(restarted.game!.history.slice(0, 5)).toEqual(end.game!.history);
  host.peer.send(oldCompletion!);
  expect(await response(host.peer)).toMatchObject({ type: 'error', code: 'STALE_ROUND' });
  expect((await read()).revision).toBe(restarted.revision);
  host.peer.send(createRoomMessage('historyPull', { requestId: requestId(), cursor: null }));
  const history = await response(host.peer);
  if (history.type !== 'historyEvents') throw new Error('HISTORY');
  expect(history.events).toHaveLength(6);
  await send(
    host.peer,
    createRoomMessage('historyReceipt', { requestId: requestId(), cursor: history.cursor }),
  );
  await send(
    host.peer,
    createRoomMessage('historyReceipt', { requestId: requestId(), cursor: history.cursor }),
  );
  members[1]!.peer.send(createRoomMessage('historyPull', { requestId: requestId(), cursor: null }));
  expect(await response(members[1]!.peer)).toMatchObject({ type: 'historyEvents', events: [] });
});
