[CmdletBinding()]
param(
    [ValidateSet('Client', 'Docs', 'Server', 'All')]
    [string]$Scope = 'All'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$client = Join-Path $root 'apps/client'

foreach ($script in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -Recurse -File) {
    $parseTokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $script.FullName, [ref]$parseTokens, [ref]$parseErrors
    ) | Out-Null
    if ($parseErrors.Count -gt 0) {
        [Console]::Error.WriteLine("PowerShell-Syntaxfehler: $($script.FullName)")
        $parseErrors | ForEach-Object { [Console]::Error.WriteLine($_.Message) }
        exit 1
    }
}

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
    Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'validate-data.mjs'), '--check')
    $testFiles = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tests') -Filter '*.test.mjs' -File |
        Sort-Object Name | ForEach-Object { $_.FullName })
    Invoke-Checked 'node' (@('--test') + $testFiles)
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
        Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'validate-data.mjs'), '--check')
        Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'generate-l10n.mjs'), '--check')
        Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'generate-room-dtos.mjs'), '--check')
        Invoke-Checked 'flutter' @('pub', 'get', '--offline', '--enforce-lockfile')
        Invoke-Checked 'dart' @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test', 'tool')
        Invoke-Checked 'flutter' @('analyze')
        Invoke-Checked 'flutter' @('test')
    } finally {
        Pop-Location
    }
}

if ($Scope -in @('Server', 'All')) {
    if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { throw 'npm.cmd fehlt. Node.js 24 installieren.' }
    $server = Join-Path $root 'apps/server'
    if (-not (Test-Path -LiteralPath (Join-Path $server 'node_modules/.bin/wrangler.cmd'))) {
        throw 'Server-Abhängigkeiten fehlen. In apps/server zuerst npm.cmd ci ausführen.'
    }
    Push-Location $server
    try {
        Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'generate-room-dtos.mjs'), '--check')
        Invoke-Checked 'npm.cmd' @('run', 'check')
    } finally { Pop-Location }
}
if ($Scope -eq 'All') { Invoke-Checked 'node' @((Join-Path $PSScriptRoot 'check-parity.mjs')) }
Write-Host "Prüfumfang $Scope erfolgreich beendet."
