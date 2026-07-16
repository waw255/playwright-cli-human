[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
  param([string]$Message)
  $failures.Add($Message)
}

function Get-RelativePath {
  param([string]$Path)
  return $Path.Substring($root.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

$requiredFiles = @(
  "README.md",
  "LICENSE",
  "NOTICE",
  "CONTRIBUTING.md",
  "SECURITY.md",
  "skill/SKILL.md",
  "skill/LICENSE",
  "skill/NOTICE",
  "skill/scripts/start-chrome-cdp.ps1",
  "skill/scripts/read-page.ps1",
  "skill/scripts/stop-chrome-cdp.ps1",
  "skill/scripts/run-site.ps1"
)

foreach ($relativePath in $requiredFiles) {
  $fullPath = Join-Path $root $relativePath
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
    Add-Failure "Missing required file: $relativePath"
  }
}

$skillPath = Join-Path $root "skill/SKILL.md"
if (Test-Path -LiteralPath $skillPath) {
  $skillText = [IO.File]::ReadAllText($skillPath).Replace("`r`n", "`n")
  $frontmatterMatch = [regex]::Match($skillText, "(?s)\A---\n(?<body>.*?)\n---\n")
  if (-not $frontmatterMatch.Success) {
    Add-Failure "skill/SKILL.md has invalid YAML frontmatter boundaries"
  } else {
    $frontmatter = $frontmatterMatch.Groups["body"].Value
    foreach ($field in @("name", "description", "license")) {
      if ($frontmatter -notmatch "(?m)^${field}:\s*\S") {
        Add-Failure "skill/SKILL.md frontmatter is missing '$field'"
      }
    }
    if ($frontmatter -notmatch "(?m)^name:\s*playwright-cli-human\s*$") {
      Add-Failure "skill/SKILL.md must preserve the name 'playwright-cli-human'"
    }
    if ($frontmatter -notmatch "(?m)^license:\s*Apache-2\.0\s*$") {
      Add-Failure "skill/SKILL.md must declare license: Apache-2.0"
    }
  }

  $lineCount = ($skillText -split "`n").Count
  if ($lineCount -gt 500) {
    Add-Failure "skill/SKILL.md has $lineCount lines; keep it at or below 500"
  }
}

$rootLicensePath = Join-Path $root "LICENSE"
$skillLicensePath = Join-Path $root "skill/LICENSE"
$rootNoticePath = Join-Path $root "NOTICE"
$skillNoticePath = Join-Path $root "skill/NOTICE"
if ((Test-Path -LiteralPath $rootLicensePath) -and (Test-Path -LiteralPath $skillLicensePath)) {
  $rootLicense = [IO.File]::ReadAllText($rootLicensePath).Replace("`r`n", "`n")
  $skillLicense = [IO.File]::ReadAllText($skillLicensePath).Replace("`r`n", "`n")
  if ($rootLicense -ne $skillLicense) {
    Add-Failure "Root LICENSE and skill/LICENSE must be identical"
  }
  if ($rootLicense -notmatch "Apache License\s+Version 2\.0") {
    Add-Failure "LICENSE must contain the Apache License, Version 2.0"
  }
}

if ((Test-Path -LiteralPath $rootNoticePath) -and (Test-Path -LiteralPath $skillNoticePath)) {
  $rootNotice = [IO.File]::ReadAllText($rootNoticePath).Replace("`r`n", "`n")
  $skillNotice = [IO.File]::ReadAllText($skillNoticePath).Replace("`r`n", "`n")
  if ($rootNotice -ne $skillNotice) {
    Add-Failure "Root NOTICE and skill/NOTICE must be identical"
  }
  if ($rootNotice -notmatch "https://github\.com/microsoft/playwright-cli") {
    Add-Failure "NOTICE must identify the microsoft/playwright-cli upstream repository"
  }
}

$adaptedFiles = @(
  "skill/SKILL.md",
  "skill/references/element-attributes.md",
  "skill/references/request-mocking.md",
  "skill/references/running-code.md",
  "skill/references/session-management.md",
  "skill/references/storage-state.md",
  "skill/references/tracing.md",
  "skill/references/video-recording.md"
)
foreach ($relativePath in $adaptedFiles) {
  $adaptedPath = Join-Path $root $relativePath
  if ((Test-Path -LiteralPath $adaptedPath) -and ([IO.File]::ReadAllText($adaptedPath) -notmatch "Modified upstream material:.*@playwright/cli")) {
    Add-Failure "$relativePath must carry a prominent modified-upstream notice"
  }
}

$readmePath = Join-Path $root "README.md"
if ((Test-Path -LiteralPath $readmePath) -and ([IO.File]::ReadAllText($readmePath) -notmatch "https://github\.com/microsoft/playwright-cli")) {
  Add-Failure "README.md must link to the microsoft/playwright-cli upstream repository"
}

Get-ChildItem -Path (Join-Path $root "skill/scripts") -Filter "*.ps1" -File | ForEach-Object {
  $tokens = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
  foreach ($parseError in @($parseErrors)) {
    Add-Failure "$(Get-RelativePath $_.FullName):$($parseError.Extent.StartLineNumber): $($parseError.Message)"
  }
}

$markdownLinkPattern = [regex]'\[[^\]]+\]\((?<target>[^)]+)\)'
Get-ChildItem -Path $root -Recurse -Filter "*.md" -File | ForEach-Object {
  $markdownFile = $_
  $content = [IO.File]::ReadAllText($markdownFile.FullName)
  foreach ($match in $markdownLinkPattern.Matches($content)) {
    $target = $match.Groups["target"].Value.Trim().Trim('<', '>')
    if ($target -match '^(?:https?://|mailto:|#)') { continue }
    $target = ($target -split '#', 2)[0]
    if (-not $target) { continue }
    $decodedTarget = [Uri]::UnescapeDataString($target)
    $resolvedTarget = Join-Path $markdownFile.DirectoryName $decodedTarget
    if (-not (Test-Path -LiteralPath $resolvedTarget)) {
      Add-Failure "$(Get-RelativePath $markdownFile.FullName): broken local link '$target'"
    }
  }
}

Get-ChildItem -Path $root -Recurse -Filter "*.json" -File | ForEach-Object {
  try {
    [IO.File]::ReadAllText($_.FullName) | ConvertFrom-Json | Out-Null
  } catch {
    Add-Failure "$(Get-RelativePath $_.FullName): invalid JSON: $($_.Exception.Message)"
  }
}

$textFiles = Get-ChildItem -Path $root -Recurse -File | Where-Object {
  $_.Extension -in @(".md", ".ps1", ".json", ".yml", ".yaml") -and $_.FullName -ne $PSCommandPath
}

$mojibakeTokens = @(
  [string][char]0xFFFD,
  [string][char]0x9225,
  [string][char]0x922B,
  ([string][char]0x93BC + [char]0x6EC5 + [char]0x50A8),
  ([string][char]0x93C8 + [char]0x20AC + [char]0x6D63)
)
$mojibakePattern = [regex](($mojibakeTokens | ForEach-Object { [regex]::Escape($_) }) -join '|')
$personalPathPattern = [regex]'(?i)E:\\sp26|C:\\Users\\Sparkling|ZT-HA-XiaoMi'
foreach ($file in $textFiles) {
  $content = [IO.File]::ReadAllText($file.FullName)
  if ($mojibakePattern.IsMatch($content)) {
    Add-Failure "$(Get-RelativePath $file.FullName): possible mojibake detected"
  }
  if ($personalPathPattern.IsMatch($content)) {
    Add-Failure "$(Get-RelativePath $file.FullName): personal absolute path detected"
  }
}

if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-Path $root ".git"))) {
  $insideWorkTree = & git -C $root rev-parse --is-inside-work-tree 2>$null
  if ($LASTEXITCODE -eq 0 -and $insideWorkTree -eq "true") {
    $trackedFiles = @(& git -C $root ls-files)
    $forbiddenPatterns = @(
      '^\.playwright-cli/',
      '(^|/)profiles/',
      '(^|/)auth\.json$',
      '(^|/)storage-state.*\.json$',
      '\.zip$'
    )
    foreach ($trackedFile in $trackedFiles) {
      foreach ($pattern in $forbiddenPatterns) {
        if ($trackedFile -match $pattern) {
          Add-Failure "Sensitive or generated file is tracked: $trackedFile"
          break
        }
      }
    }
  }
}

if ($failures.Count -gt 0) {
  Write-Host "Validation failed:" -ForegroundColor Red
  foreach ($failure in $failures) {
    Write-Host "- $failure" -ForegroundColor Red
  }
  exit 1
}

Write-Host "Validation passed: skill metadata, scripts, links, JSON, and repository hygiene are valid." -ForegroundColor Green
