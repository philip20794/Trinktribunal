import { runInDurableObject, evictDurableObject } from 'cloudflare:test';
import { afterEach, describe, expect, it } from 'vitest';
import { createRoomMessage, RoomIds } from '../../src/protocol/room_message';
import { RoomRepository, type RoomState } from '../../src/room/repository';
import { commitGameAction } from '../../src/room/actions';
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
type Stub = Awaited<ReturnType<typeof socketRoom>>['stub'];
const read = (stub: Stub) =>
  runInDurableObject(stub, (_room, ctx) => new RoomRepository(ctx.storage).read()!);
async function group() {
  const room = await socketRoom(),
    host = await authenticated(room.code, room.credential),
    guests = [];
  for (let i = 0; i < 2; i++) {
    const joined = await room.stub.join(
      createRoomMessage('join', { requestId: requestId(), profile, handshake }),
    );
    if (!joined.ok) throw new Error('JOIN');
    guests.push({
      ...(await authenticated(room.code, joined.message)),
      credential: joined.message,
    });
  }
  return { room, host, guests };
}
async function outcome(peer: Peer) {
  for (let i = 0; i < 40; i++) {
    const frame = await peer.next();
    if (frame.type === 'ack' || frame.type === 'error') return frame;
  }
  throw new Error('NO_OUTCOME');
}
function action(state: RoomState, type: string, extra: Record<string, unknown> = {}) {
  return {
    type,
    protocolVersion: 2,
    actionId: RoomIds.action(crypto.randomUUID()),
    expectedRevision: state.revision,
    ...(!['startGame', 'setConfig'].includes(type) ? { gameId: state.game?.gameId } : {}),
    ...(['completeWithoutVerdict', 'acknowledgeNumber'].includes(type)
      ? { roundId: state.game?.round?.id }
      : {}),
    ...(['restartGame', 'completeWithoutVerdict'].includes(type) ? { confirmed: true } : {}),
    ...extra,
  };
}
const config = {
  targetCases: 3,
  requestedRuleEvents: 2,
  factorTenths: 15,
  allJudges: false,
  contentLanguage: 'de',
} as const;
async function send(peer: Peer, command: unknown) {
  peer.send(command);
  const result = await outcome(peer);
  expect(result).toMatchObject({ type: 'ack', outcome: 'committed' });
  return result;
}

