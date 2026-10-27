[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Write-Host 'Multiplayer-Gate: lokale Unit-/Widget-/Workerd-Tests, keine Browser-E2E-Tests.'
& (Join-Path $PSScriptRoot 'check.ps1') -Scope All
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'Browser-/E2E-Abnahme: UEBERSPRUNGEN - spaeter manuell testen (docs/qa/M4.md).'
exit 0
