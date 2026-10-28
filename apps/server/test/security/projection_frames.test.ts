import { runInDurableObject } from 'cloudflare:test';
import { createHash } from 'node:crypto';
import { afterEach, expect, it } from 'vitest';
import { createRoomMessage, decodeRoomMessage, RoomIds } from '../../src/protocol/room_message';
import {
  protocolMetadata,
  type RoomMessage,
  type SnapshotMessage,
} from '../../src/protocol/room_message.generated';
import { RoomRepository } from '../../src/room/repository';
import {
  auth,
  authenticated,
  cleanupPeers,
  connect,
  handshake,
  profile,
  requestId,
  socketRoom,
  type Peer,
} from '../room/socket_helpers';
import { result } from '../room/all_judges_helpers';

afterEach(cleanupPeers);

async function projection(peer: Peer): Promise<RoomMessage> {
  const start = await peer.next();
  if (start.type !== 'projectionStart') return start;
  const chunks: Uint8Array[] = [];
  for (let index = 0; index < start.chunks; index++) {
    const frame = await peer.next();
    if (frame.type !== 'projectionChunk') throw new Error('EXPECTED_CHUNK');
    expect(frame).toMatchObject({
      requestId: start.requestId,
      transferId: start.transferId,
      index,
    });
    const chunk = Uint8Array.from(atob(frame.data.replaceAll('-', '+').replaceAll('_', '/')), (c) =>
      c.charCodeAt(0),
    );
    expect(chunk.length).toBeLessThanOrEqual(protocolMetadata.limits.projectionChunkBytes);
    chunks.push(chunk);
  }
  expect(await peer.next()).toMatchObject({
    type: 'projectionEnd',
    requestId: start.requestId,
    transferId: start.transferId,
  });
  const bytes = new Uint8Array(chunks.reduce((count, chunk) => count + chunk.length, 0));
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  expect(bytes.length).toBe(start.bytes);
  expect(createHash('sha256').update(bytes).digest('hex')).toBe(start.sha256);
  const message = decodeRoomMessage(
    new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(bytes),
    {
      direction: 'server',
      logical: true,
    },
  );
  expect(message).toMatchObject({ requestId: start.requestId, revision: start.revision });
  return message;
}

it('large permitted Unicode profiles travel as bounded private snapshots and lobby deltas', async () => {
  const room = await socketRoom();
  const host = await authenticated(room.code, room.credential);
  const credentials = [room.credential];
  const name = 'A' + '\u0301'.repeat(4500);
  expect([
    ...new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(name),
  ]).toHaveLength(1);
  for (let index = 0; index < 2; index++) {
    const command = createRoomMessage('join', {
      requestId: requestId(),
      handshake,
      profile: { ...profile, name },
    });
    expect(new TextEncoder().encode(JSON.stringify(command)).length).toBeLessThan(
      protocolMetadata.limits.frameBytes,
    );
    const joined = await room.stub.join(command);
    if (!joined.ok) throw new Error('JOIN');
    credentials.push(joined.message);
  }
  let delta: RoomMessage;
  do {
    delta = await projection(host.peer);
  } while (delta.type !== 'delta' || delta.publicChanges.players?.length !== 3);
  expect(delta.private).toEqual({});
  expect(delta.publicChanges.players!.filter((p) => p.profile.name === name)).toHaveLength(2);

  const peers = [host.peer];
  for (const credential of credentials.slice(1)) {
    const peer = await connect(room.code);
    peer.send(auth(credential));
    expect(await peer.next()).toMatchObject({
      type: 'authenticated',
      playerId: credential.playerId,
    });
    const snapshot = await projection(peer);
    expect(snapshot).toMatchObject({ type: 'snapshot', you: credential.playerId, private: {} });
    peers.push(peer);
  }
  const read = () =>
    runInDurableObject(room.stub, (_room, ctx) => new RoomRepository(ctx.storage).read()!);
  host.peer.send(
    createRoomMessage('startGame', {
      actionId: RoomIds.action('start'),
      expectedRevision: (await read()).revision,
    }),
  );
  expect(await result(host.peer)).toMatchObject({ type: 'ack' });
  const state = await read();
  expect(state.phase).toBe('numbers');
  for (const [index, peer] of peers.entries()) {
    let view: RoomMessage;
    do {
      view = await projection(peer);
    } while (view.type !== 'snapshot' || view.public.phase !== 'numbers');
    const snapshot = view as SnapshotMessage;
    expect(snapshot.you).toBe(credentials[index]!.playerId);
    const number = state.game!.round!.numbers.find((n) => n.playerId === snapshot.you)?.number;
    expect(snapshot.private).toEqual(number === undefined ? {} : { ownNumber: number });
    expect(snapshot.public.revealed).toEqual([]);
    for (const credential of credentials)
      expect(JSON.stringify(snapshot)).not.toContain(credential.resumeToken);
    for (const frame of peer.frames)
      expect(new TextEncoder().encode(frame).length).toBeLessThanOrEqual(
        protocolMetadata.limits.frameBytes,
      );
    expect(peer.frames.some((frame) => JSON.parse(frame).type === 'projectionStart')).toBe(true);
  }
}, 30000);
