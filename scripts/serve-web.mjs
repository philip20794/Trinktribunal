import {createServer} from 'node:http';
import {createReadStream} from 'node:fs';
import {stat, realpath, readFile} from 'node:fs/promises';
import {resolve, relative, isAbsolute, extname, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {releasePolicy,webSecurityPolicy} from './web-security.mjs';

const defaultRoot = fileURLToPath(new URL('../apps/client/build/web/', import.meta.url));
const mimeTypes = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.json':'application/json; charset=utf-8','.webmanifest':'application/manifest+json','.wasm':'application/wasm','.bin':'application/octet-stream','.ttf':'font/ttf','.otf':'font/otf','.woff2':'font/woff2','.png':'image/png','.ico':'image/x-icon','.svg':'image/svg+xml','.css':'text/css; charset=utf-8','.txt':'text/plain; charset=utf-8'};
const isInside = (root, path) => { const r=relative(root,path); return r!== '..' && !r.startsWith('..'+sep) && !isAbsolute(r); };

export async function createReleaseServer({root=defaultRoot}={}) {
  const directory = await realpath(root);
  if (!(await stat(resolve(directory,'index.html'))).isFile()) throw new Error('Missing release index.html; run build-web.ps1 first.');
  const policy = releasePolicy(await readFile(resolve(directory,'index.html'),'utf8')) ?? webSecurityPolicy();
  return createServer(async (request,response) => {
    response.setHeader('X-Content-Type-Options','nosniff');
    response.setHeader('Content-Security-Policy',policy+"; frame-ancestors 'none'");
    response.setHeader('X-Frame-Options','DENY');
    response.setHeader('Referrer-Policy','no-referrer');
    response.setHeader('Permissions-Policy','camera=(), microphone=(), geolocation=()');
    response.setHeader('Cache-Control','no-store');
    const fail = (code) => { response.writeHead(code,{'Content-Type':'text/plain; charset=utf-8'}); response.end(code===404?'Not found':'Request rejected'); };
    if (!['GET','HEAD'].includes(request.method)) { response.setHeader('Allow','GET, HEAD'); fail(405); return; }
    try {
      const raw=(request.url??'/').split('?')[0];
      if (!raw.startsWith('/')) { fail(400); return; }
      let path;
      try { path=decodeURIComponent(raw); } catch { fail(400); return; }
      const segments=path.split('/');
      if (path.includes('\\') || path.includes('\0') || path.includes(':') || segments.includes('..')) { fail(400); return; }
      if (segments.some(s=>s.startsWith('.')) || /^\/(?:api|ws|rooms|health)(?:\/|$)/.test(path)) { fail(404); return; }
      let target=resolve(directory,'.'+(path==='/'?'/index.html':path));
      if (!isInside(directory,target)) { fail(403); return; }
      let info;
      try { info=await stat(target); } catch (error) {
        if (error.code!=='ENOENT' && error.code!=='ENOTDIR') throw error;
        // Only browser navigation may fall back. Missing scripts/assets never
        // get HTML, even if a client supplies Accept: text/html.
        if (!extname(path) && !/^\/(?:assets|canvaskit)\//.test(path) && (request.headers.accept??'').includes('text/html')) {
          target=resolve(directory,'index.html'); info=await stat(target);
        } else { fail(404); return; }
      }
      if (!info.isFile()) { fail(404); return; }
      target=await realpath(target);
      if (!isInside(directory,target)) { fail(403); return; }
      response.writeHead(200,{'Content-Type':mimeTypes[extname(target).toLowerCase()]??'application/octet-stream','Content-Length':info.size,
        'Cache-Control': /(?:index\.html|flutter_bootstrap\.js|manifest\.json|version\.json|build-info\.json|service-worker\.js|precache-manifest\.json)$/.test(target)?'no-store':'no-cache'});
      if (request.method==='HEAD') { response.end(); return; }
      const stream=createReadStream(target); stream.on('error',()=>response.destroy()); stream.pipe(response);
    } catch { if (!response.headersSent) fail(500); else response.destroy(); }
  });
}

if (process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const args=process.argv.slice(2); let root=defaultRoot,port=8080;
  for(let i=0;i<args.length;i++) {
    if(args[i]==='--root') root=resolve(args[++i]);
    else if(args[i]==='--port') port=Number(args[++i]);
    else throw new Error('Unknown argument: '+args[i]);
  }
  if(!Number.isInteger(port)||port<1||port>65535) throw new Error('Port must be 1–65535');
  const server=await createReleaseServer({root});
  server.on('error',error=>{ process.stderr.write(`Local release server failed: ${error.code??error.message}\n`); process.exitCode=1; });
  server.listen(port,'127.0.0.1',()=>process.stdout.write(`Trinktribunal release: http://127.0.0.1:${port}\n`));
  for(const signal of ['SIGINT','SIGTERM']) process.on(signal,()=>server.close());
}
