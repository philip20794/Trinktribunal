import { evictDurableObject, runInDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { createRoomMessage } from '../../src/protocol/room_message';
import { immutable, type MutableGameState } from '../../src/domain/game_state';
import { RoomRepository } from '../../src/room/repository';
import { attachment } from '../../src/room/sockets';
import { allJudgesRoom } from '../room/all_judges_helpers';
import { authenticated, cleanupPeers, handshake, profile, requestId } from '../room/socket_helpers';

afterEach(cleanupPeers);

async function configured(count: number, allJudges: boolean, cases: number, rules: number) {
  const f = await allJudgesRoom(count, allJudges, false);
  await f.send(
    f.host.peer,
    createRoomMessage('setConfig', {
      actionId: f.action(),
      expectedRevision: (await f.read()).revision,
      config: { ...(await f.read()).config, targetCases: cases, requestedRuleEvents: rules },
    }),
  );
  await f.send(
    f.host.peer,
    createRoomMessage('startGame', {
      actionId: f.action(),
      expectedRevision: (await f.read()).revision,
    }),
  );
  return f;
}

for (const allJudges of [false, true]) {
  it(`${allJudges ? 'all judges' : 'normal'}: eight clients finish 50 cases/seven rules with deterministic interruptions`, async () => {
    const f = await configured(8, allJudges, 50, 7);
    const isolated = await configured(3, !allJudges, 1, 0);
    const isolatedBefore = await isolated.read();
    async function host() {
      const id = (await f.read()).hostId;
      return f.members.find((m) => m.credential.playerId === id)!;
    }
    for (let index = 0; index < 50; index++) {
      let state = await f.read();
      expect(state.phase).toBe('numbers');
      expect(state.game!.completedCases).toBe(index);
      const round = state.game!.round!;
      const sorted = [...round.numbers].sort((a, b) => a.number - b.number).map((n) => n.playerId);
      expect(new Set(round.numbers.map((n) => n.number)).size).toBe(sorted.length);
      for (const member of f.members) {
        const view = await f.snapshot(member.peer);
        expect(view.roomId).toBe(state.roomId);
        expect(view.public.revealed).toEqual([]);
        expect(view.private).toEqual(
          round.numbers.some((n) => n.playerId === member.credential.playerId)
            ? {
                ownNumber: round.numbers.find((n) => n.playerId === member.credential.playerId)!
                  .number,
              }
            : {},
        );
        expect(
          view.public.players.some((p) =>
            isolatedBefore.members.some((m) => m.playerId === p.playerId),
          ),
        ).toBe(false);
      }
      if (index === 9) {
        const member = f.members[7]!;
        const resumed = await authenticated(f.room.code, member.credential);
        expect(await member.peer.closed()).toBe(4409);
        f.members[7] = { ...resumed, credential: member.credential };
        expect((await f.read()).game!.personCounts).toEqual(state.game!.personCounts);
      }
      if (index === 12) {
        await f.send(
          (await host()).peer,
          createRoomMessage('reorderRoster', {
            actionId: f.action(),
            expectedRevision: (await f.read()).revision,
            playerIds: [...state.game!.roster].reverse(),
          }),
        );
        expect((await f.read()).game!.round).toEqual(round);
      }
      if (index % 10 === 0) {
        const member = f.members[6]!;
        await f.send(
          member.peer,
          createRoomMessage('editOwnProfile', {
            actionId: f.action(),
            expectedRevision: (await f.read()).revision,
            profile: { ...profile, name: `Changed ${index}` },
          }),
        );
      }
      for (const member of f.members.filter((m) =>
        round.recipients.includes(m.credential.playerId),
      ))
        await f.send(member.peer, await f.command('acknowledgeNumber'));
      for (const member of f.members)
        await f.send(member.peer, await f.command('readyForOrdering'));
      await f.send((await host()).peer, await f.command('beginOrdering'));
      const orders = new Map<string, readonly string[]>();
      for (const [position, member] of f.members.entries()) {
        if (!allJudges && member.credential.playerId !== state.game!.judgeId) continue;
        const order = [...sorted];
        if ((index + position) % 3 === 0) [order[0], order[1]] = [order[1]!, order[0]!];
        orders.set(member.credential.playerId, order);
        await f.send(member.peer, await f.order(order));
        if (index === 39 && (!allJudges || position === 3)) {
          const before = await f.read();
          await evictDurableObject(f.room.stub);
          expect(await f.read()).toEqual(before);
        }
      }
      for (let cursor = 0; cursor < sorted.length; cursor++) {
        await f.send(
          (await host()).peer,
          createRoomMessage('revealNext', {
            actionId: f.action(),
            expectedRevision: (await f.read()).revision,
            gameId: state.game!.gameId!,
            roundId: round.id,
            expectedCursor: cursor,
          }),
        );
      }
      const judged = await f.read();
      expect(judged.phase).toBe('judged');
      for (const member of f.members) {
        const view = await f.snapshot(member.peer);
        const revealIds = allJudges ? round.recipients : orders.get(state.game!.judgeId!)!;
        expect(view.public.revealed).toEqual(
          revealIds.map((playerId) => ({
            playerId,
            number: round.numbers.find((n) => n.playerId === playerId)!.number,
          })),
        );
        const own = orders.get(member.credential.playerId);
        expect(view.private.ownOrder).toEqual(own);
        if (allJudges) {
          const errors = own!.filter((id, position) => id !== sorted[position]).length;
          expect(view.private.ownResult).toMatchObject({ errors, sips: errors });
        }
      }
      if (!allJudges) {
        const own = orders.get(state.game!.judgeId!)!;
        const errors = own.filter((id, position) => id !== sorted[position]).length;
        const wrong = new Set(own.filter((id, position) => id !== sorted[position]));
        expect(judged.game!.round!.score).toEqual({
          kind: 'normal',
          errors,
          penalties: round.roster.map((playerId) => ({
            playerId,
            sips: playerId === state.game!.judgeId || wrong.has(playerId) ? errors : 0,
          })),
        });
      }
      if (index === 24) {
        const leaving = f.members[7]!;
        expect(
          await f.room.stub.leave(
            createRoomMessage('leaveHttp', {
              requestId: requestId(),
              actionId: f.action(),
              resumeToken: leaving.credential.resumeToken,
              confirmed: true,
            }),
          ),
        ).toMatchObject({ ok: true });
        const joined = await f.room.stub.join(
          createRoomMessage('join', {
            requestId: requestId(),
            handshake,
            profile: { ...profile, name: 'Replacement' },
          }),
        );
        if (!joined.ok) throw new Error('JOIN');
        f.members[7] = {
          ...(await authenticated(f.room.code, joined.message)),
          credential: joined.message,
        };
        expect((await f.read()).game!.round).toEqual(judged.game!.round);
      }
      if (index === 29) {
        const previous = await host();
        await runInDurableObject(f.room.stub, async (room, ctx) => {
          const socket = ctx.getWebSockets().find((socket) => {
            const info = attachment(socket);
            return info?.kind === 'authenticated' && info.playerId === previous.credential.playerId;
          })!;
          await room.webSocketClose(socket);
          const repository = new RoomRepository(ctx.storage),
            current = repository.read()!;
          const game = structuredClone(current.game!) as MutableGameState;
          game.hostDisconnectedAt = Date.now() - 90001;
          current.game = immutable(game);
          repository.write(current);
          await room.alarm();
        });
        expect((await f.read()).hostId).not.toBe(previous.credential.playerId);
        const replacement = await authenticated(f.room.code, previous.credential);
        f.members[f.members.indexOf(previous)] = {
          ...replacement,
          credential: previous.credential,
        };
        expect((await f.read()).game!.round).toEqual(judged.game!.round);
      }
      state = await f.read();
      const completion = createRoomMessage('completeCase', {
        actionId: f.action(),
        expectedRevision: state.revision,
        gameId: state.game!.gameId!,
        roundId: round.id,
      });
      const actor = await host();
      await f.send(actor.peer, completion);
      expect(await f.send(actor.peer, completion)).toMatchObject({ outcome: 'duplicate' });
      state = await f.read();
      expect(state.game!.completedCases).toBe(index + 1);
      if (state.phase === 'rule_event') {
        const rule = createRoomMessage('continueRule', {
          actionId: f.action(),
          expectedRevision: state.revision,
          gameId: state.game!.gameId!,
          afterCase: state.game!.completedCases,
        });
        await f.send((await host()).peer, rule);
        expect(await f.send((await host()).peer, rule)).toMatchObject({ outcome: 'duplicate' });
      }
    }
    const finished = await f.read();
    expect(finished.phase).toBe('finished');
    expect(finished.game!.completedRoundIds).toHaveLength(50);
    expect(new Set(finished.game!.drawnQuestionIds).size).toBe(50);
    expect(finished.game!.activeRules).toHaveLength(7);
    expect(finished.game!.ruleSlots.every((slot) => slot.status === 'activated')).toBe(true);
    expect(finished.game!.history.filter((event) => event.kind === 'question')).toHaveLength(50);
    expect(finished.game!.history.filter((event) => event.kind === 'rule')).toHaveLength(7);
    expect(await isolated.read()).toEqual(isolatedBefore);
  }, 300000);
}

it('20 admitted clients submit 20 independent orders; the 21st join is rejected', async () => {
  const f = await configured(20, true, 1, 0);
  const before = await f.read();
  expect(
    await f.room.stub.join(
      createRoomMessage('join', {
        requestId: requestId(),
        handshake,
        profile,
      }),
    ),
  ).toMatchObject({ ok: false, code: 'ROOM_FULL' });
  expect((await f.read()).members).toHaveLength(20);
  await f.ordering();
  const sorted = [...before.game!.round!.numbers]
    .sort((a, b) => a.number - b.number)
    .map((n) => n.playerId);
  for (const [index, member] of f.members.entries()) {
    const own = [...sorted.slice(index), ...sorted.slice(0, index)];
    await f.send(member.peer, await f.order(own));
  }
  expect((await f.read()).game!.round!.orders).toHaveLength(20);
  for (const [index, member] of f.members.entries()) {
    const view = await f.snapshot(member.peer);
    expect(view.private.ownOrder).toEqual([...sorted.slice(index), ...sorted.slice(0, index)]);
    expect(view.public.revealCursor).toBe(0);
    expect(view.public.revealed).toEqual([]);
  }
  for (let cursor = 0; cursor < 20; cursor++) {
    await f.send(
      f.host.peer,
      createRoomMessage('revealNext', {
        actionId: f.action(),
        expectedRevision: (await f.read()).revision,
        gameId: before.game!.gameId!,
        roundId: before.game!.round!.id,
        expectedCursor: cursor,
      }),
    );
  }
  for (const [index, member] of f.members.entries()) {
    const view = await f.snapshot(member.peer);
    expect(view.private.ownResult).toMatchObject({
      errors: index === 0 ? 0 : 20,
      sips: index === 0 ? 0 : 20,
    });
  }
}, 120000);
