import { describe, expect, it } from 'vitest';
import fixtures from '../../../packages/protocol/fixtures/messages/room-v1.json';
import adversarial from '../../../packages/protocol/fixtures/messages/codec-cases.json';
import policies from '../../../packages/protocol/message-policies.json';
import worker from '../src/index';
import {
  decodeRoomMessage,
  createRoomMessage,
  encodeRoomMessage,
  ProtocolDecodeException,
  RoomIds,
  type RoundId,
} from '../src/protocol/room_message';

describe('shared room codec fixtures in Workerd', () => {
  it('rejects malformed HTTP input without reflecting secrets and keeps the worker responsive', async () => {
    const response = await worker.fetch(
      new Request('http://local/api/rooms', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{"resumeToken":"synthetic-secret"',
      }),
    );
    expect(response.status).toBe(400);
    const text = await response.text();
    expect(text).not.toContain('synthetic-secret');
    const message = decodeRoomMessage(text, { direction: 'server' });
    expect(message.type).toBe('error');
    if (message.type === 'error') expect(message.code).toBe('INVALID_MESSAGE');
    expect((await worker.fetch(new Request('http://local/health'))).status).toBe(200);
  });
  it('bounds streamed request bodies before parsing and rejects invalid UTF-8', async () => {
    let cancelled = false;
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new Uint8Array(10000));
        controller.enqueue(new Uint8Array(10000));
      },
      cancel() {
        cancelled = true;
      },
    });
    const response = await worker.fetch(
      new Request('http://local/api/rooms', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body,
      }),
    );
    expect(response.status).toBe(413);
    expect(cancelled).toBe(true);
    const malformed = await worker.fetch(
      new Request('http://local/api/rooms', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: new Uint8Array([0xff]),
      }),
    );
    expect(malformed.status).toBe(400);
    expect(((await malformed.json()) as { code: string }).code).toBe('INVALID_MESSAGE');
  });
  for (const fixture of fixtures.fixtures) {
    it(`${fixture.fixtureId}: decode, typed serialization, reject unknown authority`, () => {
      const policy = Object.entries(policies.messages).find(
        ([type]) => type === fixture.valid.type,
      )![1];
      const direction = policy.direction === 'server' ? 'server' : 'client';
      const message = decodeRoomMessage(JSON.stringify(fixture.valid), { direction });
      expect(JSON.parse(encodeRoomMessage(message))).toEqual(fixture.valid);
      expect(Object.isFrozen(message)).toBe(true);
      expect(() => decodeRoomMessage(JSON.stringify(fixture.invalid))).toThrow(
        ProtocolDecodeException,
      );
    });
  }
  for (const fixture of adversarial.cases) {
    it(`adversarial: ${fixture.name}`, () => {
      if (fixture.code === null) {
        const decoded = decodeRoomMessage(fixture.wire);
        expect(JSON.parse(encodeRoomMessage(decoded))).toEqual(JSON.parse(fixture.wire));
      } else {
        try {
          decodeRoomMessage(fixture.wire);
          throw Error('Accepted invalid fixture');
        } catch (error) {
          expect(error).toBeInstanceOf(ProtocolDecodeException);
          expect((error as ProtocolDecodeException).code).toBe(fixture.code);
        }
      }
    });
  }
  it('constructs outbound commands from typed IDs and still validates the payload', () => {
    const message = createRoomMessage('submitOrder', {
      actionId: RoomIds.action('a'),
      expectedRevision: 0,
      gameId: RoomIds.game('g'),
      roundId: RoomIds.round('r'),
      order: [RoomIds.player('p1'), RoomIds.player('p2')],
      confirmed: true,
    });
    expect(message.type).toBe('submitOrder');
    expect(message.gameId).toBe('g');
    expect(message.roundId).toBe('r');
    expect(JSON.parse(encodeRoomMessage(message)).actionId).toBe('a');
    expect(() => createRoomMessage('submitOrder', { ...message })).toThrow(ProtocolDecodeException);
  });
  it('keeps identifier namespaces distinct at compile time and validates their bytes', () => {
    const game = RoomIds.game('same');
    // @ts-expect-error A game identity cannot be used as a round identity.
    const wrong: RoundId = game;
    void wrong;
    expect(() => RoomIds.action('has spaces')).toThrow(ProtocolDecodeException);
  });
  it('does not retain mutable private data and masks validation errors', () => {
    const source = fixtures.fixtures.find((f) => f.valid.type === 'submitOrder')!.valid;
    const message = decodeRoomMessage(JSON.stringify(source));
    if (message.type !== 'submitOrder') throw Error('Wrong discriminant');
    expect(() => Reflect.apply(Array.prototype.push, message.order, ['foreign'])).toThrow();
    expect(() => decodeRoomMessage('{"resumeToken":"synthetic-secret"')).toThrow('INVALID_JSON');
    expect(() => decodeRoomMessage(JSON.stringify(source), { direction: 'server' })).toThrow(
      ProtocolDecodeException,
    );
  });
});
