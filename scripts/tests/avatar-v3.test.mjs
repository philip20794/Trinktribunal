import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const load = (path) => JSON.parse(readFileSync(new URL(path, import.meta.url), 'utf8'));
const manifest = load('../../apps/client/assets/avatars/manifest.json');
const style = load('../../apps/client/assets/avatars/dicebear/trinktribunal-adventurer-v1.json');
const protocol = load('../../packages/protocol/schemas/room-message.schema.json');
const samples = load('../../packages/protocol/fixtures/messages/room-v2.json');

const defaults = {
  hair: 'short03', eyes: 'variant05', eyebrows: 'variant03',
  mouth: 'variant04', glasses: 'none', earrings: 'none', details: 'none',
  outfit: 'tee', board: 'classic', skinColor: '#ecad80',
  hairColor: '#6a4e35', outfitColor: '#475e74',
};
const variantSource = {
  hair: 'hair', eyes: 'eyes', eyebrows: 'eyebrows', mouth: 'mouth',
  glasses: 'glasses', earrings: 'earrings', details: 'details',
  outfit: 'ttOutfit', board: 'ttBoard',
};

test('DiceBear v3 manifest contains selectable variant and color values', () => {
  assert.equal(manifest.version, 3);
  assert.equal(manifest.renderer, 'dicebear-adventurer-trinktribunal-v1');
  assert.deepEqual(manifest.canvas, style.canvas && {
    width: style.canvas.width, height: style.canvas.height,
  });
  for (const [key, value] of Object.entries(defaults))
    assert.ok(manifest.options[key].includes(value), key);
  for (const [key, source] of Object.entries(variantSource)) {
    const values = Object.keys(style.components[source].variants);
    assert.deepEqual(manifest.options[key],
      ['glasses', 'earrings', 'details'].includes(key) ? ['none', ...values] : values);
  }
  assert.deepEqual(manifest.options.skinColor, style.colors.skin.values);
  assert.deepEqual(manifest.options.hairColor, style.colors.hair.values);
  assert.deepEqual(manifest.options.outfitColor, style.colors.outfit.values);
  assert.equal(Object.keys(style.components.hair.variants).length, 45);
});

test('v3 protocol profile and the wire fixtures match the shared manifest', () => {
  const avatar = protocol.$defs.avatar;
  assert.equal(avatar.properties.version.const, manifest.version);
  assert.equal(protocol.$defs.handshake.properties.avatarVersion.const, manifest.version);
  assert.ok(avatar.required.includes('seed'));
  assert.deepEqual(avatar.properties.selections.required, Object.keys(manifest.options));
  for (const [name, values] of Object.entries(manifest.options)) {
    const selected = avatar.properties.selections.properties[name];
    if (name.endsWith('Color')) {
      assert.equal(selected.type, 'string');
      assert.equal(selected.pattern, '^#[A-Fa-f0-9]{6}$');
      assert.equal(selected.maxLength, 7);
    } else {
      assert.deepEqual(selected.enum, values);
    }
  }
  for (const fixture of samples.fixtures) {
    for (const message of [fixture.valid]) { // invalid fixtures intentionally violate the contract
      const profiles = [];
      if (message.profile) profiles.push(message.profile);
      for (const player of message.public?.players ?? []) profiles.push(player.profile);
      if (message.handshake?.avatarVersion)
        assert.equal(message.handshake.avatarVersion, 3);
      for (const profile of profiles) {
        assert.equal(profile.avatar.version, 3);
        assert.equal(typeof profile.avatar.seed, 'string');
        assert.deepEqual(Object.keys(profile.avatar.selections), Object.keys(manifest.options));
      }
    }
  }
});

test('original Adventurer parts, nameplate and license remain in bundled style', () => {
  for (const name of ['head','eyes','eyebrows','mouth','hair','ttOutfit','ttWall',
      'ttBoard','ttHands','ttInitials']) assert.ok(style.components[name], name);
  assert.ok(style.meta.license.name.includes('CC BY'));
  assert.ok(style.canvas.elements.some(e => e.name === 'ttBoard'));
  assert.ok(style.components.ttInitials.variants.blank);
});
