import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const windows = process.platform === 'win32';
const scripts = fileURLToPath(new URL('../', import.meta.url));
const powershell = join(process.env.SystemRoot ?? 'C:\\Windows',
  'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe');

function fixture(context, exitCode = 0) {
  const root = mkdtempSync(join(tmpdir(), 'trinktribunal-shell-test-'));
  context.after(() => {
    if (dirname(root) !== resolve(tmpdir()) || !basename(root).startsWith('trinktribunal-shell-test-')) {
      throw new Error('Refusing cleanup outside this test fixture');
    }
    rmSync(root, { recursive: true, force: true });
  });
  writeFileSync(join(root, 'flutter.cmd'), '@echo off\r\necho FLUTTER_STUB %*\r\nexit /b 0\r\n');
  writeFileSync(join(root, 'node.cmd'), `@echo off\r\nexit /b ${exitCode}\r\n`);
  const env = Object.fromEntries(Object.entries(process.env)
    .filter(([key]) => key.toLowerCase() !== 'path'));
  env.Path = [root, dirname(powershell), join(process.env.SystemRoot, 'System32')].join(';');
  return { root, env };
}

function run(script, args, setup) {
  return spawnSync(powershell, ['-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', join(scripts, script), ...args], {
    env: setup.env, cwd: setup.root, encoding: 'utf8', timeout: 15000,
  });
}

test('Windows PowerShell parses the shipped UTF-8 scripts', { skip: !windows }, () => {
  for (const name of readdirSync(scripts).filter(name => name.endsWith('.ps1'))) {
    const bytes = readFileSync(join(scripts, name));
    assert.deepEqual([...bytes.subarray(0, 3)], [0xef, 0xbb, 0xbf], `${name} needs a UTF-8 BOM`);
    const result = spawnSync(powershell, ['-NoProfile', '-Command',
      '$t=$null; $e=$null; [System.Management.Automation.Language.Parser]::ParseFile($env:TRINKTRIBUNAL_SCRIPT_UNDER_TEST,[ref]$t,[ref]$e) | Out-Null; if ($e.Count) { $e; exit 1 }'], {
      env: { ...process.env, TRINKTRIBUNAL_SCRIPT_UNDER_TEST: join(scripts, name) },
      encoding: 'utf8', timeout: 15000,
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
  }
});

test('Client startup reports a missing Flutter SDK', { skip: !windows }, context => {
  const setup = fixture(context);
  setup.env.Path = [dirname(powershell), join(process.env.SystemRoot, 'System32')].join(';');
  const result = run('dev-client.ps1', [], setup);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Flutter fehlt/);
});

test('Client startup rejects a port occupied on the requested host', { skip: !windows }, async context => {
  const setup = fixture(context);
  const server = createServer();
  await new Promise((done, fail) => server.once('error', fail).listen(0, '127.0.0.1', done));
  context.after(() => new Promise(done => server.close(done)));
  const port = server.address().port;
  const result = run('dev-client.ps1', ['-Port', String(port)], setup);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /nicht verf/);
  assert.doesNotMatch(result.stdout, /FLUTTER_STUB/);
});

test('Client startup works outside the repo and forwards its options', { skip: !windows }, async context => {
  const setup = fixture(context);
  const server = createServer();
  await new Promise(done => server.listen(0, '127.0.0.1', done));
  const port = server.address().port;
  await new Promise(done => server.close(done));
  const result = run('dev-client.ps1', ['-Device', 'web-server', '-Port', String(port),
    '-ApiBaseUrl', 'http://127.0.0.1:8787'], setup);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /FLUTTER_STUB run -d web-server/);
  assert.ok(result.stdout.includes(`--web-port ${port}`));
  assert.match(result.stdout, /--dart-define=API_BASE_URL=http:\/\/127\.0\.0\.1:8787/);
});

test('The check wrapper preserves a failed child exit code', { skip: !windows }, context => {
  const setup = fixture(context, 23);
  const result = run('check.ps1', ['-Scope', 'Docs'], setup);
  assert.equal(result.status, 23, result.stderr || result.stdout);
  assert.doesNotMatch(result.stdout, /erfolgreich beendet/);
});
