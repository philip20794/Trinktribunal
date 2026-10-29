import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { httpsOrigin } from './check-android-release.mjs';

// Public compile-time values only. Never copy the CI environment into an APK.
export function clientBuildDefines(env) {
  const result = {};
  for (const key of ['API_BASE_URL', 'PUBLIC_CLIENT_BASE_URL']) {
    const value = env[key]?.trim();
    if (!value) {
      if (key === 'API_BASE_URL') throw new Error('API_BASE_URL fehlt: HTTPS-Adresse des laufenden Online-Servers in Codemagic konfigurieren.');
      continue;
    }
    try {
      const origin = httpsOrigin(value);
      if (new URL(origin).hostname.endsWith('.invalid')) throw new Error();
      result[key] = origin;
    } catch {
      throw new Error(`${key}: gueltige oeffentliche HTTPS-Origin ohne Pfad, Zugangsdaten oder Beispieladresse erforderlich.`);
    }
  }
  return result;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    if (process.argv.length !== 3) throw new Error('Usage: node scripts/write-client-build-config.mjs OUTPUT_JSON');
    const config = clientBuildDefines(process.env);
    writeFileSync(resolve(process.argv[2]), JSON.stringify(config, null, 2) + '\n');
    process.stdout.write('Oeffentliche Online-Serverkonfiguration fuer Flutter vorbereitet.\n');
  } catch (error) {
    process.stderr.write(error.message + '\n');
    process.exitCode = 1;
  }
}
