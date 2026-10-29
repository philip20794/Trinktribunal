import { runInDurableObject, evictDurableObject } from 'cloudflare:test';
import { afterEach, describe, expect, it } from 'vitest';
import { createRoomMessage, RoomIds } from '../../src/protocol/room_message';
import type { SnapshotMessage } from '../../src/protocol/room_message.generated';
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
  for (let i = 0; i < 60; i++) {
    const frame = await peer.next();
    if (frame.type === 'ack' || frame.type === 'error') return frame;
  }
  throw new Error('NO_RESULT');
}
async function setup() {
  const room = await socketRoom(),
    host = await authenticated(room.code, room.credential),
    members = [{ ...host, credential: room.credential }];
  for (let i = 0; i < 3; i++) {
    const join = await room.stub.join(
      createRoomMessage('join', {
        requestId: requestId(),
        profile: { ...profile, name: `Player ${i}` },
        handshake,
      }),
    );
    if (!join.ok) throw new Error('JOIN');
    members.push({ ...(await authenticated(room.code, join.message)), credential: join.message });
  }
  const read = () =>
    runInDurableObject(room.stub, (_room, ctx) => new RoomRepository(ctx.storage).read()!);
  const seats = [
    members[1]!.credential.playerId,
    members[2]!.credential.playerId,
    members[3]!.credential.playerId,
    room.credential.playerId,
  ];
  host.peer.send(
    createRoomMessage('reorderRoster', {
      actionId: RoomIds.action('seats'),
      expectedRevision: (await read()).revision,
      playerIds: seats,
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
  const command = async (type: 'acknowledgeNumber' | 'readyForOrdering' | 'beginOrdering') => {
    const state = await read();
    return createRoomMessage(type, {
      actionId: RoomIds.action(crypto.randomUUID()),
      expectedRevision: state.revision,
      gameId: state.game!.gameId!,
      roundId: state.game!.round!.id,
    });
  };
  const initial = await read();
  for (const member of members.filter((member) =>
    initial.game!.round!.recipients.includes(member.credential.playerId),
  )) {
    member.peer.send(await command('acknowledgeNumber'));
    await result(member.peer);
  }
  for (const member of members) {
    member.peer.send(await command('readyForOrdering'));
    await result(member.peer);
  }
  host.peer.send(await command('beginOrdering'));
  await result(host.peer);
  const state = await read(),
    judge = members.find((member) => member.credential.playerId === state.game!.judgeId)!;
  const truth = [...state.game!.round!.numbers]
      .sort((a, b) => a.number - b.number)
      .map((entry) => entry.playerId),
    proposed = [truth[1]!, truth[0]!, truth[2]!];
  judge.peer.send(
    createRoomMessage('submitOrder', {
      actionId: RoomIds.action('order'),
      expectedRevision: state.revision,
      gameId: state.game!.gameId!,
      roundId: state.game!.round!.id,
      order: proposed,
      confirmed: true,
    }),
  );
  expect(await result(judge.peer)).toMatchObject({ type: 'ack' });
  const reveal = async (cursor: number, id = crypto.randomUUID()) => {
    const state = await read();
    return createRoomMessage('revealNext', {
      actionId: RoomIds.action(id),
      expectedRevision: state.revision,
      gameId: state.game!.gameId!,
      roundId: state.game!.round!.id,
      expectedCursor: cursor,
    });
  };
  async function snapshot(peer: Peer, revision: number) {
    peer.send(createRoomMessage('requestSnapshot', { requestId: requestId() }));
    for (let i = 0; i < 60; i++) {
      const message = await peer.next();
      if (message.type === 'snapshot' && message.revision === revision) return message;
    }
    throw new Error('NO_SNAPSHOT');
  }
  return { room, host, members, judge, read, truth, proposed, reveal, snapshot };
}
describe('authoritative reveal prefix and normal verdict', () => {
  it('each cursor exposes only the committed prefix; score is first published after full reveal', async () => {
    const { host, members, read, truth, proposed, reveal, snapshot } = await setup();
    const before = await read(),
      numbers = before.game!.round!.numbers;
    for (let cursor = 0; cursor <= proposed.length; cursor++) {
      const state = await read();
      expect(state.game!.round!.revealCursor).toBe(cursor);
      for (const member of members) {
        const view = await snapshot(member.peer, state.revision);
        expect(view.public.judgeOrder).toEqual(proposed);
        expect(view.public.revealed).toEqual(
          proposed.slice(0, cursor).map((playerId) => ({
            playerId,
            number: numbers.find((entry) => entry.playerId === playerId)!.number,
          })),
        );
        expect(view.public).not.toHaveProperty('numbers');
        expect(view.public).not.toHaveProperty('truth');
        expect(view.private.ownNumber).toBe(
          numbers.find((entry) => entry.playerId === member.credential.playerId)?.number,
        );
        if (cursor < proposed.length) {
          expect(view.public.result).toBeUndefined();
          expect(state.game!.round!.score).toBeNull();
        } else {
          expect(view.public.phase).toBe('judged');
          expect(view.public.result!.errors).toBe(2);
          for (const penalty of view.public.result!.penalties)
            expect(penalty.sips).toBe(penalty.playerId === truth[2] ? 0 : 2);
        }
      }
      if (cursor < proposed.length) {
        host.peer.send(await reveal(cursor));
        expect(await result(host.peer)).toMatchObject({ type: 'ack' });
      }
    }
    const completed = await read();
    expect(completed.game!.history).toEqual(before.game!.history);
    expect(completed.game!.personCounts).toEqual(before.game!.personCounts);
  });
  it('rejects unrelated participants or stale cursor, replays once after eviction, and preserves verdict on profile changes', async () => {
    const { room, host, judge, members, read, reveal, snapshot } = await setup();
    const unrelated = members.find(
      (member) =>
        member.credential.playerId !== judge.credential.playerId &&
        member.credential.playerId !== host.snapshot.you,
    )!;
    unrelated.peer.send(await reveal(0));
    expect(await result(unrelated.peer)).toMatchObject({
      type: 'error',
      code: 'UNAUTHORIZED_ACTION',
    });
    const first = await reveal(0);
    host.peer.send(first);
    expect(await result(host.peer)).toMatchObject({ type: 'ack' });
    const one = await read();
    await evictDurableObject(room.stub);
    host.peer.send(first);
    expect(await result(host.peer)).toMatchObject({ type: 'ack', outcome: 'duplicate' });
    expect(await read()).toEqual(one);
    host.peer.send(await reveal(0));
    expect(await result(host.peer)).toMatchObject({ type: 'error', code: 'STALE_REVISION' });
    expect(await read()).toEqual(one);
    for (let cursor = 1; cursor < one.game!.round!.recipients.length; cursor++) {
      host.peer.send(await reveal(cursor));
      expect(await result(host.peer)).toMatchObject({ type: 'ack' });
    }
    const judged = await read();
    judge.peer.send(
      createRoomMessage('editOwnProfile', {
        actionId: RoomIds.action('rename'),
        expectedRevision: judged.revision,
        profile: { ...profile, name: 'Renamed judge' },
      }),
    );
    expect(await result(judge.peer)).toMatchObject({ type: 'ack' });
    const after = await read();
    expect(after.game!.round!.score).toEqual(judged.game!.round!.score);
    expect(after.game!.round!.numbers).toEqual(judged.game!.round!.numbers);
    const view = await snapshot(host.peer, after.revision);
    expect(
      view.public.players.find((player) => player.playerId === judge.credential.playerId)!.profile
        .name,
    ).toBe('Renamed judge');
    expect(view.public.result).toEqual(
      judged.game!.round!.score?.kind === 'normal'
        ? {
            errors: judged.game!.round!.score.errors,
            penalties: judged.game!.round!.score.penalties,
          }
        : undefined,
    );
  });
});
