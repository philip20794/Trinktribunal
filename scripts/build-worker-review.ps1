[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$server = Join-Path $root 'apps/server'
& node (Join-Path $PSScriptRoot 'check-production-config.mjs')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path -LiteralPath (Join-Path $server 'node_modules/.bin/wrangler.cmd'))) { throw 'Gepinnte Worker-Abhaengigkeiten fehlen: apps/server npm.cmd ci.' }
$generated = Join-Path $server 'build'
New-Item -ItemType Directory -Path $generated -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $generated 'release-review.env'), '')
Push-Location $server
try {
    & npx.cmd --no-install wrangler deploy --dry-run --autoconfig=false --config wrangler.release.example.jsonc --outdir build/release-worker --env-file build/release-review.env --metafile
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host 'Nur lokales Worker-Bundle erstellt; kein Upload.'
} finally { Pop-Location }
