[CmdletBinding()]
param([switch]$Offline, [string]$ApiBaseUrl = '', [string]$PublicClientBaseUrl = '')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$client = Join-Path $root 'apps/client'
foreach ($command in @('node','flutter')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw "$command fehlt im PATH." }
}
function Invoke-Checked {
    param([string]$Command, [string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'validate-data.mjs'), '--sync')
Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'generate-l10n.mjs'), '--check')
# Only replace generated output in this repository's known build directory.
$buildRoot = [System.IO.Path]::GetFullPath((Join-Path $client 'build'))
$output = [System.IO.Path]::GetFullPath((Join-Path $buildRoot 'web'))
if (-not $output.StartsWith($buildRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Unsicheres Buildziel.' }
if (Test-Path -LiteralPath $buildRoot) {
    if ((Get-Item -LiteralPath $buildRoot).Attributes -band [System.IO.FileAttributes]::ReparsePoint) { throw 'Buildverzeichnis darf kein Link sein.' }
}
if (Test-Path -LiteralPath $output) {
    $resolvedOutput = (Resolve-Path -LiteralPath $output).Path
    if ($resolvedOutput -ne $output -or ((Get-Item -LiteralPath $output).Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { throw 'Buildziel ist kein sicheres generiertes Verzeichnis.' }
    Remove-Item -LiteralPath $output -Recurse -Force
}
Push-Location $client
try {
    $pubArgs = @('pub','get','--enforce-lockfile')
    if ($Offline) { $pubArgs += '--offline' }
    Invoke-Checked 'flutter' $pubArgs
    $buildArgs = @('build','web','--release','--csp','--no-pub','--no-wasm-dry-run','--no-web-resources-cdn')
    if ($ApiBaseUrl) { $buildArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl" }
    if ($PublicClientBaseUrl) { $buildArgs += "--dart-define=PUBLIC_CLIENT_BASE_URL=$PublicClientBaseUrl" }
    Invoke-Checked 'flutter' $buildArgs
    Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'prepare-web.mjs'), $output, $ApiBaseUrl)
    Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'build-precache.mjs'), $output)
    Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'prepare-web.mjs'), $output, $ApiBaseUrl)
} finally { Pop-Location }
