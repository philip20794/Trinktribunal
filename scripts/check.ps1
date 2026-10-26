[CmdletBinding()]
param(
    [ValidateSet('Client', 'Docs', 'All')]
    [string]$Scope = 'All'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$client = Join-Path $root 'apps/client'

function Invoke-Checked {
    param(
        [string]$Command,
        [string[]]$Arguments
    )
    Write-Host "> $Command $($Arguments -join ' ')"
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("Prüfung fehlgeschlagen (Exitcode $LASTEXITCODE): $Command")
        exit $LASTEXITCODE
    }
}

if ($Scope -in @('Docs', 'All')) {
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Error 'Node.js fehlt im PATH (benötigt für die Dokumentationsprüfung).'
        exit 1
    }
    Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'check-docs.mjs'))
    Invoke-Checked 'node' @('--test', (Join-Path $PSScriptRoot 'tests/check-docs.test.mjs'))
    Invoke-Checked 'node' @('--test', (Join-Path $PSScriptRoot 'tests/protocol-fixtures.test.mjs'))
    Invoke-Checked 'node' @('--test', (Join-Path $PSScriptRoot 'tests/projections.test.mjs'))
}

if ($Scope -in @('Client', 'All')) {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        Write-Error 'Flutter fehlt im PATH. Flutter SDK installieren und flutter doctor -v ausführen.'
        exit 1
    }
    if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
        Write-Error 'Dart fehlt im PATH (wird mit dem Flutter SDK installiert).'
        exit 1
    }
    if (-not (Test-Path (Join-Path $client 'pubspec.yaml'))) {
        Write-Error "Flutter-Client nicht gefunden: $client"
        exit 1
    }
    Push-Location $client
    try {
        Invoke-Checked 'flutter' @('pub', 'get')
        Invoke-Checked 'dart' @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test')
        Invoke-Checked 'flutter' @('analyze')
        Invoke-Checked 'flutter' @('test')
    } finally {
        Pop-Location
    }
}

if ($Scope -eq 'All') {
    Write-Host 'Server-Prüfungen noch nicht implementiert (geplant ab TT-035); kein Server-Test behauptet.'
}
Write-Host "Prüfumfang $Scope erfolgreich beendet."
