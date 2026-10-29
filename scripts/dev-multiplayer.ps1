[CmdletBinding()]
param(
    [switch]$PlanOnly,
    [switch]$AsJson,
    [switch]$OpenBrowsers,
    [switch]$StopAfterReady,
    [ValidateSet('chrome','edge')][string]$Browser = 'chrome',
    [string]$BrowserPath = '',
    [ValidateRange(1,65535)][int]$ClientPort = 7357,
    [ValidateRange(1,65535)][int]$ServerPort = 8787
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($ClientPort -eq $ServerPort) { throw 'Client und Worker brauchen verschiedene Ports.' }
if ($ClientPort -notin @(7357,8080)) { throw 'Lokale Client-Origin ist nur auf Port 7357 oder 8080 freigegeben.' }
if ($AsJson -and -not $PlanOnly) { throw '-AsJson erfordert -PlanOnly.' }
if ($OpenBrowsers -and ($PlanOnly -or $StopAfterReady)) { throw '-OpenBrowsers ist nicht mit PlanOnly/StopAfterReady kombinierbar.' }
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$localRoot = [System.IO.Path]::GetFullPath((Join-Path $root '.local/multiplayer'))
$clientUrl = "http://127.0.0.1:$ClientPort"
$serverUrl = "http://127.0.0.1:$ServerPort"
$browserName = if ($Browser -eq 'chrome') { 'chrome.exe' } else { 'msedge.exe' }
$profiles = @(
    [pscustomobject]@{ name='A'; directory=(Join-Path $localRoot 'profile-a'); viewport='390,844' },
    [pscustomobject]@{ name='B'; directory=(Join-Path $localRoot 'profile-b'); viewport='360,800' },
    [pscustomobject]@{ name='C'; directory=(Join-Path $localRoot 'profile-c'); viewport='1440,900' }
)
$plan = [pscustomobject]@{
    clientUrl=$clientUrl; serverUrl=$serverUrl; browser=$Browser; profiles=$profiles
    browserAcceptance='SKIPPED_MANUAL_LATER'; automaticGate='unit'; persistentProfiles=$true
}
if ($PlanOnly -and $AsJson) { $plan | ConvertTo-Json -Depth 5; exit 0 }
Write-Host "Client: $clientUrl | Worker: $serverUrl/health"
Write-Host 'Browser-/E2E-Abnahme: UEBERSPRUNGEN - spaeter manuell testen. Automatisches Gate: Unit-Tests.'
Write-Host 'Drei getrennte Profile bedeuten drei unabhaengige Identitaeten; ein duplizierter Tab teilt dagegen die Identitaet.'
foreach ($profile in $profiles) {
    Write-Host ("Profil {0}: {1} --user-data-dir=`"{2}`" --new-window --window-size={3} {4}" -f $profile.name, $browserName, $profile.directory, $profile.viewport, $clientUrl)
}
if ($PlanOnly) { exit 0 }

function Quote-Argument([string]$Value) { return '"' + $Value.Replace('"','\"') + '"' }
function Assert-LocalDirectory([string]$Path) {
    $absolute = [System.IO.Path]::GetFullPath($Path)
    if (-not $absolute.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsicheres lokales Harness-Verzeichnis.' }
    if ((Test-Path -LiteralPath $absolute) -and ((Get-Item -LiteralPath $absolute).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Harness-Verzeichnis darf kein Link sein: $absolute" }
}
foreach ($path in @((Join-Path $root '.local'),$localRoot) + @($profiles | ForEach-Object { $_.directory })) {
    Assert-LocalDirectory $path
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}
foreach ($port in @($ClientPort,$ServerPort)) {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$port)
    try { $listener.Start() } catch { throw "Port $port ist belegt. Vorhandenen Prozess gezielt beenden oder freie unterstuetzte Ports waehlen." } finally { $listener.Stop() }
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter fehlt im PATH.' }
if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { throw 'npm.cmd fehlt im PATH.' }
if ($OpenBrowsers) {
    if (-not $BrowserPath) {
        $candidates = if ($Browser -eq 'chrome') {
            @((Join-Path $env:ProgramFiles 'Google/Chrome/Application/chrome.exe'),(Join-Path ${env:ProgramFiles(x86)} 'Google/Chrome/Application/chrome.exe'))
        } else {
            @((Join-Path $env:ProgramFiles 'Microsoft/Edge/Application/msedge.exe'),(Join-Path ${env:ProgramFiles(x86)} 'Microsoft/Edge/Application/msedge.exe'))
        }
        $BrowserPath = @($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1) -join ''
    }
    if (-not $BrowserPath -or -not (Test-Path -LiteralPath $BrowserPath -PathType Leaf)) { throw 'Browser nicht gefunden. -BrowserPath auf die installierte EXE setzen.' }
}
$lock = $null
$serviceJob = $null
$ownedServices = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
$ownedBrowsers = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
$runId = [Guid]::NewGuid().ToString('N')
$logRoot = Join-Path $localRoot "run-$runId"
$powerShellExe = Join-Path $PSHOME 'powershell.exe'
function Start-ServiceScript([string]$Name,[string[]]$Arguments) {
    $commandArguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File') + $Arguments
    # Join before any service process is spawned. The bootstrap must not retain
    # a job handle, otherwise closing the harness would not be the last close.
    $jobSource = (Join-Path $PSScriptRoot 'OwnedServiceJob.cs').Replace("'","''")
    $commandJson = ConvertTo-Json -InputObject $commandArguments -Compress
    $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($commandJson))
    $bootstrap = @"
`$ErrorActionPreference = 'Stop'
Add-Type -Path '$jobSource'
[OwnedServiceJob]::Join('Trinktribunal-$runId')
`$serviceArguments = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$payload')) | ConvertFrom-Json
& '$($powerShellExe.Replace("'","''"))' @serviceArguments
exit `$LASTEXITCODE
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($bootstrap))
    $escaped = "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
    $process = Start-Process -FilePath $powerShellExe -ArgumentList $escaped -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logRoot "$Name.out.log") -RedirectStandardError (Join-Path $logRoot "$Name.err.log") -PassThru
    $ownedServices.Add($process)
    return $process
}
function Wait-Endpoint([string]$Url,[System.Diagnostics.Process]$Process) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt 90) {
        if ($Process.HasExited) { throw "Lokaler Dienst wurde beendet. Logs: $logRoot" }
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 2
            if ($response.StatusCode -eq 200) { return }
        } catch { }
        Start-Sleep -Milliseconds 200
    }
    throw "Lokaler Dienst nicht rechtzeitig bereit: $Url. Logs: $logRoot"
}
function Stop-OwnedProcess([System.Diagnostics.Process]$Process) {
    try {
        if (-not $Process.HasExited) {
            # Only the process object spawned by this session; never a global name search.
            & taskkill.exe /PID $Process.Id /T /F 2>$null | Out-Null
        }
    } catch {
        if (-not $Process.HasExited) { Write-Warning "Eigener Prozess $($Process.Id) konnte nicht beendet werden." }
    } finally { $Process.Dispose() }
}
try {
    $lock = [IO.File]::Open((Join-Path $localRoot 'session.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    Add-Type -Path (Join-Path $PSScriptRoot 'OwnedServiceJob.cs')
    $serviceJob = [OwnedServiceJob]::new("Trinktribunal-$runId")
    New-Item -ItemType Directory -Path $logRoot | Out-Null
    $worker = Start-ServiceScript 'worker' @((Join-Path $PSScriptRoot 'dev-server.ps1'),'-Port',"$ServerPort")
    Wait-Endpoint "$serverUrl/health" $worker
    Write-Host 'Worker bereit.'
    $client = Start-ServiceScript 'client' @((Join-Path $PSScriptRoot 'dev-client.ps1'),'-Device','web-server','-Port',"$ClientPort",'-ApiBaseUrl',$serverUrl,'-PublicClientBaseUrl',$clientUrl)
    Wait-Endpoint $clientUrl $client
    Write-Host "Client bereit. Logs: $logRoot"
    if ($StopAfterReady) { Write-Host 'Lokaler Start geprueft; eigene Prozesse werden beendet.'; exit 0 }
    if ($OpenBrowsers) {
        foreach ($profile in $profiles) {
            $arguments = "--user-data-dir=$(Quote-Argument $profile.directory) --new-window --no-first-run --no-default-browser-check --window-size=$($profile.viewport) $clientUrl"
            $process = Start-Process -FilePath $BrowserPath -ArgumentList $arguments -WindowStyle Normal -PassThru
            $ownedBrowsers.Add($process)
            Start-Sleep -Milliseconds 500
            if ($process.HasExited) { throw 'Profilfenster konnte nicht als neuer eigener Prozess gestartet werden. Bestehende Test-Profilfenster zuerst schliessen.' }
        }
        Write-Host 'Alle drei eigenen Browserprozesse schliessen beendet die Dienste. Ctrl+C beendet ebenfalls kontrolliert.'
    } else { Write-Host 'Browser bei Bedarf mit den oben ausgegebenen Befehlen manuell oeffnen. Ctrl+C beendet nur diese lokalen Dienste.' }
    while ($true) {
        if ($worker.HasExited -or $client.HasExited) { throw "Ein Dienst wurde beendet. Logs: $logRoot" }
        if ($OpenBrowsers -and @($ownedBrowsers | Where-Object { -not $_.HasExited }).Count -eq 0) { break }
        Start-Sleep -Milliseconds 500
    }
} finally {
    # One Windows job owns the complete service trees, including grandchildren
    # whose PowerShell/cmd wrapper has already exited. Never select global PIDs.
    if ($null -ne $serviceJob) { $serviceJob.Dispose() }
    foreach ($process in $ownedBrowsers) { Stop-OwnedProcess $process }
    foreach ($process in $ownedServices) {
        try {
            if (-not $process.WaitForExit(5000)) { Write-Warning "Dienst-Bootstrap $($process.Id) wird noch beendet." }
        } finally { $process.Dispose() }
    }
    if ($null -ne $lock) { $lock.Dispose() }
    Write-Host 'Eigene Harness-Prozesse beendet. Persistente Testprofile bleiben erhalten; kein globales Browser-/Node-Aufraeumen.'
}
