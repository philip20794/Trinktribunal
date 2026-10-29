import { runInDurableObject, evictDurableObject } from 'cloudflare:test';
import { afterEach, describe, expect, it } from 'vitest';
import { createRoomMessage, RoomIds } from '../../src/protocol/room_message';
import type { PlayerId, Profile, RoomMessage } from '../../src/protocol/room_message.generated';
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
async function revision(stub: Awaited<ReturnType<typeof socketRoom>>['stub']) {
  return runInDurableObject(
    stub,
    (_room, ctx) =>
      JSON.parse(
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
      ).revision as number,
  );
}
async function nextType(peer: Peer, type: RoomMessage['type']) {
  for (let i = 0; i < 30; i++) {
    const message = await peer.next();
    if (message.type === type) return message;
  }
  throw Error('Expected ' + type);
}
async function nextDelta(peer: Peer, target: number) {
  for (let i = 0; i < 30; i++) {
    const message = await peer.next();
    if (message.type === 'delta' && message.revision === target) return message;
  }
  throw Error('Expected delta revision');
}
async function outcome(peer: Peer) {
  for (let i = 0; i < 30; i++) {
    const message = await peer.next();
    if (message.type === 'ack' || message.type === 'error') return message;
  }
  throw Error('Expected action outcome');
}
async function group() {
  const room = await socketRoom(),
    host = await authenticated(room.code, room.credential);
  const guests = [];
  for (let i = 0; i < 2; i++) {
    const result = await room.stub.join(
      createRoomMessage('join', { requestId: requestId(), profile, handshake }),
    );
    if (!result.ok) throw Error('join');
    guests.push({
      ...(await authenticated(room.code, result.message)),
      credential: result.message,
    });
  }
  return { room, host, guests };
}
function edit(expectedRevision: number, name: string, avatar: Profile['avatar'] = profile.avatar) {
  return createRoomMessage('editOwnProfile', {
    actionId: RoomIds.action(crypto.randomUUID()),
    expectedRevision,
    profile: { name, avatar },
  });
}
describe('confirmed live profiles', () => {
  it('disconnect/resume changes only presence and generation, never membership, profiles or room activity', async () => {
    const { room, host, guests } = await group(),
      member = guests[1]!,
      before = await revision(room.stub);
    const activity = await runInDurableObject(
      room.stub,
      (_room, ctx) =>
        JSON.parse(
          ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
        ).lastDomainActivity as number,
    );
    member.peer.socket.close(1000);
    await member.peer.closed();
    const offline = await nextDelta(host.peer, before + 1);
    expect(Object.keys(offline.publicChanges)).toEqual(['players']);
    expect(
      offline.publicChanges.players?.find(
        (player) => player.playerId === member.credential.playerId,
      )?.connected,
    ).toBe(false);
    expect(offline.publicChanges.players).toHaveLength(3);
    const resumed = await authenticated(room.code, member.credential);
    expect(resumed.identity.generation).toBe(2);
    expect(resumed.snapshot.you).toBe(member.credential.playerId);
    const online = await nextDelta(host.peer, before + 2);
    expect(
      online.publicChanges.players?.find((player) => player.playerId === member.credential.playerId)
        ?.connected,
    ).toBe(true);
    expect(
      online.publicChanges.players?.every((player) => player.profile.name === profile.name),
    ).toBe(true);
    await runInDurableObject(room.stub, (_room, ctx) => {
      const state = JSON.parse(
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
      );
      expect(state.members).toHaveLength(3);
      expect(state.lastDomainActivity).toBe(activity);
    });
  });
  it('only the host may reorder or remove lobby members; a removed credential cannot resume', async () => {
    const { room, host, guests } = await group(),
      a = guests[0]!,
      b = guests[1]!;
    const ids = [room.credential.playerId, a.credential.playerId, b.credential.playerId];
    a.peer.send(
      createRoomMessage('reorderRoster', {
        actionId: RoomIds.action(crypto.randomUUID()),
        expectedRevision: await revision(room.stub),
        playerIds: [...ids].reverse(),
      }),
    );
    expect(await nextType(a.peer, 'error')).toMatchObject({ code: 'UNAUTHORIZED_ACTION' });
    const head = await revision(room.stub);
    host.peer.send(
      createRoomMessage('reorderRoster', {
        actionId: RoomIds.action(crypto.randomUUID()),
        expectedRevision: head,
        playerIds: [ids[0]!, ids[2]!, ids[1]!],
      }),
    );
    expect(await nextType(host.peer, 'ack')).toMatchObject({ outcome: 'committed' });
    const reordered = await nextDelta(b.peer, head + 1);
    expect(reordered.publicChanges.players?.map((player) => player.playerId)).toEqual([
      ids[0],
      ids[2],
      ids[1],
    ]);
    host.peer.send(
      createRoomMessage('kick', {
        actionId: RoomIds.action(crypto.randomUUID()),
        expectedRevision: head + 1,
        targetPlayerId: a.credential.playerId,
        confirmed: true,
      }),
    );
    expect(await nextType(host.peer, 'ack')).toMatchObject({ outcome: 'committed' });
    expect(await nextType(a.peer, 'error')).toMatchObject({ code: 'CREDENTIAL_INVALID' });
    expect(await a.peer.closed()).toBe(4401);
    const removed = await nextDelta(b.peer, head + 2);
    expect(removed.publicChanges.players).toHaveLength(2);
    expect(
      await room.stub.authenticate(
        createRoomMessage('authenticate', {
          requestId: requestId(),
          resumeToken: a.credential.resumeToken,
          handshake,
        }),
      ),
    ).toMatchObject({ ok: false, code: 'CREDENTIAL_INVALID' });
  });
  it('a non-host edits only itself; all three clients receive a small redacted delta after persistence', async () => {
    const { room, host, guests } = await group(),
      author = guests[0]!,
      other = guests[1]!,
      before = await revision(room.stub);
    const message = edit(before, 'Neue Person', {
      ...profile.avatar,
      selections: { ...profile.avatar.selections, hair: 'long01' },
    });
    author.peer.send(message);
    expect(await nextType(author.peer, 'ack')).toMatchObject({
      actionId: message.actionId,
      outcome: 'committed',
      revision: before + 1,
    });
    for (const peer of [host.peer, author.peer, other.peer]) {
      const delta = await nextDelta(peer, before + 1);
      expect(Object.keys(delta.publicChanges).sort()).toEqual(['expiresAtUtc', 'players']);
      expect(delta.private).toEqual({});
      expect(
        delta.publicChanges.players?.find((p) => p.playerId === author.credential.playerId)
          ?.profile,
      ).toMatchObject({ name: 'Neue Person', avatar: { selections: { hair: 'long01' } } });
      expect(
        delta.publicChanges.players?.find((p) => p.playerId === room.credential.playerId)?.profile
          .name,
      ).toBe(profile.name);
      const raw = JSON.stringify(delta);
      expect(raw).not.toContain(author.credential.resumeToken);
      expect(raw).not.toContain('verifier');
      expect(raw).not.toContain('lobbyReceipts');
    }
    await runInDurableObject(room.stub, (_room, ctx) => {
      const state = JSON.parse(
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
      );
      expect(
        state.members.find((m: { playerId: PlayerId }) => m.playerId === author.credential.playerId)
          .profile.name,
      ).toBe('Neue Person');
      expect(state.lobbyReceipts).toHaveLength(1);
    });
  });
  it('concurrent global revisions accept one writer, reject the stale intention, and refresh/retry is explicit', async () => {
    const { room, host, guests } = await group(),
      a = guests[0]!,
      b = guests[1]!,
      before = await revision(room.stub);
    a.peer.send(edit(before, 'Alpha'));
    b.peer.send(edit(before, 'Beta'));
    const answers = await Promise.all([outcome(a.peer), outcome(b.peer)]);
    expect(answers.filter((message) => message.type === 'ack')).toHaveLength(1);
    expect(
      answers.filter((message) => message.type === 'error' && message.code === 'STALE_REVISION'),
    ).toHaveLength(1);
    const loser = answers[0]!.type === 'error' ? a : b,
      loserName = loser === a ? 'Alpha' : 'Beta';
    expect(await revision(room.stub)).toBe(before + 1);
    loser.peer.send(createRoomMessage('requestSnapshot', { requestId: requestId() }));
    expect(await nextType(loser.peer, 'snapshot')).toMatchObject({ revision: before + 1 });
    loser.peer.send(edit(before + 1, loserName));
    expect(await nextType(loser.peer, 'ack')).toMatchObject({
      outcome: 'committed',
      revision: before + 2,
    });
    const final = await nextDelta(host.peer, before + 2);
    expect(final.publicChanges.players?.map((p) => p.profile.name)).toContain('Alpha');
    expect(final.publicChanges.players?.map((p) => p.profile.name)).toContain('Beta');
  });
  it('action replay survives eviction without an extra revision, lease extension or duplicate broadcast', async () => {
    const { room, host, guests } = await group(),
      author = guests[0]!,
      before = await revision(room.stub),
      message = edit(before, 'Einmal');
    author.peer.send(message);
    expect(await nextType(author.peer, 'ack')).toMatchObject({ outcome: 'committed' });
    await nextDelta(author.peer, before + 1);
    await nextDelta(host.peer, before + 1);
    const persisted = await runInDurableObject(
      room.stub,
      (_room, ctx) =>
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
    );
    await evictDurableObject(room.stub);
    author.peer.send(message);
    expect(await nextType(author.peer, 'ack')).toMatchObject({
      outcome: 'duplicate',
      revision: before + 1,
    });
    await runInDurableObject(room.stub, (_room, ctx) =>
      expect(
        ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
      ).toBe(persisted),
    );
    author.peer.send({ ...message, profile: { ...message.profile, name: 'Anders' } });
    expect(await nextType(author.peer, 'error')).toMatchObject({ code: 'ACTION_ID_CONFLICT' });
    expect(await revision(room.stub)).toBe(before + 1);
  });
  it('unknown avatar/foreign player fields never change a persisted profile or grant host powers', async () => {
    for (const invalid of ['avatar', 'actor']) {
      const { room, host, guests } = await group(),
        author = guests[0]!,
        message = edit(await revision(room.stub), 'Untrusted');
      author.peer.send(
        invalid === 'avatar'
          ? {
              ...message,
              profile: {
                ...message.profile,
                avatar: {
                  ...profile.avatar,
                  selections: { ...profile.avatar.selections, hair: 'url:evil' },
                },
              },
            }
          : { ...message, targetPlayerId: room.credential.playerId },
      );
      expect((await nextType(author.peer, 'error')).type).toBe('error');
      await author.peer.closed();
      await runInDurableObject(room.stub, (_room, ctx) => {
        const state = JSON.parse(
          ctx.storage.sql.exec<{ state: string }>('SELECT state FROM room_record').one().state,
        );
        expect(
          state.members.every((m: { profile: Profile }) => m.profile.name === profile.name),
        ).toBe(true);
        expect(state.hostId).toBe(room.credential.playerId);
      });
      host.peer.send(createRoomMessage('requestSnapshot', { requestId: requestId() }));
      const snapshot = await nextType(host.peer, 'snapshot');
      expect(snapshot.type).toBe('snapshot');
    }
  });
});
