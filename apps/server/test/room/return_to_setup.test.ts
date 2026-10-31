import { evictDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { createRoomMessage } from '../../src/protocol/room_message';
import { roomInPhase } from './game_phase_helpers';
import { cleanupPeers } from './socket_helpers';

afterEach(cleanupPeers);
for (const allJudges of [false, true])
  for (const phase of ['numbers', 'finished', 'paused']) {
    it(`return to editable setup survives eviction and clears private gameplay: ${allJudges}/${phase}`, async () => {
      const f = await roomInPhase(allJudges, phase),
        before = await f.read();
      await f.send(
        f.host.peer,
        createRoomMessage('restartGame', {
          actionId: f.action(),
          expectedRevision: before.revision,
          gameId: before.game!.gameId!,
          config: before.config,
          confirmed: true,
          setupOnly: true,
        }),
      );
      const setup = await f.read();
      expect(setup.phase).toBe('lobby');
      expect(setup.game).toMatchObject({
        gameId: null,
        round: null,
        activeRules: [],
        completedCases: 0,
        lastCompletion: null,
      });
      expect(setup.game!.history).toEqual(before.game!.history);
      expect(setup.members.map((m) => m.playerId)).toEqual(before.members.map((m) => m.playerId));
      await evictDurableObject(f.room.stub);
      expect(await f.read()).toEqual(setup);
      const snapshot = await f.snapshot(f.host.peer);
      expect(snapshot.public).toMatchObject({
        phase: 'lobby',
        gameId: null,
        roundId: null,
        question: null,
        activeRules: [],
        completedCases: 0,
      });
      expect(snapshot.private).not.toHaveProperty('ownNumber');
      await f.send(
        f.host.peer,
        createRoomMessage('setConfig', {
          actionId: f.action(),
          expectedRevision: setup.revision,
          config: { ...setup.config, factorTenths: 40 },
        }),
      );
      if (phase !== 'paused') {
        await f.send(
          f.host.peer,
          createRoomMessage('startGame', {
            actionId: f.action(),
            expectedRevision: (await f.read()).revision,
          }),
        );
        const restarted = await f.read();
        expect(restarted.game!.gameId).not.toBe(before.game!.gameId);
        expect(restarted.game!.completedCases).toBe(0);
        expect(restarted.config.factorTenths).toBe(40);
      }
    });
  }
