import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { checkProductionConfig } from '../check-production-config.mjs';
import { checkWebPolicy } from '../check-web-release.mjs';
import { webSecurityPolicy } from '../web-security.mjs';

const read = path => JSON.parse(readFileSync(new URL('../../' + path, import.meta.url), 'utf8'));
function fixture() { return [read('docs/config/production.example.json'), read('apps/server/wrangler.release.example.jsonc')]; }
test('production example separates public origins from local bindings and cannot masquerade as configured deployment', () => {
  const [config, worker] = fixture(), result = checkProductionConfig(config, worker);
  assert.equal(result.exampleOnly, true); assert.equal(result.deploymentPerformed, false);
  assert.throws(() => checkProductionConfig(config, worker, { requireRealOrigins: true }), /Replace example origins/);
});
test('real HTTPS origins must agree with worker CORS before a production build', () => {
  const [config, worker] = fixture();
  config.apiBaseUrl = 'https://api.example.org'; config.publicClientBaseUrl = 'https://app.example.org';
  assert.throws(() => checkProductionConfig(config, worker), /origin\/telemetry policy/);
  worker.vars.CLIENT_ORIGINS = config.publicClientBaseUrl;
  assert.equal(checkProductionConfig(config, worker, { requireRealOrigins: true }).exampleOnly, false);
});
test('release examples cannot accept cleartext, secret-bearing config or development overrides', () => {
  const [config, worker] = fixture();
  assert.throws(() => checkProductionConfig({ ...config, apiBaseUrl: 'http://localhost:8787' }, worker), /HTTPS origin/);
  assert.throws(() => checkProductionConfig({ ...config, token: 'synthetic-secret' }, worker), /public production configuration/);
  assert.throws(() => checkProductionConfig(config, { ...worker, dev: { port: 8787 } }), /policy mismatch/);
});
test('worker must keep one local SQLite room binding and avoid undeclared resources', () => {
  const [config, worker] = fixture();
  const remote = structuredClone(worker); remote.durable_objects.bindings[0].remote = true;
  assert.throws(() => checkProductionConfig(config, remote), /binding\/migration/);
  assert.throws(() => checkProductionConfig(config, { ...worker, migrations: [] }), /binding\/migration/);
  assert.throws(() => checkProductionConfig(config, { ...worker, r2_buckets: [{ binding: 'EXTRA' }] }), /additional production resource/);
});
test('CanvasKit Wasm permission and inline styles do not imply JavaScript eval or inline scripts', () => {
  const policy = webSecurityPolicy('https://api.example.org');
  assert.deepEqual(checkWebPolicy(policy), ["'self'", 'https://api.example.org', 'wss://api.example.org']);
});
test('release policy rejects JavaScript eval, inline scripts and remote entry-script origins', () => {
  const policy = webSecurityPolicy();
  for (const extra of ["'unsafe-eval'", "'unsafe-inline'", 'https://cdn.example.org'])
    assert.throws(() => checkWebPolicy(policy.replace("script-src 'self'", `script-src 'self' ${extra}`)));
});
test('production package check rejects local HTTP websocket origins and missing security policy', () => {
  assert.throws(() => checkWebPolicy(webSecurityPolicy('http://localhost:8787')), /HTTPS origin/);
  assert.throws(() => checkWebPolicy(null));
});
