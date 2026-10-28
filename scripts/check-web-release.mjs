import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createReleaseServer } from './serve-web.mjs';
import { measureWeb } from './web-performance.mjs';
import { releasePolicy } from './web-security.mjs';
import { httpsOrigin } from './check-android-release.mjs';

export function checkWebPolicy(policy) {
  const scripts = /(?:^|;\s*)script-src\s+([^;]+)/.exec(policy ?? '')?.[1];
  const scriptTokens = scripts?.split(/\s+/) ?? [];
  assert.ok(scriptTokens.includes("'self'") && scriptTokens.every(token => ["'self'", "'wasm-unsafe-eval'"].includes(token)));
  const connections = /(?:^|;\s*)connect-src\s+([^;]+)/.exec(policy ?? '')?.[1].split(/\s+/) ?? [];
  assert.ok(connections.includes("'self'"));
  for (const origin of connections.filter(value => value !== "'self'")) {
    if (origin.startsWith('wss://')) httpsOrigin(origin.replace('wss://', 'https://'));
    else httpsOrigin(origin);
  }
  return connections;
}

export async function checkWebRelease(root) {
  function privateFiles(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (entry.isSymbolicLink()) throw new Error('Symlink in web release');
      if (/^(?:\.env(?:\..*)?|key\.properties|local\.properties)$|\.(?:jks|keystore|pem|dart)$/i.test(entry.name))
        throw new Error('Private/development file in web release');
      if (entry.isDirectory()) privateFiles(join(directory, entry.name));
    }
  }
  privateFiles(root);
  const measurement = measureWeb(root);
  assert.deepEqual(measurement.builds.map(b => [b.compileTarget, b.renderer]), [['dart2js', 'canvaskit']]);
  assert.ok(measurement.precache?.files > 0, 'Complete offline package required');
  const policy = releasePolicy(readFileSync(join(root, 'index.html'), 'utf8'));
  const connections = checkWebPolicy(policy);
  const server = await createReleaseServer({ root }), requests = [];
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  const origin = `http://127.0.0.1:${server.address().port}`;
  try {
    for (const [path, status, mime, method] of [
      ['/', 200, 'text/html', 'GET'],
      ['/join/ABCD2345', 200, 'text/html', 'GET'],
      ['/missing-asset.js', 404, 'text/plain', 'GET'],
      ['/api/rooms', 404, 'text/plain', 'GET'],
      ['/.env', 404, 'text/plain', 'GET'],
      ['/main.dart.js', 200, 'text/javascript', 'HEAD'],
      ['/canvaskit/canvaskit.wasm', 200, 'application/wasm', 'HEAD'],
      ['/assets/assets/fonts/roboto-regular.ttf', 200, 'font/ttf', 'HEAD'],
      ['/service-worker.js', 200, 'text/javascript', 'GET'],
    ]) {
      const response = await fetch(origin + path, { method, headers: { Accept: 'text/html' } });
      assert.equal(response.status, status, path);
      assert.ok(response.headers.get('content-type')?.startsWith(mime), path);
      assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
      assert.ok(response.headers.get('content-security-policy')?.includes("frame-ancestors 'none'"));
      if (path === '/' || path === '/service-worker.js') assert.equal(response.headers.get('cache-control'), 'no-store');
      await response.arrayBuffer();
      requests.push({ path, status, mime });
    }
  } finally {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
  }
  return { renderer: 'JS/CanvasKit', totals: measurement.totals, precache: measurement.precache,
    configuredConnections: connections, requests, browserAcceptance: 'SKIPPED - later manual testing', deploymentPerformed: false };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const root = resolve(process.argv[2] ?? fileURLToPath(new URL('../apps/client/build/web', import.meta.url)));
    process.stdout.write(JSON.stringify(await checkWebRelease(root), null, 2) + '\n');
  } catch (error) { process.stderr.write(error.message + '\n'); process.exitCode = 1; }
}
