export function webSecurityPolicy(apiBaseUrl = '') {
  const connections = ["'self'"];
  if (apiBaseUrl) {
    let api;
    try { api = new URL(apiBaseUrl); } catch { throw new Error('Invalid API origin for web release'); }
    const local = ['localhost', '127.0.0.1', '[::1]', '10.0.2.2'].includes(api.hostname);
    if (api.username || api.password || api.search || api.hash || api.pathname !== '/' ||
        !(api.protocol === 'https:' || api.protocol === 'http:' && local)) {
      throw new Error('Invalid API origin for web release');
    }
    connections.push(api.origin);
    api.protocol = api.protocol === 'https:' ? 'wss:' : 'ws:';
    connections.push(api.origin);
  }
  return [
    "default-src 'self'", "base-uri 'self'", "object-src 'none'",
    "script-src 'self' 'wasm-unsafe-eval'", "script-src-attr 'none'",
    "style-src 'self' 'unsafe-inline'", "img-src 'self' data: blob:",
    "font-src 'self' data:", "media-src 'self' data: blob:",
    "worker-src 'self' blob:", "frame-src 'none'", "form-action 'none'",
    "manifest-src 'self'", `connect-src ${connections.join(' ')}`,
  ].join('; ');
}

const policyMeta = /<meta\s+http-equiv="Content-Security-Policy"\s+content="([^"]*)"\s*\/?\s*>/gi;
export function releasePolicy(html) {
  return [...html.matchAll(policyMeta)][0]?.[1] ?? null;
}
export function secureReleaseHtml(html, apiBaseUrl = '') {
  // Only repository-owned entry scripts are allowed. Renderer scripts are loaded
  // from the local bootstrap; user names/content never enter HTML construction.
  for (const script of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)) {
    const source = script[1].match(/\bsrc\s*=\s*(['"])(.*?)\1/i)?.[2];
    if (!source || !/^(?:\.\/)?(?:install|offline|flutter_bootstrap)\.js$/.test(source) || script[2].trim()) {
      throw new Error('Release entry scripts must be local and external');
    }
  }
  if (/\son[a-z]+\s*=/i.test(html)) throw new Error('Release HTML cannot contain script handlers');
  const meta = `<meta http-equiv="Content-Security-Policy" content="${webSecurityPolicy(apiBaseUrl)}">`;
  const policies = [...html.matchAll(policyMeta)];
  if (policies.length > 1) throw new Error('Duplicate release security policy');
  if (policies.length === 1) return html.replace(policyMeta, meta);
  const clean = html;
  if (/<head\b[^>]*>/i.test(clean)) return clean.replace(/<head\b[^>]*>/i, head => head + '\n' + meta);
  if (/^<!doctype[^>]*>/i.test(clean)) return clean.replace(/^<!doctype[^>]*>/i, type => type + '\n' + meta);
  return meta + '\n' + clean;
}
