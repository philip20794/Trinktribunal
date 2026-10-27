'use strict';
// Explicit preparation only; an ordinary first visit makes no offline promise.
globalThis.trinktribunalOffline = async function(action) {
  const pageVersion='PAGE_VERSION';
  const result = value => JSON.stringify(value);
  if (!isSecureContext || !('serviceWorker' in navigator)) return result({state:'unavailable'});
  const base = new URL('./', document.baseURI);
  const rpc = (worker,type,extra={}) => new Promise((resolve,reject) => {
    const channel = new MessageChannel();
    const timer = setTimeout(()=>{channel.port1.close();reject(new Error('timeout'));},120000);
    channel.port1.onmessage = e => {clearTimeout(timer);channel.port1.close();resolve(e.data);};
    worker.postMessage({type,...extra},[channel.port2]);
  });
  try {
    let registration = await navigator.serviceWorker.getRegistration(base.href);
    if (action === 'clear') {
      if(registration?.active && !(await rpc(registration.active,'canClear')).ok) return result({state:'closeTabs'});
      if (registration) await registration.unregister();
      for(const name of await caches.keys()) if(name.startsWith('trinktribunal-offline-'+encodeURIComponent(base.pathname)+'-')) await caches.delete(name);
      return result({state:'empty'});
    }
    if (action === 'prepare') {
      registration = await navigator.serviceWorker.register(new URL('service-worker.js',base),{scope:base.pathname,updateViaCache:'none'});
      await registration.update();
      const installing=registration.installing;
      if(installing) await new Promise((resolve,reject)=>{
        const check=()=>{if(installing.state==='installed'||installing.state==='activated')resolve();if(installing.state==='redundant')reject(new Error('install failed'));};
        installing.addEventListener('statechange',check);check();
      });
      if(registration.active&&!registration.waiting&&!(await rpc(registration.active,'status')).ready) {
        if((await rpc(registration.active,'repair')).error) return result({state:'failed'});
      }
    }
    if (!registration) return result({state:'empty'});
    if (action === 'apply') {
      const worker=registration.waiting;
      if(worker) {
        const answer=await rpc(worker,'activate');
        if(answer.error) return result({state:answer.error});
        if(worker.state!=='activated') await new Promise(resolve=>{const check=()=>{if(worker.state==='activated')resolve();};worker.addEventListener('statechange',check);check();});
      }
      location.reload();return result({state:'loading'});
    }
    const worker=registration.waiting||registration.active;
    if(!worker) return result({state:'empty'});
    const status=await rpc(worker,'status');
    if(status.ready&&status.pageVersion===pageVersion&&navigator.serviceWorker.controller&&!registration.waiting) await rpc(worker,'prune',{version:status.version});
    return result({...status,state:!status.ready?'empty':registration.waiting?'update':!navigator.serviceWorker.controller||status.pageVersion!==pageVersion?'reload':'ready'});
  } catch (_) {return result({state:'failed'});}
};
