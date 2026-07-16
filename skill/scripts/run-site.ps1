# One-shot lifecycle for a page that is not expected to require a human pause.
[CmdletBinding()]
param(
  [string]$Url = "",
  [ValidateRange(1024, 65535)]
  [int]$Port = 9222,
  [string]$Profile = "$env:USERPROFILE\.playwright-cli\profiles\human-chrome",
  [ValidatePattern('^[A-Za-z0-9._-]+$')]
  [string]$Session = "human",
  [string]$SnapshotFile = "",
  [Alias("ReadOnly")]
  [switch]$AttachOnly,
  [switch]$SkipStop,
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$startScript = Join-Path $PSScriptRoot "start-chrome-cdp.ps1"
$readScript = Join-Path $PSScriptRoot "read-page.ps1"
$stopScript = Join-Path $PSScriptRoot "stop-chrome-cdp.ps1"

if (-not $AttachOnly -and -not $Url) {
  throw "Url is required unless -AttachOnly is used."
}

$readArguments = @{
  Port = $Port
  Session = $Session
}
if ($SnapshotFile) { $readArguments.SnapshotFile = $SnapshotFile }
if ($Json) { $readArguments.Json = $true }

$exitCode = 0
$lifecycleActive = $AttachOnly
try {
  if (-not $AttachOnly) {
    & $startScript -Url $Url -Port $Port -Profile $Profile -Quiet:$Json
    $lifecycleActive = $true
  }

  try {
    & $readScript @readArguments
    $exitCode = $LASTEXITCODE
  } catch {
    if (-not $Json) { Write-Warning "Read failed: $($_.Exception.Message)" }
    $exitCode = 1
  }
} finally {
  if ($lifecycleActive -and -not $SkipStop) {
    & $stopScript -Port $Port -Profile $Profile -Session $Session -Quiet:$Json
    $stopExitCode = $LASTEXITCODE
    if ($exitCode -eq 0 -and $stopExitCode -ne 0) {
      $exitCode = $stopExitCode
    }
  }
}

exit $exitCode
