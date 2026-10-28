import { evictDurableObject, runInDurableObject } from 'cloudflare:test';
import { afterEach, expect, it } from 'vitest';
import { migrateRoomState } from '../../src/room/migrations';
import { createRoomMessage } from '../../src/protocol/room_message';
import { protocolMetadata } from '../../src/protocol/room_message.generated';
import { attachment } from '../../src/room/sockets';
import { roomInPhase } from './game_phase_helpers';
import {
  authenticated,
  cleanupPeers,
  requestId,
  connect,
  auth,
  framesFromServerMessage,
} from './socket_helpers';
import { result } from './all_judges_helpers';

afterEach(cleanupPeers);

it('old v1 handshakes receive a specific mismatch before identity or private data', async () => {
  const f = await roomInPhase(false, 'numbers');
  const peer = await connect(f.room.code);
  const command = auth(f.room.credential);
  peer.send({ ...command, handshake: { ...command.handshake, avatarVersion: 1 } });
  expect(await peer.next()).toMatchObject({ type: 'error', code: 'AVATAR_MISMATCH' });
  expect(await peer.closed()).toBe(4400);
  expect(peer.frames).toHaveLength(1);
});

it('known avatar v1 migration preserves every identity, selection and game value across eviction', async () => {
  const f = await roomInPhase(false, 'ordering');
  const before = await f.read();
  const legacy = JSON.parse(JSON.stringify(before));
  for (const member of legacy.members) member.profile.avatar.version = 1;
  const migrated = migrateRoomState(JSON.stringify(legacy));
  expect(migrated.migrated).toBe(true);
  expect(migrated.state).toEqual(before);
  expect(migrateRoomState(JSON.stringify(migrated.state)).migrated).toBe(false);
  await runInDurableObject(f.room.stub, (_room, ctx) => {
    ctx.storage.sql.exec('UPDATE room_record SET state = ?', JSON.stringify(legacy));
  });
  await evictDurableObject(f.room.stub);
  expect(await f.read()).toEqual(before);
});

it('a new option pretending to be a legacy avatar is not guessed or migrated', async () => {
  const f = await roomInPhase(false, 'numbers');
  const legacy = JSON.parse(JSON.stringify(await f.read()));
  legacy.members[0].profile.avatar.version = 1;
  legacy.members[0].profile.avatar.selections.hat = 'tricorn';
  expect(() => migrateRoomState(JSON.stringify(legacy))).toThrow('ROOM_UNAVAILABLE');
});

it('a pre-upgrade live attachment gets an explicit mismatch and can resume the same identity with v2', async () => {
  const f = await roomInPhase(true, 'numbers');
  const member = f.members[2]!;
  await f.snapshot(member.peer);
  const before = await f.read();
  await runInDurableObject(f.room.stub, (_room, ctx) => {
    const socket = ctx.getWebSockets().find((socket) => {
      const info = attachment(socket);
      return info?.kind === 'authenticated' && info.playerId === member.credential.playerId;
    })!;
    const info = attachment(socket);
    if (info?.kind !== 'authenticated') throw new Error('ATTACHMENT');
    const legacy = { ...info };
    delete legacy.avatarVersion;
    socket.serializeAttachment(legacy);
  });
  await evictDurableObject(f.room.stub);
  const frames = await framesFromServerMessage(
    f.room.stub,
    member.credential.playerId,
    createRoomMessage('ping', { requestId: requestId() }),
  );
  expect(await result(member.peer)).toMatchObject({ type: 'error', code: 'AVATAR_MISMATCH' });
  expect(await member.peer.closed()).toBe(4400);
  expect(frames).toHaveLength(1);
  expect(frames.every((frame) => JSON.parse(frame).type === 'error')).toBe(true);
  const resumed = await authenticated(f.room.code, member.credential);
  expect(resumed.identity.playerId).toBe(member.credential.playerId);
  expect(resumed.identity.handshake.avatarVersion).toBe(protocolMetadata.avatarVersion);
  expect(resumed.snapshot.private.ownNumber).toBe(
    before.game!.round!.numbers.find((n) => n.playerId === member.credential.playerId)!.number,
  );
  expect((await f.read()).game!.personCounts).toEqual(before.game!.personCounts);
  expect((await f.read()).game!.history).toEqual(before.game!.history);
});
