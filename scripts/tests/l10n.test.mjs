import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
const root = fileURLToPath(new URL('../../', import.meta.url));

test('German/English ARB keys, interpolation and generated Dart stay in sync', () => {
  const de = JSON.parse(fs.readFileSync(join(root,'apps/client/lib/l10n/app_de.arb'), 'utf8'));
  const en = JSON.parse(fs.readFileSync(join(root,'apps/client/lib/l10n/app_en.arb'), 'utf8'));
  const keys = source => Object.keys(source).filter(k => !k.startsWith('@')).sort();
  const placeholders = source => [...source.matchAll(/\{([A-Za-z][A-Za-z0-9]*)\}/g)].map(x=>x[1]).sort();
  assert.equal(de['@@locale'], 'de');
  assert.equal(en['@@locale'], 'en');
  assert.deepEqual(keys(de),keys(en));
  for (const key of keys(de)) {
    assert.equal(typeof de[key], 'string');
    assert.equal(typeof en[key], 'string');
    assert.deepEqual(placeholders(de[key]), placeholders(en[key]), key);
  }
  execFileSync(process.execPath, [join(root,'scripts/generate-l10n.mjs'), '--check'], {stdio: 'pipe', cwd: tmpdir()});
  for (const path of fs.readdirSync(join(root,'apps/client/lib'),{recursive:true}).filter(p=>p.endsWith('.dart'))) {
    const source=fs.readFileSync(join(root,'apps/client/lib',path),'utf8');
    for(const match of source.matchAll(/\b(?:tr|TText)\(\s*['"]([A-Za-z][A-Za-z0-9_]*)['"]/g)) assert.ok(match[1] in de, `Missing UI key ${match[1]} in ${path}`);
  }
});
