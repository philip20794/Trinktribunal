[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$client = Join-Path $root 'apps/client'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('Flutter SDK fehlt im PATH. flutter doctor -v prüfen.')
    exit 1
}
if (-not (Test-Path (Join-Path $client 'pubspec.yaml'))) {
    [Console]::Error.WriteLine("Client pubspec.yaml fehlt: $client")
    exit 1
}

# Flutter create darf die bereits im Repository vorhandenen Dateien nicht
# überschreiben. Gegenprüfung anhand ihrer SHA-256-Hashes.
$sourcePaths = @(
    'pubspec.yaml',
    'lib/main.dart',
    'lib/app/trinktribunal_app.dart',
    'lib/features/home/home_screen.dart',
    'lib/features/home/mode_preview_screen.dart',
    'lib/features/profile/profile_screen.dart',
    'lib/features/settings/settings_screen.dart',
    'test/app_shell_test.dart',
    'test/widget_test.dart',
    'web/index.html',
    'web/flutter_bootstrap.js',
    'web/manifest.json'
)
$originalHashes = @{}
foreach ($relativePath in $sourcePaths) {
    $path = Join-Path $client $relativePath
    if (-not (Test-Path $path)) {
        [Console]::Error.WriteLine("Erwartete TT-001-Quelldatei fehlt: $path")
        exit 1
    }
    $originalHashes[$relativePath] = (Get-FileHash -Algorithm SHA256 -Path $path).Hash
}

Write-Host 'Flutter-Version:'
& flutter --version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Initialisiere nur noch fehlende Android-/Web-Templatedateien in $client"
Write-Host 'WICHTIG: bewusst ohne --overwrite; vorhandene App-Shell behalten.'
& flutter create --platforms=android,web --project-name trinktribunal $client
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

foreach ($relativePath in $sourcePaths) {
    $path = Join-Path $client $relativePath
    $after = (Get-FileHash -Algorithm SHA256 -Path $path).Hash
    if ($after -ne $originalHashes[$relativePath]) {
        [Console]::Error.WriteLine("Bestehende Quelldatei wurde verändert: $relativePath. Änderungen manuell prüfen!")
        exit 1
    }
}

foreach ($relativePath in @('.metadata', 'android/app/src/main/AndroidManifest.xml')) {
    $path = Join-Path $client $relativePath
    if (-not (Test-Path $path)) {
        [Console]::Error.WriteLine("Flutter-Gerüst unvollständig: $relativePath fehlt.")
        exit 1
    }
}

Push-Location $client
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (-not (Test-Path 'pubspec.lock')) {
        [Console]::Error.WriteLine('pubspec.lock fehlt nach flutter pub get.')
        exit 1
    }

    & flutter analyze
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & flutter test
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}

Write-Host 'TT-001 Flutter-Gerüst erzeugt und automatische Checks bestanden.'
Write-Host 'Noch manuell nötig: Chrome 360x800 / 1440x900, Zurücknavigation, Hot Reload.'
Write-Host 'Anschließend generierte Android-Dateien, .metadata und pubspec.lock committen.'
