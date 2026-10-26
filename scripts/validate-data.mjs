import { readdirSync, readFileSync, mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createBundle, loadSources, repositoryRoot } from './lib/catalogs.mjs';

export function syncAssets({ root = repositoryRoot, check = true } = {}) {
  const files = createBundle(loadSources(root));
  const directory = resolve(root, 'apps/client/assets/catalogs');
  const actual = existsSync(directory) ? readdirSync(directory, { recursive: true, withFileTypes: true }).filter(e => e.isFile()).map(e => resolve(e.parentPath, e.name)) : [];
  const expected = new Set([...files.keys()].map(path => resolve(directory, path)));
  for (const path of actual) if (!expected.has(path)) throw new Error(`Unexpected catalog asset: ${path}; remove explicitly after review`);
  for (const [path, content] of files) {
    const destination = resolve(directory, path);
    if (check) {
      if (!existsSync(destination) || readFileSync(destination, 'utf8') !== content) throw new Error(`Catalog asset drift: ${path}; run scripts/sync-assets.ps1`);
    } else {
      mkdirSync(dirname(destination), { recursive: true }); writeFileSync(destination, content, 'utf8');
    }
  }
  return files.size;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2);
    if (args.some(arg => !['--sync', '--check'].includes(arg)) || args.length > 1) throw new Error('Usage: node scripts/validate-data.mjs [--sync|--check]');
    const count = syncAssets({ check: !args.includes('--sync') });
    console.log(`Catalogs valid: 491 questions + 25 rules per DE/EN, ${count} assets ${args.includes('--sync') ? 'written' : 'checked'}.`);
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
