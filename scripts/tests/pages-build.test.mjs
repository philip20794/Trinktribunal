import test from 'node:test';
import assert from 'node:assert/strict';
import { chmodSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const bash = '/bin/bash';
const pipeline = fileURLToPath(new URL('../build-pages.sh', import.meta.url));
const shellPath = path => path.replaceAll('\\', '/');

for (const scenario of ['success', 'failed-tests', 'wrong-sdk']) {
  test(`Pages publishes only a checked, pinned release: ${scenario}`, {
    skip: process.platform === 'win32' || !existsSync(bash) ? 'Runs in the Linux Pages build environment.' : false,
  }, context => {
    const temporary = mkdtempSync(join(tmpdir(), 'trinktribunal-pages-test-'));
    context.after(() => {
      assert.ok(resolve(temporary).startsWith(resolve(tmpdir()) + (process.platform === 'win32' ? '\\' : '/')));
      rmSync(temporary, { recursive: true, force: true });
    });
    const log = join(temporary, 'commands.log');
    const wrappers = {
      flutter: `#!/usr/bin/env bash
printf 'flutter %s\\n' "$*" >> "$TT_PAGES_TEST_LOG"
if [[ "$*" == '--version --machine' ]]; then
  printf '{"frameworkVersion":"%s"}\\n' "$TT_PAGES_SDK"
fi
if [[ "$*" == 'test --no-pub' && "$TT_PAGES_SCENARIO" == failed-tests ]]; then exit 42; fi
`,
      node: `#!/usr/bin/env bash
printf 'node %s\\n' "$*" >> "$TT_PAGES_TEST_LOG"
if [[ "$1" == -e ]]; then exec "$TT_PAGES_REAL_NODE" "$@"; fi
if [[ "$1" == -p ]]; then printf 'https://client.example\\n'; fi
`,
      npm: `#!/usr/bin/env bash
printf 'npm %s\\n' "$*" >> "$TT_PAGES_TEST_LOG"
`,
    };
    for (const [name, content] of Object.entries(wrappers)) {
      writeFileSync(join(temporary, name), content);
      chmodSync(join(temporary, name), 0o755);
    }
    const result = spawnSync(bash, ['-c', 'export PATH="$1:$PATH"; exec bash "$2"', '--', shellPath(temporary), shellPath(pipeline)], {
      env: { ...process.env, TT_PAGES_TEST_LOG: shellPath(log), TT_PAGES_SCENARIO: scenario,
        TT_PAGES_REAL_NODE: shellPath(process.execPath), TT_PAGES_SDK: scenario === 'wrong-sdk' ? '0.0.0' : '3.47.7' },
      encoding: 'utf8', timeout: 15000,
    });
    assert.equal(result.error, undefined, result.error?.message);
    const commands = readFileSync(log, 'utf8');
    if (scenario === 'success') {
      assert.equal(result.status, 0, result.stderr);
      assert.ok(commands.indexOf('flutter test --no-pub') < commands.indexOf('flutter build web'));
      assert.ok(commands.indexOf('npm run check') < commands.indexOf('flutter build web'));
      assert.match(commands, /flutter build web --release --csp --no-pub --no-wasm-dry-run --no-web-resources-cdn/);
      assert.match(commands.trim(), /node scripts\/check-web-release\.mjs apps\/client\/build\/web$/);
    } else {
      assert.notEqual(result.status, 0);
      assert.doesNotMatch(commands, /flutter build web|prepare-web\.mjs/);
    }
  });
}
