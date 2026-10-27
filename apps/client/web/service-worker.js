'use strict';
const manifest = /* PRECACHE_MANIFEST */;
const base = new URL('./', self.location.href);
const prefix = 'trinktribunal-offline-' + encodeURIComponent(base.pathname) + '-';
const cacheName = prefix + manifest.version;
const assets = new Map(manifest.files.map(f => [new URL(f.path, base).href, f]));
const digest = async buffer => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', buffer)), b => b.toString(16).padStart(2, '0')).join('');
async function complete() {
  const cache = await caches.open(cacheName);
  for (const url of assets.keys()) if (!await cache.match(url)) return false;
  return true;
}
async function download() {
  const cache = await caches.open(cacheName);
  const wasComplete = await complete();
  try {
    for (const [url, file] of assets) {
      const response = await fetch(url, {cache: 'no-store', credentials: 'omit', redirect: 'error'});
      if (!response.ok || response.type === 'opaque') throw new Error('Offline download failed');
      const bytes = await response.clone().arrayBuffer();
      if (bytes.byteLength !== file.bytes || await digest(bytes) !== file.sha256) throw new Error('Offline asset changed during download');
      await cache.put(url, response);
    }
    if (!await complete()) throw new Error('Incomplete cache');
  } catch (error) { if(!wasComplete) await caches.delete(cacheName); throw error; }
  // Updates wait. The previous version continues serving its own complete assets.
}
self.addEventListener('install', event => event.waitUntil(download()));
self.addEventListener('activate', event => event.waitUntil(Promise.resolve()));
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || event.request.headers.has('authorization') || url.origin !== base.origin || url.search || !url.href.startsWith(base.href)) return;
  const relative = url.pathname.slice(base.pathname.length);
  if (/^(?:api|ws|rooms|health)(?:\/|$)/.test(relative)) return;
  const target = event.request.mode === 'navigate' && (!relative || relative === 'index.html' || !relative.includes('.')) ? new URL('index.html', base).href : url.href;
  if (!assets.has(target)) return;
  // Never silently mix the cached application with assets from a newer deployment.
  event.respondWith((async () => (await (await caches.open(cacheName)).match(target)) || new Response('Offline cache missing. Reconnect and prepare again.', {status:503}))());
});
self.addEventListener('message', event => {
  event.waitUntil((async () => {
    const reply = value => event.ports[0]?.postMessage(value);
    if (!event.source || !event.source.url.startsWith(base.href)) return;
    if (event.data?.type === 'status') reply({ready:await complete(),version:manifest.version,pageVersion:manifest.pageVersion,bytes:manifest.bytes});
    if (event.data?.type === 'repair') {
      try {await download();reply({ok:true});} catch (_) {reply({error:'failed'});}
    }
    if (event.data?.type === 'canClear') {
      const tabs = await self.clients.matchAll({type:'window',includeUncontrolled:true});
      reply({ok:tabs.filter(c=>c.url.startsWith(base.href)).length===1});
    }
    if (event.data?.type === 'activate') {
      const tabs = await self.clients.matchAll({type:'window',includeUncontrolled:true});
      if (tabs.filter(c=>c.url.startsWith(base.href)).length !== 1 || !await complete()) {reply({error:'closeTabs'});return;}
      reply({ok:true}); await self.skipWaiting();
    }
    if (event.data?.type === 'prune') {
      // Only a page actually served by this version may remove previous bundles.
      if (event.data.version !== manifest.version || !await complete()) {reply({ok:false});return;}
      const tabs = await self.clients.matchAll({type:'window',includeUncontrolled:true});
      if (tabs.filter(c=>c.url.startsWith(base.href)).length === 1) for(const name of await caches.keys()) if(name.startsWith(prefix)&&name!==cacheName) await caches.delete(name);
      reply({ok:true});
    }
  })());
});
