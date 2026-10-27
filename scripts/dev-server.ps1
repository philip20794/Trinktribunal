[CmdletBinding()]
param([ValidateRange(1, 65535)][int]$Port = 8787)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$server = Join-Path $root 'apps/server'
if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { throw 'npm.cmd fehlt. Node.js 24 installieren.' }
if (-not (Test-Path -LiteralPath (Join-Path $server 'package-lock.json'))) { throw 'Server-Lockfile fehlt.' }
$listener = $null
try {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    $listener.Start()
} catch {
    throw "Port $Port auf 127.0.0.1 ist nicht verfügbar. Anderen Wert über -Port wählen."
} finally {
    if ($null -ne $listener) { $listener.Stop() }
}
Push-Location $server
try {
    $wrangler = Join-Path $server 'node_modules/.bin/wrangler.cmd'
    if (-not (Test-Path -LiteralPath $wrangler)) {
        & npm.cmd ci --no-fund --no-audit
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    Write-Host "Worker lokal: http://127.0.0.1:$Port/health"
    & $wrangler dev --local --ip 127.0.0.1 --port "$Port" --inspector-port 0
    exit $LASTEXITCODE
} finally { Pop-Location }
