Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- 1) Gather Git-derived version pieces ---
$majorMinor  = '1.0'
try { $buildNumber = (git rev-list --count HEAD).Trim() } catch { $buildNumber = '0' }
try { $shortHash   = (git rev-parse --short HEAD).Trim() } catch { $shortHash = '000000' }
$revision    = '0'
$fullVersion = "$majorMinor.$buildNumber.$revision"    # e.g., 1.0.152.0

Write-Host "Computed version: $fullVersion (short hash: $shortHash)" -ForegroundColor Cyan

# --- 2) Patch pubspec.yaml msix_config (version + display name) ---
$pubspecPath = Join-Path $PSScriptRoot 'pubspec.yaml'
if (-not (Test-Path $pubspecPath)) { throw "pubspec.yaml not found at $pubspecPath" }

$yaml = Get-Content $pubspecPath -Raw

if ($yaml -match 'msix_version:\s*[\d\.]+') {
    $yaml = $yaml -replace 'msix_version:\s*[\d\.]+', "msix_version: $fullVersion"
} else {
    throw "msix_version not found in pubspec.yaml under msix_config."
}

if ($yaml -match 'display_name:\s*.*') {
    $yaml = $yaml -replace 'display_name:\s*.*', "display_name: Freak-Flix [$shortHash]"
} else {
    throw "display_name not found in pubspec.yaml under msix_config."
}

if ($yaml -match 'identity_name:\s*.*') {
    $yaml = $yaml -replace 'identity_name:\s*.*', 'identity_name: FreaksEmpire.FreakFlix'
}
if ($yaml -match 'publisher:\s*.*') {
    $yaml = $yaml -replace 'publisher:\s*.*', 'publisher: CN=MNDL'
}

Set-Content -Path $pubspecPath -Value $yaml -NoNewline
Write-Host "pubspec.yaml msix_config updated with version $fullVersion and display name Freak-Flix [$shortHash]" -ForegroundColor Green

# --- 3) Build Flutter Windows + MSIX ---
flutter clean
flutter pub get
flutter build windows --release
flutter pub run msix:create

$msixName   = "FreakFlix_$fullVersion.msix"
$msixDir    = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release'
$msixSource = Get-ChildItem -Path $msixDir -Filter *.msix -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $msixSource) {
    throw "MSIX not found in $msixDir. Check msix:create output path."
}
$msixSourcePath = $msixSource.FullName
$msixDest = Join-Path $msixDir $msixName
Copy-Item $msixSourcePath $msixDest -Force
Write-Host "MSIX prepared: $msixDest" -ForegroundColor Green

# --- 4) Generate/Update appinstaller ---
$packageUriBase    = 'https://freaks-empire.github.io/Freak-Flix'
$appInstallerPath  = Join-Path $PSScriptRoot 'FreakFlix.appinstaller'
$pagesOutput       = Join-Path $PSScriptRoot 'docs'

$appInstallerXml = @"
<?xml version="1.0" encoding="utf-8"?>
<AppInstaller
        xmlns="http://schemas.microsoft.com/appx/appinstaller/2018"
        Version="$fullVersion"
        Uri="$packageUriBase/FreakFlix.appinstaller">
    <MainPackage
        Name="FreaksEmpire.FreakFlix"
    Publisher="CN=FreakFlix Dev"
        Version="$fullVersion"
        ProcessorArchitecture="x64"
        Uri="$packageUriBase/$msixName" />
    <UpdateSettings>
        <OnLaunch HoursBetweenUpdateChecks="0" />
    </UpdateSettings>
</AppInstaller>
"@

Set-Content -Path $appInstallerPath -Value $appInstallerXml -NoNewline
Write-Host "AppInstaller updated: $appInstallerPath (Version $fullVersion)" -ForegroundColor Green

# --- 4b) Copy installer assets to GitHub Pages folder (docs) ---
New-Item -ItemType Directory -Path $pagesOutput -Force | Out-Null
$pagesMsixPath = Join-Path $pagesOutput $msixName
$pagesAppInstallerPath = Join-Path $pagesOutput 'FreakFlix.appinstaller'
Copy-Item $msixDest $pagesMsixPath -Force
Copy-Item $appInstallerPath $pagesAppInstallerPath -Force
Write-Host "Copied MSIX + appinstaller to docs/:`n - $pagesMsixPath`n - $pagesAppInstallerPath" -ForegroundColor Green

# --- 5) Final instructions ---
Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Yellow
Write-Host "1) Push the updated files:" -ForegroundColor Yellow
Write-Host "   git add pubspec.yaml FreakFlix.appinstaller build/windows/x64/runner/Release/$msixName docs/FreakFlix.appinstaller docs/$msixName" -ForegroundColor Gray
Write-Host "   git commit -m \"release: $fullVersion\"" -ForegroundColor Gray
Write-Host "   git push" -ForegroundColor Gray
Write-Host "2) GitHub Pages already has artifacts staged in docs/. Ensure Pages serves from /docs (default) or move to your chosen path." -ForegroundColor Yellow
Write-Host "3) Users can install/update via the appinstaller URL:" -ForegroundColor Yellow
Write-Host "   $packageUriBase/FreakFlix.appinstaller" -ForegroundColor Gray