import { env } from 'cloudflare:workers';
import fixtures from '../../../../packages/protocol/fixtures/messages/room-v1.json';
import worker from '../../src/index';
import { createRoomMessage, decodeRoomMessage, RoomIds } from '../../src/protocol/room_message';
import type { CredentialMessage } from '../../src/protocol/room_message.generated';
import { randomRoomCode } from '../../src/http/rooms';

const initial = decodeRoomMessage(
  JSON.stringify(fixtures.fixtures.find((f) => f.valid.type === 'create')!.valid),
);
if (initial.type !== 'create') throw Error('create fixture');
export const profile = initial.profile,
  handshake = initial.handshake;
export const requestId = () => RoomIds.request(crypto.randomUUID());
export async function socketRoom() {
  const code = randomRoomCode(),
    stub = env.ROOMS.getByName(code);
  const result = await stub.createIfAbsent(
    code,
    createRoomMessage('create', { requestId: requestId(), profile, handshake }),
  );
  if ('collision' in result || !result.ok) throw Error('create');
  return { code, stub, credential: result.message };
}
export function auth(credential: CredentialMessage) {
  return createRoomMessage('authenticate', {
    requestId: requestId(),
    handshake,
    resumeToken: credential.resumeToken,
  });
}
export const peers: Peer[] = [];
export class Peer {
  readonly frames: string[] = [];
  private queue: string[] = [];
  private waiting: ((value: string) => void) | null = null;
  private closedCode: number | null = null;
  private waitingClose: ((value: number) => void) | null = null;
  constructor(readonly socket: WebSocket) {
    socket.addEventListener('message', (event) => {
      const raw = String(event.data);
      this.frames.push(raw);
      if (this.waiting) {
        this.waiting(raw);
        this.waiting = null;
      } else this.queue.push(raw);
    });
    socket.addEventListener('close', (event) => {
      this.closedCode = event.code;
      this.waitingClose?.(event.code);
      this.waitingClose = null;
    });
    socket.accept();
    peers.push(this);
  }
  async next() {
    const raw =
      this.queue.shift() ?? (await new Promise<string>((resolve) => (this.waiting = resolve)));
    return decodeRoomMessage(raw, { direction: 'server' });
  }
  async closed() {
    return this.closedCode ?? new Promise<number>((resolve) => (this.waitingClose = resolve));
  }
  send(message: unknown) {
    this.socket.send(typeof message === 'string' ? message : JSON.stringify(message));
  }
}
export async function upgrade(code: string, headers: Record<string, string> = {}) {
  return worker.fetch(
    new Request(`http://localhost/api/rooms/${code}/socket`, {
      headers: { Upgrade: 'websocket', 'CF-Connecting-IP': crypto.randomUUID(), ...headers },
    }),
    env,
  );
}
export async function connect(code: string, headers: Record<string, string> = {}) {
  const response = await upgrade(code, headers);
  if (response.status !== 101 || !response.webSocket) throw Error('Upgrade ' + response.status);
  return new Peer(response.webSocket);
}
export async function authenticated(code: string, credential: CredentialMessage) {
  const peer = await connect(code);
  peer.send(auth(credential));
  const identity = await peer.next(),
    snapshot = await peer.next();
  if (identity.type !== 'authenticated' || snapshot.type !== 'snapshot')
    throw Error('Auth then snapshot required');
  return { peer, identity, snapshot };
}
export async function cleanupPeers() {
  await Promise.all(
    peers.splice(0).map(async (peer) => {
      if (peer.socket.readyState === 1) peer.socket.close(1000);
      await peer.closed();
    }),
  );
}
