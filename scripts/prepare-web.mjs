import {readFileSync, writeFileSync, readdirSync, statSync, lstatSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';

export const webRoot = fileURLToPath(new URL('../apps/client/build/web/',import.meta.url));
const hash = content => createHash('sha256').update(content).digest('hex');
export function listBundleFiles(root, directory='') {
  const result=[];
  for(const name of readdirSync(join(root,directory)).sort()) {
    if(name.startsWith('.')||name==='build-info.json') continue;
    const relative=directory?directory+'/'+name:name;
    const full=join(root,relative); if(lstatSync(full).isSymbolicLink()) throw new Error('Symlinks are not release assets');
    if(statSync(full).isDirectory()) result.push(...listBundleFiles(root,relative));
    else result.push({path:relative,bytes:statSync(full).size,sha256:hash(readFileSync(full))});
  }
  return result;
}

export function prepareWeb(root=webRoot,{sourceRevision='unknown',sourceDirty=false}={}) {
  const required=['index.html','flutter_bootstrap.js','main.dart.js','version.json','manifest.json','assets/AssetManifest.bin','assets/FontManifest.json','assets/assets/catalogs/manifest.json','assets/assets/avatars/manifest.json','canvaskit/canvaskit.js','canvaskit/canvaskit.wasm'];
  for(const path of required) if(!statSync(join(root,path)).isFile()) throw new Error('Missing release asset: '+path);
  const html=readFileSync(join(root,'index.html'),'utf8'); const bootstrap=readFileSync(join(root,'flutter_bootstrap.js'),'utf8');
  if(html.includes('$FLUTTER_BASE_HREF')||bootstrap.includes('{{flutter_')) throw new Error('Unexpanded Flutter template');
  if(!/canvasKitBaseUrl\s*:\s*new URL\(['"]canvaskit\/['"],\s*document\.baseURI\)/.test(bootstrap)||!/fontFallbackBaseUrl\s*:\s*new URL\(['"]assets\/font-fallback\/['"],\s*document\.baseURI\)/.test(bootstrap)) throw new Error('Renderer/font URLs must be origin-local');
  const fonts=JSON.parse(readFileSync(join(root,'assets/FontManifest.json'),'utf8'));
  for(const family of fonts) for(const font of family.fonts) if(!statSync(join(root,'assets',font.asset)).isFile()) throw new Error('Missing bundled font');
  const manifest=JSON.parse(readFileSync(join(root,'assets/assets/catalogs/manifest.json'),'utf8'));
  const version=JSON.parse(readFileSync(join(root,'version.json'),'utf8'));
  const files=listBundleFiles(root);
  const info={formatVersion:1,renderer:'canvaskit',compileTarget:'dart2js',version:version.version,buildNumber:version.build_number,sourceRevision,sourceDirty,
    catalogHashes:manifest.catalogs.map(({kind,language,sha256})=>({kind,language,sha256})),
    bundleHash:hash(JSON.stringify(files)),files};
  writeFileSync(join(root,'build-info.json'),JSON.stringify(info,null,2)+'\n');
  return info;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const repo=fileURLToPath(new URL('../',import.meta.url)); let sourceRevision='unknown',sourceDirty=false;
  try { sourceRevision=execFileSync('git',['rev-parse','HEAD'],{cwd:repo,encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim(); sourceDirty=execFileSync('git',['status','--porcelain'],{cwd:repo,encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim().length>0; } catch {}
  const info=prepareWeb(process.argv[2]?resolve(process.argv[2]):webRoot,{sourceRevision,sourceDirty});
  process.stdout.write(`Web release ${info.version}+${info.buildNumber}: ${info.files.length} files, ${info.bundleHash}\n`);
}
