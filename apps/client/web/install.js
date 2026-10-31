'use strict';
// Loaded before Flutter so the browser's one-shot install event cannot be lost.
(() => {
  const inviteKey = 'trinktribunal.pendingInvite.v1';
  const dismissKey = 'trinktribunal.installDismissed.v1';
  const ttl = 15 * 60 * 1000;
  const cooldown = 14 * 24 * 60 * 60 * 1000;
  const apk = 'https://github.com/philip20794/Trinktribunal/releases/latest/download/trinktribunal.apk';
  let prompt = null, installed = false, relatedPwa = false, relatedApk = false;
  let downloaded = false, memoryInvite = null, memoryDismiss = null;
  let initialRelated = Promise.resolve();
  const read = key => { try { return localStorage.getItem(key); } catch (_) { return null; } };
  const write = (key, value) => { try { localStorage.setItem(key, value); } catch (_) { /* Browser join still works. */ } };
  const remove = key => { try { localStorage.removeItem(key); } catch (_) { /* Optional persistence. */ } };
  const standalone = () => navigator.standalone === true ||
    ['standalone', 'fullscreen', 'minimal-ui'].some(mode => matchMedia(`(display-mode: ${mode})`).matches);
  const android = /Android/i.test(navigator.userAgent);
  const ios = /iPad|iPhone|iPod/i.test(navigator.userAgent) || navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1;
  const changed = () => dispatchEvent(new Event('trinktribunal-install-change'));
  function pending() {
    try {
      const value = JSON.parse(read(inviteKey) || memoryInvite || 'null');
      if (value && /^[A-HJ-NP-Z2-9]{8}$/.test(value.code) && Number.isSafeInteger(value.at) &&
          Date.now() >= value.at && Date.now() - value.at < ttl) return value.code;
    } catch (_) { /* Invalid/expired invitations never affect routing. */ }
    remove(inviteKey); memoryInvite = null;
    return null;
  }
  function status() {
    const storedDismissal = Number(read(dismissKey) || memoryDismiss || 0);
    const dismissed = Number.isSafeInteger(storedDismissal) && storedDismissal <= Date.now() ? storedDismissal : 0;
    const code = pending();
    let apkRequested = false;
    try { apkRequested = !!code && JSON.parse(read(inviteKey) || memoryInvite || 'null')?.apkRequested === true; } catch (_) { /* Optional flag. */ }
    return { web: true, android, ios, standalone: standalone(),
      pwaInstalled: standalone() || installed || relatedPwa, apkInstalled: relatedApk,
      canPrompt: !!prompt, downloaded: downloaded || apkRequested, pending: code,
      showPromotion: !(standalone() || installed || relatedPwa || relatedApk) &&
        (dismissed <= 0 || Date.now() - dismissed >= cooldown) };
  }
  async function related() {
    if (!navigator.getInstalledRelatedApps) return;
    try {
      const apps = await navigator.getInstalledRelatedApps();
      relatedPwa = apps.some(app => app.platform === 'webapp' && new URL(app.url, location.href).origin === location.origin);
      relatedApk = apps.some(app => app.platform === 'play' && app.id === 'com.example.trinktribunal');
      changed();
    } catch (_) { /* Unknown means unknown; never guess from timing or UA. */ }
  }
  addEventListener('beforeinstallprompt', event => { event.preventDefault(); prompt = event; changed(); });
  addEventListener('appinstalled', () => { installed = true; prompt = null; changed(); });
  addEventListener('pageshow', related);
  addEventListener('focus', related);
  addEventListener('storage', changed);
  for (const mode of ['standalone', 'fullscreen', 'minimal-ui']) {
    matchMedia(`(display-mode: ${mode})`).addEventListener('change', changed);
  }
  globalThis.trinktribunalInstall = async (action, argument = '') => {
    try {
      if (action === 'status' && !standalone()) await initialRelated;
      if (action === 'remember' && /^[A-HJ-NP-Z2-9]{8}$/.test(argument)) {
        // Revisiting/installing must not extend an existing invitation's lifetime.
        if (pending() !== argument) {
          memoryInvite = JSON.stringify({code: argument, at: Date.now()});
          write(inviteKey, memoryInvite);
        }
      } else if (action === 'clear' && pending() === argument) {
        remove(inviteKey); memoryInvite = null;
      } else if (action === 'dismiss') {
        memoryDismiss = String(Date.now()); write(dismissKey, memoryDismiss);
      } else if (action === 'prompt') {
        if (!prompt || status().pwaInstalled) return JSON.stringify({...status(), result:'unavailable'});
        const event = prompt; prompt = null;
        // No await before prompt(): preserve the button's user activation.
        const choice = await event.prompt();
        changed();
        return JSON.stringify({...status(), result:choice?.outcome || (await event.userChoice).outcome});
      } else if (action === 'download' && android && !relatedApk) {
        downloaded = true;
        if (pending()) {
          const invitation = JSON.parse(read(inviteKey) || memoryInvite);
          memoryInvite = JSON.stringify({...invitation, apkRequested:true});
          write(inviteKey, memoryInvite);
        }
        const link = document.createElement('a');
        link.href = apk; link.target = '_blank'; link.rel = 'noopener';
        link.click(); changed();
      } else if (action === 'open' && android) {
        const code = pending();
        if (!code) return JSON.stringify({...status(), result:'expired'});
        const fallback = new URL('/join', location.origin);
        fallback.searchParams.set('room', code);
        location.href = `intent://app/join?room=${code}#Intent;scheme=trinktribunal;package=com.example.trinktribunal;S.browser_fallback_url=${encodeURIComponent(fallback.href)};end`;
      }
      return JSON.stringify(status());
    } catch (_) { return JSON.stringify({...status(), result:'failed'}); }
  };
  initialRelated = related();
})();
