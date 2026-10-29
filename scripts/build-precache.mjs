import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {webRoot,listBundleFiles} from './prepare-web.mjs';

export function buildPrecache(root=webRoot) {
  const digest=value=>createHash('sha256').update(value).digest('hex');
  const pageVersion=digest(JSON.stringify(listBundleFiles(root).filter(f=>!['offline.js','service-worker.js','precache-manifest.json','flutter_service_worker.js'].includes(f.path))));
  writeFileSync(resolve(root,'offline.js'),readFileSync(new URL('../apps/client/web/offline.js',import.meta.url),'utf8').replace("'PAGE_VERSION'",JSON.stringify(pageVersion)));
  // Only generated, public application assets. No runtime/API responses enter this list.
  const files=listBundleFiles(root).filter(f=>!['service-worker.js','precache-manifest.json','flutter_service_worker.js'].includes(f.path));
  for(const f of files) if(!/^(?:index\.html|flutter(?:_bootstrap)?\.js|main\.dart\.js|version\.json|manifest\.json|favicon\.png|offline\.js|icons\/[\w.-]+|scanner\/(?:zxing-0\.23\.0\.min\.js|LICENSE)|assets\/[\w./-]+|canvaskit\/[\w./-]+)$/.test(f.path)||f.path.split('/').includes('..')) throw new Error('Non-public precache path: '+f.path);
  for(const required of ['index.html','main.dart.js','offline.js','canvaskit/canvaskit.wasm','assets/FontManifest.json','assets/assets/catalogs/manifest.json']) if(!files.some(f=>f.path===required)) throw new Error('Missing offline asset: '+required);
  const version=digest(JSON.stringify(files));
  const manifest={formatVersion:1,version,pageVersion,bytes:files.reduce((n,f)=>n+f.bytes,0),files};
  const template=readFileSync(new URL('../apps/client/web/service-worker.js',import.meta.url),'utf8');
  writeFileSync(resolve(root,'service-worker.js'),template.replace('/* PRECACHE_MANIFEST */',JSON.stringify(manifest)));
  writeFileSync(resolve(root,'precache-manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  return manifest;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {const m=buildPrecache(process.argv[2]?resolve(process.argv[2]):webRoot);process.stdout.write(`Offline bundle: ${m.files.length} assets, ${m.bytes} bytes, ${m.version}\n`);}
