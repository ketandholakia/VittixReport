<#
  Phase 5 — regression gate.

  One command that runs every Phase 5 quality gate in order and fails fast:

    1. Build the DUnitX test project (Release, Win32).
    2. Run the tests  -> require exit 0 AND "Tests Leaked : 0".
    3. Build VittixRunner.
    4. Run VittixRunner --strict -> require exit 0 (pagination baseline
       reconciled, no execution failures) and enforce resource thresholds.
    5. Optional (-IncludePackages): build runtime package, design package and
       the standalone designer as a packaging smoke check.

  Structural counters and page counts are the gates; timing is informational.

  Usage:
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\ci_gate.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\ci_gate.ps1 -IncludePackages
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\ci_gate.ps1 -SkipRunner

  Exit codes: 0 = all gates passed, 1 = gate failure, 2 = environment error.

  PowerShell 5.1 compatible (no && / ternary / null-coalescing operators).
#>
[CmdletBinding()]
param(
  [string]$Config = 'Release',
  [string]$Platform = 'Win32',
  [int]$GdiDeltaLimit = 16,
  [switch]$SkipRunner,
  [switch]$IncludePackages
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$script:Failures = 0

function Write-Step([string]$Message) {
  Write-Host ''
  Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Fail([string]$Message) {
  Write-Host "GATE FAILED: $Message" -ForegroundColor Red
  exit 1
}

function Note([string]$Message) {
  Write-Host "  $Message"
}

# --- Locate repository root (this script lives in tools\) -------------------
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $RepoRoot 'tests\VittixReportTests.dproj'))) {
  Write-Host 'Environment error: repository root not found (expected tests\VittixReportTests.dproj).' -ForegroundColor Red
  exit 2
}
Set-Location $RepoRoot

$GateOut = Join-Path $RepoRoot 'build\gate'
if (-not (Test-Path $GateOut)) {
  New-Item -ItemType Directory -Force -Path $GateOut | Out-Null
}

# --- Delphi environment -----------------------------------------------------
$RsvarsCandidates = @(
  'C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat',
  'C:\Program Files (x86)\Embarcadero\Studio\22.0\bin\rsvars.bat'
)
$Rsvars = $null
foreach ($Candidate in $RsvarsCandidates) {
  if (Test-Path $Candidate) { $Rsvars = $Candidate; break }
}

$MsbuildOnPath = $null -ne (Get-Command msbuild -ErrorAction SilentlyContinue)
if (-not $MsbuildOnPath -and $null -eq $Rsvars) {
  Write-Host 'Environment error: msbuild is not on PATH and no Delphi rsvars.bat was found.' -ForegroundColor Red
  exit 2
}

