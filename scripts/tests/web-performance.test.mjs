import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname,resolve,basename} from 'node:path';
import {trimJsRenderers,measureWeb} from '../web-performance.mjs';
import {buildPrecache} from '../build-precache.mjs';

function fixture(t) {
  const root=mkdtempSync(join(tmpdir(),'trinktribunal-performance-'));
  t.after(()=>{
    if(dirname(root)!==resolve(tmpdir())||!basename(root).startsWith('trinktribunal-performance-')) throw new Error('Unsafe cleanup');
    rmSync(root,{recursive:true,force:true});
  });
  const put=(path,data)=>{mkdirSync(dirname(join(root,path)),{recursive:true});writeFileSync(join(root,path),data);};
  const bootstrap=(builds=[{compileTarget:'dart2js',renderer:'canvaskit'}],variant='full')=>put('flutter_bootstrap.js',`_flutter.buildConfig = ${JSON.stringify({builds})};\n_flutter.loader.load({config:{canvasKitVariant:'${variant}'}});`);
  bootstrap();
  for(const path of ['index.html','main.dart.js','offline.js','assets/FontManifest.json','assets/assets/catalogs/manifest.json','canvaskit/canvaskit.js','canvaskit/canvaskit.wasm','canvaskit/skwasm.wasm','canvaskit/chromium/canvaskit.js','canvaskit/webparagraph/canvaskit.wasm','canvaskit/canvaskit.js.symbols']) put(path,'public asset '.repeat(100));
  return {root,put,bootstrap};
}

test('JS trim preserves selected full renderer and complete app assets, is idempotent',t=>{
  const {root}=fixture(t),before=readFileSync(join(root,'canvaskit/canvaskit.wasm'));
  const result=trimJsRenderers(root);
  assert.equal(result.removedFiles.length,4);
  assert.ok(result.removedBytes>0);
  assert.deepEqual(readFileSync(join(root,'canvaskit/canvaskit.wasm')),before);
  assert.ok(existsSync(join(root,'assets/assets/catalogs/manifest.json')));
  assert.equal(trimJsRenderers(root).removedBytes,0);
  assert.ok(buildPrecache(root).files.some(f=>f.path==='canvaskit/canvaskit.wasm'));
});

test('dual Wasm/fallback or automatic renderer variants cannot be trimmed',t=>{
  const {root,bootstrap}=fixture(t);
  bootstrap([{compileTarget:'dart2wasm',renderer:'skwasm'},{compileTarget:'dart2js',renderer:'canvaskit'}]);
  assert.throws(()=>trimJsRenderers(root),/JS-only/);
  bootstrap(undefined,'auto');assert.throws(()=>trimJsRenderers(root),/JS-only/);
  assert.ok(existsSync(join(root,'canvaskit/skwasm.wasm')));
});

test('unknown future renderer file fails before deleting any known file',t=>{
  const {root,put}=fixture(t);put('canvaskit/new-runtime.wasm','future');
  assert.throws(()=>trimJsRenderers(root),/Unknown renderer/);
  assert.ok(existsSync(join(root,'canvaskit/skwasm.wasm')));
});

test('measurement reports real bytes/compression and rejects a stale offline bundle',t=>{
  const {root,put}=fixture(t);trimJsRenderers(root);const manifest=buildPrecache(root);
  const result=measureWeb(root);
  assert.equal(result.precache.bytes,manifest.bytes);
  assert.equal(result.totals.bytes,result.files.reduce((n,f)=>n+f.bytes,0));
  assert.ok(result.totals.gzipBytes<result.totals.bytes);
  assert.ok(result.totals.brotliBytes<result.totals.bytes);
  put('main.dart.js','new version');assert.throws(()=>measureWeb(root),/Precache integrity/);
});
