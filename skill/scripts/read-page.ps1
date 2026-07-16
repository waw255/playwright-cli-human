[CmdletBinding()]
param(
  [ValidateRange(1024, 65535)]
  [int]$Port = 9222,
  [ValidatePattern('^[A-Za-z0-9._-]+$')]
  [string]$Session = "human",
  [string]$SnapshotFile = "",
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-PlaywrightCli {
  param([string[]]$Arguments)

  $output = @(& playwright-cli @Arguments 2>&1)
  $exitCode = $LASTEXITCODE
  $text = ($output | Out-String).Trim()
  if ($exitCode -ne 0) {
    throw "playwright-cli failed with exit code $exitCode`: $text"
  }
  return $text
}

function ConvertFrom-RawValue {
  param([string]$Value)

  if (-not $Value) { return "" }
  try {
    return [string]($Value | ConvertFrom-Json)
  } catch {
    return $Value.Trim()
  }
}

if (-not (Get-Command playwright-cli -ErrorAction SilentlyContinue)) {
  throw "playwright-cli is not installed or is not available on PATH."
}

$cdp = "http://127.0.0.1:$Port"
try {
  $null = Invoke-WebRequest -Uri "$cdp/json/version" -UseBasicParsing -TimeoutSec 3
} catch {
  throw "CDP is not available at $cdp. Start the dedicated Chrome instance first."
}

$sessionFlag = "-s=$Session"
$attached = $false
$title = ""
$url = ""
$snapshotText = ""
$snapshotPath = $null

try {
  $attachOutput = Invoke-PlaywrightCli -Arguments @("attach", "--cdp=$cdp", "--session=$Session")
  $attached = $true
  if (-not $Json -and $attachOutput) { Write-Host $attachOutput }

  $title = ConvertFrom-RawValue (Invoke-PlaywrightCli -Arguments @($sessionFlag, "--raw", "eval", "() => document.title"))
  $url = ConvertFrom-RawValue (Invoke-PlaywrightCli -Arguments @($sessionFlag, "--raw", "eval", "() => location.href"))

  if ($SnapshotFile) {
    $snapshotOutput = Invoke-PlaywrightCli -Arguments @($sessionFlag, "snapshot", "--filename=$SnapshotFile")
    $snapshotPath = $SnapshotFile
    if (Test-Path -LiteralPath $SnapshotFile -PathType Leaf) {
      $snapshotText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $SnapshotFile).Path)
    }
    if (-not $Json -and $snapshotOutput) { Write-Host $snapshotOutput }
  } else {
    $snapshotText = Invoke-PlaywrightCli -Arguments @($sessionFlag, "--raw", "snapshot")
    if (-not $Json -and $snapshotText) { Write-Host $snapshotText }
  }
} finally {
  if ($attached) {
    try {
      $detachOutput = Invoke-PlaywrightCli -Arguments @($sessionFlag, "detach")
      if (-not $Json -and $detachOutput) { Write-Host $detachOutput }
    } catch {
      if (-not $Json) { Write-Warning $_.Exception.Message }
    }
  }
}

$blockedHints = @(
  "Just a moment",
  "Checking your browser",
  "Attention Required",
  "cf-browser-verification",
  "unusual traffic",
  "captcha",
  "hcaptcha",
  "recaptcha",
  "are you a robot",
  "verify you are human",
  "Enable JavaScript and cookies",
  "google.com/sorry",
  "/sorry/index",
  "Our systems have detected unusual traffic",
  "before you continue to Google"
)
$blockedHints += @(
  ([string][char]0x6B63 + [char]0x5728 + [char]0x786E + [char]0x8BA4),
  ([string][char]0x673A + [char]0x5668 + [char]0x4EBA),
  ([string][char]0x8BF7 + [char]0x5B8C + [char]0x6210 + [char]0x5B89 + [char]0x5168 + [char]0x9A8C + [char]0x8BC1)
)

$probe = "$title`n$url`n$snapshotText"
$isBlocked = $false
foreach ($hint in $blockedHints) {
  if ($hint -and $probe.IndexOf($hint, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
    $isBlocked = $true
    break
  }
}

$result = [ordered]@{
  url = $url
  title = $title
  blocked = $isBlocked
  snapshot = $snapshotPath
  port = $Port
  session = $Session
}

if ($Json) {
  Write-Output ($result | ConvertTo-Json -Compress)
} else {
  Write-Host "URL:     $url"
  Write-Host "Title:   $title"
  Write-Host "Blocked: $isBlocked"
}

if ($isBlocked) { exit 3 }
exit 0
