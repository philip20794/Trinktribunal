import {readFileSync,readdirSync,existsSync,lstatSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve,join,isAbsolute} from 'node:path';
import {fileURLToPath} from 'node:url';

const repository=fileURLToPath(new URL('../',import.meta.url));
const digest=data=>createHash('sha256').update(data).digest('hex');
function safePath(root,path) {
  if(typeof path!=='string'||!path||isAbsolute(path)||/[\\:\0]/.test(path)||path.split('/').some(p=>['','..','.'].includes(p))) throw new Error('Invalid registry path');
  return join(root,path);
}
export function rightsInventory(root=repository) {
  const files=[];
  function scan(path,accept) {
    const full=safePath(root,path);
    if(!existsSync(full)) return;
    const stat=lstatSync(full);
    if(stat.isSymbolicLink()) throw new Error('Symlink in rights inventory');
    if(stat.isDirectory()) for(const name of readdirSync(full).sort()) scan(path+'/'+name,accept);
    else if(accept(path)) files.push(path);
  }
  scan('apps/client/assets',()=>true);
  for(const path of ['apps/client/web','apps/client/android/app/src/main/res','docs/avatars/references','docs/design/references/screens']) scan(path,p=>/\.(png|jpe?g|webp|svg|avif|ttf|otf)$/.test(p));
  return files.sort();
}
export function checkRights(registry,{root=repository,requiredFiles=rightsInventory(root),requireCleared=false}={}) {
  if(registry.formatVersion!==1||!Array.isArray(registry.packages)) throw new Error('Invalid rights registry');
  const ids=new Set(),files=new Set(),unresolved=[];
  for(const group of registry.packages) {
    if(!/^[a-z][a-z0-9-]+$/.test(group.id)||ids.has(group.id)) throw new Error('Duplicate or invalid rights package');
    ids.add(group.id);
    if(!['runtime','source-only','reference-only'].includes(group.distribution)||!['original','licensed','unresolved'].includes(group.status)||!group.provenance||!Array.isArray(group.files)||!group.files.length) throw new Error('Incomplete rights package: '+group.id);
    if(!existsSync(safePath(root,group.evidence))) throw new Error('Missing provenance evidence: '+group.id);
    if(group.status==='licensed') {
      if(!group.licenseId||!group.licenseFile||!group.files.some(f=>f.path===group.licenseFile)||!readFileSync(safePath(root,group.licenseFile),'utf8').trim()) throw new Error('Missing bundled license: '+group.id);
    }
    for(const file of group.files) {
      const full=safePath(root,file.path);
      if(files.has(file.path)) throw new Error('Duplicate rights file: '+file.path);
      files.add(file.path);
      if(lstatSync(full).isSymbolicLink()||!file.sha256||digest(readFileSync(full))!==file.sha256) throw new Error('Rights review hash mismatch: '+file.path);
    }
    if(group.status==='unresolved'&&group.distribution==='runtime') unresolved.push(group.id);
  }
  for(const path of requiredFiles) if(!files.has(path)) throw new Error('Unregistered asset: '+path);
  // An unbundled PNG package cannot silently become runtime without a rights review.
  const pubspec=existsSync(join(root,'apps/client/pubspec.yaml'))?readFileSync(join(root,'apps/client/pubspec.yaml'),'utf8'):'';
  const assetPaths=[...pubspec.matchAll(/^\s+-\s+(?:asset:\s+)?['"]?(assets\/[^'"\s]+)['"]?\s*(?:#.*)?$/gm)].map(m=>'apps/client/'+m[1]);
  for(const group of registry.packages) {
    if(group.distribution==='runtime') continue;
    if(group.files.some(f=>/^apps\/client\/(web|android)\//.test(f.path)||assetPaths.some(p=>p.endsWith('/')?f.path.startsWith(p):f.path===p))) throw new Error('Runtime asset declared source/reference-only: '+group.id);
  }
  if(requireCleared&&unresolved.length) throw new Error('Public release not cleared: '+unresolved.join(', '));
  return {packages:ids.size,files:files.size,unresolvedRuntime:unresolved,publicReleaseCleared:unresolved.length===0};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  if(process.argv.slice(2).some(arg=>arg!=='--require-cleared')) throw new Error('Unknown rights check argument');
  try {
    const result=checkRights(JSON.parse(readFileSync(join(repository,'docs/qa/rights-registry.json'),'utf8')),{requireCleared:process.argv.includes('--require-cleared')});
    process.stdout.write(`Rights inventory: ${result.packages} packages / ${result.files} files; unresolved runtime: ${result.unresolvedRuntime.join(', ')||'none'}; public release ${result.publicReleaseCleared?'CLEARED':'NOT CLEARED'}.\n`);
  } catch(error) {process.stderr.write(error.message+'\n');process.exitCode=1;}
}
