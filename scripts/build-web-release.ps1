[CmdletBinding()]
param([string]$ConfigPath = 'docs/config/production.example.json',
    [string]$WorkerConfigPath = 'apps/server/wrangler.release.example.jsonc', [switch]$Offline)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$configuration = if ([IO.Path]::IsPathRooted($ConfigPath)) { $ConfigPath } else { Join-Path $root $ConfigPath }
$workerConfiguration = if ([IO.Path]::IsPathRooted($WorkerConfigPath)) { $WorkerConfigPath } else { Join-Path $root $WorkerConfigPath }
& node (Join-Path $PSScriptRoot 'check-production-config.mjs') --config $configuration --worker-config $workerConfiguration --require-real-origins
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$config = Get-Content -LiteralPath $configuration -Raw -Encoding UTF8 | ConvertFrom-Json
& (Join-Path $PSScriptRoot 'build-web.ps1') -Offline:$Offline -ApiBaseUrl $config.apiBaseUrl -PublicClientBaseUrl $config.publicClientBaseUrl
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& node (Join-Path $PSScriptRoot 'check-web-release.mjs')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'Webpaket lokal geprueft. Kein Upload/Deployment ausgefuehrt.'
