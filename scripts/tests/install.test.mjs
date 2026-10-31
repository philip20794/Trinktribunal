import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../../apps/client/web/install.js', import.meta.url), 'utf8');
function browser({ storage = new Map(), android = true, ios = false, standalone = false, blocked = false, now = 1_000_000, relatedApps } = {}) {
  const events = new Map(), links = [], location = {origin:'https://trinktribunal.pages.dev',href:'https://trinktribunal.pages.dev/join?room=ABCD2345'};
  const env = { URL, Event, JSON, Number, Date:{now:()=>now}, location,
    navigator:{userAgent:android?'Android Chrome':ios?'iPhone Safari':'Desktop',platform:'',maxTouchPoints:0,standalone:ios && standalone},
    localStorage:{getItem:key=>{if(blocked)throw Error();return storage.get(key)??null;},setItem:(key,v)=>{if(blocked)throw Error();storage.set(key,v);},removeItem:key=>storage.delete(key)},
    document:{createElement:()=>{const a={click:()=>links.push(a)};return a;}},
    matchMedia:()=>({matches:standalone,addEventListener:()=>{}}),
    addEventListener:(name,callback)=>{events.set(name,callback);},dispatchEvent:()=>{},
  };
  if (relatedApps) env.navigator.getInstalledRelatedApps = async () => relatedApps;
  vm.runInNewContext(source,env);
  return {env,storage,links,location,advance:ms=>now+=ms,event:(name,event)=>events.get(name)?.(event),action:async(a,arg)=>JSON.parse(await env.trinktribunalInstall(a,arg))};
}

test('declining a normal promotion suppresses it for exactly 14 days',async()=>{
  const b=browser();assert.equal((await b.action('status')).showPromotion,true);
  await b.action('dismiss');assert.equal((await b.action('status')).showPromotion,false);
  b.advance(14*86400000-1);assert.equal((await b.action('status')).showPromotion,false);
  b.advance(1);assert.equal((await b.action('status')).showPromotion,true);
});
test('Android PWA restores same-origin invitation, never extends TTL, clears only matching successful join',async()=>{
  const b=browser();await b.action('remember','ABCD2345');b.advance(14*60000);
  await b.action('remember','ABCD2345');
  const pwa=browser({storage:b.storage,standalone:true,now:1_000_000+14*60000});
  assert.equal((await pwa.action('status')).pending,'ABCD2345');
  assert.equal((await pwa.action('status')).showPromotion,false);
  await pwa.action('clear','WXYZ2345');assert.equal((await pwa.action('status')).pending,'ABCD2345');
  b.advance(60000);assert.equal((await b.action('status')).pending,null);
  await pwa.action('clear','ABCD2345');assert.equal((await pwa.action('status')).pending,null);
});
test('APK download preserves invite and explicit open passes only room to the app with browser fallback',async()=>{
  const b=browser();await b.action('remember','ABCD2345');
  const state=await b.action('download');assert.equal(state.downloaded,true);
  assert.equal(b.links[0].href,'https://github.com/philip20794/Trinktribunal/releases/latest/download/trinktribunal.apk');
  assert.equal(b.links[0].rel,'noopener');
  assert.equal((await browser({storage:b.storage}).action('status')).downloaded,true);
  await b.action('open');assert.match(b.location.href,/^intent:\/\/app\/join\?room=ABCD2345#Intent;scheme=trinktribunal;package=com.example.trinktribunal;/);
  assert.ok(b.location.href.includes(encodeURIComponent('https://trinktribunal.pages.dev/join?room=ABCD2345')));
  b.advance(15*60000);assert.equal((await b.action('open')).result,'expired');
});
test('one-shot native prompt is captured early and installation suppresses promotion without guessing APK presence',async()=>{
  const b=browser();let calls=0,prevented=false;
  b.event('beforeinstallprompt',{preventDefault:()=>prevented=true,prompt:async()=>{calls++;return{outcome:'accepted'};}});
  assert.equal(prevented,true);assert.equal((await b.action('status')).canPrompt,true);
  assert.equal((await b.action('prompt')).result,'accepted');
  assert.equal((await b.action('prompt')).result,'unavailable');assert.equal(calls,1);
  b.event('appinstalled');const s=await b.action('status');assert.equal(s.pwaInstalled,true);assert.equal(s.apkInstalled,false);assert.equal(s.showPromotion,false);
});
test('iOS, corrupt/future storage and blocked storage retain a usable browser fallback',async()=>{
  const b=browser({android:false,ios:true,blocked:true});
  await b.action('remember','ABCD2345');assert.equal((await b.action('status')).pending,'ABCD2345');
  assert.equal((await b.action('prompt')).result,'unavailable');
  assert.equal((await b.action('status')).ios,true);await b.action('download');assert.equal(b.links.length,0);
  const storage=new Map([['trinktribunal.pendingInvite.v1',JSON.stringify({code:'ABCD2345',at:999999999})]]);
  assert.equal((await browser({storage}).action('status')).pending,null);
});
test('App Links use the actual release certificate and stable origin/package identity',()=>{
  const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
  const links=JSON.parse(read('apps/client/web/.well-known/assetlinks.json'));
  assert.equal(links[0].target.package_name,'com.example.trinktribunal');
  assert.match(links[0].target.sha256_cert_fingerprints[0],/^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$/);
  const manifest=read('apps/client/android/app/src/main/AndroidManifest.xml');
  assert.match(manifest,/android:autoVerify="true"/);assert.match(manifest,/android:host="trinktribunal.pages.dev" android:path="\/join"/);
  assert.match(manifest,/android:scheme="trinktribunal" android:host="app"/);
  const pwa=JSON.parse(read('apps/client/web/manifest.json'));assert.equal(pwa.display,'standalone');assert.equal(pwa.id,'.');
  assert.equal(pwa.related_applications[0].url,'https://trinktribunal.pages.dev/manifest.json');
});

test('reliably detected installed PWA disables promotion on the first status read',async()=>{
  const b=browser({relatedApps:[{platform:'webapp',url:'https://trinktribunal.pages.dev/manifest.json'}]});
  const state=await b.action('status');
  assert.equal(state.pwaInstalled,true);assert.equal(state.showPromotion,false);
});
