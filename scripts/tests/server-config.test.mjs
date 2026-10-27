import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const read=path=>JSON.parse(readFileSync(new URL('../../apps/server/'+path,import.meta.url),'utf8'));
test('worker configuration keeps all bindings local and declares SQLite migration',()=>{
  const config=read('wrangler.jsonc');
  assert.equal(config.workers_dev,false);
  assert.equal(config.send_metrics,false);
  for(const key of ['account_id','routes','route','services','kv_namespaces','d1_databases','r2_buckets'])assert.equal(config[key],undefined,key);
  assert.equal(config.dev.ip,'127.0.0.1');
  assert.equal(config.durable_objects.bindings.length,1);
  const binding=config.durable_objects.bindings[0];
  assert.equal(binding.name,'ROOMS');assert.equal(binding.class_name,'Room');assert.notEqual(binding.remote,true);assert.equal(binding.script_name,undefined);
  assert.ok(config.migrations.some(m=>m.new_sqlite_classes?.includes('Room')));
});
test('worker tools are exact dependencies with a committed matching lockfile',()=>{
  const pkg=read('package.json'),lock=read('package-lock.json');
  for(const version of Object.values(pkg.devDependencies))assert.match(version,/^\d+\.\d+\.\d+$/);
  assert.deepEqual(lock.packages[''].devDependencies,pkg.devDependencies);
});
