import test from 'node:test';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {tmpdir} from 'node:os';

test('typed DTOs, catalog metadata and shared adversarial fixtures have no generator drift',()=>{
  for(const name of ['generate-room-dtos.mjs','generate-codec-fixtures.mjs'])execFileSync(process.execPath,[fileURLToPath(new URL('../'+name,import.meta.url)),'--check'],{cwd:tmpdir(),stdio:'pipe'});
});
