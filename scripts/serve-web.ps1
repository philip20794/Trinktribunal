[CmdletBinding()]
param([ValidateRange(1,65535)][int]$Port = 8080)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Node.js fehlt im PATH.' }
& node (Join-Path $PSScriptRoot 'serve-web.mjs') --port $Port
exit $LASTEXITCODE
