import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { checkAndroidRelease, signingVariables } from '../check-android-release.mjs';

const read = path => readFileSync(new URL('../../' + path, import.meta.url), 'utf8');
function fixture() {
  return { pubspec: read('apps/client/pubspec.yaml'), gradle: read('apps/client/android/app/build.gradle.kts'),
    mainManifest: read('apps/client/android/app/src/main/AndroidManifest.xml'),
    debugManifest: read('apps/client/android/app/src/debug/AndroidManifest.xml'),
    mainActivity: read('apps/client/android/app/src/main/kotlin/com/example/trinktribunal/MainActivity.kt') };
}
test('current Android identity and manifests have an explicit release/debug boundary', () => {
  const result = checkAndroidRelease(fixture());
  assert.equal(result.applicationId, 'com.example.trinktribunal');
  assert.equal(result.version, '0.1.0'); assert.equal(result.buildNumber, 1);
  assert.equal(result.signingReady, false); assert.deepEqual(result.missingSigningVariables, signingVariables);
});
test('release signing fails before build without CM credentials and never returns secret values', () => {
  assert.throws(() => checkAndroidRelease({ ...fixture(), requireSigning: true }), /Release signing unavailable/);
  const env = Object.fromEntries(signingVariables.map(name => [name, 'synthetic-secret']));
  const result = checkAndroidRelease({ ...fixture(), requireSigning: true, env, exists: () => true });
  assert.equal(result.signingReady, true);
  assert.ok(!JSON.stringify(result).includes('synthetic-secret'));
  assert.throws(() => checkAndroidRelease({ ...fixture(), env, exists: () => false }), /keystore file unavailable/);
});
test('release endpoints reject cleartext, loopback, credentials, query and non-origin paths', () => {
  for (const url of ['http://localhost:8787', 'https://localhost', 'https://user:pass@example.com', 'https://example.com/path', 'https://example.com/?token=x', 'bad'])
    assert.throws(() => checkAndroidRelease({ ...fixture(), apiBaseUrl: url }), /HTTPS origin/);
  assert.equal(checkAndroidRelease({ ...fixture(), apiBaseUrl: 'https://api.example.com' }).apiOrigin, 'https://api.example.com');
});
test('unsafe network/signing mutations and invalid version codes fail', () => {
  const current = fixture();
  assert.throws(() => checkAndroidRelease({ ...current, mainManifest: current.mainManifest.replace('usesCleartextTraffic="false"', 'usesCleartextTraffic="true"') }), /policy mismatch/);
  assert.throws(() => checkAndroidRelease({ ...current, gradle: current.gradle.replace('signingConfig = signingConfigs.getByName("release")', 'signingConfig = signingConfigs.getByName("debug")') }), /signing policy mismatch/);
  assert.throws(() => checkAndroidRelease({ ...current, mainActivity: current.mainActivity.replace('package com.example', 'package other.example') }), /namespace mismatch/);
  for (const value of ['0', '-1', '2147483648', 'not-a-number'])
    assert.throws(() => checkAndroidRelease({ ...current, env: { BUILD_NUMBER: value } }), /identity\/version/);
});
