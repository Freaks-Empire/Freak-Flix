param(
  [switch]$NoPublish,
  [switch]$SkipClean,
  [int]$MaxAttempts = 2,
  [string]$LogDir = "$PSScriptRoot/logs",
  [string]$PublishRoot = "build/release-artifacts"
)

$ErrorActionPreference = 'Continue'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
Set-Location $repoRoot

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$logFile = Join-Path $LogDir "android-build.log"
$resultPath = Join-Path $LogDir "android-result.json"
$artifactPath = Join-Path $repoRoot "build/app/outputs/flutter-apk/app-release.apk"

$command = "flutter build apk --release"
$allOutput = New-Object System.Collections.Generic.List[string]
$exitCode = 1
$attempt = 0

while ($attempt -lt $MaxAttempts) {
  $attempt += 1
  $allOutput.Add("=== Attempt $attempt of $MaxAttempts ===")

  if (-not $SkipClean) {
    $cleanOutput = & flutter clean 2>&1
    $allOutput.AddRange([string[]]$cleanOutput)
  }

  $buildOutput = & flutter build apk --release 2>&1
  $exitCode = $LASTEXITCODE
  $allOutput.AddRange([string[]]$buildOutput)

  if ($exitCode -eq 0 -and (Test-Path $artifactPath)) {
    break
  }
}

$allOutput | Set-Content -Path $logFile

$warningCount = ($allOutput | Select-String -Pattern "(?i)warning").Count
$runtimeNoiseCount = ($allOutput | Select-String -Pattern "(?i)error|exception|failed").Count
$artifactExists = Test-Path $artifactPath
$status = if ($exitCode -eq 0 -and $artifactExists) { "PASS" } else { "FAIL" }
$blockerCount = if ($status -eq "FAIL") { $runtimeNoiseCount } else { 0 }
if ($status -eq "PASS" -and $runtimeNoiseCount -gt 0) {
  $warningCount += $runtimeNoiseCount
}

$publishedArtifact = ""
if (-not $NoPublish -and $status -eq "PASS") {
  $publishDir = Join-Path $repoRoot $PublishRoot
  New-Item -ItemType Directory -Path $publishDir -Force | Out-Null
  $target = Join-Path $publishDir "android"
  if (Test-Path $target) {
    Remove-Item -Recurse -Force $target
  }
  New-Item -ItemType Directory -Path $target -Force | Out-Null
  Copy-Item -Force $artifactPath (Join-Path $target "app-release.apk")
  $publishedArtifact = Join-Path $target "app-release.apk"
}

$result = [pscustomobject]@{
  platform = "Android"
  timestamp = $timestamp
  command = $command
  status = $status
  attempts = $attempt
  clean_strategy = (-not $SkipClean)
  artifact = $artifactPath
  artifact_exists = $artifactExists
  published_artifact = $publishedArtifact
  warning_count = $warningCount
  blocker_count = $blockerCount
  log = $logFile
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $resultPath

Write-Host "[android] status=$status attempts=$attempt warnings=$warningCount blockers=$blockerCount artifact=$artifactPath"
if ($status -eq "FAIL") {
  exit 1
}
exit 0
