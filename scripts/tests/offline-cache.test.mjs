import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash,webcrypto} from 'node:crypto';
import {runInNewContext} from 'node:vm';

const source=readFileSync(new URL('../../apps/client/web/service-worker.js',import.meta.url),'utf8');
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
class Storage {
  stores=new Map();
  async open(name) {if(!this.stores.has(name)) this.stores.set(name,new Map());const map=this.stores.get(name);return {match:async key=>map.get(key)?.clone(),put:async(key,value)=>map.set(key,value.clone())};}
  async keys(){return [...this.stores.keys()];}
  async delete(name){return this.stores.delete(name);}
}
function worker(version,{caches=new Storage(),bad=null,tabs=1}={}) {
  const files={'index.html':`<html>${version}</html>`,'main.dart.js':`app ${version}`,'assets/catalog.json':`catalog ${version}`,'canvaskit/canvaskit.wasm':'wasm'};
  const manifest={version,pageVersion:'page-'+version,bytes:123,files:Object.entries(files).map(([path,content])=>({path,bytes:Buffer.byteLength(content),sha256:hash(content)}))};
  const listeners={};let skipped=false;let network=0;
  const self={location:{href:'https://example.test/game/service-worker.js'},addEventListener:(type,fn)=>listeners[type]=fn,skipWaiting:async()=>{skipped=true;},clients:{matchAll:async()=>Array.from({length:tabs},(_,i)=>({id:String(i),url:'https://example.test/game/'}))}};
  runInNewContext(source.replace('/* PRECACHE_MANIFEST */',JSON.stringify(manifest)),{self,caches,crypto:webcrypto,URL,Response,Uint8Array,Map,Promise,fetch:async url=>{network++;const path=new URL(url).pathname.replace('/game/','');return new Response(path===bad?'corrupt':files[path],{status:path in files?200:404});}});
  return {caches,manifest,get skipped(){return skipped;},get network(){return network;},
    async install(){let task;listeners.install({waitUntil:p=>task=p});await task;},
    async message(type,extra={}){let task,reply;listeners.message({data:{type,...extra},source:{url:'https://example.test/game/'},ports:[{postMessage:value=>reply=value}],waitUntil:p=>task=p});await task;return reply;},
    async fetch(path,{method='GET',mode='cors',auth=false}={}) {let response;listeners.fetch({request:{url:new URL(path,'https://example.test/game/').href,method,mode,headers:new Headers(auth?{authorization:'secret'}:{})},respondWith:p=>response=p});return response?await response:null;},
  };
}
test('complete verified cache is ready and serves every asset without network',async()=>{
  const w=worker('A');assert.equal((await w.message('status')).ready,false);await w.install();assert.equal((await w.message('status')).ready,true);
  const requests=w.network;assert.equal(await (await w.fetch('main.dart.js')).text(),'app A');assert.equal(await (await w.fetch('play',{mode:'navigate'})).text(),'<html>A</html>');assert.equal(w.network,requests);assert.equal(w.skipped,false);
});
test('API, credentials, query strings, methods, unknown assets and other origins bypass cache',async()=>{
  const w=worker('A');await w.install();
  for(const path of ['api/rooms','ws','rooms/123','health','missing.js','main.dart.js?token=secret','https://other.test/main.dart.js']) assert.equal(await w.fetch(path),null,path);
  assert.equal(await w.fetch('main.dart.js',{auth:true}),null);assert.equal(await w.fetch('main.dart.js',{method:'POST'}),null);
});
test('corrupt update cannot destroy A; B remains waiting until explicit safe activation',async()=>{
  const a=worker('A');await a.install();const bad=worker('B',{caches:a.caches,bad:'assets/catalog.json'});await assert.rejects(()=>bad.install(),/changed/);
  assert.equal(await (await a.fetch('assets/catalog.json')).text(),'catalog A');assert.equal((await a.caches.keys()).length,1);
  const b=worker('B',{caches:a.caches});await b.install();assert.equal(b.skipped,false);assert.equal(await (await a.fetch('main.dart.js')).text(),'app A');assert.equal(await (await b.fetch('main.dart.js')).text(),'app B');
  assert.equal((await b.message('activate')).ok,true);assert.equal(b.skipped,true);
});
test('multiple tabs block activation/clearing and old caches survive until matching new page',async()=>{
  const a=worker('A');await a.install();const b=worker('B',{caches:a.caches,tabs:2});await b.install();assert.equal((await b.message('activate')).error,'closeTabs');assert.equal((await b.message('canClear')).ok,false);assert.equal(b.skipped,false);
  await b.message('prune',{version:'B'});assert.equal((await a.caches.keys()).length,2);
  const single=worker('B',{caches:a.caches});await single.message('prune',{version:'A'});assert.equal((await a.caches.keys()).length,2);await single.message('prune',{version:'B'});assert.equal((await a.caches.keys()).length,1);
});
test('evicted asset removes ready; missing cached asset fails closed; preparation repairs it',async()=>{
  const w=worker('A');await w.install();const cache=w.caches.stores.values().next().value;cache.delete('https://example.test/game/main.dart.js');assert.equal((await w.message('status')).ready,false);assert.equal((await w.fetch('main.dart.js')).status,503);
  assert.equal((await w.message('repair')).ok,true);assert.equal((await w.message('status')).ready,true);
});
test('failed re-download of an existing complete version preserves verified bundle',async()=>{
  const a=worker('A');await a.install();const again=worker('A',{caches:a.caches,bad:'main.dart.js'});await assert.rejects(()=>again.install());assert.equal((await a.message('status')).ready,true);assert.equal(await (await a.fetch('main.dart.js')).text(),'app A');
});
