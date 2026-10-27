import { runInDurableObject, evictDurableObject } from 'cloudflare:test';
import { afterEach, describe, expect, it } from 'vitest';
import { createRoomMessage, RoomIds } from '../../src/protocol/room_message';
import type { PlayerId, SnapshotMessage } from '../../src/protocol/room_message.generated';
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
  for (let i = 0; i < 50; i++) {
    const value = await peer.next();
    if (value.type === 'ack' || value.type === 'error') return value;
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
  const ids = [
    members[1]!.credential.playerId,
    members[2]!.credential.playerId,
    room.credential.playerId,
  ];
  host.peer.send(
    createRoomMessage('reorderRoster', {
      actionId: RoomIds.action('seats'),
      expectedRevision: (await read()).revision,
      playerIds: ids,
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
  const before = await read(),
    judge = members.find((member) => member.credential.playerId === before.game!.judgeId)!;
  const order = (
    ids: readonly PlayerId[],
    actionId = crypto.randomUUID(),
    revision = before.revision,
  ) =>
    createRoomMessage('submitOrder', {
      actionId: RoomIds.action(actionId),
      expectedRevision: revision,
      gameId: before.game!.gameId!,
      roundId: before.game!.round!.id,
      order: ids,
      confirmed: true,
    });
  return { room, host, members, read, before, judge, order };
}
describe('one authoritative private normal-judge order', () => {
  for (const malformed of ['missing', 'duplicate'] as const)
    it(`rejects ${malformed} IDs before committing any order`, async () => {
      const { before, judge, read, order } = await setup(),
        ids = before.game!.round!.recipients;
      const command = {
        ...order(ids),
        order: malformed === 'missing' ? [ids[0]!] : [ids[0]!, ids[0]!],
      };
      judge.peer.send(command);
      expect(await result(judge.peer)).toMatchObject({ type: 'error', code: 'INVALID_MESSAGE' });
      expect((await read()).game).toEqual(before.game);
      expect(await judge.peer.closed()).toBe(4400);
    });
  it('host cannot submit for the judge; incomplete/foreign permutations leave state unchanged', async () => {
    const { host, judge, before, read, order } = await setup();
    const ids = before.game!.round!.recipients;
    host.peer.send(order(ids));
    expect(await result(host.peer)).toMatchObject({ type: 'error', code: 'UNAUTHORIZED_ACTION' });
    judge.peer.send(order([ids[0]!, RoomIds.player('foreign')]));
    expect(await result(judge.peer)).toMatchObject({ type: 'error', code: 'INVALID_PERMUTATION' });
    expect(await read()).toEqual(before);
  });
  it('only the judge gets its committed order; duplicate after eviction does not mutate or redraw', async () => {
    const { room, members, read, before, judge, order } = await setup(),
      command = order([...before.game!.round!.recipients].reverse());
    judge.peer.send(command);
    expect(await result(judge.peer)).toMatchObject({ type: 'ack', outcome: 'committed' });
    const committed = await read();
    expect(committed.phase).toBe('revealing');
    expect(committed.game!.round!.orders).toEqual([
      { playerId: judge.credential.playerId, order: command.order },
    ]);
    expect(committed.game!.round!.revealCursor).toBe(0);
    expect(committed.game!.history).toEqual(before.game!.history);
    for (const member of members) {
      member.peer.send(createRoomMessage('requestSnapshot', { requestId: requestId() }));
      let snapshot: SnapshotMessage | undefined;
      for (let i = 0; i < 50; i++) {
        const frame = await member.peer.next();
        if (frame.type === 'snapshot' && frame.revision === committed.revision) {
          snapshot = frame;
          break;
        }
      }
      expect(snapshot).toBeDefined();
      expect(snapshot!.private.ownOrder).toEqual(
        member.credential.playerId === judge.credential.playerId ? command.order : undefined,
      );
      expect(snapshot!.public).not.toHaveProperty('orders');
      expect(snapshot!.public.revealed).toEqual([]);
    }
    await evictDurableObject(room.stub);
    judge.peer.send(command);
    expect(await result(judge.peer)).toMatchObject({ type: 'ack', outcome: 'duplicate' });
    expect(await read()).toEqual(committed);
    judge.peer.send(order(before.game!.round!.recipients, crypto.randomUUID(), committed.revision));
    expect(await result(judge.peer)).toMatchObject({ type: 'error', code: 'INVALID_PHASE' });
    expect(await read()).toEqual(committed);
  });
});
