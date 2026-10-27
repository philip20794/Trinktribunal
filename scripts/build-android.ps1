[CmdletBinding()]
param([switch]$Offline)
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
Push-Location $client
try {
    $pubArgs = @('pub','get','--enforce-lockfile')
    if ($Offline) { $pubArgs += '--offline' }
    Invoke-Checked 'flutter' $pubArgs
    Invoke-Checked 'flutter' @('build','apk','--debug','--no-pub')
    $apk = Join-Path $client 'build/app/outputs/flutter-apk/app-debug.apk'
    if (-not (Test-Path -LiteralPath $apk -PathType Leaf)) { throw 'Debug-APK fehlt.' }
    Write-Host "Debug-APK: $apk"
    Write-Host "SHA-256: $((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash)"
    Write-Host 'Nur Debug-Signatur. Release-Signierung erfolgt separat in Codemagic.'
} finally { Pop-Location }
