import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { checkUiInventory } from '../check-ui-inventory.mjs';

const inventory = () => JSON.parse(readFileSync(new URL('../../docs/design/ui-inventory.json', import.meta.url), 'utf8'));
test('screen inventory covers every real feature source and all actual PNG review hashes', () => {
  assert.deepEqual(checkUiInventory(inventory()), { sections: 21, featureFiles: 35, assets: 33, quarantined: 3 });
});
test('new/unmapped sources and edited source assets cannot silently inherit an old review', () => {
  const missing = inventory(); missing.sections.shift();
  assert.throws(() => checkUiInventory(missing), /Unmapped feature source/);
  const stale = inventory(); stale.assets[0].sha256 = '0'.repeat(64);
  assert.throws(() => checkUiInventory(stale), /Stale PNG review/);
});
test('placeholder and misleading mockup title never become a production requirement; broken assets stay unbundled', () => {
  const placeholder = inventory(); placeholder.sections[0].references.push('03');
  assert.throws(() => checkUiInventory(placeholder), /Invalid screen reference/);
  const people = inventory(); people.references.find(ref => ref.id === '10').role = 'verdict';
  assert.throws(() => checkUiInventory(people), /Incorrect placeholder/);
  assert.throws(() => checkUiInventory(inventory(), { pubspecText: 'flutter:\n  assets:\n    - assets/ui/courtroom/\n' }), /Quarantined asset bundled/);
});
