import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {tmpdir} from 'node:os';
import {join,dirname,resolve,basename} from 'node:path';
import {checkRights} from '../check-rights.mjs';

function fixture(t) {
  const root=mkdtempSync(join(tmpdir(),'trinktribunal-rights-'));
  t.after(()=>{
    if(dirname(root)!==resolve(tmpdir())||!basename(root).startsWith('trinktribunal-rights-')) throw new Error('Unsafe cleanup');
    rmSync(root,{recursive:true,force:true});
  });
  const put=(path,data)=>{mkdirSync(dirname(join(root,path)),{recursive:true});writeFileSync(join(root,path),data);};
  put('evidence.md','Unresolved source, no permission assumed.');
  put('sample.png','graphic');
  const entry={path:'sample.png',sha256:createHash('sha256').update('graphic').digest('hex')};
  const registry={formatVersion:1,packages:[{id:'sample-graphic',distribution:'runtime',status:'unresolved',provenance:'Supplied by owner, rights unknown',evidence:'evidence.md',files:[entry]}]};
  return {root,put,registry,options:{root,requiredFiles:['sample.png']}};
}

test('current inventory covers source/runtime images, fonts and content copies with their recorded evidence',()=>{
  const registry=JSON.parse(readFileSync(new URL('../../docs/qa/rights-registry.json',import.meta.url)));
  const result=checkRights(registry);
  for(const id of ['catalog-questions-de','catalog-questions-en','catalog-rules-de','catalog-rules-en','launcher-icons']) assert.ok(registry.packages.some(p=>p.id===id));
  assert.equal(registry.packages.find(p=>p.id==='roboto-fonts').licenseId,'Apache-2.0');
  if(result.unresolvedRuntime.length) assert.throws(()=>checkRights(registry,{requireCleared:true}),/Public release not cleared/);
  else assert.equal(checkRights(registry,{requireCleared:true}).publicReleaseCleared,true);
});

test('changed and new unregistered files invalidate the reviewed inventory',t=>{
  const f=fixture(t);f.put('sample.png','changed');
  assert.throws(()=>checkRights(f.registry,f.options),/hash mismatch/);
  f.put('sample.png','graphic');
  assert.throws(()=>checkRights(f.registry,{...f.options,requiredFiles:['sample.png','new.png']}),/Unregistered/);
});

test('duplicate IDs/files and escaping paths are rejected',t=>{
  const f=fixture(t),duplicate=structuredClone(f.registry.packages[0]);
  f.registry.packages.push(duplicate);assert.throws(()=>checkRights(f.registry,f.options),/Duplicate/);
  duplicate.id='second-package';assert.throws(()=>checkRights(f.registry,f.options),/Duplicate rights file/);
  f.registry.packages.pop();f.registry.packages[0].files[0].path='../outside';
  assert.throws(()=>checkRights(f.registry,f.options),/Invalid registry path/);
});

test('reference-only material does not clear runtime material or silently become bundled',t=>{
  const f=fixture(t),group=f.registry.packages[0];
  group.distribution='reference-only';
  assert.equal(checkRights(f.registry,{...f.options,requireCleared:true}).unresolvedRuntime.length,0);
  f.put('apps/client/pubspec.yaml',"flutter:\n  assets:\n    - 'assets/new/' # newly bundled\n");
  f.put('apps/client/assets/new/sample.png','graphic');group.files[0].path='apps/client/assets/new/sample.png';
  assert.throws(()=>checkRights(f.registry,{...f.options,requiredFiles:[group.files[0].path]}),/Runtime asset declared/);
});

test('licensed entries require the actual bundled, hashed license file',t=>{
  const f=fixture(t),group=f.registry.packages[0];group.status='licensed';group.licenseId='test-license';
  assert.throws(()=>checkRights(f.registry,f.options),/Missing bundled license/);
  f.put('license.txt','Test license evidence');group.licenseFile='license.txt';
  group.files.push({path:'license.txt',sha256:createHash('sha256').update('Test license evidence').digest('hex')});
  assert.equal(checkRights(f.registry,{...f.options,requireCleared:true}).publicReleaseCleared,true);
});
