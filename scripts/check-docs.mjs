#!/usr/bin/env node
// TT-002: validate repository-local Markdown links and the 84-task register.
// No dependencies, network access or changes to repository files.
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const rootFlagIndex = process.argv.indexOf('--root');
if (rootFlagIndex >= 0 && !process.argv[rootFlagIndex + 1]) {
  console.error('Missing directory after --root');
  process.exit(2);
}
const root = resolve(rootFlagIndex >= 0
  ? process.argv[rootFlagIndex + 1]
  : join(scriptDir, '..'));
const errors = [];

function report(path, problem) {
  errors.push(`${relative(root, path)}: ${problem}`);
}

function markdownFiles(path) {
  if (!existsSync(path)) {
    errors.push(`Expected directory or file is missing: ${relative(root, path)}`);
    return [];
  }
  if (statSync(path).isFile()) {
    return path.endsWith('.md') ? [path] : [];
  }
  return readdirSync(path, { withFileTypes: true }).flatMap(entry =>
    entry.isDirectory()
      ? markdownFiles(join(path, entry.name))
      : entry.isFile() && entry.name.endsWith('.md')
        ? [join(path, entry.name)]
        : [],
  );
}

const files = [
  ...markdownFiles(join(root, 'README.md')),
  ...markdownFiles(join(root, 'docs')),
  ...markdownFiles(join(root, 'data', 'questions', 'README.md')),
  ...markdownFiles(join(root, 'data', 'rules', 'README.md')),
  ...['packages/protocol', 'apps/client/README.md'].flatMap(path =>
    existsSync(join(root, path)) ? markdownFiles(join(root, path)) : []),
];

for (const file of files) {
  const source = readFileSync(file, 'utf8');
  // Fenced examples are not Markdown navigation links.
  const text = source.replace(/^\s*(`{3,}|~{3,})[^\n]*\n[\s\S]*?^\s*\1\s*$/gm, '');
  for (const match of text.matchAll(/!?\[[^\]\n]*\]\(([^)]+)\)/g)) {
    let target = match[1].trim();
    if (target.startsWith('<')) {
      target = target.slice(1, target.indexOf('>'));
    } else {
      target = target.split(/\s+["']/)[0];
    }
    if (!target || /^(?:https?:|mailto:|tel:|data:|#)/i.test(target)) continue;
    try {
      target = decodeURIComponent(target.split('#')[0].split('?')[0]);
    } catch {
      report(file, `Invalid percent-encoding in link: ${match[1]}`);
      continue;
    }
    const resolved = isAbsolute(target) ? resolve(target) : resolve(dirname(file), target);
    const fromRoot = relative(root, resolved);
    if (fromRoot === '..' || fromRoot.startsWith(`..${sep}`)) {
      report(file, `Link points outside repository: ${match[1]}`);
    } else if (!existsSync(resolved)) {
      report(file, `Broken local link: ${match[1]}`);
    }
  }
}

const planPath = join(root, 'docs', 'IMPLEMENTATION_PLAN.md');
const progressPath = join(root, 'docs', 'PROGRESS.md');
if (existsSync(planPath) && existsSync(progressPath)) {
  const plan = readFileSync(planPath, 'utf8');
  const progress = readFileSync(progressPath, 'utf8');
  const headings = [...plan.matchAll(/^#{3,4}\s+(TT-\d{3})\s+[–—-]/gm)]
    .map(match => match[1]);
  const rows = [...progress.matchAll(/^\|\s*(TT-\d{3})\s*\|[^\n|]*\|\s*(OFFEN|IN ARBEIT|BLOCKIERT|ERLEDIGT)\s*\|/gm)]
    .map(match => match[1]);
  const expected = Array.from({ length: 84 }, (_, i) =>
    `TT-${String(i + 1).padStart(3, '0')}`);

  for (const [file, actual, name] of [
    [planPath, headings, 'task heading'],
    [progressPath, rows, 'task status row'],
  ]) {
    const counts = new Map();
    for (const id of actual) counts.set(id, (counts.get(id) ?? 0) + 1);
    for (const id of expected) {
      if (!counts.has(id)) report(file, `Missing ${name}: ${id}`);
      if ((counts.get(id) ?? 0) > 1) report(file, `Duplicate ${name}: ${id}`);
    }
    for (const id of counts.keys()) {
      if (!expected.includes(id)) report(file, `Unexpected ${name}: ${id}`);
    }
    if (actual.length !== 84) report(file, `Expected 84 ${name}s, found ${actual.length}`);
  }
  for (const file of files) {
    const text = readFileSync(file, 'utf8');
    for (const match of text.matchAll(/\bTT-(\d{3})\b/g)) {
      const id = `TT-${match[1]}`;
      if (!expected.includes(id)) report(file, `Unknown referenced task: ${id}`);
    }
  }
}

if (errors.length) {
  for (const error of errors) console.error(`ERROR ${error}`);
  console.error(`Document checks FAILED: ${errors.length} error(s).`);
  process.exit(1);
}
console.log(`Document checks OK: ${files.length} Markdown files, 84 plan tasks and 84 status rows.`);
