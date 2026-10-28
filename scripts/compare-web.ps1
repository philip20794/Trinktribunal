[CmdletBinding()]
param([switch]$Offline, [string]$ApiBaseUrl = '', [string]$PublicClientBaseUrl = '')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$client = Join-Path $root 'apps/client'
& (Join-Path $PSScriptRoot 'build-web.ps1') -Offline:$Offline -ApiBaseUrl $ApiBaseUrl -PublicClientBaseUrl $PublicClientBaseUrl
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
function Invoke-Checked {
    param([string]$Command, [string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
# Comparison only. This directory is never the release/deployment root.
$output = Join-Path $client 'build/web-wasm-review'
Push-Location $client
try {
    $buildArgs = @('build','web','--release','--wasm','--csp','--no-pub','--no-web-resources-cdn','--output',$output)
    if ($ApiBaseUrl) { $buildArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl" }
    if ($PublicClientBaseUrl) { $buildArgs += "--dart-define=PUBLIC_CLIENT_BASE_URL=$PublicClientBaseUrl" }
    Invoke-Checked 'flutter' $buildArgs
    Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'web-performance.mjs'), 'measure', (Join-Path $client 'build/web'), (Join-Path $client 'build/web-js-performance.json'))
    Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'web-performance.mjs'), 'measure', $output, (Join-Path $client 'build/web-wasm-performance.json'))
    Write-Host 'Comparison reports: apps/client/build/web-{js,wasm}-performance.json. Browser timings remain manual.'
} finally { Pop-Location }
