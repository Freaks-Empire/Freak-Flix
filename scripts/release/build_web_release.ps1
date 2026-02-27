param(
  [switch]$NoPublish,
  [string]$LogDir = "$PSScriptRoot/logs",
  [string]$PublishRoot = "build/release-artifacts"
)

$ErrorActionPreference = 'Continue'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
Set-Location $repoRoot

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$logFile = Join-Path $LogDir "web-build.log"
$resultPath = Join-Path $LogDir "web-result.json"
$artifactPath = Join-Path $repoRoot "build/web/index.html"

$command = "flutter build web --release"
$buildOutput = & flutter build web --release 2>&1
$exitCode = $LASTEXITCODE
$buildOutput | Set-Content -Path $logFile

$warningCount = ($buildOutput | Select-String -Pattern "(?i)warning").Count
$runtimeNoiseCount = ($buildOutput | Select-String -Pattern "(?i)error|exception|failed").Count
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
  $target = Join-Path $publishDir "web"
  if (Test-Path $target) {
    Remove-Item -Recurse -Force $target
  }
  Copy-Item -Recurse -Force (Join-Path $repoRoot "build/web") $target
  $publishedArtifact = (Join-Path $target "index.html")
}

$result = [pscustomobject]@{
  platform = "Web"
  timestamp = $timestamp
  command = $command
  status = $status
  artifact = $artifactPath
  artifact_exists = $artifactExists
  published_artifact = $publishedArtifact
  warning_count = $warningCount
  blocker_count = $blockerCount
  log = $logFile
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $resultPath

Write-Host "[web] status=$status warnings=$warningCount blockers=$blockerCount artifact=$artifactPath"
if ($status -eq "FAIL") {
  exit 1
}
exit 0
