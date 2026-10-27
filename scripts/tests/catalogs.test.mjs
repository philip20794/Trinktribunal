import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, mkdirSync, writeFileSync, copyFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, resolve, basename } from 'node:path';
import { canonicalJson, createBundle, loadSources, readSchema, repositoryRoot, validateCatalog, validatePair, validateSchema } from '../lib/catalogs.mjs';
import { syncAssets } from '../validate-data.mjs';

const question = () => ({ version: 1, language: 'de', questions: [{ id: '001-a', text: 'Frage', scale: { green: 'wenig', connector: 'bis', red: 'viel' } }] });
const rules = () => ({ version: 1, language: 'de', rules: [{ id: 'one', text: 'Regel', excludes: [] }, { id: 'two', text: 'Andere', excludes: [] }] });
const role = () => ({ selection: 'random' });

test('production counts, removed IDs, same text/different scales and D-04 are valid', () => {
  const sources = loadSources(); assert.equal(sources.length, 4);
  assert.equal(sources[0].catalog.questions.length, 491);
  const a = sources[0].catalog.questions.find(e => e.id === '024-b');
  const b = sources[0].catalog.questions.find(e => e.id === '206-a');
  assert.equal(a.text, b.text); assert.notDeepEqual(a.scale, b.scale);
});
test('canonical bundle is stable across object insertion order and CRLF source formatting', () => {
  assert.equal(canonicalJson({ z: 2, a: { b: 1, a: 'ü' } }), '{"a":{"a":"ü","b":1},"z":2}');
  const sources = loadSources(); const first = createBundle(sources);
  const reformatted = sources.map(e => ({ ...e, catalog: JSON.parse(JSON.stringify(e.catalog, null, 2).replaceAll('\n', '\r\n')) }));
  assert.deepEqual(first, createBundle(reformatted));
  reformatted[0].catalog.questions[0].text += '!';
  assert.notEqual(JSON.parse(createBundle(reformatted).get('manifest.json')).catalogs[0].sha256, JSON.parse(first.get('manifest.json')).catalogs[0].sha256);
  const manifest = JSON.parse(first.get('manifest.json'));
  assert.equal(manifest.catalogs.length, 4); assert.match(manifest.catalogs[0].sha256, /^[a-f0-9]{64}$/);
});
test('role exclusively in scale is valid and must be defined', () => {
  const q = question(); q.questions[0].scale.green = '{player1}'; q.questions[0].players = { player1: role() };
  assert.doesNotThrow(() => validateCatalog(q, 'questions'));
  delete q.questions[0].players; assert.throws(() => validateCatalog(q, 'questions'), /role/);
});

