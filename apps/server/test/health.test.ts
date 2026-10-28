import { env } from 'cloudflare:workers';
import { runInDurableObject } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import worker from '../src/index';

describe('local worker health', () => {
  it('returns a small deterministic response without identity or credentials', async () => {
    const response = await worker.fetch(new Request('http://localhost/health'));
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      status: 'ok',
      service: 'trinktribunal',
      protocolVersion: 2,
    });
    expect(response.headers.get('Cache-Control')).toBe('no-store');
    expect(response.headers.get('Content-Type')).toContain('application/json');
  });
  it('supports HEAD and rejects mutation methods', async () => {
    expect(
      await (await worker.fetch(new Request('http://localhost/health', { method: 'HEAD' }))).text(),
    ).toBe('');
    const response = await worker.fetch(new Request('http://localhost/health', { method: 'POST' }));
    expect(response.status).toBe(405);
    expect(response.headers.get('Allow')).toBe('GET, HEAD');
  });
  it('keeps unknown and future room routes closed', async () => {
    for (const path of ['/', '/health/extra', '/api/rooms']) {
      const response = await worker.fetch(new Request('http://localhost' + path));
      expect(response.status).toBe(404);
      expect(await response.json()).toEqual({ error: 'NOT_FOUND' });
    }
  });
  it('provides a real local SQLite-backed Durable Object binding', async () => {
    const stub = env.ROOMS.getByName('unit-runtime-probe');
    await runInDurableObject(stub, (_room, state) => {
      const row = state.storage.sql.exec<{ value: number }>('SELECT 1 AS value').one();
      expect(row.value).toBe(1);
    });
    expect((await stub.fetch('http://room/')).status).toBe(404);
  });
});
