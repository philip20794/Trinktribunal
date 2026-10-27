[CmdletBinding()]
param(
    [ValidateSet('chrome', 'edge', 'web-server')]
    [string]$Device = 'chrome',
    [ValidateRange(1, 65535)]
    [int]$Port = 7357,
    [string]$ApiBaseUrl = '',
    [string]$PublicClientBaseUrl = '',
    [string]$WebHost = '127.0.0.1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$client = Join-Path $root 'apps/client'

if (-not (Test-Path (Join-Path $client 'pubspec.yaml'))) {
    Write-Error "Flutter-Client nicht gefunden: $client"
    exit 1
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error 'Flutter fehlt im PATH. Flutter SDK installieren und flutter doctor -v ausführen.'
    exit 1
}

try {
    $ip = [System.Net.IPAddress]::Parse($WebHost)
} catch {
    try {
        $ip = [System.Net.Dns]::GetHostAddresses($WebHost) |
            Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
            Select-Object -First 1
    } catch {
        Write-Error "WebHost kann nicht aufgelöst werden: $WebHost"
        exit 1
    }
}
if ($null -eq $ip) {
    Write-Error "Keine IPv4-Adresse für WebHost: $WebHost"
    exit 1
}

$listener = $null
try {
    $listener = [System.Net.Sockets.TcpListener]::new($ip, $Port)
    $listener.Start()
} catch {
    Write-Error "Port $Port auf $WebHost ist nicht verfügbar. Anderen Wert über -Port wählen."
    exit 1
} finally {
    if ($null -ne $listener) { $listener.Stop() }
}

Push-Location $client
try {
    Write-Host "Flutter-Version:"
    & flutter --version
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host "Abhängigkeiten prüfen: $client"
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $runArgs = @('run', '-d', $Device, '--web-hostname', $WebHost, '--web-port', "$Port")
    if ($ApiBaseUrl) { $runArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl" }
    if ($PublicClientBaseUrl) { $runArgs += "--dart-define=PUBLIC_CLIENT_BASE_URL=$PublicClientBaseUrl" }
    Write-Host "Flutter lokal auf http://${WebHost}:${Port}/ (Gerät: $Device)"
    & flutter @runArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