const questionFailures = [
  ['missing root', q => delete q.version], ['wrong version', q => q.version = 2],
  ['wrong language', q => q.language = 'fr'], ['empty list', q => q.questions = []],
  ['wrong type', q => q.questions = {}], ['unknown field', q => q.extra = true],
  ['duplicate IDs', q => q.questions.push(structuredClone(q.questions[0]))],
  ['invalid ID', q => q.questions[0].id = 'x'], ['blank text', q => q.questions[0].text = '  '],
  ['missing scale', q => delete q.questions[0].scale.red], ['wrong connector', q => q.questions[0].scale.connector = 'to'],
  ['unused role', q => q.questions[0].players = { player1: role() }],
  ['empty players', q => q.questions[0].players = {}],
  ['undefined role', q => q.questions[0].text = '{player1}'],
  ['invalid role ID', q => { q.questions[0].text = '{other}'; q.questions[0].players = { other: role() }; }],
  ['invalid selection', q => { q.questions[0].text = '{player1}'; q.questions[0].players = { player1: { selection: 'first' } }; }],
  ['self role ref', q => { q.questions[0].text = '{player1}'; q.questions[0].players = { player1: { ...role(), differentFrom: ['player1'] } }; }],
  ['foreign role ref', q => { q.questions[0].text = '{player1}'; q.questions[0].players = { player1: { ...role(), differentFrom: ['player2'] } }; }],
  ['duplicate role refs', q => { q.questions[0].text = '{player1} {player2}'; q.questions[0].players = { player1: { ...role(), differentFrom: ['player2', 'player2'] }, player2: role() }; }],
];
for (const [name, mutate] of questionFailures) test(`reject question: ${name}`, () => {
  const q = question(); mutate(q); assert.throws(() => validateCatalog(q, 'questions'));
});
for (const [name, exclusions] of [['self', ['one']], ['unknown', ['missing']], ['duplicate', ['two', 'two']], ['not reciprocal', ['two']]]) {
  test(`reject rule exclusion: ${name}`, () => { const r = rules(); r.rules[0].excludes = exclusions; assert.throws(() => validateCatalog(r, 'rules')); });
}
test('valid reciprocal exclusions and differentFrom', () => {
  const r = rules(); r.rules[0].excludes = ['two']; r.rules[1].excludes = ['one'];
  r.rules[0].text = '{player1} {player2}'; r.rules[0].players = { player1: role(), player2: { ...role(), differentFrom: ['player1'] } };
  assert.doesNotThrow(() => validateCatalog(r, 'rules'));
});
for (const drift of ['language', 'order', 'roles', 'constraints']) test(`reject language pair drift: ${drift}`, () => {
  const de = rules(), en = rules(); en.language = 'en';
  if (drift === 'language') en.language = 'de';
  if (drift === 'order') en.rules.reverse();
  if (drift === 'roles') { en.rules[0].text = '{player1}'; en.rules[0].players = { player1: role() }; }
  if (drift === 'constraints') { en.rules[0].excludes = ['two']; en.rules[1].excludes = ['one']; }
  assert.throws(() => validatePair(de, en, 'rules'));
});
test('schema interpreter rejects unknown keywords, unresolved refs and malformed manifests', () => {
  assert.throws(() => validateSchema({}, { unsupported: true }), /unsupported/);
  assert.throws(() => validateSchema({}, { $ref: '#/$defs/missing' }), /unknown reference/);
  assert.throws(() => validateSchema({}, { $ref: 'https://example.com' }), /local/);
  assert.doesNotThrow(() => validateSchema('a', { $defs: { s: { type: 'string' } }, $ref: '#/$defs/s' }));
  assert.throws(() => validateSchema(0, { type: 'integer', minimum: 1 }), /minimum/);
  const manifest = JSON.parse(createBundle(loadSources()).get('manifest.json'));
  manifest.catalogs[0].sha256 = 'invalid';
  assert.throws(() => validateSchema(manifest, readSchema('catalog-manifest')), /pattern/);
});
test('asset check is read-only and detects missing, changed and extra assets', () => {
  const root = mkdtempSync(resolve(tmpdir(), 'trinktribunal-catalog-'));
  try {
    for (const { source } of loadSources()) { const path = resolve(root, source); mkdirSync(dirname(path), { recursive: true }); copyFileSync(resolve(repositoryRoot, source), path); }
    assert.throws(() => syncAssets({ root }), /drift/);
    syncAssets({ root, check: false }); assert.equal(syncAssets({ root }), 5);
    const serverManifest = resolve(root, 'data/manifest.json');
    writeFileSync(serverManifest, '{}');
    assert.throws(() => syncAssets({ root }), /Server catalog manifest drift/);
    syncAssets({ root, check: false });
    const path = resolve(root, 'apps/client/assets/catalogs/questions/de.json');
    writeFileSync(path, '{}'); assert.throws(() => syncAssets({ root }), /drift/); assert.equal(readFileSync(path, 'utf8'), '{}');
    syncAssets({ root, check: false }); writeFileSync(resolve(root, 'apps/client/assets/catalogs/extra.json'), '{}');
    assert.throws(() => syncAssets({ root }), /Unexpected/);
  } finally {
    assert.equal(dirname(root), resolve(tmpdir())); assert.ok(basename(root).startsWith('trinktribunal-catalog-')); rmSync(root, { recursive: true });
  }
});
