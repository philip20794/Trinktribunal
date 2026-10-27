import { runInDurableObject } from 'cloudflare:test';
import { expect } from 'vitest';
import { createRoomMessage, RoomIds } from '../../src/protocol/room_message';
import type { RoomMessage } from '../../src/protocol/room_message.generated';
import { RoomRepository } from '../../src/room/repository';
import {
  socketRoom,
  authenticated,
  profile,
  handshake,
  requestId,
  type Peer,
} from './socket_helpers';

export async function result(peer: Peer) {
  for (let index = 0; index < 100; index++) {
    const frame = await peer.next();
    if (frame.type === 'ack' || frame.type === 'error') return frame;
  }
  throw new Error('NO_RESULT');
}
export async function allJudgesRoom(count = 3) {
  const room = await socketRoom(),
    host = await authenticated(room.code, room.credential),
    members = [{ ...host, credential: room.credential }];
  for (let index = 1; index < count; index++) {
    const join = await room.stub.join(
      createRoomMessage('join', {
        requestId: requestId(),
        profile: { ...profile, name: `Player ${index}` },
        handshake,
      }),
    );
    if (!join.ok) throw new Error('JOIN');
    members.push({ ...(await authenticated(room.code, join.message)), credential: join.message });
  }
  const read = () =>
    runInDurableObject(room.stub, (_room, ctx) => new RoomRepository(ctx.storage).read()!);
  const action = () => RoomIds.action(crypto.randomUUID());
  async function send(peer: Peer, command: RoomMessage) {
    peer.send(command);
    const ack = await result(peer);
    expect(ack, JSON.stringify({ command: command.type, ack })).toMatchObject({ type: 'ack' });
    await runInDurableObject(room.stub, (_room, ctx) => {
      ctx.storage.sql.exec('UPDATE action_limits SET updated = ?', Date.now() - 1000);
    });
    return ack;
  }
  await send(
    host.peer,
    createRoomMessage('reorderRoster', {
      actionId: action(),
      expectedRevision: (await read()).revision,
      playerIds: [...members.slice(1), members[0]!].map((m) => m.credential.playerId),
    }),
  );
  await send(
    host.peer,
    createRoomMessage('setConfig', {
      actionId: action(),
      expectedRevision: (await read()).revision,
      config: { ...(await read()).config, allJudges: true, targetCases: 3, requestedRuleEvents: 2 },
    }),
  );
  await send(
    host.peer,
    createRoomMessage('startGame', {
      actionId: action(),
      expectedRevision: (await read()).revision,
    }),
  );
  const initial = (await read()).game!;
  const command = async (type: 'acknowledgeNumber' | 'readyForOrdering' | 'beginOrdering') =>
    createRoomMessage(type, {
      actionId: action(),
      expectedRevision: (await read()).revision,
      gameId: initial.gameId!,
      roundId: initial.round!.id,
    });
  const snapshot = async (peer: Peer) => {
    const revision = (await read()).revision;
    peer.send(createRoomMessage('requestSnapshot', { requestId: requestId() }));
    for (let index = 0; index < 100; index++) {
      const frame = await peer.next();
      if (frame.type === 'snapshot' && frame.revision === revision) return frame;
    }
    throw new Error('NO_SNAPSHOT');
  };
  const ordering = async () => {
    for (const member of members) await send(member.peer, await command('acknowledgeNumber'));
    for (const member of members) await send(member.peer, await command('readyForOrdering'));
    await send(host.peer, await command('beginOrdering'));
  };
  const order = async (ids: readonly (typeof initial.effectiveRoster)[number][]) =>
    createRoomMessage('submitOrder', {
      actionId: action(),
      expectedRevision: (await read()).revision,
      gameId: initial.gameId!,
      roundId: initial.round!.id,
      order: ids,
      confirmed: true,
    });
  return { room, host, members, read, action, command, snapshot, ordering, order, initial, send };
}
