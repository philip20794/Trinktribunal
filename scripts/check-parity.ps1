[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
foreach ($command in @('node', 'dart', 'npm.cmd')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw "$command fehlt im PATH." }
}
& node (Join-Path $PSScriptRoot 'check-parity.mjs')
exit $LASTEXITCODE
