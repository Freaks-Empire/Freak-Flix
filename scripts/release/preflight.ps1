param(
  [string]$LogDir = "$PSScriptRoot/logs"
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
Set-Location $repoRoot

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$logFile = Join-Path $LogDir "preflight.log"
$resultPath = Join-Path $LogDir "preflight-result.json"

$checks = New-Object System.Collections.Generic.List[object]
function Add-Check {
  param(
    [string]$Name,
    [string]$Status,
    [string]$Detail
  )
  $checks.Add([pscustomobject]@{
      name = $Name
      status = $Status
      detail = $Detail
    })
}

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -eq $flutterCmd) {
  Add-Check -Name "flutter" -Status "FAIL" -Detail "flutter command not found in PATH"
} else {
  Add-Check -Name "flutter" -Status "PASS" -Detail $flutterCmd.Source
}

$pubspecPath = Join-Path $repoRoot "pubspec.yaml"
if (Test-Path $pubspecPath) {
  Add-Check -Name "pubspec" -Status "PASS" -Detail $pubspecPath
} else {
  Add-Check -Name "pubspec" -Status "FAIL" -Detail "pubspec.yaml missing"
}

$androidGradleProps = Join-Path $repoRoot "android/gradle.properties"
if (Test-Path $androidGradleProps) {
  Add-Check -Name "android-gradle-properties" -Status "PASS" -Detail $androidGradleProps
} else {
  Add-Check -Name "android-gradle-properties" -Status "WARN" -Detail "android/gradle.properties missing"
}

if ($null -ne $flutterCmd) {
  $versionOutput = (& flutter --version 2>&1) -join [Environment]::NewLine
  $doctorOutput = & flutter doctor -v 2>&1
  $doctorText = $doctorOutput -join [Environment]::NewLine

  "=== flutter --version ===`n$versionOutput`n`n=== flutter doctor -v ===`n$doctorText" | Set-Content -Path $logFile

  $doctorWarnings = ($doctorOutput | Select-String -Pattern "\[!\]").Count
  $doctorFailures = ($doctorOutput | Select-String -Pattern "\[x\]" -CaseSensitive).Count

  if ($doctorFailures -gt 0) {
    Add-Check -Name "flutter-doctor" -Status "WARN" -Detail "doctor reported blockers ($doctorFailures). See $logFile"
  } elseif ($doctorWarnings -gt 0) {
    Add-Check -Name "flutter-doctor" -Status "WARN" -Detail "doctor reported warnings ($doctorWarnings). See $logFile"
  } else {
    Add-Check -Name "flutter-doctor" -Status "PASS" -Detail "doctor reported no warnings"
  }
}

$failCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
$warnCount = @($checks | Where-Object { $_.status -eq "WARN" }).Count
$status = if ($failCount -gt 0) { "FAIL" } elseif ($warnCount -gt 0) { "WARN" } else { "PASS" }

$result = [pscustomobject]@{
  phase = "02"
  stage = "preflight"
  timestamp = $timestamp
  status = $status
  fail_count = $failCount
  warn_count = $warnCount
  checks = $checks
  log = $logFile
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $resultPath

Write-Host "[preflight] status=$status fail=$failCount warn=$warnCount"
$checks | Format-Table -AutoSize

if ($failCount -gt 0) {
  exit 1
}
exit 0
