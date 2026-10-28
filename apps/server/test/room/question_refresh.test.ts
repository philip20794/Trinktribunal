import { evictDurableObject, runInDurableObject } from 'cloudflare:test';
import { afterEach, describe, expect, it } from 'vitest';
import { createRoomMessage } from '../../src/protocol/room_message';
import { attachment } from '../../src/room/sockets';
import { roomInPhase } from './game_phase_helpers';
import { result } from './all_judges_helpers';
import { authenticated, cleanupPeers, framesFromServerMessage, requestId } from './socket_helpers';

afterEach(cleanupPeers);
describe('authenticated question refresh wire route', () => {
  it('refuses refresh after the first publicly revealed digital number without a second draw', async () => {
    const f = await roomInPhase(false, 'revealing'),
      state = await f.read();
    await f.send(
      f.host.peer,
      createRoomMessage('revealNext', {
        actionId: f.action(),
        expectedRevision: state.revision,
        gameId: state.game!.gameId!,
        roundId: state.game!.round!.id,
        expectedCursor: 0,
      }),
    );
    const before = await f.read(),
      actor = f.members.find((m) => m.credential.playerId === before.game!.judgeId)!;
    actor.peer.send(
      createRoomMessage('rerollCurrentQuestion', {
        actionId: f.action(),
        expectedRevision: before.revision,
        gameId: before.game!.gameId!,
        roundId: before.game!.round!.id,
      }),
    );
    expect(await result(actor.peer)).toMatchObject({ type: 'error', code: 'INVALID_PHASE' });
    expect(await f.read()).toEqual(before);
  });
  for (const allJudges of [false, true]) {
    it(`uses judge/reader authority, synchronizes a fresh instance and preserves private values (${allJudges})`, async () => {
      const f = await roomInPhase(allJudges, 'ordering');
      if (allJudges) await f.send(f.host.peer, await f.order(f.initial.round!.recipients));
      const before = await f.read(),
        game = before.game!;
      const actor = f.members.find(
        (m) => m.credential.playerId === (allJudges ? game.readerId : game.judgeId),
      )!;
      expect(actor.credential.playerId).not.toBe(before.hostId);
      const command = createRoomMessage('rerollCurrentQuestion', {
        actionId: f.action(),
        expectedRevision: before.revision,
        gameId: game.gameId!,
        roundId: game.round!.id,
      });
      f.host.peer.send(command);
      expect(await result(f.host.peer)).toMatchObject({
        type: 'error',
        code: 'UNAUTHORIZED_ACTION',
      });
      expect(await f.read()).toEqual(before);
      await f.send(actor.peer, command);
      const after = await f.read();
      expect(after.game!.round!.id).not.toBe(game.round!.id);
      expect(after.game!.round!.numbers).toEqual(game.round!.numbers);
      expect(after.game!.round!.orders).toEqual([]);
      expect(after.game!.personCounts.reduce((sum, p) => sum + p.count, 0)).toBeGreaterThanOrEqual(
        game.personCounts.reduce((sum, p) => sum + p.count, 0),
      );
      for (const member of f.members) {
        const snapshot = await f.snapshot(member.peer);
        if (snapshot.type !== 'snapshot') throw new Error('SNAPSHOT');
        expect(snapshot.public.roundId).toBe(after.game!.round!.id);
        expect(snapshot.public.question).toEqual(after.game!.round!.question);
        expect(snapshot.public.completedCases).toBe(0);
        expect(snapshot.public.revealed).toEqual([]);
        expect(snapshot.private.ownOrder).toBeUndefined();
        expect(snapshot.private.ownNumber).toBe(
          game.round!.numbers.find((n) => n.playerId === member.credential.playerId)?.number,
        );
        expect(snapshot.public).not.toHaveProperty('numbers');
        expect(snapshot.public).not.toHaveProperty('questionDraws');
      }
      actor.peer.send(command);
      expect(await result(actor.peer)).toMatchObject({ type: 'ack', outcome: 'duplicate' });
      expect(await f.read()).toEqual(after);
      actor.peer.send(
        createRoomMessage('submitOrder', {
          actionId: f.action(),
          expectedRevision: after.revision,
          gameId: game.gameId!,
          roundId: game.round!.id,
          order: game.round!.recipients,
          confirmed: true,
        }),
      );
      expect(await result(actor.peer)).toMatchObject({ type: 'error', code: 'STALE_ROUND' });
      await evictDurableObject(f.room.stub);
      const resumed = await authenticated(f.room.code, actor.credential);
      expect(resumed.snapshot.public.roundId).toBe(after.game!.round!.id);
      expect((await f.read()).game).toEqual(after.game);
    });
  }
  for (const missing of [false, true])
    it(`rejects ${missing ? 'missing' : 'v1'} live protocol attachment without losing identity or round`, async () => {
      const f = await roomInPhase(false, 'numbers'),
        member = f.members[1]!,
        before = await f.read();
      await runInDurableObject(f.room.stub, (_room, ctx) => {
        const socket = ctx.getWebSockets().find((socket) => {
          const info = attachment(socket);
          return info?.kind === 'authenticated' && info.playerId === member.credential.playerId;
        })!;
        const info = attachment(socket);
        if (info?.kind !== 'authenticated') throw new Error('ATTACHMENT');
        const old = { ...info };
        if (missing) delete old.protocolVersion;
        else old.protocolVersion = 1;
        socket.serializeAttachment(old);
      });
      await evictDurableObject(f.room.stub);
      const frames = await framesFromServerMessage(
        f.room.stub,
        member.credential.playerId,
        createRoomMessage('ping', { requestId: requestId() }),
      );
      expect(frames).toHaveLength(1);
      expect(JSON.parse(frames[0]!)).toMatchObject({ type: 'error', code: 'PROTOCOL_MISMATCH' });
      expect(await result(member.peer)).toMatchObject({ type: 'error', code: 'PROTOCOL_MISMATCH' });
      expect(await member.peer.closed()).toBe(4400);
      const resumed = await authenticated(f.room.code, member.credential);
      expect(resumed.identity.playerId).toBe(member.credential.playerId);
      expect((await f.read()).game).toEqual(before.game);
    });
});
