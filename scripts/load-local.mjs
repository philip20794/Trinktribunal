import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {cpus,totalmem,platform,release} from 'node:os';

// Exercises the real local workerd/SQLite/WebSocket stack through its test binding.
// No public endpoint, deployment, credential log, browser or internet load traffic.
const root=fileURLToPath(new URL('../',import.meta.url));
const args=process.argv.slice(2);
if(args.length&&!(args.length===2&&args[0]==='--output')) throw new Error('Usage: node scripts/load-local.mjs [--output REPORT.json]');
const output=resolve(root,args[1]??'apps/server/test-results/load-report.json');
const child=spawn(process.execPath,['node_modules/vitest/vitest.mjs','run','--no-file-parallelism','--reporter=default','--reporter=../../scripts/local-load-reporter.mjs','test/integration/full_game.test.ts','test/integration/cost_budget.test.ts'],{
  cwd:resolve(root,'apps/server'),env:{...process.env,NO_COLOR:'1',TT_LOCAL_BUDGET:'1'},stdio:['ignore','pipe','pipe'],
});
let log='';
child.stdout.on('data',chunk=>{log+=chunk.toString();process.stdout.write(chunk);});
child.stderr.on('data',chunk=>process.stderr.write(chunk));
const code=await new Promise((done,fail)=>{child.once('error',fail);child.once('close',done);});
if(code!==0) {process.exitCode=Number(code)||1;}
else {
  const measurements=[...log.matchAll(/TT_LOCAL_METRICS (\{[^\r\n]*\})/g)].map(match=>JSON.parse(match[1]));
  if(measurements.length!==4) throw new Error('Incomplete local measurements; expected both games, reconnect and parallel ACK run');
  mkdirSync(dirname(output),{recursive:true});
  writeFileSync(output,JSON.stringify({formatVersion:1,date:new Date().toISOString(),environment:{platform:platform(),release:release(),cpu:cpus()[0]?.model,physicalMemoryBytes:totalmem(),node:process.version},
    scope:'Local workerd test binding, not internet latency or Cloudflare billing. SQL read counts include test inspection; synthetic rate-token resets are excluded.',measurements},null,2)+'\n');
  process.stdout.write(`Local budget report: ${output}\n`);
}
