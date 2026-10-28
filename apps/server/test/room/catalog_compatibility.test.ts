import { evictDurableObject, runInDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { attachment } from '../../src/room/sockets';
import { createRoomMessage } from '../../src/protocol/room_message';
import { roomInPhase } from './game_phase_helpers';
import { result } from './all_judges_helpers';
import { authenticated, cleanupPeers, requestId } from './socket_helpers';

afterEach(cleanupPeers);

for (const missing of [false, true]) {
  it(`a live connection with ${missing ? 'missing' : 'old'} catalog hash cannot continue mixed content and retains its identity`, async () => {
    const f = await roomInPhase(true, 'ordering');
    const member = f.members[2]!;
    await f.snapshot(member.peer);
    const before = await f.read(),
      start = member.peer.frames.length;
    await runInDurableObject(f.room.stub, (_room, ctx) => {
      const socket = ctx.getWebSockets().find((socket) => {
        const info = attachment(socket);
        return info?.kind === 'authenticated' && info.playerId === member.credential.playerId;
      })!;
      const info = attachment(socket);
      if (info?.kind !== 'authenticated') throw new Error('ATTACHMENT');
      const stale = { ...info };
      if (missing) delete stale.catalogHash;
      else stale.catalogHash = '0'.repeat(64);
      socket.serializeAttachment(stale);
    });
    await evictDurableObject(f.room.stub);
    member.peer.send(createRoomMessage('ping', { requestId: requestId() }));
    expect(await result(member.peer)).toMatchObject({ type: 'error', code: 'CATALOG_MISMATCH' });
    expect(await member.peer.closed()).toBe(4400);
    expect(
      member.peer.frames.slice(start).every((frame) => JSON.parse(frame).type === 'error'),
    ).toBe(true);
    const resumed = await authenticated(f.room.code, member.credential);
    expect(resumed.identity.playerId).toBe(member.credential.playerId);
    expect(resumed.snapshot.public.roundId).toBe(before.game!.round!.id);
    const after = await f.read();
    expect(after.game!.round).toEqual(before.game!.round);
    expect(after.game!.personCounts).toEqual(before.game!.personCounts);
    expect(after.game!.history).toEqual(before.game!.history);
  });
}
