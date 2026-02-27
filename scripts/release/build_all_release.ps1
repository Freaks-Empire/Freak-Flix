param(
  [switch]$NoPublish,
  [string]$LogDir = "$PSScriptRoot/logs",
  [string]$LedgerPath = ".planning/phases/02-cross-platform-baseline-and-releases/02-release-artifacts.md"
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
Set-Location $repoRoot

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$preflightScript = Join-Path $PSScriptRoot "preflight.ps1"
$webScript = Join-Path $PSScriptRoot "build_web_release.ps1"
$windowsScript = Join-Path $PSScriptRoot "build_windows_release.ps1"
$androidScript = Join-Path $PSScriptRoot "build_android_release.ps1"

$preflightOk = $true
& $preflightScript -LogDir $LogDir
if ($LASTEXITCODE -ne 0) {
  $preflightOk = $false
}

$results = New-Object System.Collections.Generic.List[object]

function Add-ResultFromJson {
  param([string]$Path)
  if (Test-Path $Path) {
    $results.Add((Get-Content $Path -Raw | ConvertFrom-Json))
    return
  }

  $results.Add([pscustomobject]@{
      platform = [System.IO.Path]::GetFileNameWithoutExtension($Path)
      timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
      command = ""
      status = "FAIL"
      attempts = 0
      clean_strategy = $false
      artifact = ""
      artifact_exists = $false
      published_artifact = ""
      warning_count = 0
      blocker_count = 1
      log = ""
    })
}

& $webScript -NoPublish:$NoPublish -LogDir $LogDir
$webExit = $LASTEXITCODE
Add-ResultFromJson -Path (Join-Path $LogDir "web-result.json")

& $windowsScript -NoPublish:$NoPublish -LogDir $LogDir
$windowsExit = $LASTEXITCODE
Add-ResultFromJson -Path (Join-Path $LogDir "windows-result.json")

& $androidScript -NoPublish:$NoPublish -LogDir $LogDir
$androidExit = $LASTEXITCODE
Add-ResultFromJson -Path (Join-Path $LogDir "android-result.json")

$overallFail = -not $preflightOk -or $webExit -ne 0 -or $windowsExit -ne 0 -or $androidExit -ne 0

$ledgerAbs = Join-Path $repoRoot $LedgerPath
$ledgerDir = Split-Path -Parent $ledgerAbs
New-Item -ItemType Directory -Path $ledgerDir -Force | Out-Null

$generated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Phase 02 Release Artifact Ledger")
$lines.Add("")
$lines.Add("Generated: $generated")
$lines.Add("Command: ``pwsh ./scripts/release/build_all_release.ps1 -NoPublish``")
$lines.Add("")
$lines.Add("| Platform | Status | Command | Artifact | Exists | Warnings | Blockers | Log |")
$lines.Add("|---|---|---|---|---|---:|---:|---|")

foreach ($result in $results) {
  $artifactExistsText = if ($result.artifact_exists) { "yes" } else { "no" }
  $logPath = $result.log
  $lines.Add("| $($result.platform) | $($result.status) | ``$($result.command)`` | ``$($result.artifact)`` | $artifactExistsText | $($result.warning_count) | $($result.blocker_count) | ``$logPath`` |")
}

$lines.Add("")
$lines.Add("## Classification")
$lines.Add("")
foreach ($result in $results) {
  $classification = if ($result.status -ne "PASS") { "blocker" } elseif ($result.warning_count -gt 0) { "warning" } else { "clean" }
  $lines.Add("- $($result.platform): $classification")
}

$lines.Add("")
$lines.Add("## Notes")
$lines.Add("")
$lines.Add("- Preflight status: $(if ($preflightOk) { 'PASS/WARN' } else { 'FAIL' })")
$lines.Add("- Android build uses retry-safe clean strategy via ``build_android_release.ps1``.")

$lines | Set-Content -Path $ledgerAbs

Write-Host "[build-all] preflight_ok=$preflightOk web=$webExit windows=$windowsExit android=$androidExit"
$results | Format-Table platform, status, warning_count, blocker_count, artifact_exists -AutoSize
Write-Host "[build-all] ledger=$ledgerAbs"

if ($overallFail) {
  exit 1
}
exit 0
