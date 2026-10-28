import {readFileSync, writeFileSync, unlinkSync} from 'node:fs';
import {gzipSync, brotliCompressSync, constants} from 'node:zlib';
import {createHash} from 'node:crypto';
import {resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {listBundleFiles,flutterBuilds} from './prepare-web.mjs';

// The pinned loader selects only these two files when canvasKitVariant is full.
// Refuse new/dual build layouts rather than silently breaking a renderer fallback.
export function trimJsRenderers(root) {
  const {bootstrap,builds}=flutterBuilds(root);
  if(builds.length!==1||builds[0].compileTarget!=='dart2js'||builds[0].renderer!=='canvaskit'||
     !/canvasKitVariant\s*:\s*['"]full['"]/.test(bootstrap)) throw new Error('Trimming requires JS-only full CanvasKit');
  const files=listBundleFiles(root).filter(f=>f.path.startsWith('canvaskit/'));
  const keep=new Set(['canvaskit/canvaskit.js','canvaskit/canvaskit.wasm']);
  for(const path of keep) if(!files.some(f=>f.path===path)) throw new Error('Missing full CanvasKit asset');
  const remove=files.filter(f=>!keep.has(f.path));
  for(const {path} of remove) if(!/^canvaskit\/(?:(?:chromium|webparagraph)\/canvaskit\.(?:js|wasm|js\.symbols)|canvaskit\.js\.symbols|(?:skwasm|skwasm_heavy|wimp)\.(?:js|wasm|js\.symbols))$/.test(path)) throw new Error('Unknown renderer asset: '+path);
  // All paths were enumerated without symlinks and validated before the first write.
  for(const {path} of remove) unlinkSync(join(root,path));
  return {removedBytes:remove.reduce((sum,f)=>sum+f.bytes,0),removedFiles:remove.map(f=>f.path)};
}

export function measureWeb(root) {
  const {builds}=flutterBuilds(root);
  const files=listBundleFiles(root).map(file=>{
    const data=readFileSync(join(root,file.path));
    return {...file,gzipBytes:gzipSync(data,{level:9}).length,brotliBytes:brotliCompressSync(data,{params:{[constants.BROTLI_PARAM_QUALITY]:6}}).length};
  });
  let precache=null;
  try { precache=JSON.parse(readFileSync(join(root,'precache-manifest.json'),'utf8')); }
  catch(error) { if(error.code!=='ENOENT') throw error; }
  if(precache) {
    for(const item of precache.files) {
      const actual=files.find(f=>f.path===item.path);
      if(!actual||actual.bytes!==item.bytes||actual.sha256!==item.sha256) throw new Error('Precache integrity mismatch: '+item.path);
    }
    if(precache.bytes!==precache.files.reduce((sum,f)=>sum+f.bytes,0)||
       precache.version!==createHash('sha256').update(JSON.stringify(precache.files)).digest('hex')) throw new Error('Precache summary mismatch');
  }
  const sum=key=>files.reduce((total,f)=>total+f[key],0);
  return {formatVersion:1,builds,files,totals:{files:files.length,bytes:sum('bytes'),gzipBytes:sum('gzipBytes'),brotliBytes:sum('brotliBytes')},
    precache:precache?{files:precache.files.length,bytes:precache.bytes,version:precache.version}:null,
    compression:'Per-file gzip level 9 / Brotli quality 6 laboratory compression; HTTP server compression and browser timings are not measured.'};
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const [mode,root,report]=process.argv.slice(2);
  if(!root||!['trim-js','measure'].includes(mode)) throw new Error('Usage: web-performance.mjs trim-js|measure BUILD_ROOT');
  const result=JSON.stringify(mode==='trim-js'?trimJsRenderers(resolve(root)):measureWeb(resolve(root)),null,2)+'\n';
  if(report) writeFileSync(resolve(report),result);
  else process.stdout.write(result);
}
