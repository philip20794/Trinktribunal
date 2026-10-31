import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { canonicalJson, repositoryRoot } from './lib/catalogs.mjs';
import { syncAssets } from './validate-data.mjs';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');

// Refresh catalog bytes and synthetic handshakes, preserving rights decisions
// and intentionally incompatible handshake values.
export function syncCatalogReviews({ root = repositoryRoot, check = true } = {}) {
  const read = path => readFileSync(resolve(root, path), 'utf8');
  const update = (path, actual, expected) => {
    if (actual === expected) return;
    if (check) throw new Error(`Stale catalog metadata: ${path}; run node scripts/sync-catalog-metadata.mjs --sync`);
    writeFileSync(resolve(root, path), expected);
  };
  const catalogHash = hash(canonicalJson(JSON.parse(read('apps/client/assets/catalogs/manifest.json'))));
  const registryPath = 'docs/qa/rights-registry.json';
  const registryText = read(registryPath), registry = JSON.parse(registryText);
  let changed = false;
  for (const group of registry.packages) {
    for (const file of group.files) {
      if (!/^(?:apps\/client\/assets\/catalogs\/.+\.json|data\/(?:manifest\.json|rules\/(?:de|en)\.json|questions\/top-ten\/(?:de|en)\.json))$/.test(file.path)) continue;
      const digest = hash(readFileSync(resolve(root, file.path)));
      if (file.sha256 !== digest) { file.sha256 = digest; changed = true; }
    }
  }
  if (changed) update(registryPath, registryText, JSON.stringify(registry, null, 2) + '\n');

  const fixturePath = 'packages/protocol/fixtures/messages/room-v2.json';
  const fixtureText = read(fixturePath), fixture = JSON.parse(fixtureText);
  changed = false;
  for (const row of fixture.fixtures) {
    const previous = row.valid.handshake?.catalogHash;
    if (!previous || previous === catalogHash) continue;
    const replace = value => {
      if (!value || typeof value !== 'object') return;
      for (const [key, child] of Object.entries(value)) {
        if (key === 'catalogHash' && child === previous) { value[key] = catalogHash; changed = true; }
        else replace(child);
      }
    };
    replace(row);
  }
  if (changed) update(fixturePath, fixtureText, JSON.stringify(fixture, null, 2) + '\n');
  return catalogHash;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  if (args.length !== 1 || !['--sync', '--check'].includes(args[0])) throw new Error('Usage: node scripts/sync-catalog-metadata.mjs --sync|--check');
  const check = args[0] === '--check';
  syncAssets({ check });
  const catalogHash = syncCatalogReviews({ check });
  for (const script of ['generate-room-dtos.mjs', 'generate-codec-fixtures.mjs']) {
    execFileSync(process.execPath, [fileURLToPath(new URL(script, import.meta.url)), ...(check ? ['--check'] : [])], { stdio: 'inherit' });
  }
  process.stdout.write(`Catalog assets, rights, handshakes and codecs synchronized: ${catalogHash}\n`);
}