describe('atomic authoritative game actions in actual SQLite/hibernating room', () => {
  it('bounds the shared action journal while credential revocation remains available', async () => {
    const { room, host } = await group();
    await runInDurableObject(room.stub, (_room, ctx) => {
      const repository = new RoomRepository(ctx.storage),
        state = repository.read()!;
      state.lobbyReceipts = Array.from({ length: 16384 }, (_, index) => ({
        actionId: `previous_${index}`,
        playerId: state.hostId,
        fingerprint: '0'.repeat(64),
        revision: 0,
      }));
      repository.write(state);
    });
    const before = await read(room.stub);
    host.peer.send(action(before, 'startGame'));
    expect(await outcome(host.peer)).toMatchObject({ type: 'error', code: 'RATE_LIMITED' });
    expect(await read(room.stub)).toEqual(before);
    expect(
      await room.stub.leave(
        createRoomMessage('leaveHttp', {
          requestId: requestId(),
          resumeToken: room.credential.resumeToken,
          actionId: RoomIds.action('leave_at_limit'),
          confirmed: true,
        }),
      ),
    ).toMatchObject({ ok: true });
  });
  it('serializes concurrent starts and stores draws, counters and receipts before the ACK', async () => {
    const { room, host } = await group();
    const before = await read(room.stub);
    const first = action(before, 'startGame'),
      second = action(before, 'startGame');
    host.peer.send(first);
    host.peer.send(second);
    expect(await outcome(host.peer)).toMatchObject({
      type: 'ack',
      outcome: 'committed',
      revision: before.revision + 1,
    });
    expect(await outcome(host.peer)).toMatchObject({ type: 'error', code: 'STALE_REVISION' });
    expect(await host.peer.next()).toMatchObject({
      type: 'snapshot',
      revision: before.revision + 1,
      public: { phase: 'numbers' },
    });
    const after = await read(room.stub);
    expect(after.revision).toBe(before.revision + 1);
    expect(after.game!.history).toHaveLength(1);
    expect(after.game!.drawnQuestionIds).toHaveLength(1);
    expect(after.game!.receipts).toHaveLength(1);
    expect(after.game!.round!.numbers).toHaveLength(2);
    const bound = new Set(Object.values(after.game!.round!.question.bindings));
    for (const entry of after.game!.personCounts)
      expect(entry.count).toBe(bound.has(entry.playerId) ? 1 : 0);
    expect(after.historyOwners?.[after.game!.history[0]!.eventId]).toBe(room.credential.playerId);
    for (const raw of host.peer.frames) {
      const wire = JSON.parse(raw);
      if (wire.type === 'snapshot') {
        expect(wire).not.toHaveProperty('historyOwners');
        expect(wire.public).not.toHaveProperty('history');
        expect(wire.public).not.toHaveProperty('numbers');
      }
    }
  });

  it('rolls back real SQLite failure without success broadcast; retry commits once', async () => {
    const { room, host } = await group();
    const before = await read(room.stub),
      command = action(before, 'startGame');
    await runInDurableObject(room.stub, (_room, ctx) => {
      ctx.storage.sql.exec(
        "CREATE TRIGGER fail_room_commit BEFORE INSERT ON room_record BEGIN SELECT RAISE(ABORT, 'injected storage failure'); END",
      );
    });
    host.peer.send(command);
    expect(await host.peer.closed()).toBe(1011);
    expect(await read(room.stub)).toEqual(before);
    expect(host.peer.frames.some((raw) => JSON.parse(raw).type === 'ack')).toBe(false);
    await runInDurableObject(room.stub, (_room, ctx) => {
      ctx.storage.sql.exec('DROP TRIGGER fail_room_commit');
    });
    const resumed = await authenticated(room.code, room.credential);
    await send(resumed.peer, action(await read(room.stub), 'startGame'));
    const state = await read(room.stub);
    expect(state.game!.history).toHaveLength(1);
    expect(state.game!.receipts).toHaveLength(1);
  });

  it('replays a lost ACK after real eviction without another draw or lease extension', async () => {
    const { room, host } = await group();
    const command = action(await read(room.stub), 'startGame');
    await send(host.peer, command);
    const committed = await read(room.stub);
    await evictDurableObject(room.stub);
    host.peer.send(command);
    expect(await outcome(host.peer)).toMatchObject({
      type: 'ack',
      outcome: 'duplicate',
      revision: committed.revision,
    });
    expect(await read(room.stub)).toEqual(committed);
    host.peer.send({ ...command, expectedRevision: committed.revision });
    expect(await outcome(host.peer)).toMatchObject({ type: 'error', code: 'ACTION_ID_CONFLICT' });
    expect(await read(room.stub)).toEqual(committed);
  });

  it('counts repeated D-07 completion and its next rule slot once across eviction', async () => {
    const { room, host } = await group();
    await send(host.peer, action(await read(room.stub), 'setConfig', { config }));
    await send(host.peer, action(await read(room.stub), 'startGame'));
    const started = await read(room.stub),
      command = action(started, 'completeWithoutVerdict');
    await send(host.peer, command);
    const completed = await read(room.stub);
    expect(completed.game!.completedCases).toBe(1);
    expect(completed.phase).toBe('rule_event');
    expect(completed.game!.ruleSlots[0]!.status).toBe('activated');
    expect(completed.game!.lastCompletion!.score).toBeNull();
    expect(completed.game!.drawnQuestionIds).toEqual(started.game!.drawnQuestionIds);
    expect(completed.game!.history).toHaveLength(2);
    const oldJudge = started.game!.judgeId!,
      seats = started.game!.effectiveRoster;
    expect(completed.game!.judgeId).toBe(seats[(seats.indexOf(oldJudge) + 1) % seats.length]);
    await evictDurableObject(room.stub);
    host.peer.send(command);
    expect(await outcome(host.peer)).toMatchObject({ type: 'ack', outcome: 'duplicate' });
    expect(await read(room.stub)).toEqual(completed);
    const continueCommand = action(completed, 'continueRule', { afterCase: 1 });
    await send(host.peer, continueCommand);
    const next = await read(room.stub);
    host.peer.send(command);
    expect(await outcome(host.peer)).toMatchObject({ type: 'ack', outcome: 'duplicate' });
    expect(await read(room.stub)).toEqual(next);
  });

  it('restart preserves room usage, resets person counts and invalidates old-game actions', async () => {
    const { room, host } = await group();
    await send(host.peer, action(await read(room.stub), 'startGame'));
    const old = await read(room.stub),
      oldCommand = action(old, 'completeWithoutVerdict');
    await send(host.peer, oldCommand);
    const before = await read(room.stub),
      restart = action(before, 'restartGame', { config });
    await send(host.peer, restart);
    const state = await read(room.stub);
    expect(state.game!.gameId).not.toBe(old.game!.gameId);
    expect(state.game!.history.slice(0, before.game!.history.length)).toEqual(before.game!.history);
    expect(state.game!.completedCases).toBe(0);
    expect(state.game!.drawnQuestionIds).toHaveLength(1);
    const bound = new Set(Object.values(state.game!.round!.question.bindings));
    for (const entry of state.game!.personCounts)
      expect(entry.count).toBe(bound.has(entry.playerId) ? 1 : 0);
    host.peer.send(oldCommand);
    expect(await outcome(host.peer)).toMatchObject({ type: 'error', code: 'STALE_ROUND' });
    host.peer.send(restart);
    expect(await outcome(host.peer)).toMatchObject({ type: 'ack', outcome: 'duplicate' });
    expect(await read(room.stub)).toEqual(state);
  });

  it('rejects stale authenticated generation and cross-action ID reuse in both directions', async () => {
    const { room, host } = await group(),
      before = await read(room.stub);
    const rejected = await runInDurableObject(room.stub, (_room, ctx) =>
      commitGameAction(
        new RoomRepository(ctx.storage),
        { playerId: room.credential.playerId, generation: 0 },
        action(before, 'startGame'),
        new Set([room.credential.playerId]),
      ),
    );
    expect(rejected).toMatchObject({ ok: false, code: 'CREDENTIAL_INVALID' });
    const start = action(before, 'startGame');
    await send(host.peer, start);
    host.peer.send(
      createRoomMessage('editOwnProfile', {
        actionId: start.actionId,
        expectedRevision: (await read(room.stub)).revision,
        profile,
      }),
    );
    expect(await outcome(host.peer)).toMatchObject({ type: 'error', code: 'ACTION_ID_CONFLICT' });
  });
});
