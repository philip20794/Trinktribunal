import {canonicalJson,validateSchema} from '../../packages/protocol/schema-validation.mjs';
export {canonicalJson,validateSchema};
const fail = (path, message) => { throw new Error(`${path}: ${message}`); };
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const repositoryRoot = fileURLToPath(new URL('../../', import.meta.url));
export function readSchema(kind) {
  return JSON.parse(readFileSync(new URL(`../../packages/protocol/schemas/${kind}.schema.json`, import.meta.url), 'utf8'));
}
export const placeholders = text => [...text.matchAll(/\{([A-Za-z][A-Za-z0-9_]*)\}/g)].map(match => match[1]);

export function validateCatalog(catalog, kind) {
  validateSchema(catalog, readSchema(kind));
  const entries = catalog[kind];
  const ids = new Set(entries.map(entry => entry.id));
  if (ids.size !== entries.length) fail(kind, 'duplicate IDs');
  for (const entry of entries) {
    const path = `${kind}.${entry.id}`;
    const texts = [entry.text, ...(kind === 'questions' ? [entry.scale.green, entry.scale.red] : [])];
    if(texts.some(text=>!text.trim())) fail(path,'blank content text');
    const roles = entry.players ?? {};
    if (entry.players && Object.keys(roles).length === 0) fail(path, 'omit empty players');
    const used = new Set(texts.flatMap(placeholders));
    if (canonicalJson([...used].sort()) !== canonicalJson(Object.keys(roles).sort())) fail(path, 'undefined or unused role');
    for (const [role, definition] of Object.entries(roles)) {
      for (const other of definition.differentFrom ?? []) {
        if (other === role || !(other in roles)) fail(path, 'self or unknown role reference');
      }
    }
    if (kind === 'questions' && entry.scale.connector !== (catalog.language === 'de' ? 'bis' : 'to')) fail(path, 'incorrect connector');
    for (const other of entry.excludes ?? []) {
      if (other === entry.id || !ids.has(other)) fail(path, 'self or unknown exclusion');
      if (!entries.find(item => item.id === other).excludes.includes(entry.id)) fail(path, 'nonreciprocal exclusion');
    }
  }
  return catalog;
}

export function validatePair(de, en, kind) {
  validateCatalog(de, kind); validateCatalog(en, kind);
  if (de.language !== 'de' || en.language !== 'en' || de.version !== en.version) fail(kind, 'language/version drift');
  const signature = catalog => catalog[kind].map(entry => ({ id: entry.id, players: entry.players ?? {}, excludes: entry.excludes ?? [] }));
  if (canonicalJson(signature(de)) !== canonicalJson(signature(en))) fail(kind, 'ID order, roles or constraints differ between languages');
}

export function loadSources(root = repositoryRoot) {
  const catalogs = [];
  for (const kind of ['questions', 'rules']) {
    const pair = ['de', 'en'].map(language => {
      const source = kind === 'questions' ? `data/questions/top-ten/${language}.json` : `data/rules/${language}.json`;
      let catalog;
      try { catalog = JSON.parse(readFileSync(`${root}/${source}`, 'utf8')); }
      catch (error) { fail(source, error.message); }
      catalogs.push({ kind, source, catalog }); return catalog;
    });
    validatePair(...pair, kind);
  }
  // Explicit project policy; format schemas remain reusable for small fixtures.
  const removed = ['008-b', '023-a', '039-b', '041-b', '043-b', '174-a', '188-a', '205-a', '221-a'];
  for (const { kind, catalog } of catalogs) {
    const entries = catalog[kind];
    if (entries.length !== (kind === 'questions' ? 491 : 25)) fail(kind, 'unexpected production count');
    if (entries.filter(entry => !entry.players).length !== (kind === 'questions' ? 431 : 22)) fail(kind, 'unexpected card-mode count');
    if (kind === 'questions') {
      const expected = Array.from({ length: 250 }, (_, i) => ['a', 'b'].map(side => `${String(i + 1).padStart(3, '0')}-${side}`)).flat().filter(id => !removed.includes(id));
      if (canonicalJson(entries.map(entry => entry.id)) !== canonicalJson(expected)) fail(kind, 'unexpected production IDs');
    } else {
      const pairs = [['left_hand_drinking', 'two_hands_drinking'], ['two_hands_drinking', 'touch_player_while_drinking']];
      for (const [a, b] of pairs) if (!entries.find(e => e.id === a)?.excludes.includes(b) || !entries.find(e => e.id === b)?.excludes.includes(a)) fail(kind, 'missing D-04 exclusion');
      if (entries.find(e => e.id === 'imaginary_kobold')?.excludes.includes('imaginary_fly') || entries.find(e => e.id === 'imaginary_fly')?.excludes.includes('imaginary_kobold')) fail(kind, 'kobold/fly must coexist');
    }
  }
  return catalogs;
}

export function createBundle(catalogs) {
  const files = new Map();
  const manifest = { version: 1, canonicalization: 'sorted-keys-utf16-json-v1', catalogs: catalogs.map(({ kind, source, catalog }) => {
    const path = `${kind}/${catalog.language}.json`;
    const content = canonicalJson(catalog) + '\n';
    files.set(path, content);
    return { path, source, kind, language: catalog.language, formatVersion: catalog.version, ids: catalog[kind].map(entry => entry.id), sha256: createHash('sha256').update(content, 'utf8').digest('hex') };
  }) };
  validateSchema(manifest, readSchema('catalog-manifest'));
  files.set('manifest.json', canonicalJson(manifest) + '\n');
  return files;
}
