[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Url,
  [ValidateRange(1024, 65535)]
  [int]$Port = 9222,
  [string]$Profile = "$env:USERPROFILE\.playwright-cli\profiles\human-chrome",
  [string]$ChromePath = "",
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Status {
  param([string]$Message)
  if (-not $Quiet) { Write-Host $Message }
}

function Resolve-ProfilePath {
  param([string]$Path)
  $expandedPath = [Environment]::ExpandEnvironmentVariables($Path)
  return [IO.Path]::GetFullPath($expandedPath).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Find-Chrome {
  if ($ChromePath) {
    if (Test-Path -LiteralPath $ChromePath -PathType Leaf) {
      return (Resolve-Path -LiteralPath $ChromePath).Path
    }
    throw "Chrome was not found at '$ChromePath'."
  }

  $pathCommand = Get-Command chrome.exe -ErrorAction SilentlyContinue
  if ($pathCommand) { return $pathCommand.Source }

  $candidates = @(
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
  }

  throw "Chrome was not found. Install Google Chrome or pass -ChromePath."
}

function Test-Cdp {
  try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/version" -UseBasicParsing -TimeoutSec 2
    return $response.StatusCode -eq 200
  } catch {
    return $false
  }
}

function Test-LoopbackPort {
  $client = [Net.Sockets.TcpClient]::new()
  try {
    $asyncResult = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
    if (-not $asyncResult.AsyncWaitHandle.WaitOne(300)) { return $false }
    $client.EndConnect($asyncResult)
    return $true
  } catch {
    return $false
  } finally {
    $client.Dispose()
  }
}

function Get-DedicatedBrowserProcesses {
  param([string]$ResolvedProfile)

  $profileNeedle = $ResolvedProfile.Replace("/", "\").ToLowerInvariant()
  $portPattern = "(?i)(?:^|\s)--remote-debugging-port=$([regex]::Escape([string]$Port))(?:\s|$)"
  $processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match '^(chrome|msedge)\.exe$' -and $_.CommandLine
  }

  return @($processes | Where-Object {
    $commandLine = ([string]$_.CommandLine).Replace("/", "\").ToLowerInvariant()
    $commandLine.Contains($profileNeedle) -and ([string]$_.CommandLine -match $portPattern)
  })
}

$uri = $null
if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -notin @("http", "https")) {
  throw "Url must be an absolute HTTP or HTTPS URL."
}

$resolvedProfile = Resolve-ProfilePath -Path $Profile
if ($resolvedProfile.Contains('"')) { throw "Profile path cannot contain a double quote." }

$chrome = Find-Chrome
New-Item -ItemType Directory -Force -Path $resolvedProfile | Out-Null

if (Test-LoopbackPort) {
  $ownedProcesses = @(Get-DedicatedBrowserProcesses -ResolvedProfile $resolvedProfile)
  if (-not (Test-Cdp) -or $ownedProcesses.Count -eq 0) {
    throw "Port $Port is already in use by an unrecognized process. Choose another -Port or stop it manually."
  }

  Write-Status "Stopping the previous dedicated Chrome instance on port $Port."
  $stopScript = Join-Path $PSScriptRoot "stop-chrome-cdp.ps1"
  & $stopScript -Port $Port -Profile $resolvedProfile -Quiet:$Quiet
  if ($LASTEXITCODE -ne 0) {
    throw "The previous dedicated Chrome instance could not be stopped safely."
  }
  Start-Sleep -Milliseconds 500
}

$arguments = @(
  "--remote-debugging-address=127.0.0.1",
  "--remote-debugging-port=$Port",
  "--user-data-dir=`"$resolvedProfile`"",
  "--no-first-run",
  "--no-default-browser-check",
  "--new-window",
  "`"$($uri.AbsoluteUri)`""
)

$process = Start-Process -FilePath $chrome -ArgumentList $arguments -PassThru
$pidFile = Join-Path $resolvedProfile ".playwright-cli-human.pid"
[IO.File]::WriteAllText($pidFile, [string]$process.Id)

Write-Status "Started dedicated Chrome pid=$($process.Id) port=$Port profile=$resolvedProfile"
Write-Status "URL: $($uri.AbsoluteUri)"

$ready = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
  if (Test-Cdp) {
    $ready = $true
    break
  }
  Start-Sleep -Milliseconds 400
}

if (-not $ready) {
  Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
  throw "Chrome started but CDP did not become ready at http://127.0.0.1:$Port."
}

Write-Status "CDP ready at http://127.0.0.1:$Port"
exit 0
