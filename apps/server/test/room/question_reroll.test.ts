import { evictDurableObject, runInDurableObject } from 'cloudflare:test';
import { afterEach, describe, expect, it } from 'vitest';
import { commitRerollAction } from '../../src/room/actions';
import { RoomRepository, type RoomState } from '../../src/room/repository';
import { migrateRoomState } from '../../src/room/migrations';
import { roomInPhase } from './game_phase_helpers';
import { authenticated, cleanupPeers } from './socket_helpers';

afterEach(cleanupPeers);
function intent(state: RoomState) {
  return {
    type: 'rerollCurrentQuestion',
    protocolVersion: 2,
    actionId: crypto.randomUUID(),
    expectedRevision: state.revision,
    gameId: state.game!.gameId,
    roundId: state.game!.round!.id,
  };
}

describe('atomic question reroll persistence', () => {
  for (const allJudges of [false, true])
    it(`commits ten draws once, restores after eviction, and preserves numbers/case/slots (${allJudges})`, async () => {
      const f = await roomInPhase(allJudges, 'ordering'),
        initial = await f.read();
      const result = await runInDurableObject(f.room.stub, (_room, ctx) => {
        const repository = new RoomRepository(ctx.storage),
          before = repository.read()!;
        const game = before.game!,
          actorId = (allJudges ? game.readerId : game.judgeId)!;
        const actor = before.members.find((m) => m.playerId === actorId)!;
        const connected = new Set(before.members.map((m) => m.playerId));
        for (let i = 0; i < 10; i++) {
          const state = repository.read()!,
            command = intent(state);
          expect(commitRerollAction(repository, actor, command, connected)).toMatchObject({
            ok: true,
            duplicate: false,
          });
          const next = repository.read()!;
          expect(commitRerollAction(repository, actor, command, connected)).toMatchObject({
            ok: true,
            duplicate: true,
          });
          expect(
            commitRerollAction(
              repository,
              actor,
              { ...command, actionId: crypto.randomUUID() },
              connected,
            ),
          ).toMatchObject({ ok: false, code: 'STALE_REVISION' });
          expect(repository.read()).toEqual(next);
          expect(next.game!.round!.numbers).toEqual(game.round!.numbers);
          expect(next.game!.ruleSlots).toEqual(game.ruleSlots);
          expect(next.game!.round).toMatchObject({
            acknowledged: [],
            answerReady: [],
            orders: [],
            revealOrder: [],
            revealCursor: 0,
            score: null,
          });
          expect(next.game!.completedCases).toBe(0);
          expect(migrateRoomState(JSON.stringify(next)).migrated).toBe(false);
        }
        return repository.read()!;
      });
      expect(result.game!.history).toHaveLength(11);
      expect(result.game!.questionDraws).toHaveLength(11);
      expect(Object.keys(result.historyOwners!)).toHaveLength(11);
      expect(result.revision).toBe(initial.revision + 10);
      await evictDurableObject(f.room.stub);
      const resumed = await authenticated(f.room.code, f.room.credential);
      expect(resumed).toBeDefined();
      const restored = await f.read();
      expect(restored.game).toEqual(result.game);
      expect(restored.historyOwners).toEqual(result.historyOwners);
    });

  it('rolls back SQLite state/history/counters/receipt on a failed write; retry commits once', async () => {
    const f = await roomInPhase(false, 'answers');
    await runInDurableObject(f.room.stub, (_room, ctx) => {
      const repository = new RoomRepository(ctx.storage),
        before = repository.read()!;
      const actor = before.members.find((m) => m.playerId === before.game!.judgeId)!;
      const connected = new Set(before.members.map((m) => m.playerId)),
        command = intent(before);
      const write = repository.write.bind(repository);
      repository.write = (state) => {
        write(state);
        throw new Error('after write failure');
      };
      expect(commitRerollAction(repository, actor, command, connected)).toMatchObject({
        ok: false,
        code: 'ROOM_UNAVAILABLE',
        retryable: true,
      });
      expect(repository.read()).toEqual(before);
      repository.write = write;
      expect(
        commitRerollAction(
          repository,
          { ...actor, generation: actor.generation + 1 },
          command,
          connected,
        ),
      ).toMatchObject({ ok: false, code: 'CREDENTIAL_INVALID' });
      expect(repository.read()).toEqual(before);
      expect(commitRerollAction(repository, actor, command, connected)).toMatchObject({
        ok: true,
        duplicate: false,
      });
      expect(repository.read()!.game!.history).toHaveLength(2);
    });
  });

  it('migrates only known one-question-per-case roots and refuses a corrupt reroll ledger', async () => {
    const f = await roomInPhase(false, 'numbers'),
      before = await f.read();
    const old = structuredClone(before) as unknown as { game: Record<string, unknown> };
    delete old.game.questionDraws;
    expect(migrateRoomState(JSON.stringify(old))).toEqual({ state: before, migrated: true });
    await runInDurableObject(f.room.stub, (_room, ctx) => {
      const repo = new RoomRepository(ctx.storage),
        state = repo.read()!;
      const actor = state.members.find((m) => m.playerId === state.game!.judgeId)!;
      expect(
        commitRerollAction(
          repo,
          actor,
          intent(state),
          new Set(state.members.map((m) => m.playerId)),
        ),
      ).toMatchObject({ ok: true });
    });
    const after = await f.read();
    const missing = structuredClone(after) as unknown as { game: Record<string, unknown> };
    delete missing.game.questionDraws;
    expect(() => migrateRoomState(JSON.stringify(missing))).toThrow();
    const corrupt = structuredClone(after) as any;
    corrupt.game.questionDraws[1].roundId = corrupt.game.questionDraws[0].roundId;
    expect(() => migrateRoomState(JSON.stringify(corrupt))).toThrow();
  });
});
