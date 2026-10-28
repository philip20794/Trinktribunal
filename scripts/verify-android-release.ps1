[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ArtifactPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$artifact = (Resolve-Path -LiteralPath $ArtifactPath).Path
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$extension = [IO.Path]::GetExtension($artifact).ToLowerInvariant()
if ($extension -eq '.apk') {
    $androidSdkPath = [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT')
    if (-not $androidSdkPath) { $androidSdkPath = [Environment]::GetEnvironmentVariable('ANDROID_HOME') }
    if (-not $androidSdkPath) {
        $properties = Join-Path $root 'apps/client/android/local.properties'
        if (Test-Path -LiteralPath $properties) {
            $line = Get-Content -LiteralPath $properties | Where-Object { $_ -like 'sdk.dir=*' } | Select-Object -First 1
            if ($line) { $androidSdkPath = $line.Substring(8).Replace('\\','\').Replace('\:',':') }
        }
    }
    if (-not $androidSdkPath) { throw 'Android-SDK fuer apksigner fehlt.' }
    $signer = Get-ChildItem -LiteralPath (Join-Path $androidSdkPath 'build-tools') -Directory |
        Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'apksigner.bat' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $signer) { throw 'apksigner.bat fehlt im konfigurierten Android-SDK.' }
    $certificate = & $signer verify --print-certs $artifact 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'APK-Signaturpruefung fehlgeschlagen.' }
} elseif ($extension -eq '.aab') {
    foreach ($tool in @('jarsigner','keytool')) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool fehlt im PATH." }
    }
    $verified = & jarsigner -J-Duser.language=en -verify $artifact 2>&1
    if ($LASTEXITCODE -ne 0 -or ($verified -join "`n") -notmatch 'jar verified\.') { throw 'AAB ist nicht gueltig signiert.' }
    $certificate = & keytool -J-Duser.language=en -printcert -jarfile $artifact 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'AAB-Zertifikat fehlt.' }
} else { throw 'Nur APK oder AAB pruefbar.' }
$certificateText = $certificate -join "`n"
if ($certificateText -match 'CN\s*=\s*Android Debug') { throw 'Debug-Zertifikat ist keine Release-Signatur.' }
$match = [regex]::Match($certificateText, '(?im)(?:certificate SHA-256 digest:|SHA256:)\s*([0-9a-f:]{64,95})')
if (-not $match.Success) { throw 'Signer-Fingerabdruck fehlt; Release nicht bestaetigt.' }
[ordered]@{
    artifact = [IO.Path]::GetFileName($artifact)
    bytes = (Get-Item -LiteralPath $artifact).Length
    sha256 = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
    certificateSha256 = $match.Groups[1].Value.Replace(':','').ToLowerInvariant()
    signatureVerified = $true
} | ConvertTo-Json
