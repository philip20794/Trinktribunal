import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const repository = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
function list(root, path, extension) {
  return readdirSync(join(root, path), { withFileTypes: true }).flatMap(entry => {
    const child = `${path}/${entry.name}`;
    return entry.isDirectory() ? list(root, child, extension) : child.endsWith(extension) ? [child] : [];
  }).sort();
}
export function checkUiInventory(inventory, { root = repository, pubspecText } = {}) {
  const fail = message => { throw new Error(message); };
  const file = path => {
    if (typeof path !== 'string' || !path || path.includes('\\')) fail('Invalid inventory path');
    const full = resolve(root, path);
    if (!full.startsWith(resolve(root) + sep) || !existsSync(full) || !statSync(full).isFile()) fail(`Missing inventory file: ${path}`);
    return full;
  };
  const png = record => {
    const bytes = readFileSync(file(record.path));
    if (!bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) ||
        bytes.readUInt32BE(16) !== record.width || bytes.readUInt32BE(20) !== record.height ||
        digest(bytes) !== record.sha256) fail(`Stale PNG review: ${record.path}`);
  };
  if (inventory.formatVersion !== 1 || inventory.task !== 'TT-071' ||
      JSON.stringify(inventory.languages) !== '["de","en"]') fail('Invalid UI inventory version/languages');
  file(inventory.rightsEvidence);
  const references = new Map();
  for (const ref of inventory.references) {
    if (references.has(ref.id) || ref.useAsWholeScreen !== false) fail('Reference cannot be a production screen');
    png(ref); references.set(ref.id, ref);
  }
  if (references.size !== 10 || references.get('03')?.role !== 'placeholder' ||
      references.get('10')?.role !== 'people_management') fail('Incorrect placeholder/people-management reference');
  const sourceFiles = new Set(), sectionIds = new Set();
  for (const section of inventory.sections) {
    if (sectionIds.has(section.id) || !section.states?.length || !section.roles?.length ||
        !section.modes?.length || section.modes.some(mode => !['cards', 'shared_phone', 'multiplayer'].includes(mode)) ||
        !/^TT-(?:068|07[2-7])$/.test(section.targetTask)) fail('Incomplete screen/state section');
    sectionIds.add(section.id);
    for (const path of section.files) {
      file(path);
      if (sourceFiles.has(path)) fail(`Duplicate feature source: ${path}`);
      sourceFiles.add(path);
    }
    if (!section.tests.length && !section.roles.includes('unreachable_legacy')) fail(`Missing state tests: ${section.id}`);
    section.tests.forEach(file);
    for (const ref of section.references) {
      if (!references.has(ref) || ref === '03') fail(`Invalid screen reference: ${section.id}`);
    }
  }
  const featureFiles = list(root, 'apps/client/lib/features', '.dart');
  if (featureFiles.length !== sourceFiles.size || featureFiles.some(path => !sourceFiles.has(path))) fail('Unmapped feature source');
  if (inventory.redesign) {
    if (inventory.redesign.task !== 'TT-078' || inventory.redesign.implementationStatus !== 'complete' ||
        inventory.redesign.manualAcceptance !== 'ÜBERSPRUNGEN – später manuell testen' ||
        inventory.redesign.browserTestsRun !== false) fail('Invalid redesign/manual acceptance record');
    for (const section of inventory.sections) {
      if (section.implementation?.status !== 'implemented' || section.implementation.task !== section.targetTask)
        fail(`Incomplete redesign section: ${section.id}`);
    }
    for (const path of featureFiles) {
      if (/\bScaffold\s*\(/.test(readFileSync(file(path), 'utf8'))) fail(`Unmigrated feature scaffold: ${path}`);
    }
  }
  const pubspec = pubspecText ?? readFileSync(file('apps/client/pubspec.yaml'), 'utf8');
  const bundled = [...pubspec.matchAll(/^\s+-\s+(?:asset:\s+)?['"]?(assets\/[^'"\s]+)['"]?\s*(?:#.*)?$/gm)].map(match => 'apps/client/' + match[1]);
  const assets = new Set();
  for (const asset of inventory.assets) {
    if (assets.has(asset.path) || !['candidate', 'quarantine'].includes(asset.review) || !asset.notes) fail('Missing individual asset review');
    assets.add(asset.path); png(asset);
    if (readFileSync(file(asset.path)).length !== asset.bytes ||
        !Number.isInteger(asset.alpha_min) || !Number.isInteger(asset.alpha_max) ||
        asset.alpha_min < 0 || asset.alpha_max > 255 || asset.alpha_min > asset.alpha_max ||
        !Number.isInteger(asset.transparent_pixels) || !Number.isInteger(asset.nonopaque_pixels) ||
        asset.transparent_pixels < 0 || asset.nonopaque_pixels < asset.transparent_pixels ||
        asset.nonopaque_pixels > asset.width * asset.height ||
        !asset.alpha_bbox || asset.alpha_bbox.length !== 4 || !asset.alpha_bbox.every(Number.isInteger) ||
        asset.alpha_bbox[0] < 0 || asset.alpha_bbox[1] < 0 || asset.alpha_bbox[2] > asset.width || asset.alpha_bbox[3] > asset.height ||
        asset.alpha_bbox[0] >= asset.alpha_bbox[2] || asset.alpha_bbox[1] >= asset.alpha_bbox[3]) fail(`Invalid asset metrics: ${asset.path}`);
    if (asset.review === 'quarantine' && bundled.some(path => path.endsWith('/') ? asset.path.startsWith(path) : asset.path === path)) fail(`Quarantined asset bundled: ${asset.path}`);
  }
  const pngFiles = list(root, 'apps/client/assets/ui/courtroom', '.png');
  if (pngFiles.length !== assets.size || pngFiles.some(path => !assets.has(path))) fail('Unreviewed courtroom asset');
  return { sections: sectionIds.size, featureFiles: featureFiles.length, assets: assets.size,
    quarantined: inventory.assets.filter(asset => asset.review === 'quarantine').length };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const inventory = JSON.parse(readFileSync(join(repository, 'docs/design/ui-inventory.json'), 'utf8'));
  const result = checkUiInventory(inventory);
  process.stdout.write(`UI inventory: ${result.sections} sections / ${result.featureFiles} feature files / ${result.assets} assets, ${result.quarantined} quarantined.\n`);
}
