<#
build_release.ps1
One-click Flutter Windows MSIX release with Git-driven versioning and appinstaller generation.

Steps:
- Compute version as Major.Minor (static) + commit count + revision.
- Update msix_config in pubspec.yaml (version, display name, identity, publisher).
- Build Windows release and MSIX.
- Rename MSIX to include the version and emit an appinstaller pointing to GitHub Pages.
- Print git push/upload instructions.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- 1) Gather Git-derived version pieces ---
$majorMinor  = '1.0'
$buildNumber = (git rev-list --count HEAD).Trim() # Monotonic build counter
$revision    = '0'
$fullVersion = "$majorMinor.$buildNumber.$revision"    # e.g., 1.0.152.0
$shortHash   = (git rev-parse --short HEAD).Trim()       # e.g., a1b2c

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
$msixSource = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release\app.msix'
$msixDest   = Join-Path $PSScriptRoot "build\windows\x64\runner\Release\$msixName"

if (-not (Test-Path $msixSource)) {
    throw "MSIX not found at $msixSource. Check msix:create output path."
}
Copy-Item $msixSource $msixDest -Force
Write-Host "MSIX prepared: $msixDest" -ForegroundColor Green

# --- 4) Generate/Update appinstaller ---
$packageUriBase    = 'https://freaks-empire.github.io/Freak-Flix'
$appInstallerPath  = Join-Path $PSScriptRoot 'FreakFlix.appinstaller'

$appInstallerXml = @"
<AppInstaller xmlns="http://schemas.microsoft.com/appx/appinstaller/2018">
  <MainBundle
    Name="FreaksEmpire.FreakFlix"
    Publisher="CN=MNDL"
    Version="$fullVersion"
    Uri="$packageUriBase/$msixName" />
  <UpdateSettings>
    <OnLaunch HoursBetweenUpdateChecks="24" />
  </UpdateSettings>
</AppInstaller>
"@

Set-Content -Path $appInstallerPath -Value $appInstallerXml -NoNewline
Write-Host "AppInstaller updated: $appInstallerPath (Version $fullVersion)" -ForegroundColor Green

# --- 5) Final instructions ---
Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Yellow
Write-Host "1) Push the updated files:" -ForegroundColor Yellow
Write-Host "   git add pubspec.yaml FreakFlix.appinstaller build/windows/x64/runner/Release/$msixName" -ForegroundColor Gray
Write-Host "   git commit -m \"release: $fullVersion\"" -ForegroundColor Gray
Write-Host "   git push" -ForegroundColor Gray
Write-Host "2) Upload the MSIX and appinstaller to GitHub Pages at: $packageUriBase" -ForegroundColor Yellow
Write-Host "   (Ensure the .msix filename matches $msixName in the appinstaller.)" -ForegroundColor Gray
Write-Host "3) Users can install/update via the appinstaller URL:" -ForegroundColor Yellow
Write-Host "   $packageUriBase/FreakFlix.appinstaller" -ForegroundColor Gray