[CmdletBinding()]
param([switch]$CompileOnly)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo
if ((git rev-parse HEAD) -ne '3e7f6ba0293482146313fb5d504de80edaab92f8') { throw 'Unexpected release base' }
if ((git branch --show-current) -ne 'release/v1.0.1-preparation') { throw 'Use isolated release-preparation branch' }
if (git diff HEAD -- source packages vittixdesigner demo tools) { throw 'Product build inputs differ from verified merged source' }
$rsvars = 'C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat'
$iscc = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
if (!(Test-Path $rsvars) -or !(Test-Path $iscc)) { throw 'Delphi 12 / Inno Setup 6 prerequisite missing' }
$out = Join-Path $repo 'build\release-audit'
New-Item -ItemType Directory -Force $out | Out-Null
$stage = Join-Path $repo 'build\release-payload'
if ((Test-Path $stage) -and !$CompileOnly) { throw 'Payload already exists; preserve it. Use -CompileOnly to verify and recompile this stage.' }
if ($CompileOnly -and !(Test-Path $stage)) { throw 'No staged payload to compile' }

function InvokeBuild([string]$project, [string]$platform, [string]$extra, [string]$log) {
  $line = 'call "{0}" && msbuild "{1}" /t:Rebuild /p:Config=Release /p:Platform={2} {3} /v:minimal' -f $rsvars,$project,$platform,$extra
  & cmd.exe /d /c $line 1> (Join-Path $out $log) 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Build failed: $project $platform; see $log" }
}

$saved = @{}
foreach ($p in (git ls-files '*.res')) { $saved[$p] = [IO.File]::ReadAllBytes((Join-Path $repo $p)) }
try {
  & cmd.exe /d /c installer\test_ownership.bat 1> (Join-Path $out 'ownership-tests.log') 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Ownership regression failed' }
  if (!$CompileOnly) {
  InvokeBuild 'packages\VittixReportRuntime.dproj' 'Win32' '' 'runtime-build.log'
  InvokeBuild 'packages\VittixReportDesign.dproj' 'Win32' '' 'design-build.log'
  $win32 = Join-Path $repo 'build\release-bin\Win32'
  $win64 = Join-Path $repo 'build\release-bin\Win64'
  New-Item -ItemType Directory -Force $win32,$win64 | Out-Null
  InvokeBuild 'vittixdesigner\VittixDesigner.dproj' 'Win32' ('/p:DCC_ExeOutput="{0}" /p:DCC_DcuOutput="{0}\dcu-designer"' -f $win32) 'designer-win32-build.log'
  InvokeBuild 'vittixdesigner\VittixDesigner.dproj' 'Win64' ('/p:DCC_ExeOutput="{0}" /p:DCC_DcuOutput="{0}\dcu-designer" /p:VerInfo_IncludeVerInfo=true /p:VerInfo_Keys="FileVersion=1.0.1.0%3BProductVersion=1.0.1.0"' -f $win64) 'designer-win64-build.log'
  InvokeBuild 'demo\VittixReportDemo.dproj' 'Win32' ('/p:DCC_ExeOutput="{0}" /p:DCC_DcuOutput="{0}\dcu-demo"' -f $win32) 'demo-build.log'
  New-Item -ItemType Directory $stage | Out-Null
  $inputs = @(git ls-files source packages demo)
  $inputs += @('README.md','LICENSE','USER_MANUAL.md','DEVELOPER_MANUAL.md','TESTING.md','branding/vittix-report.ico')
  foreach ($p in $inputs) {
    $allowed = $p.StartsWith('source/') -or
      ($p -match '^packages/[^/]+\.(dpk|dproj|res)$') -or
      ($p -match '^demo/[^/]+\.(pas|dfm|dpr|dproj|res|md)$') -or
      ($p -eq 'demo/db/vittixreportdemodb.db') -or ($p -eq 'demo/db/vittix_demo_sqlite.sql') -or
      ($p -match '^demo/vrt/[^/]+\.(vrt|md)$') -or ($p -notmatch '^(source|packages|demo)/')
    if (!$allowed) { continue }
    $dest = Join-Path $stage $p
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo $p) -Destination $dest
  }
  $binaries = @(
    @('build\bpl\VittixReportRuntime.bpl','Bpl\VittixReportRuntime.bpl'),
    @('build\bpl\VittixReportDesign.bpl','Bpl\VittixReportDesign.bpl'),
    @('build\dcp\VittixReportRuntime.dcp','Bpl\VittixReportRuntime.dcp'),
    @('build\dcp\VittixReportDesign.dcp','Bpl\VittixReportDesign.dcp'),
    @('build\release-bin\Win32\VittixDesigner.exe','vittixdesigner\VittixDesigner.exe'),
    @('build\release-bin\Win64\VittixDesigner.exe','vittixdesigner\Win64\VittixDesigner.exe'),
    @('build\release-bin\Win32\VittixReportDemo.exe','demo\VittixReportDemo.exe')
  )
  foreach ($pair in $binaries) {
    $dest = Join-Path $stage $pair[1]
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo $pair[0]) -Destination $dest
  }
  # The Demo requires the canonical Northwind sample to launch. Build only
  # from the existing merged helper's pinned, SHA-256-verified upstream SQL.
  & python demo\db\build_northwind_acceptance.py --output (Join-Path $stage 'demo\db\northwind.db') 1> (Join-Path $out 'northwind-build.log') 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Pinned Northwind sample build failed' }
  }
  & python installer\verify_payload.py $stage
  if ($LASTEXITCODE -ne 0) { throw 'Payload verification failed' }
  & $iscc 'installer\VittixReport.iss' 1> (Join-Path $out 'iscc-build.log') 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed; see iscc-build.log' }
  & python installer\verify_payload.py $stage 'build\installer\VittixReport-1.0.1-setup.exe'
  if ($LASTEXITCODE -ne 0) { throw 'Final artifact verification failed' }
  Write-Output 'Release candidate built; owner reports overall disposable-VM PASS, but VM-side hash and itemized scenarios remain unverified.'
} finally {
  foreach ($p in $saved.Keys) { [IO.File]::WriteAllBytes((Join-Path $repo $p), $saved[$p]) }
}
