import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { httpsOrigin } from './check-android-release.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
export function checkProductionConfig(config, worker, { requireRealOrigins = false } = {}) {
  if (config.formatVersion !== 1 || Object.keys(config).some(key => !['formatVersion','apiBaseUrl','publicClientBaseUrl'].includes(key)))
    throw new Error('Invalid public production configuration');
  const workerKeys = ['$schema','name','main','compatibility_date','compatibility_flags','workers_dev','send_metrics',
    'vars','durable_objects','migrations','account_id','routes','route','dev','kv_namespaces','d1_databases','r2_buckets','services'];
  if (Object.keys(worker).some(key => !workerKeys.includes(key))) throw new Error('Invalid public worker configuration');
  const apiOrigin = httpsOrigin(config.apiBaseUrl), publicClientOrigin = httpsOrigin(config.publicClientBaseUrl);
  if (!apiOrigin || !publicClientOrigin) throw new Error('Missing public HTTPS origins');
  const placeholder = [apiOrigin, publicClientOrigin].some(origin => new URL(origin).hostname.endsWith('.invalid'));
  if (requireRealOrigins && placeholder) throw new Error('Replace example origins before building a production package');
  if (worker.workers_dev !== false || worker.send_metrics !== false || worker.dev ||
      worker.vars?.CLIENT_ORIGINS !== publicClientOrigin ||
      Object.keys(worker.vars ?? {}).some(key => key !== 'CLIENT_ORIGINS')) throw new Error('Production worker origin/telemetry policy mismatch');
  const bindings = worker.durable_objects?.bindings;
  if (!Array.isArray(bindings) || bindings.length !== 1 || bindings[0].name !== 'ROOMS' || bindings[0].class_name !== 'Room' || bindings[0].remote || bindings[0].script_name ||
      !worker.migrations?.some(m => m.new_sqlite_classes?.includes('Room'))) throw new Error('Production SQLite binding/migration mismatch');
  for (const key of ['kv_namespaces','d1_databases','r2_buckets','services'])
    if (worker[key]?.length) throw new Error('Unexpected additional production resource');
  return { apiOrigin, publicClientOrigin, exampleOnly: placeholder, workerName: worker.name,
    signingSecretsInConfig: false, deploymentPerformed: false };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    let configPath = 'docs/config/production.example.json', workerPath = 'apps/server/wrangler.release.example.jsonc', requireRealOrigins = false;
    const args = process.argv.slice(2);
    for (let i = 0; i < args.length; i++) {
      if (args[i] === '--config' && args[i + 1]) configPath = args[++i];
      else if (args[i] === '--worker-config' && args[i + 1]) workerPath = args[++i];
      else if (args[i] === '--require-real-origins') requireRealOrigins = true;
      else throw new Error('Unknown production configuration argument');
    }
    const read = path => JSON.parse(readFileSync(resolve(root, path), 'utf8'));
    process.stdout.write(JSON.stringify(checkProductionConfig(read(configPath), read(workerPath), { requireRealOrigins }), null, 2) + '\n');
  } catch (error) { process.stderr.write(error.message + '\n'); process.exitCode = 1; }
}
