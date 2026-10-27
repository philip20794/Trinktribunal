import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';

test('German/English ARB keys, interpolation and generated Dart stay in sync', () => {
  const de = JSON.parse(fs.readFileSync('apps/client/lib/l10n/app_de.arb', 'utf8'));
  const en = JSON.parse(fs.readFileSync('apps/client/lib/l10n/app_en.arb', 'utf8'));
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
  execFileSync(process.execPath, ['scripts/generate-l10n.mjs', '--check'], {stdio: 'pipe'});
});
