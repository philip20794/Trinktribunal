import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const fixture = resolve(root, 'packages/protocol/fixtures/rules/parity/v1.json');
const temporary = mkdtempSync(resolve(tmpdir(), 'trinktribunal-parity-'));
function run(language, path, shouldFail, changedCase = 'normal-number-gaps') {
  const windows = process.platform === 'win32';
  const command = language === 'Dart' ? 'dart' : (windows ? 'npm.cmd' : 'npm');
  const args = language === 'Dart' ? ['run', 'tool/game_parity.dart', path] : ['test', '--', 'test/domain/rules.test.ts'];
  // Windows .cmd launch needs cmd.exe; arguments contain only repository/tool paths.
  // Quote every argument, reject cmd metacharacters and never interpolate a payload.
  let executable = command, parameters = args;
  if (windows) {
    const values = [command, ...args];
    if (values.some(value => /["%&|<>^\r\n]/.test(value))) throw new Error('Unsafe command path');
    executable = process.env.ComSpec || 'cmd.exe';
    parameters = ['/d', '/s', '/c', `${command} ${args.map(value => /\s/.test(value) ? `"${value}"` : value).join(' ')}`];
  }
  const result = spawnSync(executable, parameters, {
    cwd: resolve(root, language === 'Dart' ? 'apps/client' : 'apps/server'),
    env: { ...process.env, TT_PARITY_FIXTURE: path }, encoding: 'utf8', timeout: 120000,
    maxBuffer: 8 * 1024 * 1024, windowsVerbatimArguments: windows,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  if (result.error || result.status === null || (shouldFail ? result.status === 0 || !output.includes(changedCase) : result.status !== 0)) {
    throw new Error(`${language} ${shouldFail ? 'mutation detection' : 'parity'} failed:\n${output}\n${result.error ?? ''}`);
  }
  console.log(`${language}: ${shouldFail ? 'changed expected value rejected' : 'shared fixtures passed'}.`);
}
try {
  run('Dart', fixture, false);
  run('TypeScript', fixture, false);
  const modified = JSON.parse(readFileSync(fixture, 'utf8'));
  const target = modified.cases.find(c => c.id === 'normal-number-gaps');
  target.expected.max++;
  const altered = resolve(temporary, 'altered.json');
  writeFileSync(altered, JSON.stringify(modified), 'utf8');
  run('Dart', altered, true);
  run('TypeScript', altered, true);
  const alteredVerdict = JSON.parse(readFileSync(fixture, 'utf8'));
  alteredVerdict.cases.find(c => c.id === 'normal-verdict-correct').expected.errors++;
  const wrongVerdict = resolve(temporary, 'altered-verdict.json');
  writeFileSync(wrongVerdict, JSON.stringify(alteredVerdict), 'utf8');
  run('Dart', wrongVerdict, true, 'normal-verdict-correct');
  run('TypeScript', wrongVerdict, true, 'normal-verdict-correct');
  const personal = JSON.parse(readFileSync(fixture, 'utf8'));
  personal.cases.find(c=>c.id==='all-judges-verdict-2-4-0-0').expected.A++;
  const wrongPersonal = resolve(temporary, 'altered-personal.json');
  writeFileSync(wrongPersonal, JSON.stringify(personal), 'utf8');
  run('Dart', wrongPersonal, true, 'all-judges-verdict-2-4-0-0');
  run('TypeScript', wrongPersonal, true, 'all-judges-verdict-2-4-0-0');
  console.log('Dart/TypeScript parity and mutation checks passed; original fixtures unchanged.');
} finally {
  const parent = resolve(tmpdir());
  if (dirname(temporary) !== parent || !temporary.startsWith(parent + sep) || !temporary.slice(parent.length + 1).startsWith('trinktribunal-parity-')) throw new Error('Unsafe parity cleanup');
  rmSync(temporary, { recursive: true });
}
