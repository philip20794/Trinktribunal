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
    '-ApiBaseUrl', 'http://127.0.0.1:8787', '-PublicClientBaseUrl', 'http://127.0.0.1:7357'], setup);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /FLUTTER_STUB run -d web-server/);
  assert.ok(result.stdout.includes(`--web-port ${port}`));
  assert.match(result.stdout, /--dart-define=API_BASE_URL=http:\/\/127\.0\.0\.1:8787/);
  assert.match(result.stdout, /--dart-define=PUBLIC_CLIENT_BASE_URL=http:\/\/127\.0\.0\.1:7357/);
});

test('The check wrapper preserves a failed child exit code', { skip: !windows }, context => {
  const setup = fixture(context, 23);
  const result = run('check.ps1', ['-Scope', 'Docs'], setup);
  assert.equal(result.status, 23, result.stderr || result.stdout);
  assert.doesNotMatch(result.stdout, /erfolgreich beendet/);
});

test('Multiplayer plan is read-only, works outside the repo and separates three persistent profiles', {skip:!windows}, context=>{
  const setup=fixture(context);
  const result=run('dev-multiplayer.ps1',['-PlanOnly','-AsJson'],setup);
  assert.equal(result.status,0,result.stderr);
  const plan=JSON.parse(result.stdout);
  assert.equal(plan.clientUrl,'http://127.0.0.1:7357');
  assert.equal(plan.serverUrl,'http://127.0.0.1:8787');
  assert.equal(plan.browserAcceptance,'SKIPPED_MANUAL_LATER');
  assert.equal(plan.automaticGate,'unit');
  assert.deepEqual(plan.profiles.map(profile=>profile.viewport),['390,844','360,800','1440,900']);
  assert.equal(new Set(plan.profiles.map(profile=>profile.directory)).size,3);
  for(const profile of plan.profiles)assert.ok(profile.directory.startsWith(resolve(scripts,'..','.local','multiplayer')));
  assert.doesNotMatch(result.stdout,/FLUTTER_STUB/);
});
test('Multiplayer rejects conflicting or non-allowlisted ports before starting anything', {skip:!windows},context=>{
  const setup=fixture(context);
  for(const args of [['-ClientPort','7357','-ServerPort','7357'],['-ClientPort','9000'],['-AsJson'],['-PlanOnly','-OpenBrowsers']]){
    const result=run('dev-multiplayer.ps1',args,setup);
    assert.notEqual(result.status,0);
    assert.doesNotMatch(result.stdout,/FLUTTER_STUB/);
  }
});
test('Multiplayer alternate supported origin keeps stable profile locations and prints no credential payloads', {skip:!windows},context=>{
  const setup=fixture(context);
  const result=run('dev-multiplayer.ps1',['-PlanOnly','-AsJson','-ClientPort','8080','-ServerPort','8790','-Browser','edge'],setup);
  assert.equal(result.status,0,result.stderr);
  const plan=JSON.parse(result.stdout);
  assert.equal(plan.clientUrl,'http://127.0.0.1:8080');assert.equal(plan.serverUrl,'http://127.0.0.1:8790');
  assert.equal(plan.browser,'edge');assert.equal(plan.persistentProfiles,true);
  assert.doesNotMatch(result.stdout,/resumeToken|requestId|roomId|playerId/);
});

for (const shutdown of ['dispose', 'owner-exit']) {
  test(`Service job releases a listening grandchild after its wrapper exits: ${shutdown}`, { skip: !windows }, async context => {
    const setup = fixture(context);
    const leaf = join(setup.root, 'leaf.ps1');
    const wrapper = join(setup.root, 'wrapper.ps1');
    const owner = join(setup.root, 'owner.ps1');
    const ready = join(setup.root, 'ready.txt');
    writeFileSync(leaf, `
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$listener.Start()
[IO.File]::WriteAllText($env:JOB_READY,[string]$listener.LocalEndpoint.Port)
while ($true) { Start-Sleep -Milliseconds 100 }
`);
    writeFileSync(wrapper, `
$ErrorActionPreference = 'Stop'
Add-Type -Path $env:JOB_SOURCE
[OwnedServiceJob]::Join($env:JOB_NAME)
Start-Process -FilePath $env:JOB_POWERSHELL -ArgumentList ('-NoProfile -File "' + $env:JOB_LEAF + '"') -WindowStyle Hidden -RedirectStandardOutput ($env:JOB_READY + '.leaf.out') -RedirectStandardError ($env:JOB_READY + '.leaf.err')
exit 0
`);
    writeFileSync(owner, `
$ErrorActionPreference = 'Stop'
Add-Type -Path $env:JOB_SOURCE
$job = [OwnedServiceJob]::new($env:JOB_NAME)
$wrapper = Start-Process -FilePath $env:JOB_POWERSHELL -ArgumentList ('-NoProfile -File "' + $env:JOB_WRAPPER + '"') -WindowStyle Hidden -RedirectStandardOutput ($env:JOB_READY + '.wrapper.out') -RedirectStandardError ($env:JOB_READY + '.wrapper.err') -PassThru
$null = $wrapper.Handle
if (-not $wrapper.WaitForExit(10000) -or $wrapper.ExitCode -ne 0) { throw ('Wrapper failed: ' + (Get-Content ($env:JOB_READY + '.wrapper.err') -Raw)) }
$watch = [Diagnostics.Stopwatch]::StartNew()
while (-not (Test-Path -LiteralPath $env:JOB_READY)) {
    if ($watch.Elapsed.TotalSeconds -gt 10) { throw 'Grandchild not listening' }
    Start-Sleep -Milliseconds 50
}
if ($env:JOB_SHUTDOWN -eq 'dispose') { $job.Dispose() }
`);
    const unrelated = createServer();
    await new Promise(done => unrelated.listen(0, '127.0.0.1', done));
    context.after(() => new Promise(done => unrelated.close(done)));
    const result = spawnSync(powershell, ['-NoProfile', '-File', owner], {
      env: { ...setup.env, JOB_SOURCE: join(scripts, 'OwnedServiceJob.cs'),
        JOB_NAME: `Trinktribunal-test-${basename(setup.root)}`, JOB_POWERSHELL: powershell,
        JOB_LEAF: leaf, JOB_WRAPPER: wrapper, JOB_READY: ready, JOB_SHUTDOWN: shutdown },
      encoding: 'utf8', timeout: 25000,
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    const port = Number(readFileSync(ready, 'utf8'));
    assert.ok(port > 0);
    // Kernel teardown may finish just after the owner exits. Verify socket
    // reuse rather than trusting process-parent IDs or a cleanup message.
    let released = false;
    for (let attempt = 0; attempt < 50 && !released; attempt++) {
      const probe = createServer();
      released = await new Promise(done => {
        probe.once('error', () => done(false));
        probe.listen(port, '127.0.0.1', () => probe.close(() => done(true)));
      });
      if (!released) await new Promise(done => setTimeout(done, 100));
    }
    assert.ok(released, `Orphaned service still occupies port ${port}`);
    assert.ok(unrelated.listening, 'Unrelated listener must remain untouched');
  });
}
