import { runInDurableObject, evictDurableObject } from 'cloudflare:test';
import { afterEach, describe, expect, it } from 'vitest';
import { createRoomMessage, RoomIds } from '../../src/protocol/room_message';
import type {
  RoomMessage,
  SnapshotMessage,
  PlayerId,
} from '../../src/protocol/room_message.generated';
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
async function frame(peer: Peer, type: RoomMessage['type']) {
  for (let i = 0; i < 40; i++) {
    const next = await peer.next();
    if (next.type === type) return next;
  }
  throw new Error(type);
}
async function setup(allJudges = false) {
  const room = await socketRoom(),
    host = await authenticated(room.code, room.credential),
    members = [{ ...host, credential: room.credential }];
  for (let i = 0; i < 2; i++) {
    const join = await room.stub.join(
      createRoomMessage('join', {
        requestId: requestId(),
        profile: { ...profile, name: `Guest ${i}` },
        handshake,
      }),
    );
    if (!join.ok) throw new Error('JOIN');
    members.push({ ...(await authenticated(room.code, join.message)), credential: join.message });
  }
  const read = () =>
    runInDurableObject(room.stub, (_room, ctx) => new RoomRepository(ctx.storage).read()!);
  const roster = [
    members[1]!.credential.playerId,
    members[2]!.credential.playerId,
    room.credential.playerId,
  ];
  host.peer.send(
    createRoomMessage('reorderRoster', {
      actionId: RoomIds.action('seats'),
      expectedRevision: (await read()).revision,
      playerIds: roster,
    }),
  );
  await frame(host.peer, 'ack');
  host.peer.send(
    createRoomMessage('setConfig', {
      actionId: RoomIds.action('config'),
      expectedRevision: (await read()).revision,
      config: {
        targetCases: 3,
        requestedRuleEvents: 2,
        factorTenths: 15,
        allJudges,
        contentLanguage: 'en',
      },
    }),
  );
  await frame(host.peer, 'ack');
  host.peer.send(
    createRoomMessage('startGame', {
      actionId: RoomIds.action('start'),
      expectedRevision: (await read()).revision,
    }),
  );
  await frame(host.peer, 'ack');
  const state = await read(),
    views: SnapshotMessage[] = [];
  for (const member of members) {
    for (let i = 0; i < 40; i++) {
      const next = (await frame(member.peer, 'snapshot')) as SnapshotMessage;
      if (next.public.phase === 'numbers') {
        views.push(next);
        break;
      }
    }
  }
  expect(views).toHaveLength(3);
  return { room, host, members, views, state, read };
}
describe('own-number projections with frozen server configuration', () => {
  for (const allJudges of [false, true])
    it(`sends only own numbers, allJudges=${allJudges}`, async () => {
      const { room, views, state } = await setup(allJudges),
        round = state.game!.round!;
      expect(state.game!.judgeId).not.toBe(room.credential.playerId);
      for (const view of views) {
        const own = round.numbers.find((entry) => entry.playerId === view.you);
        expect(view.private).toEqual(own ? { ownNumber: own.number } : {});
        expect(view.public.config.contentLanguage).toBe('en');
        expect(view.public.config.factorTenths).toBe(15);
        expect(view.public.question).toEqual(round.question);
        expect(view.public.revealed).toEqual([]);
        expect(view.public).not.toHaveProperty('numbers');
        expect(view.public).not.toHaveProperty('ownNumber');
        expect(view.public).not.toHaveProperty('history');
        expect(view.public).not.toHaveProperty('receipts');
      }
      expect(
        new Set(
          views.map((view) => view.private.ownNumber).filter((number) => number !== undefined),
        ).size,
      ).toBe(allJudges ? 3 : 2);
    });

  it('keeps assignment/history/counters unchanged across eviction and credential resume', async () => {
    const { room, host, read, state } = await setup(false),
      own = state.game!.round!.numbers.find(
        (entry) => entry.playerId === room.credential.playerId,
      )!;
    await evictDurableObject(room.stub);
    const resumed = await authenticated(room.code, room.credential);
    expect(resumed.snapshot.private).toEqual({ ownNumber: own.number });
    const after = await read();
    expect(after.game!.round).toEqual(state.game!.round);
    expect(after.game!.history).toEqual(state.game!.history);
    expect(after.game!.personCounts).toEqual(state.game!.personCounts);
    expect(await host.peer.closed()).toBe(4409);
  });

  it('acknowledges only the actor number and keeps host configuration frozen', async () => {
    const { host, members, views, state, read } = await setup(false),
      judge = state.game!.judgeId!;
    const judgeMember = members.find((member) => member.credential.playerId === judge)!;
    judgeMember.peer.send(
      createRoomMessage('acknowledgeNumber', {
        actionId: RoomIds.action('judge_ack'),
        expectedRevision: state.revision,
        gameId: state.game!.gameId!,
        roundId: state.game!.round!.id,
      }),
    );
    expect(await frame(judgeMember.peer, 'error')).toMatchObject({ code: 'UNAUTHORIZED_ACTION' });
    host.peer.send(
      createRoomMessage('setConfig', {
        actionId: RoomIds.action('change_frozen'),
        expectedRevision: state.revision,
        config: { ...state.config, contentLanguage: 'de' },
      }),
    );
    expect(await frame(host.peer, 'error')).toMatchObject({ code: 'INVALID_PHASE' });
    expect(await read()).toEqual(state);
    for (const view of views.filter((view) => view.private.ownNumber !== undefined)) {
      const member = members.find((member) => member.credential.playerId === view.you)!;
      member.peer.send(
        createRoomMessage('acknowledgeNumber', {
          actionId: RoomIds.action(`ack_${view.you}`),
          expectedRevision: (await read()).revision,
          gameId: state.game!.gameId!,
          roundId: state.game!.round!.id,
        }),
      );
      const ack = await frame(member.peer, 'ack');
      expect(Object.keys(ack).sort()).toEqual([
        'actionId',
        'outcome',
        'protocolVersion',
        'requestId',
        'revision',
        'type',
      ]);
    }
    const after = await read();
    expect(after.phase).toBe('answers');
    expect(after.game!.history).toEqual(state.game!.history);
    expect(after.game!.round!.numbers).toEqual(state.game!.round!.numbers);
  });

  it('refuses a one-person start without committing a question', async () => {
    const room = await socketRoom(),
      host = await authenticated(room.code, room.credential);
    host.peer.send(
      createRoomMessage('startGame', {
        actionId: RoomIds.action('too_few'),
        expectedRevision: host.snapshot.revision,
      }),
    );
    expect(await frame(host.peer, 'error')).toMatchObject({ code: 'INVALID_CONFIG' });
    const after = await runInDurableObject(room.stub, (_room, ctx) =>
      new RoomRepository(ctx.storage).read()!,
    );
    expect(after.phase).toBe('lobby');
    expect(after.game).toBeUndefined();
  });
});
