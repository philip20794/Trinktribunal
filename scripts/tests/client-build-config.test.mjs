import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmdirSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { clientBuildDefines } from '../write-client-build-config.mjs';

const script = fileURLToPath(new URL('../write-client-build-config.mjs', import.meta.url));

test('an online APK cannot silently omit its server configuration', () => {
  for (const API_BASE_URL of [undefined, '', '   ']) {
    assert.throws(() => clientBuildDefines({ API_BASE_URL }), /API_BASE_URL fehlt/);
  }
});

test('only public client defines enter the APK, never CI signing or GitHub credentials', () => {
  assert.deepEqual(clientBuildDefines({
    API_BASE_URL: ' https://api.example.com/ ', PUBLIC_CLIENT_BASE_URL: 'https://app.example.com/',
    GITHUB_TOKEN: 'secret-token', CM_KEYSTORE_PASSWORD: 'secret-password',
  }), { API_BASE_URL: 'https://api.example.com', PUBLIC_CLIENT_BASE_URL: 'https://app.example.com' });
  assert.deepEqual(clientBuildDefines({ API_BASE_URL: 'https://api.example.com' }), {
    API_BASE_URL: 'https://api.example.com',
  }); // Joining by room code does not require a hosted web client.
});

test('unusable endpoints fail without echoing credentials in the validation error', () => {
  for (const value of ['http://localhost:8787', 'https://localhost', 'https://api.example.invalid',
    'https://user:private-password@example.com', 'https://example.com/path', 'https://example.com/?token=private-token']) {
    for (const key of ['API_BASE_URL', 'PUBLIC_CLIENT_BASE_URL']) {
      assert.throws(() => clientBuildDefines({ API_BASE_URL: 'https://api.example.com', [key]: value }), error => {
        assert.ok(error.message.includes(key));
        assert.ok(!error.message.includes('private-password') && !error.message.includes('private-token'));
        return true;
      });
    }
  }
});

test('the actual CI command writes Flutter-compatible JSON and stops before output on missing API', t => {
  const directory = mkdtempSync(join(tmpdir(), 'trinktribunal-client-config-'));
  const output = join(directory, 'defines.json');
  t.after(() => { if (existsSync(output)) unlinkSync(output); rmdirSync(directory); });
  const env = { ...process.env, API_BASE_URL: '', PUBLIC_CLIENT_BASE_URL: '' };
  const failure = spawnSync(process.execPath, [script, output], { env, encoding: 'utf8' });
  assert.equal(failure.status, 1);
  assert.match(failure.stderr, /API_BASE_URL fehlt/);
  assert.equal(existsSync(output), false);
  execFileSync(process.execPath, [script, output], { env: { ...env, API_BASE_URL: 'https://api.example.com' } });
  assert.deepEqual(JSON.parse(readFileSync(output)), { API_BASE_URL: 'https://api.example.com' });
});

test('Codemagic validates configuration before work and passes that same file into Flutter', () => {
  const yaml = readFileSync(new URL('../../codemagic.yaml', import.meta.url), 'utf8');
  const prepare = 'node scripts/write-client-build-config.mjs "$CM_BUILD_DIR/client-build-defines.json"';
  assert.ok(yaml.includes(prepare));
  assert.ok(yaml.indexOf(prepare) < yaml.indexOf('flutter pub get'));
  assert.match(yaml, /flutter build apk --release[^\n]*\\\r?\n\s+--dart-define-from-file="\$CM_BUILD_DIR\/client-build-defines\.json"/);
});
