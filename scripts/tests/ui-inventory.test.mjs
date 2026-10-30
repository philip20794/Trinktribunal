import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { checkUiInventory } from '../check-ui-inventory.mjs';

const inventory = () => JSON.parse(readFileSync(new URL('../../docs/design/ui-inventory.json', import.meta.url), 'utf8'));
test('screen inventory covers every real feature source and all actual PNG review hashes', () => {
  assert.deepEqual(checkUiInventory(inventory()), { sections: 22, featureFiles: 46, assets: 27, quarantined: 0 });
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
  const quarantined = inventory(); quarantined.assets[0].review = 'quarantine';
  assert.throws(() => checkUiInventory(quarantined), /Quarantined asset bundled/);
});
test('redesign completion requires every mapped section and preserves skipped manual acceptance', () => {
  const missing = inventory();
  delete missing.sections[0].implementation;
  assert.throws(() => checkUiInventory(missing), /Incomplete redesign section/);
  const invented = inventory(); invented.redesign.browserTestsRun = true;
  assert.throws(() => checkUiInventory(invented), /Invalid redesign\/manual acceptance/);
});
