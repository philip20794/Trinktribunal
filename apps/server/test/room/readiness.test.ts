import { runInDurableObject, evictDurableObject } from 'cloudflare:test';
import { afterEach, describe, expect, it } from 'vitest';
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
async function result(peer: Peer) {
  for (let i = 0; i < 40; i++) {
    const frame = await peer.next();
    if (frame.type === 'ack' || frame.type === 'error') return frame;
  }
  throw new Error('NO_RESULT');
}
async function setup() {
  const room = await socketRoom(),
    host = await authenticated(room.code, room.credential),
    members = [{ ...host, credential: room.credential }];
  for (let i = 0; i < 2; i++) {
    const join = await room.stub.join(
      createRoomMessage('join', { requestId: requestId(), profile, handshake }),
    );
    if (!join.ok) throw new Error('JOIN');
    members.push({ ...(await authenticated(room.code, join.message)), credential: join.message });
  }
  const read = () =>
    runInDurableObject(room.stub, (_room, ctx) => new RoomRepository(ctx.storage).read()!);
  host.peer.send(
    createRoomMessage('reorderRoster', {
      actionId: RoomIds.action('seats'),
      expectedRevision: (await read()).revision,
      playerIds: [
        members[1]!.credential.playerId,
        members[2]!.credential.playerId,
        room.credential.playerId,
      ],
    }),
  );
  await result(host.peer);
  host.peer.send(
    createRoomMessage('setConfig', {
      actionId: RoomIds.action('config'),
      expectedRevision: (await read()).revision,
      config: {
        targetCases: 3,
        requestedRuleEvents: 0,
        factorTenths: 15,
        allJudges: false,
        contentLanguage: 'de',
      },
    }),
  );
  await result(host.peer);
  host.peer.send(
    createRoomMessage('startGame', {
      actionId: RoomIds.action('start'),
      expectedRevision: (await read()).revision,
    }),
  );
  await result(host.peer);
  const command = async (
    type: 'acknowledgeNumber' | 'readyForOrdering' | 'beginOrdering' | 'completeWithoutVerdict',
    id = crypto.randomUUID(),
  ) => {
    const state = await read();
    return {
      type,
      protocolVersion: 1,
      actionId: id,
      expectedRevision: state.revision,
      gameId: state.game!.gameId!,
      roundId: state.game!.round!.id,
      ...(type === 'completeWithoutVerdict' ? { confirmed: true } : {}),
    };
  };
  const answers = async () => {
    const state = await read();
    for (const member of members.filter((member) =>
      state.game!.round!.recipients.includes(member.credential.playerId),
    )) {
      member.peer.send(await command('acknowledgeNumber'));
      expect(await result(member.peer)).toMatchObject({ type: 'ack' });
    }
  };
  return { room, host, members, read, command, answers };
}
describe('own phase readiness and conservative D-07 waiting', () => {
  it('needs separate oral-answer readiness from every frozen participant, including the judge', async () => {
    const { room, host, members, read, command, answers } = await setup();
    await answers();
    const before = await read();
    expect(before.phase).toBe('answers');
    expect(before.game!.round!.answerReady).toEqual([]);
    expect(before.game!.judgeId).not.toBe(room.credential.playerId);
    host.peer.send(await command('beginOrdering'));
    expect(await result(host.peer)).toMatchObject({ type: 'error', code: 'INVALID_PHASE' });
    for (const member of members) {
      member.peer.send(await command('readyForOrdering'));
      expect(await result(member.peer)).toMatchObject({ type: 'ack' });
    }
    expect((await read()).phase).toBe('answers');
    const judge = members.find((member) => member.credential.playerId === before.game!.judgeId)!;
    judge.peer.send(await command('beginOrdering'));
    expect(await result(judge.peer)).toMatchObject({ type: 'error', code: 'UNAUTHORIZED_ACTION' });
    host.peer.send(await command('beginOrdering'));
    expect(await result(host.peer)).toMatchObject({ type: 'ack' });
    const after = await read();
    expect(after.phase).toBe('ordering');
    expect(after.game!.round!.orders).toEqual([]);
    expect(after.game!.history).toEqual(before.game!.history);
    expect(after.game!.personCounts).toEqual(before.game!.personCounts);
  });

  it('replays the same ready action after eviction without another mutation; late new ready is stale', async () => {
    const { room, host, read, command, answers } = await setup();
    await answers();
    const ready = await command('readyForOrdering');
    host.peer.send(ready);
    expect(await result(host.peer)).toMatchObject({ type: 'ack' });
    const before = await read();
    await evictDurableObject(room.stub);
    host.peer.send(ready);
    expect(await result(host.peer)).toMatchObject({ type: 'ack', outcome: 'duplicate' });
    expect(await read()).toEqual(before);
    host.peer.send(await command('completeWithoutVerdict'));
    expect(await result(host.peer)).toMatchObject({ type: 'ack' });
    const after = await read();
    expect(after.game!.completedCases).toBe(1);
    expect(after.game!.round!.answerReady).toEqual([]);
    host.peer.send({ ...ready, actionId: 'late_ready', expectedRevision: after.revision });
    expect(await result(host.peer)).toMatchObject({ type: 'error', code: 'STALE_ROUND' });
    expect(await read()).toEqual(after);
  });

  it('does not advance when a ready participant disconnects; reconnect resumes the same case', async () => {
    const { room, host, members, read, command, answers } = await setup();
    await answers();
    for (const member of members) {
      member.peer.send(await command('readyForOrdering'));
      await result(member.peer);
    }
    const before = await read(),
      missing = members[1]!;
    missing.peer.socket.close(1000);
    await missing.peer.closed();
    // The authoritative snapshot with disconnected status is the event barrier.
    for (let i = 0; i < 40; i++) {
      const frame = await host.peer.next();
      if (
        frame.type === 'snapshot' &&
        frame.revision > before.revision &&
        frame.public.players.some(
          (player) => player.playerId === missing.credential.playerId && !player.connected,
        )
      )
        break;
    }
    host.peer.send(await command('beginOrdering'));
    expect(await result(host.peer)).toMatchObject({ type: 'error', code: 'INVALID_PHASE' });
    const waiting = await read();
    expect(waiting.phase).toBe('answers');
    expect(waiting.game!.completedCases).toBe(0);
    expect(waiting.game!.round!.orders).toEqual([]);
    await authenticated(room.code, missing.credential);
    host.peer.send(await command('beginOrdering'));
    expect(await result(host.peer)).toMatchObject({ type: 'ack' });
    const resumed = await read();
    expect(resumed.phase).toBe('ordering');
    expect(resumed.game!.round!.numbers).toEqual(before.game!.round!.numbers);
    expect(resumed.game!.history).toEqual(before.game!.history);
  });

  it('newly joined members cannot ready somebody in the frozen case', async () => {
    const { room, read, command, answers } = await setup();
    await answers();
    const join = await room.stub.join(
      createRoomMessage('join', { requestId: requestId(), profile, handshake }),
    );
    if (!join.ok) throw new Error('JOIN');
    const later = await authenticated(room.code, join.message),
      before = await read();
    later.peer.send(await command('readyForOrdering'));
    expect(await result(later.peer)).toMatchObject({ type: 'error', code: 'UNAUTHORIZED_ACTION' });
    expect(await read()).toEqual(before);
  });

  it('upgrades pre-TT-047 stored rounds without implicit readiness, redraw or revision', async () => {
    const { room, host, read, command, answers } = await setup();
    await answers();
    const before = await read();
    await runInDurableObject(room.stub, (_room, ctx) => {
      const raw = JSON.parse(
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
      );
      delete raw.game.round.answerReady;
      ctx.storage.sql.exec(
        'UPDATE room_record SET state = ? WHERE singleton = 1',
        JSON.stringify(raw),
      );
    });
    await evictDurableObject(room.stub);
    const migrated = await read();
    expect(migrated.game!.round!.answerReady).toEqual([]);
    expect(migrated.revision).toBe(before.revision);
    expect(migrated.game!.history).toEqual(before.game!.history);
    host.peer.send(await command('readyForOrdering'));
    expect(await result(host.peer)).toMatchObject({ type: 'ack' });
    expect((await read()).game!.round!.answerReady).toEqual([room.credential.playerId]);
  });
});
