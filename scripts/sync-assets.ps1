[CmdletBinding()]
param([switch]$Check)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error 'Node.js fehlt im PATH.'
    exit 1
}
$mode = if ($Check) { '--check' } else { '--sync' }
& node (Join-Path $PSScriptRoot 'validate-data.mjs') $mode
exit $LASTEXITCODE
