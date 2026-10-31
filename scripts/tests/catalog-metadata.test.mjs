import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join, resolve, basename } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { syncCatalogReviews } from '../sync-catalog-metadata.mjs';
import { canonicalJson } from '../lib/catalogs.mjs';

test('catalog updates refresh reviews and valid handshakes without altering negative cases or other rights records', t => {
  const root = mkdtempSync(join(tmpdir(), 'trinktribunal-catalog-metadata-'));
  t.after(() => {
    if (dirname(root) !== resolve(tmpdir()) || !basename(root).startsWith('trinktribunal-catalog-metadata-')) throw new Error('Unsafe cleanup');
    rmSync(root, { recursive: true, force: true });
  });
  const put = (path, value) => {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), typeof value === 'string' ? value : JSON.stringify(value, null, 2) + '\n');
  };
  const read = path => JSON.parse(readFileSync(join(root, path), 'utf8'));
  const manifest = { catalogs: [{ kind: 'rules', sha256: 'b'.repeat(64) }] };
  put('apps/client/assets/catalogs/manifest.json', manifest);
  put('data/rules/de.json', '{"rules":[]}\n');
  const rights = { packages: [{ status: 'unresolved', files: [
    { path: 'data/rules/de.json', sha256: '0'.repeat(64) },
    { path: 'apps/client/assets/catalogs/manifest.json', sha256: '0'.repeat(64) },
    { path: 'apps/client/lib/design/example.dart', sha256: '1'.repeat(64) },
  ] }] };
  put('docs/qa/rights-registry.json', rights);
  const old = 'a'.repeat(64), incompatible = 'f'.repeat(64);
  put('packages/protocol/fixtures/messages/room-v2.json', { fixtures: [
    { valid: { handshake: { catalogHash: old } }, invalid: { handshake: { catalogHash: incompatible } } },
    { valid: { handshake: { catalogHash: old } }, invalid: { handshake: { catalogHash: old }, actorId: 'spoofed' } },
  ] });
  assert.throws(() => syncCatalogReviews({ root }), /Stale catalog metadata/);
  assert.deepEqual(read('docs/qa/rights-registry.json'), rights, 'check must not repair files');
  const expected = createHash('sha256').update(canonicalJson(manifest)).digest('hex');
  assert.equal(syncCatalogReviews({ root, check: false }), expected);
  const fixture = read('packages/protocol/fixtures/messages/room-v2.json');
  assert.equal(fixture.fixtures[0].valid.handshake.catalogHash, expected);
  assert.equal(fixture.fixtures[0].invalid.handshake.catalogHash, incompatible);
  assert.equal(fixture.fixtures[1].invalid.handshake.catalogHash, expected);
  assert.equal(fixture.fixtures[1].invalid.actorId, 'spoofed');
  const reviewed = read('docs/qa/rights-registry.json');
  assert.equal(reviewed.packages[0].status, 'unresolved');
  assert.deepEqual(reviewed.packages[0].files[2], rights.packages[0].files[2]);
  assert.equal(reviewed.packages[0].files[0].sha256, createHash('sha256').update(readFileSync(join(root, 'data/rules/de.json'))).digest('hex'));
  assert.equal(syncCatalogReviews({ root }), expected);
  put('data/rules/de.json', '{"rules":[1]}\n');
  assert.throws(() => syncCatalogReviews({ root }), /Stale catalog metadata/);
});

test('full catalog synchronization check works from outside the repository', () => {
  execFileSync(process.execPath, [fileURLToPath(new URL('../sync-catalog-metadata.mjs', import.meta.url)), '--check'], { cwd: tmpdir(), stdio: 'pipe' });
});