function Invoke-Msbuild([string]$ProjectRelative, [string]$Target) {
  $ProjectPath = Join-Path $RepoRoot $ProjectRelative
  if (-not (Test-Path $ProjectPath)) {
    Fail "project not found: $ProjectRelative"
  }
  Write-Host "  msbuild $ProjectRelative /t:$Target /p:Config=$Config /p:Platform=$Platform"
  if (Test-Path $Rsvars) {
    $CmdLine = 'call "{0}" && msbuild "{1}" /t:{2} /p:Config={3} /p:Platform={4} /v:q' -f `
      $Rsvars, $ProjectPath, $Target, $Config, $Platform
    & cmd.exe /c $CmdLine
  } else {
    & msbuild $ProjectPath "/t:$Target" "/p:Config=$Config" "/p:Platform=$Platform" '/v:q'
  }
  if ($LASTEXITCODE -ne 0) {
    Fail "msbuild failed ($ProjectRelative /t:$Target), exit $LASTEXITCODE"
  }
}

# --- Gate 1 + 2: build and run the DUnitX suite -----------------------------
Write-Step 'Gate 1/4: build test project'
Invoke-Msbuild 'tests\VittixReportTests.dproj' 'Build'

Write-Step 'Gate 2/4: run DUnitX suite (exit 0, zero leaks)'
$TestExe = Join-Path $RepoRoot ('tests\{0}\{1}\VittixReportTests.exe' -f $Platform, $Config)
if (-not (Test-Path $TestExe)) {
  Fail "test executable not found: $TestExe"
}
$TestXml = Join-Path $RepoRoot 'tests\dunitx-results.xml'
$TestLog = Join-Path $GateOut 'dunitx-console.txt'

$TestOutput = & $TestExe "-xml:$TestXml" 2>&1 | Out-String
$TestExit = $LASTEXITCODE
Set-Content -Path $TestLog -Value $TestOutput -Encoding UTF8
Write-Host $TestOutput

if ($TestExit -ne 0) {
  Fail "DUnitX exited $TestExit (expected 0)"
}
if ($TestOutput -notmatch 'Tests\s+Leaked\s*:\s*0') {
  Fail "DUnitX leak check did not report 'Tests Leaked : 0'"
}
if ($TestOutput -match 'Tests\s+Found\s*:\s*(\d+)') { $Found = [int]$Matches[1] } else { $Found = -1 }
if ($TestOutput -match 'Tests\s+Passed\s*:\s*(\d+)') { $Passed = [int]$Matches[1] } else { $Passed = -1 }
if ($TestOutput -match 'Tests\s+Failed\s*:\s*(\d+)') { $Failed = [int]$Matches[1] } else { $Failed = -1 }
if ($TestOutput -match 'Tests\s+Errored\s*:\s*(\d+)') { $Errored = [int]$Matches[1] } else { $Errored = -1 }
Note ("found={0} passed={1} failed={2} errored={3} leaked=0" -f $Found, $Passed, $Failed, $Errored)
if ($Failed -gt 0 -or $Errored -gt 0) {
  Fail "DUnitX reported failures ($Failed) or errors ($Errored)"
}

# --- Gate 3 + 4: build and run the regression runner ------------------------
if (-not $SkipRunner) {
  Write-Step 'Gate 3/4: build VittixRunner'
  Invoke-Msbuild 'VittixRunner.dproj' 'Build'

  Write-Step 'Gate 4/4: run VittixRunner --strict (pagination + resources)'
  $RunnerExe = Join-Path $RepoRoot ('bin\{0}\{1}\VittixRunner.exe' -f $Platform, $Config)
  if (-not (Test-Path $RunnerExe)) {
    Fail "runner executable not found: $RunnerExe"
  }
  $RunnerLog = Join-Path $GateOut 'runner-console.txt'
  $RunnerOutput = & $RunnerExe '--strict' '--keep-vector-pdf' '--output' $GateOut 2>&1 | Out-String
  $RunnerExit = $LASTEXITCODE
  Set-Content -Path $RunnerLog -Value $RunnerOutput -Encoding UTF8
  Write-Host $RunnerOutput

  if ($RunnerExit -ne 0) {
    Fail "VittixRunner --strict exited $RunnerExit (expected 0: 1 = regression, 2 = usage/baseline error)"
  }

  # Resource thresholds. USER must not grow; GDI is bounded (cache allocations
  # in the first reports are expected); memory is informational.
  $UserDelta = $null
  $GdiDelta = $null
  if ($RunnerOutput -match 'USER\s+Handles\s*:\s*\d+\s*->\s*\d+\s*\(Delta:\s*(-?\d+)\)') {
    $UserDelta = [int]$Matches[1]
  }
  if ($RunnerOutput -match 'GDI\s+Handles\s*:\s*\d+\s*->\s*\d+\s*\(Delta:\s*(-?\d+)\)') {
    $GdiDelta = [int]$Matches[1]
  }
  if ($null -eq $UserDelta) {
    Write-Host '  WARNING: USER handle delta not found in runner output; skipping USER threshold.' -ForegroundColor Yellow
  } elseif ($UserDelta -ne 0) {
    Fail "USER handle delta is $UserDelta (expected 0)"
  } else {
    Note 'USER handle delta = 0'
  }
  if ($null -ne $GdiDelta) {
    Note ("GDI handle delta = {0} (limit {1})" -f $GdiDelta, $GdiDeltaLimit)
    if ($GdiDelta -gt $GdiDeltaLimit) {
      Fail "GDI handle delta $GdiDelta exceeds limit $GdiDeltaLimit"
    }
  }
} else {
  Write-Step 'Gates 3/4: skipped (-SkipRunner)'
}

# --- Optional packaging smoke ----------------------------------------------
if ($IncludePackages) {
  Write-Step 'Packaging smoke: runtime package, design package, designer'
  Invoke-Msbuild 'packages\VittixReportRuntime.dproj' 'Build'
  Invoke-Msbuild 'packages\VittixReportDesign.dproj' 'Build'
  Invoke-Msbuild 'vittixdesigner\VittixDesigner.dproj' 'Build'
}

Write-Host ''
Write-Host 'All gates passed.' -ForegroundColor Green
exit 0
