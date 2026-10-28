import { runInDurableObject, evictDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { createRoomMessage } from '../../src/protocol/room_message';
import { RoomRepository } from '../../src/room/repository';
import { immutable, type MutableGameState } from '../../src/domain/game_state';
import { cleanupPeers, authenticated, profile, handshake, requestId } from './socket_helpers';
import { allJudgesRoom } from './all_judges_helpers';
import { roomInPhase as setup } from './game_phase_helpers';

afterEach(cleanupPeers);
type Fixture = Awaited<ReturnType<typeof allJudgesRoom>>;
async function join(f: Fixture) {
  const result = await f.room.stub.join(
    createRoomMessage('join', { requestId: requestId(), profile, handshake }),
  );
  if (!result.ok) throw new Error(result.code);
  return { ...(await authenticated(f.room.code, result.message)), credential: result.message };
}
async function leave(f: Fixture, member: Fixture['members'][number]) {
  const result = await f.room.stub.leave(
    createRoomMessage('leaveHttp', {
      requestId: requestId(),
      actionId: f.action(),
      resumeToken: member.credential.resumeToken,
      confirmed: true,
    }),
  );
  expect(result.ok).toBe(true);
}
async function complete(f: Fixture) {
  const state = await f.read(),
    game = state.game!;
  const command = createRoomMessage(
    game.phase === 'judged' ? 'completeCase' : 'completeWithoutVerdict',
    {
      actionId: f.action(),
      expectedRevision: state.revision,
      gameId: game.gameId!,
      roundId: game.round!.id,
      ...(game.phase === 'judged' ? {} : { confirmed: true as const }),
    },
  );
  await f.send(f.host.peer, command);
  await f.send(f.host.peer, command);
}
async function continueRule(f: Fixture) {
  const state = await f.read();
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
for (const allJudges of [false, true])
  for (const phase of [
    'numbers',
    'answers',
    'ordering',
    'revealing',
    'judged',
    'rule_event',
    'paused',
    'finished',
  ]) {
    it(`${allJudges ? 'all judges' : 'normal'} ${phase}: join/leave/reorder are pending, preserve the frozen case, and apply once at the next case`, async () => {
      const f = await setup(allJudges, phase),
        before = await f.read(),
        round = before.game!.round;
      await f.send(
        f.host.peer,
        createRoomMessage('editOwnProfile', {
          actionId: f.action(),
          expectedRevision: before.revision,
          profile: { ...profile, name: 'Updated host' },
        }),
      );
      const renamed = await f.snapshot(f.host.peer);
      expect(renamed.public.players.find((p) => p.playerId === before.hostId)!.profile.name).toBe(
        'Updated host',
      );
      expect((await f.read()).game!.round).toEqual(round);
      const added = await join(f),
        afterJoin = await f.read();
      expect(afterJoin.game!.pendingRoster).toContain(added.credential.playerId);
      expect((await f.snapshot(added.peer)).private).toEqual({});
      expect(afterJoin.game!.round).toEqual(round);
      const victim = f.members.find(
        (m) =>
          m.credential.playerId !== before.hostId &&
          !before.members.find((p) => p.playerId === m.credential.playerId)!.revoked,
      )!;
      await leave(f, victim);
      const revoked = await f.read();
      expect(revoked.game!.round).toEqual(round);
      expect(revoked.game!.history).toEqual(before.game!.history);
      if (round?.roster.includes(victim.credential.playerId)) {
        const snapshot = await f.snapshot(f.host.peer);
        expect(
          snapshot.public.players.find((p) => p.playerId === victim.credential.playerId)!.active,
        ).toBe(false);
        expect(
          snapshot.public.players.find((p) => p.playerId === victim.credential.playerId)?.profile,
        ).toEqual(
          victim.snapshot.public.players.find((p) => p.playerId === victim.credential.playerId)!
            .profile,
        );
      }
      expect(
        await f.room.stub.authenticate(
          createRoomMessage('authenticate', {
            requestId: requestId(),
            resumeToken: victim.credential.resumeToken,
            handshake,
          }),
        ),
      ).toMatchObject({ ok: false, code: 'CREDENTIAL_INVALID' });
      const returned = await join(f);
      expect(returned.credential.playerId).not.toBe(victim.credential.playerId);
      const active = (await f.read()).members
        .filter((m) => !m.revoked)
        .map((m) => m.playerId)
        .reverse();
      const reorder = createRoomMessage('reorderRoster', {
        actionId: f.action(),
        expectedRevision: (await f.read()).revision,
        playerIds: active,
      });
      await f.send(f.host.peer, reorder);
      await f.send(f.host.peer, reorder);
      const pending = await f.read();
      expect(pending.game!.pendingRoster).toEqual(active);
      expect(pending.game!.round).toEqual(round);
      expect(pending.game!.personCounts).toEqual(before.game!.personCounts);
      await evictDurableObject(f.room.stub);
      expect((await f.read()).game).toEqual(pending.game);
      if (phase === 'rule_event') await continueRule(f);
      else if (phase === 'paused' || phase === 'finished') {
        const state = await f.read();
        await f.send(
          f.host.peer,
          phase === 'paused'
            ? createRoomMessage('resumePaused', {
                actionId: f.action(),
                expectedRevision: state.revision,
                gameId: state.game!.gameId!,
              })
            : createRoomMessage('restartGame', {
                actionId: f.action(),
                expectedRevision: state.revision,
                gameId: state.game!.gameId!,
                config: state.config,
                confirmed: true,
              }),
        );
      } else {
        await complete(f);
        if ((await f.read()).phase === 'rule_event') await continueRule(f);
      }
      if ((await f.read()).phase === 'rule_event') await continueRule(f);
      const next = (await f.read()).game!;
      expect(next.effectiveRoster).toEqual(active);
      expect(next.pendingRoster).toBeNull();
      expect(next.round!.roster).toEqual(active);
      expect(next.round!.recipients).toContain(added.credential.playerId);
      expect(next.round!.id).not.toBe(round?.id);
      for (const rule of next.activeRules)
        expect(Object.values(rule.bindings).every((id) => active.includes(id))).toBe(true);
      expect(active).toContain(allJudges ? next.readerId : next.judgeId);
    });
  }

it('a departed seat remains reserved up to the boundary and cannot create a twenty-first public identity', async () => {
  const f = await allJudgesRoom(20),
    victim = f.members[18]!;
  await leave(f, victim);
  const full = await f.room.stub.join(
    createRoomMessage('join', { requestId: requestId(), profile, handshake }),
  );
  expect(full).toMatchObject({ ok: false, code: 'ROOM_FULL' });
  expect((await f.snapshot(f.host.peer)).public.players).toHaveLength(20);
  await complete(f);
  const member = await join(f);
  expect((await f.read()).game!.pendingRoster).toContain(member.credential.playerId);
  expect((await f.snapshot(f.host.peer)).public.players).toHaveLength(20);
});

it('new identity gets the remaining active maximum, while credential resume never resets counters or assignments', async () => {
  const f = await allJudgesRoom(4),
    old = f.members[1]!.credential.playerId;
  await runInDurableObject(f.room.stub, (_room, ctx) => {
    const repository = new RoomRepository(ctx.storage),
      state = repository.read()!,
      game = structuredClone(state.game!) as MutableGameState;
    for (const member of state.members) member.selectionCount = member.playerId === old ? 19 : 7;
    game.personCounts = state.members.map((m) => ({
      playerId: m.playerId,
      count: m.selectionCount,
    }));
    state.game = immutable(game);
    repository.write(state);
  });
  const seeded = await f.read(),
    member = f.members[2]!;
  const resumed = await authenticated(f.room.code, member.credential);
  Object.assign(member, resumed);
  expect((await f.read()).game).toEqual(seeded.game);
  const kick = createRoomMessage('kick', {
    actionId: f.action(),
    expectedRevision: (await f.read()).revision,
    targetPlayerId: old,
    confirmed: true,
  });
  await f.send(f.host.peer, kick);
  await f.send(f.host.peer, kick);
  const fresh = await join(f);
  expect(
    (await f.read()).members.find((m) => m.playerId === fresh.credential.playerId)!.selectionCount,
  ).toBe(7);
  await complete(f);
  const boundary = (await f.read()).game!,
    count = boundary.personCounts.find((p) => p.playerId === fresh.credential.playerId)!.count;
  // The new rule can bind this identity once, but the old identity's 19 is never inherited.
  expect(count).toBeGreaterThanOrEqual(7);
  expect(count).toBeLessThanOrEqual(8);
  expect(boundary.personCounts.find((p) => p.playerId === old)!.count).toBe(19);
  const retry = await f.read();
  await f.send(f.host.peer, kick);
  expect((await f.read()).game).toEqual(retry.game);
});

for (const allJudges of [false, true])
  it(`${allJudges ? 'all judges' : 'normal'} rule-event removal rebinds only the lost rule role once before drawing the next case`, async () => {
    const f = await allJudgesRoom(4, allJudges);
    await complete(f);
    const victim = f.members[1]!,
      id = victim.credential.playerId;
    await runInDurableObject(f.room.stub, (_room, ctx) => {
      const repository = new RoomRepository(ctx.storage),
        state = repository.read()!,
        game = structuredClone(state.game!) as MutableGameState;
      game.activeRules = [{ contentId: 'toast_to_player', bindings: { player1: id } }];
      game.drawnRuleIds = ['toast_to_player'];
      game.ruleSlots[0]!.ruleId = 'toast_to_player';
      game.history.find((e) => e.kind === 'rule')!.contentId = 'toast_to_player';
      game.personCounts = state.members.map((m) => ({
        playerId: m.playerId,
        count: m.playerId === id ? 8 : 7,
      }));
      state.game = immutable(game);
      repository.write(state);
    });
    const before = await f.read();
    await leave(f, victim);
    expect((await f.snapshot(f.host.peer)).public.players.some((p) => p.playerId === id)).toBe(
      true,
    );
    const state = await f.read(),
      command = createRoomMessage('continueRule', {
        actionId: f.action(),
        expectedRevision: state.revision,
        gameId: state.game!.gameId!,
        afterCase: 1,
      });
    await f.send(f.host.peer, command);
    const next = await f.read(),
      game = next.game!,
      rule = game.activeRules.find((r) => r.contentId === 'toast_to_player')!;
    expect(rule.bindings.player1).not.toBe(id);
    expect(game.effectiveRoster).toContain(rule.bindings.player1);
    const previousTotal = before.game!.personCounts.reduce((total, p) => total + p.count, 0),
      newTotal = game.personCounts.reduce((total, p) => total + p.count, 0);
    expect(newTotal - previousTotal).toBe(
      1 + new Set(Object.values(game.round!.question.bindings)).size,
    );
    expect(game.history).toHaveLength(before.game!.history.length + 1);
    expect(next.members.find((m) => m.playerId === id)!.profile).toBeUndefined();
    await f.send(f.host.peer, command);
    expect((await f.read()).game).toEqual(game);
  });
