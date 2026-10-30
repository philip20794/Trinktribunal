#!/usr/bin/env bash
# Cloudflare Pages: checked main builds publish the same prepared JS/PWA bundle
# as the local release command. Cloudflare handles the upload after this exits 0.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

flutter_version=3.47.7
flutter_sha256=af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230
sdk_directory="${TMPDIR:-/tmp}/trinktribunal-flutter-${flutter_version}"

# The Pages Linux image does not supply our pinned Flutter SDK. Unlike the
# Codemagic SDK installer, allow 15 minutes and resume interrupted downloads.
if ! command -v flutter >/dev/null 2>&1; then
  test "$(uname -s)" = Linux
  test "$(uname -m)" = x86_64
  mkdir -p "$sdk_directory"
  archive="$sdk_directory/flutter.tar.xz"
  curl --fail --location --show-error --retry 3 --retry-all-errors \
    --connect-timeout 20 --max-time 900 --continue-at - \
    --output "$archive" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${flutter_version}-stable.tar.xz"
  printf '%s  %s\n' "$flutter_sha256" "$archive" | sha256sum --check -
  tar --extract --xz --file "$archive" --directory "$sdk_directory"
  export PATH="$sdk_directory/flutter/bin:$PATH"
fi

flutter config --no-analytics
flutter --version --machine | node -e '
let data=""; process.stdin.on("data", chunk => data+=chunk);
process.stdin.on("end", () => {
  if (JSON.parse(data).frameworkVersion !== "3.47.7") {
    throw new Error("Pages requires the pinned Flutter 3.47.7 SDK");
  }
});'

node scripts/check-production-config.mjs --config docs/config/production.json \
  --worker-config apps/server/wrangler.production.jsonc --require-real-origins
node scripts/check-docs.mjs
node scripts/validate-data.mjs --check
node scripts/generate-l10n.mjs --check
node --test scripts/tests/*.test.mjs

export API_BASE_URL="$(node -p "require('./docs/config/production.json').apiBaseUrl")"
export PUBLIC_CLIENT_BASE_URL="$(node -p "require('./docs/config/production.json').publicClientBaseUrl")"
defines="$(mktemp "${TMPDIR:-/tmp}/trinktribunal-client-defines.XXXXXX")"
trap 'rm -f -- "$defines"' EXIT
node scripts/write-client-build-config.mjs "$defines"

cd apps/client
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
flutter test --no-pub
cd ../server
npm ci --no-fund --no-audit
npm run check
cd "$repo_root"
node scripts/check-parity.mjs

cd apps/client
flutter build web --release --csp --no-pub --no-wasm-dry-run \
  --no-web-resources-cdn --dart-define-from-file="$defines"
cd "$repo_root"
node scripts/web-performance.mjs trim-js apps/client/build/web
node scripts/prepare-web.mjs apps/client/build/web "$API_BASE_URL"
node scripts/build-precache.mjs apps/client/build/web
node scripts/prepare-web.mjs apps/client/build/web "$API_BASE_URL"
node scripts/check-web-release.mjs apps/client/build/web
