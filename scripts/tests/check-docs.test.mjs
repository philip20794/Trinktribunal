import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const checker = fileURLToPath(new URL('../check-docs.mjs', import.meta.url));

function fixture(run) {
  const root = mkdtempSync(join(tmpdir(), 'trinktribunal-docs-'));
  try {
    mkdirSync(join(root, 'docs'), { recursive: true });
    mkdirSync(join(root, 'data', 'questions'), { recursive: true });
    mkdirSync(join(root, 'data', 'rules'), { recursive: true });

    const ids = Array.from({ length: 70 }, (_, i) =>
      `TT-${String(i + 1).padStart(3, '0')}`);
    writeFileSync(
      join(root, 'docs', 'IMPLEMENTATION_PLAN.md'),
      ids.map(id => `#### ${id} – Beispiel\n\nImplementieren.\n`).join('\n'),
    );
    writeFileSync(
      join(root, 'docs', 'PROGRESS.md'),
      ids.map(id => `| ${id} | Beispiel | OFFEN | — |`).join('\n'),
    );
    writeFileSync(join(root, 'README.md'), '[Plan](docs/IMPLEMENTATION_PLAN.md)\n');
    writeFileSync(join(root, 'data', 'questions', 'README.md'), '# Fragen\n');
    writeFileSync(join(root, 'data', 'rules', 'README.md'), '# Regeln\n');

    const execute = () => spawnSync(process.execPath, [checker, '--root', root], {
      encoding: 'utf8',
      timeout: 10000,
    });
    run({ root, execute });
  } finally {
    if (dirname(root) !== resolve(tmpdir()) || !basename(root).startsWith('trinktribunal-docs-')) {
      throw new Error('Refusing cleanup outside this test fixture');
    }
    rmSync(root, { recursive: true, force: true });
  }
}

test('70 korrekte Aufgaben und lokale Links ergeben Exitcode 0', () => {
  fixture(({ execute }) => {
    const result = execute();
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /70 plan tasks and 70 status rows/);
  });
});

test('nicht existierender Markdown-Link ergibt Exitcode 1', () => {
  fixture(({ root, execute }) => {
    writeFileSync(join(root, 'README.md'), '[Kaputt](docs/fehlt.md)\n');
    const result = execute();
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Broken local link/);
  });
});

test('Auch Protokoll- und Client-README-Links werden geprueft', () => {
  fixture(({ root, execute }) => {
    for (const folder of ['packages/protocol', 'apps/client']) {
      mkdirSync(join(root, folder), { recursive: true });
      writeFileSync(join(root, folder, 'README.md'), '[Missing](missing.md)\n');
    }
    const result = execute();
    assert.equal(result.status, 1);
    assert.equal((result.stderr.match(/Broken local link/g) ?? []).length, 2);
  });
});

test('doppelte Aufgabenüberschrift ergibt Exitcode 1', () => {
  fixture(({ root, execute }) => {
    const path = join(root, 'docs', 'IMPLEMENTATION_PLAN.md');
    writeFileSync(path, readFileSync(path, 'utf8') + '\n#### TT-001 – Duplikat\n');
    const result = execute();
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Duplicate task heading: TT-001/);
  });
});

test('fehlender Registereintrag ergibt Exitcode 1', () => {
  fixture(({ root, execute }) => {
    const path = join(root, 'docs', 'PROGRESS.md');
    writeFileSync(path, readFileSync(path, 'utf8')
      .split('\n').filter(line => !line.startsWith('| TT-070 |')).join('\n'));
    const result = execute();
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Missing task status row: TT-070/);
  });
});


test('Links innerhalb von fenced Markdown-Code werden nicht als Navigation geprüft', () => {
  fixture(({ root, execute }) => {
    writeFileSync(join(root, 'README.md'), '```markdown\n[Code-Beispiel](datei-die-nicht-existiert.md)\n```\n[Plan](docs/IMPLEMENTATION_PLAN.md)\n');
    const result = execute();
    assert.equal(result.status, 0, result.stderr);
  });
});

test('Ungültige Aufgabenreferenz TT-999 wird erkannt', () => {
  fixture(({ root, execute }) => {
    writeFileSync(join(root, 'README.md'), 'Details zu TT-999\n');
    const result = execute();
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Unknown referenced task: TT-999/);
  });
});

test('Duplikat im Fortschrittsregister wird erkannt', () => {
  fixture(({ root, execute }) => {
    const path = join(root, 'docs', 'PROGRESS.md');
    writeFileSync(path, readFileSync(path, 'utf8') + '\n| TT-001 | Duplikat | OFFEN | — |\n');
    const result = execute();
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Duplicate task status row: TT-001/);
  });
});

test('Relative Links dürfen das Repository nicht verlassen', () => {
  fixture(({ root, execute }) => {
    writeFileSync(join(root, 'README.md'), '[Außerhalb](../secret.txt)\n');
    const result = execute();
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Link points outside repository/);
  });
});

test('Fehlerhafte Prozentkodierung in Links ist ein Testfehler', () => {
  fixture(({ root, execute }) => {
    writeFileSync(join(root, 'README.md'), '[Unlesbar](docs/invalid%ZZ.md)\n');
    const result = execute();
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Invalid percent-encoding/);
  });
});

test('Externe Links werden offline nicht abgefragt', () => {
  fixture(({ root, execute }) => {
    writeFileSync(join(root, 'README.md'), '[Externe Quelle](https://example.invalid/missing)\n[Plan](docs/IMPLEMENTATION_PLAN.md)\n');
    const result = execute();
    assert.equal(result.status, 0, result.stderr);
  });
});

test('Fehlender --root-Wert liefert Exitcode 2', () => {
  const result = spawnSync(process.execPath, [checker, '--root'], { encoding: 'utf8' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Missing directory after --root/);
});
