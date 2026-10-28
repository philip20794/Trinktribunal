import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
export const signingVariables = ['CM_KEYSTORE_PATH', 'CM_KEYSTORE_PASSWORD', 'CM_KEY_ALIAS', 'CM_KEY_PASSWORD'];

function httpsOrigin(value) {
  if (!value) return null;
  let uri;
  try { uri = new URL(value); } catch { throw new Error('Invalid release HTTPS origin'); }
  if (uri.protocol !== 'https:' || uri.username || uri.password || uri.search || uri.hash || uri.pathname !== '/' ||
      ['localhost', '127.0.0.1', '[::1]', '10.0.2.2'].includes(uri.hostname)) throw new Error('Invalid release HTTPS origin');
  return uri.origin;
}

export function checkAndroidRelease({ pubspec, gradle, mainManifest, debugManifest, mainActivity,
  env = {}, requireSigning = false, exists = existsSync, apiBaseUrl = '', publicClientBaseUrl = '' }) {
  const version = /^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:-[\w.-]+)?)\+([0-9]+)\s*$/m.exec(pubspec);
  const applicationId = /applicationId\s*=\s*"([a-z][\w]*(?:\.[a-z][\w]*)+)"/.exec(gradle)?.[1];
  const namespace = /namespace\s*=\s*"([a-z][\w]*(?:\.[a-z][\w]*)+)"/.exec(gradle)?.[1];
  const buildNumber = Number(env.BUILD_NUMBER ?? version?.[2]);
  if (!version || !applicationId || !namespace || !Number.isSafeInteger(buildNumber) || buildNumber < 1 || buildNumber > 2147483647)
    throw new Error('Invalid Android application identity/version');
  if (!mainActivity.startsWith(`package ${namespace}\n`) && !mainActivity.startsWith(`package ${namespace}\r\n`))
    throw new Error('Android activity namespace mismatch');
  const permissions = [...mainManifest.matchAll(/<uses-permission\s+android:name="([^"]+)"/g)].map(m => m[1]);
  if (permissions.length !== 1 || permissions[0] !== 'android.permission.INTERNET' ||
      !mainManifest.includes('android:usesCleartextTraffic="false"') ||
      !debugManifest.includes('android:usesCleartextTraffic="true"') ||
      !debugManifest.includes('tools:replace="android:usesCleartextTraffic"') ||
      !mainManifest.includes('android:allowBackup="false"') || !mainManifest.includes('android:icon="@mipmap/ic_launcher"'))
    throw new Error('Android release network/backup/icon policy mismatch');
  if (!gradle.includes('signingConfig = signingConfigs.getByName("release")') ||
      /signingConfig\s*=.*getByName\("debug"\)/.test(gradle) ||
      !gradle.includes('releaseRequested && missingSigningVariables.isNotEmpty()') ||
      signingVariables.some(name => !gradle.includes(`"${name}"`))) throw new Error('Android release signing policy mismatch');
  const missingSigningVariables = signingVariables.filter(name => typeof env[name] !== 'string' || !env[name].trim());
  if (env.CM_KEYSTORE_PATH && !exists(env.CM_KEYSTORE_PATH)) throw new Error('Codemagic keystore file unavailable');
  if (requireSigning && missingSigningVariables.length) throw new Error(`Release signing unavailable: ${missingSigningVariables.join(', ')}`);
  return { applicationId, namespace, version: version[1], buildNumber, apiOrigin: httpsOrigin(apiBaseUrl),
    publicClientOrigin: httpsOrigin(publicClientBaseUrl), signingReady: missingSigningVariables.length === 0,
    missingSigningVariables };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2), options = {};
    for (let i = 0; i < args.length; i++) {
      if (args[i] === '--require-signing') options.requireSigning = true;
      else if (args[i] === '--api-base-url' && args[i + 1]) options.apiBaseUrl = args[++i];
      else if (args[i] === '--public-client-base-url' && args[i + 1]) options.publicClientBaseUrl = args[++i];
      else throw new Error('Unknown Android release check argument');
    }
    const read = path => readFileSync(resolve(root, path), 'utf8');
    const gradle = read('apps/client/android/app/build.gradle.kts');
    const namespace = /namespace\s*=\s*"([^"]+)"/.exec(gradle)?.[1];
    const result = checkAndroidRelease({ ...options, gradle, env: process.env,
      pubspec: read('apps/client/pubspec.yaml'), mainManifest: read('apps/client/android/app/src/main/AndroidManifest.xml'),
      debugManifest: read('apps/client/android/app/src/debug/AndroidManifest.xml'),
      mainActivity: read(`apps/client/android/app/src/main/kotlin/${namespace?.replaceAll('.', '/')}/MainActivity.kt`) });
    process.stdout.write(JSON.stringify(result, null, 2) + '\n');
  } catch (error) { process.stderr.write(error.message + '\n'); process.exitCode = 1; }
}
