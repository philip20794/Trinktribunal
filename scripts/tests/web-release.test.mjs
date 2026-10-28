import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync,symlinkSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname,resolve,basename} from 'node:path';
import {request} from 'node:http';
import {createReleaseServer} from '../serve-web.mjs';
import {prepareWeb} from '../prepare-web.mjs';
import {buildPrecache} from '../build-precache.mjs';
import {secureReleaseHtml,webSecurityPolicy,releasePolicy} from '../web-security.mjs';

function fixture(t) {
  const root=mkdtempSync(join(tmpdir(),'trinktribunal-web-test-'));
  t.after(()=>{ if(dirname(root)!==resolve(tmpdir())||!basename(root).startsWith('trinktribunal-web-test-')) throw new Error('Unsafe fixture cleanup'); rmSync(root,{recursive:true,force:true}); });
  const put=(path,data)=>{ mkdirSync(dirname(join(root,path)),{recursive:true});writeFileSync(join(root,path),data); };
  put('index.html','<!doctype html><base href="/"><title>Trinktribunal</title>');
  put('flutter_bootstrap.js','_flutter.buildConfig = {"builds":[{"compileTarget":"dart2js","renderer":"canvaskit"}]};\n_flutter.loader.load({config:{canvasKitBaseUrl:new URL("canvaskit/",document.baseURI),fontFallbackBaseUrl:new URL("assets/font-fallback/",document.baseURI)}});');
  put('main.dart.js','console.log("release")'); put('version.json',JSON.stringify({version:'0.1.0',build_number:'1'}));
  put('manifest.json','{}'); put('assets/AssetManifest.bin',Buffer.from([0,1])); put('assets/FontManifest.json','[{"family":"test","fonts":[{"asset":"test.ttf"}]}]'); put('assets/test.ttf','font');
  put('assets/assets/catalogs/manifest.json','{"catalogs":[{"kind":"questions","language":"de","sha256":"test-hash"}]}');
  put('assets/assets/avatars/manifest.json','{"version":1}'); put('canvaskit/canvaskit.js','export default {}'); put('canvaskit/canvaskit.wasm',Buffer.from([0,97,115,109]));
  put('.env','private'); return {root,put};
}
async function serve(t,root) {
  const server=await createReleaseServer({root}); await new Promise((done,fail)=>{server.once('error',fail); server.listen(0,'127.0.0.1',done);});
  t.after(()=>new Promise(done=>server.close(done)));
  return (path,{method='GET',accept='*/*'}={})=>new Promise((done,fail)=>{
    const req=request({host:'127.0.0.1',port:server.address().port,path,method,headers:{accept}},res=>{const data=[];res.on('data',chunk=>data.push(chunk));res.on('end',()=>done({code:res.statusCode,headers:res.headers,body:Buffer.concat(data)}));}); req.on('error',fail);req.end();
  });
}
test('release server returns correct HTML/JS/Wasm/font MIME and HEAD',async t=>{
  const {root}=fixture(t),get=await serve(t,root);
  for(const [path,mime] of [['/','text/html'],['/main.dart.js','text/javascript'],['/canvaskit/canvaskit.wasm','application/wasm'],['/assets/test.ttf','font/ttf']]) {
    const res=await get(path); assert.equal(res.code,200); assert.ok(res.headers['content-type'].startsWith(mime));assert.equal(res.headers['x-content-type-options'],'nosniff');
    const head=await get(path,{method:'HEAD'});assert.equal(head.code,200);assert.equal(head.body.length,0);assert.equal(Number(head.headers['content-length']),res.body.length);
  }
  assert.equal((await get('/')).headers['cache-control'],'no-store');
  assert.equal((await get('/main.dart.js')).headers['cache-control'],'no-cache');
  assert.equal((await get('/flutter_bootstrap.js')).headers['cache-control'],'no-store');
});
test('SPA fallback is navigation-only, missing assets and APIs remain 404',async t=>{
  const {root}=fixture(t),get=await serve(t,root);
  assert.equal((await get('/game/session',{accept:'text/html'})).code,200);
  for(const path of ['/missing.js','/assets/missing','/canvaskit/missing.wasm','/api/rooms','/ws','/rooms/ABC','/.env','/.git/config']) assert.equal((await get(path,{accept:'text/html'})).code,404,path);
  assert.equal((await get('/unknown')).code,404);
  assert.equal((await get('/',{method:'POST'})).code,405);
});
test('traversal, malformed escapes and backslashes cannot escape release root',async t=>{
  const {root}=fixture(t),get=await serve(t,root);
  for(const path of ['/../outside','/%2e%2e/outside','/%5c..%5coutside','/%00','/%zz']) assert.equal((await get(path)).code,400,path);
});
test('symlinks to outside files are rejected when the platform supports links',async t=>{
  const {root,put}=fixture(t); put('nested/private.txt','private');
  try { symlinkSync(join(root,'nested/private.txt'),join(root,'link.txt')); } catch(error) { if(error.code==='EPERM') {t.skip('Symlinks unavailable');return;} throw error; }
  // A sibling target is used to exercise the canonical-path boundary.
  const outside=join(tmpdir(),basename(root)+'-outside.txt');writeFileSync(outside,'outside');t.after(()=>rmSync(outside,{force:true}));
  symlinkSync(outside,join(root,'escape.txt')); const get=await serve(t,root);assert.equal((await get('/escape.txt')).code,403);
  assert.throws(()=>prepareWeb(root),/Symlinks/);
});
test('bundle metadata is stable and changes only when an asset changes',t=>{
  const {root,put}=fixture(t); const one=prepareWeb(root,{sourceRevision:'unit'});const two=prepareWeb(root,{sourceRevision:'unit'});
  assert.equal(one.bundleHash,two.bundleHash);assert.deepEqual(one.files,two.files);assert.equal(one.compileTarget,'dart2js');assert.equal(one.avatarVersion,1);assert.equal(one.catalogHashes[0].sha256,'test-hash');
  assert.ok(!one.files.some(f=>f.path.startsWith('.')));put('main.dart.js','changed');assert.notEqual(prepareWeb(root).bundleHash,one.bundleHash);
  assert.equal(JSON.parse(readFileSync(join(root,'build-info.json'),'utf8')).version,'0.1.0');
});
test('unexpanded templates, remote-default bootstraps and missing fonts fail preparation',t=>{
  const {root,put}=fixture(t);put('index.html','<base href="$FLUTTER_BASE_HREF">');assert.throws(()=>prepareWeb(root),/Unexpanded/);
  put('index.html','html');put('flutter_bootstrap.js','_flutter.loader.load();');assert.throws(()=>prepareWeb(root),/configuration/);
  put('flutter_bootstrap.js','_flutter.buildConfig = {"builds":[{"compileTarget":"dart2js","renderer":"canvaskit"}]};\ncanvasKitBaseUrl:new URL("canvaskit/",document.baseURI),fontFallbackBaseUrl:new URL("assets/font-fallback/",document.baseURI)');put('assets/FontManifest.json','[{"fonts":[{"asset":"missing.ttf"}]}]');assert.throws(()=>prepareWeb(root),/ENOENT|Missing/);
});

