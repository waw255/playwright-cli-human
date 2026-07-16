[CmdletBinding()]
param(
  [ValidateRange(1024, 65535)]
  [int]$Port = 9222,
  [string]$Profile = "$env:USERPROFILE\.playwright-cli\profiles\human-chrome",
  [ValidatePattern('^[A-Za-z0-9._-]+$')]
  [string]$Session = "human",
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

function Write-Status {
  param([string]$Message)
  if (-not $Quiet) { Write-Host $Message }
}

function Resolve-ProfilePath {
  param([string]$Path)
  $expandedPath = [Environment]::ExpandEnvironmentVariables($Path)
  return [IO.Path]::GetFullPath($expandedPath).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Test-Cdp {
  try {
    $null = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/version" -UseBasicParsing -TimeoutSec 1
    return $true
  } catch {
    return $false
  }
}

$resolvedProfile = Resolve-ProfilePath -Path $Profile
$profileNeedle = $resolvedProfile.Replace("/", "\").ToLowerInvariant()
$portPattern = "(?i)(?:^|\s)--remote-debugging-port=$([regex]::Escape([string]$Port))(?:\s|$)"
$processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
  $_.Name -match '^(chrome|msedge)\.exe$' -and $_.CommandLine
})

$owners = @($processes | Where-Object {
  $commandLine = ([string]$_.CommandLine).Replace("/", "\").ToLowerInvariant()
  $commandLine.Contains($profileNeedle) -and ([string]$_.CommandLine -match $portPattern)
})

$pidFile = Join-Path $resolvedProfile ".playwright-cli-human.pid"
if ($owners.Count -eq 0) {
  Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
  if (Test-Cdp) {
    Write-Status "Refusing to stop Chrome: CDP port $Port does not match the dedicated profile '$resolvedProfile'."
    exit 2
  }
  Write-Status "No dedicated Chrome matched port=$Port profile=$resolvedProfile"
  exit 0
}

if (Get-Command playwright-cli -ErrorAction SilentlyContinue) {
  try {
    $null = & playwright-cli "-s=$Session" detach 2>$null
  } catch {}
}

$profileProcesses = @($processes | Where-Object {
  ([string]$_.CommandLine).Replace("/", "\").ToLowerInvariant().Contains($profileNeedle)
})
$processIds = @($profileProcesses.ProcessId | Sort-Object -Unique)

foreach ($processId in $processIds) {
  Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue

if ($processIds.Count -gt 0) {
  Write-Status "Stopped dedicated Chrome pids: $($processIds -join ', ')"
}

Start-Sleep -Milliseconds 500
if (Test-Cdp) {
  Write-Status "WARNING: CDP is still responding on port $Port."
  exit 2
}

Write-Status "CDP port $Port is closed."
exit 0
