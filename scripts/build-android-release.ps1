[CmdletBinding()]
param([ValidateSet('Apk','AppBundle')][string]$Target = 'Apk', [switch]$Offline,
    [string]$ApiBaseUrl = '', [string]$PublicClientBaseUrl = '')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
function Invoke-Checked {
    param([string]$Command, [string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
# Validate before dependency downloads/builds. Secrets stay in the existing CM_* environment.
$preflight = @((Join-Path $PSScriptRoot 'check-android-release.mjs'), '--require-signing')
if ($ApiBaseUrl) { $preflight += @('--api-base-url', $ApiBaseUrl) }
if ($PublicClientBaseUrl) { $preflight += @('--public-client-base-url', $PublicClientBaseUrl) }
Invoke-Checked 'node' $preflight
Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'validate-data.mjs'), '--sync')
Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'generate-l10n.mjs'), '--check')
Invoke-Checked 'java' @('-Djava.awt.headless=true', (Join-Path $PSScriptRoot 'GenerateAppIcons.java'))
Push-Location (Join-Path $root 'apps/client')
try {
    $pubArgs = @('pub','get','--enforce-lockfile')
    if ($Offline) { $pubArgs += '--offline' }
    Invoke-Checked 'flutter' $pubArgs
    $kind = if ($Target -eq 'Apk') { 'apk' } else { 'appbundle' }
    $buildArgs = @('build', $kind, '--release', '--no-pub')
    if ($env:BUILD_NUMBER) { $buildArgs += "--build-number=$env:BUILD_NUMBER" }
    if ($ApiBaseUrl) { $buildArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl" }
    if ($PublicClientBaseUrl) { $buildArgs += "--dart-define=PUBLIC_CLIENT_BASE_URL=$PublicClientBaseUrl" }
    Invoke-Checked 'flutter' $buildArgs
    $artifact = if ($Target -eq 'Apk') { 'build/app/outputs/flutter-apk/app-release.apk' } else { 'build/app/outputs/bundle/release/app-release.aab' }
    if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) { throw 'Release-Artefakt fehlt.' }
    & (Join-Path $PSScriptRoot 'verify-android-release.ps1') -ArtifactPath $artifact
} finally { Pop-Location }