test('experimental Wasm cannot be mislabeled and published as an approved JS release',t=>{
  const {root,put}=fixture(t);
  put('flutter_bootstrap.js','_flutter.buildConfig = {"builds":[{"compileTarget":"dart2wasm","renderer":"skwasm"},{"compileTarget":"dart2js","renderer":"canvaskit"}]};');
  assert.throws(()=>prepareWeb(root),/comparison-only/);
});

test('precache is deterministic, integrity-complete and excludes workers/metadata',t=>{
  const {root,put}=fixture(t);put('offline.js','placeholder');
  const first=buildPrecache(root),second=buildPrecache(root);
  assert.deepEqual(first,second);
  for(const path of ['index.html','main.dart.js','offline.js','assets/test.ttf','canvaskit/canvaskit.wasm']) assert.ok(first.files.some(f=>f.path===path),path);
  assert.ok(!first.files.some(f=>['service-worker.js','build-info.json','precache-manifest.json'].includes(f.path)));
  assert.ok(readFileSync(join(root,'service-worker.js'),'utf8').includes(first.version));
  put('main.dart.js','next release');assert.notEqual(buildPrecache(root).version,first.version);
  put('api/secret.json','private');assert.throws(()=>buildPrecache(root),/Non-public/);
});

test('release CSP pins HTTPS and websocket origins without remote scripts or JavaScript eval',()=>{
  const policy=webSecurityPolicy('https://api.example.test:8443/');
  assert.ok(policy.includes("script-src 'self' 'wasm-unsafe-eval'"));
  assert.ok(policy.includes("connect-src 'self' https://api.example.test:8443 wss://api.example.test:8443"));
  assert.ok(!policy.includes("'unsafe-eval'"));
  assert.ok(!policy.includes('https:;'));
  assert.ok(webSecurityPolicy('http://localhost:8787').includes('ws://localhost:8787'));
  for(const api of ['http://remote.example','https://user:PRIVATE_MARKER@example.test','https://example.test/path','https://example.test/?PRIVATE_MARKER','https://example.test/#PRIVATE_MARKER','javascript:PRIVATE_MARKER']) {
    assert.throws(()=>webSecurityPolicy(api),error=>error.message==='Invalid API origin for web release');
  }
});

test('HTML hardening is idempotent and rejects injected entry scripts and handlers',()=>{
  const html='<!doctype html><html><head><base href="/"></head><body><script src="offline.js"></script><script src="flutter_bootstrap.js" async></script></body></html>';
  const secured=secureReleaseHtml(html,'https://api.example.test');
  assert.equal(secureReleaseHtml(secured,'https://api.example.test'),secured);
  assert.ok(secured.indexOf('Content-Security-Policy')<secured.indexOf('<base'));
  assert.equal(releasePolicy(secured),webSecurityPolicy('https://api.example.test'));
  const updated=secureReleaseHtml(secured,'https://new.example.test');
  assert.ok(!updated.includes('api.example.test'));
  for(const bad of ['<script>alert(1)</script>','<script src="https://foreign.test/script.js"></script>','<script src="offline.js">alert(1)</script>','<img src="x" onerror="alert(1)">']) {
    assert.throws(()=>secureReleaseHtml(html.replace('</body>',bad+'</body>')),/Release/);
  }
});

test('prepared HTML and release responses use the same API policy and preserve offline integrity',async t=>{
  const {root}=fixture(t);
  const apiBaseUrl='https://api.example.test';
  prepareWeb(root,{apiBaseUrl});
  const manifest=buildPrecache(root);
  const first=readFileSync(join(root,'index.html'),'utf8');
  prepareWeb(root,{apiBaseUrl});
  assert.equal(readFileSync(join(root,'index.html'),'utf8'),first);
  const get=await serve(t,root);
  for(const path of ['/','/game/session','/service-worker.js']) {
    const response=await get(path,{accept:'text/html'});
    assert.equal(response.code,200);
    assert.equal(response.headers['content-security-policy'],webSecurityPolicy(apiBaseUrl)+"; frame-ancestors 'none'");
    assert.equal(response.headers['referrer-policy'],'no-referrer');
    assert.equal(response.headers['x-frame-options'],'DENY');
    assert.equal(response.headers['permissions-policy'],'camera=(), microphone=(), geolocation=()');
  }
  assert.deepEqual(buildPrecache(root),manifest);
});
