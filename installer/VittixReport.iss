; ---------------------------------------------------------------------------
; VittixReport setup script (Inno Setup 6)
;
; Packages the VittixReport Delphi component library and the standalone
; Vittix Report Designer into a single Windows installer:
;
;   - source\            full framework sources (incl. vendored QRCodeGenLib)
;   - packages\          runtime + design-time .dpk/.dproj package projects
;   - Bpl\               prebuilt Win32 .bpl/.dcp files (Delphi 12 / BDS 23.0)
;   - vittixdesigner\    the standalone Vittix Report Designer executable
;   - demo\              demo application, sample .vrt reports, SQLite data
;   - documentation      README, user/developer manuals, testing notes, MIT license
;
; Optional RAD Studio integration ("Integrate with RAD Studio" task):
;   - registers VittixReportDesign.bpl under HKCU Known Packages (BDS 23.0)
;     so the "Vittix Reporting" palette page appears after an IDE restart
;   - appends source\ for BDS 23.0/24.0 Win32/Win64; Delphi 12 Win32
;     additionally receives Bpl\ (never Delphi 12 DCPs in Delphi 13 paths)
;   - the component editor finds VittixDesigner.exe via the documented
;     lookup ("..\vittixdesigner\VittixDesigner.exe" relative to the BPL),
;     so double-clicking TVittixReport works out of the box
;
; Build:  installer\build_installer.bat   (or ISCC installer\VittixReport.iss)
; ---------------------------------------------------------------------------

#if VER < 0x06010000
#error "Inno Setup 6.1 or later is required"
#endif

#define AppName "VittixReport"
#define AppVersion "1.0.1"

; Only the verified, tracked-only distribution stage is packaged.
#define RepoRoot ExtractFilePath(RemoveBackslashUnlessRoot(SourcePath)) + "build\release-payload\"

; --- build-artifact guards ---------------------------------------------------
#if !FileExists(RepoRoot + "Bpl\VittixReportRuntime.bpl")
#error "Verified payload missing. Run installer\build_installer.bat first."
#endif
#if !FileExists(RepoRoot + "Bpl\VittixReportDesign.bpl")
#error "Verified payload missing. Run installer\build_installer.bat first."
#endif
#if !FileExists(RepoRoot + "Bpl\VittixReportRuntime.dcp")
#error "Verified payload missing. Run installer\build_installer.bat first."
#endif
#if !FileExists(RepoRoot + "vittixdesigner\VittixDesigner.exe")
#error "Verified payload missing. Run installer\build_installer.bat first."
#endif

[Setup]
AppId={{B7E91D42-8C3A-4F6E-9D25-1A0C7E4B8F63}
AppName={#AppName}
AppVersion={#AppVersion}
VersionInfoVersion=1.0.1.0
VersionInfoProductVersion=1.0.1.0
MinVersion=10.0
PrivilegesRequired=admin
AppVerName={#AppName} {#AppVersion}
AppPublisher=Ketan Dholakia
AppCopyright=Copyright (c) 2026 Ketan Dholakia
DefaultDirName={commonpf}\VittixReport
DefaultGroupName=VittixReport
DisableDirPage=yes
UsePreviousAppDir=yes
LicenseFile={#RepoRoot}LICENSE
SetupIconFile={#RepoRoot}branding\vittix-report.ico
UninstallDisplayIcon={app}\vittixdesigner\VittixDesigner.exe
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
OutputDir=..\build\installer
OutputBaseFilename=VittixReport-{#AppVersion}-setup
OutputManifestFile=VittixReport-1.0.1-payload.txt
SetupLogging=yes

[Types]
Name: "full"; Description: "Full installation (component library, designer, demo)"; Flags: iscustom
Name: "compact"; Description: "Component library and designer only (no demo)"

[Components]
Name: "core"; Description: "VittixReport sources, packages, prebuilt BPL/DCP and Report Designer"; Types: full compact; Flags: fixed
Name: "demo"; Description: "Demo application, sample reports and SQLite databases"; Types: full

[Tasks]
Name: "idesetup"; Description: "Integrate with RAD Studio (register design-time package, add library search paths)"; Check: DelphiInstalled
Name: "desktopicon"; Description: "Create a &desktop shortcut for Vittix Report Designer"; Flags: unchecked

[Files]
; --- documentation -----------------------------------------------------------
Source: "{#RepoRoot}README.md"; DestDir: "{app}"; Components: core; Flags: ignoreversion
Source: "{#RepoRoot}LICENSE"; DestDir: "{app}"; Components: core; Flags: ignoreversion
Source: "{#RepoRoot}USER_MANUAL.md"; DestDir: "{app}"; Components: core; Flags: ignoreversion
Source: "{#RepoRoot}DEVELOPER_MANUAL.md"; DestDir: "{app}"; Components: core; Flags: ignoreversion
Source: "{#RepoRoot}TESTING.md"; DestDir: "{app}"; Components: core; Flags: ignoreversion

; --- framework sources (recursive, incl. ThirdParty\QRCodeGenLib) ------------
Source: "{#RepoRoot}source\*"; DestDir: "{app}\source"; Components: core; Excludes: "__history,__history\*,*\__history\*,*.dcu,*.local,*.identcache,*.~*,*.bak"; Flags: recursesubdirs createallsubdirs ignoreversion

; --- package projects ---------------------------------------------------------
Source: "{#RepoRoot}packages\*.dpk"; DestDir: "{app}\packages"; Components: core; Flags: ignoreversion
Source: "{#RepoRoot}packages\*.dproj"; DestDir: "{app}\packages"; Components: core; Flags: ignoreversion
Source: "{#RepoRoot}packages\*.res"; DestDir: "{app}\packages"; Components: core; Flags: ignoreversion

; --- prebuilt Win32 packages (BDS 23.0) ---------------------------------------
Source: "{#RepoRoot}Bpl\VittixReportRuntime.bpl"; DestDir: "{app}\Bpl"; Components: core; Flags: ignoreversion
Source: "{#RepoRoot}Bpl\VittixReportDesign.bpl"; DestDir: "{app}\Bpl"; Components: core; Flags: ignoreversion
Source: "{#RepoRoot}Bpl\VittixReportRuntime.dcp"; DestDir: "{app}\Bpl"; Components: core; Flags: ignoreversion
Source: "{#RepoRoot}Bpl\VittixReportDesign.dcp"; DestDir: "{app}\Bpl"; Components: core; Flags: ignoreversion

; --- standalone designer -------------------------------------------------------
; Installed under vittixdesigner\ so the IDE component editor's documented
; fallback (..\vittixdesigner\VittixDesigner.exe relative to the BPL) resolves.
Source: "{#RepoRoot}vittixdesigner\VittixDesigner.exe"; DestDir: "{app}\vittixdesigner"; Components: core; Flags: ignoreversion
Source: "{#RepoRoot}vittixdesigner\Win64\VittixDesigner.exe"; DestDir: "{app}\vittixdesigner\Win64"; Components: core; Flags: ignoreversion

; --- demo application ----------------------------------------------------------
Source: "{#RepoRoot}demo\VittixReportDemo.exe"; DestDir: "{app}\demo"; Components: demo; Flags: ignoreversion
Source: "{#RepoRoot}demo\*.pas"; DestDir: "{app}\demo"; Components: demo; Flags: ignoreversion
Source: "{#RepoRoot}demo\*.dfm"; DestDir: "{app}\demo"; Components: demo; Flags: ignoreversion
Source: "{#RepoRoot}demo\*.dpr"; DestDir: "{app}\demo"; Components: demo; Flags: ignoreversion
Source: "{#RepoRoot}demo\*.dproj"; DestDir: "{app}\demo"; Components: demo; Flags: ignoreversion
Source: "{#RepoRoot}demo\*.res"; DestDir: "{app}\demo"; Components: demo; Flags: ignoreversion
Source: "{#RepoRoot}demo\README.md"; DestDir: "{app}\demo"; Components: demo; Flags: ignoreversion
Source: "{#RepoRoot}demo\db\vittixreportdemodb.db"; DestDir: "{app}\demo\db"; Components: demo; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#RepoRoot}demo\db\vittix_demo_sqlite.sql"; DestDir: "{app}\demo\db"; Components: demo; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#RepoRoot}demo\db\northwind.db"; DestDir: "{app}\demo\db"; Components: demo; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#RepoRoot}demo\vrt\*.vrt"; DestDir: "{app}\demo\vrt"; Components: demo; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#RepoRoot}demo\vrt\README.md"; DestDir: "{app}\demo\vrt"; Components: demo; Flags: ignoreversion

[Icons]
Name: "{group}\Vittix Report Designer"; Filename: "{app}\vittixdesigner\VittixDesigner.exe"; WorkingDir: "{app}\vittixdesigner"; Comment: "Standalone visual report designer for .vrt reports"
Name: "{group}\Vittix Report Demo"; Filename: "{app}\demo\VittixReportDemo.exe"; WorkingDir: "{app}\demo"; Components: demo; Comment: "Sample-browser style demo: preview, design and export the bundled reports"
Name: "{group}\Sample Reports"; Filename: "{app}\demo\vrt"; Components: demo; Comment: "Sample .vrt report files used by the demo"
Name: "{group}\User Manual"; Filename: "{app}\USER_MANUAL.md"; Comment: "VittixReport user manual"
Name: "{group}\Installation Folder"; Filename: "{app}"
Name: "{group}\Uninstall VittixReport"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Vittix Report Designer"; Filename: "{app}\vittixdesigner\VittixDesigner.exe"; WorkingDir: "{app}\vittixdesigner"; Tasks: desktopicon

[Run]
Filename: "{app}\vittixdesigner\VittixDesigner.exe"; Description: "Launch Vittix Report Designer"; Flags: postinstall nowait skipifsilent unchecked

[Code]
function ORead(const Key, Name: string; var Value: string): Boolean;
begin
  Value := '';
  Result := RegValueExists(HKCU, Key, Name);
  if Result then
    if not RegQueryStringValue(HKCU, Key, Name, Value) then
      RaiseException('Cannot read registry string safely: ' + Key + '\' + Name);
end;

function OReadMachine(const Key, Name: string; var Value: string): Boolean;
begin
  Value := '';
  Result := RegValueExists(HKLM, Key, Name);
  if Result then
    if not RegQueryStringValue(HKLM, Key, Name, Value) then
      RaiseException('Cannot read machine registry string safely: ' + Key + '\' + Name);
end;

function OWrite(const Key, Name, Value: string): Boolean;
begin
  Result := RegWriteStringValue(HKCU, Key, Name, Value);
end;

function ODelete(const Key, Name: string): Boolean;
begin
  Result := not RegValueExists(HKCU, Key, Name);
  if not Result then Result := RegDeleteValue(HKCU, Key, Name);
end;

procedure OLog(const Message: string);
begin
  Log(Message);
end;

#include "IdeOwnership.inc"
#include "InstallerSecurity.inc"

function HasDirCommandLineOverride: Boolean;
var
  I: Integer;
  Argument: string;
begin
  Result := False;
  for I := 1 to ParamCount do
  begin
    Argument := ParamStr(I);
    if (CompareText(Argument, '/DIR') = 0) or
       (CompareText(Argument, '-DIR') = 0) or
       (CompareText(Copy(Argument, 1, 5), '/DIR=') = 0) or
       (CompareText(Copy(Argument, 1, 5), '-DIR=') = 0) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function InitializeSetup: Boolean;
begin
  { No application path constant is expanded before wizard initialization. }
  Result := not HasDirCommandLineOverride;
  if not Result then
    SuppressibleMsgBox('The /DIR override is not supported. VittixReport must ' +
      'use the fixed Program Files location.', mbError, MB_OK, IDOK);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  SelectedDir, SecurityError: string;
begin
  Result := '';
  SelectedDir := ExpandFileName(ExpandConstant('{app}'));
  if not IsExpectedInstallPath(SelectedDir) then
    Result := 'An existing VittixReport installation uses an unsupported ' +
      'directory. Setup stopped without migrating or overwriting it.'
  else if not ValidateInstallLocation(SelectedDir, False, SecurityError) then
    Result := SecurityError;
end;

function BdsVersion(Index: Integer): string;
begin
  if Index = 0 then Result := '23.0' else Result := '24.0';
end;

function BdsInstalled(const Version: string): Boolean;
begin
  Result := RegKeyExists(HKCU, 'Software\Embarcadero\BDS\' + Version) or
    RegKeyExists(HKLM, 'Software\Embarcadero\BDS\' + Version);
end;

function DelphiInstalled: Boolean;
begin
  Result := BdsInstalled('23.0') or BdsInstalled('24.0');
end;

procedure SetOwnershipRoot;
begin
  { Stable across upgrade/reinstall; distinct for separate install directories.
    Keep the legacy state untouched: it cannot prove individual ownership. }
  OwnershipRoot := 'Software\VittixReport\Installer\OwnedV2\' +
    GetSHA256OfString(PathIdentity(ExpandConstant('{app}')));
end;

procedure IntegrateIDE;
var
  I: Integer;
  Version, AppDir, Legacy: string;
begin
  AppDir := AddBackslash(ExpandConstant('{app}'));
  for I := 0 to 1 do
  begin
    Version := BdsVersion(I);
    if not BdsInstalled(Version) then Continue;
    if ORead('Software\VittixReport\Installer\' + Version + '\Win32', 'Original', Legacy) then
      Log('Legacy snapshot found: ambiguous pre-existing paths are preserved, never restored or claimed.');
    IntegrateVersion(Version, AppDir);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  SecurityError: string;
begin
  if CurStep = ssInstall then
  begin
    if not ValidateInstallLocation(ExpandConstant('{app}'), False, SecurityError) then
      RaiseException('Unsafe VittixReport installation location: ' + SecurityError);
    if WizardIsTaskSelected('idesetup') then
    begin
      SetOwnershipRoot;
      BeginOwnershipTransaction;
    end;
  end;
  if (CurStep = ssPostInstall) and WizardIsTaskSelected('idesetup') then
  begin
    if not ValidateInstallLocation(ExpandConstant('{app}'), True, SecurityError) then
      RaiseException('Delphi package registration refused: ' + SecurityError);
    IntegrateIDE;
  end;
  if CurStep = ssDone then EndOwnershipTransaction;
end;

procedure DeinitializeSetup;
begin
  if OwnershipJournal <> nil then
  begin
    if not RollbackOwnership then
      Log('ERROR: IDE rollback incomplete. Retained ownership records require recovery.');
    EndOwnershipTransaction;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  I: Integer;
  Version, AppDir: string;
begin
  if CurUninstallStep <> usUninstall then Exit;
  SetOwnershipRoot;
  AppDir := AddBackslash(ExpandConstant('{app}'));
  BeginOwnershipTransaction;
  try
    for I := 0 to 1 do
    begin
      Version := BdsVersion(I);
      RemoveOwnedPath(Version, 'Win32', 'source', AppDir + 'source');
      RemoveOwnedPath(Version, 'Win32', 'Bpl', AppDir + 'Bpl');
      RemoveOwnedPath(Version, 'Win64', 'source', AppDir + 'source');
    end;
    RemoveOwnedPackage(AppDir + 'Bpl\VittixReportDesign.bpl');
  except
    if not RollbackOwnership then Log('ERROR: IDE uninstall rollback incomplete.');
    EndOwnershipTransaction;
    RaiseException('IDE cleanup failed; uninstall stopped. See uninstall log.');
  end;
  EndOwnershipTransaction;
end;

#call SaveToFile(ExtractFilePath(RemoveBackslashUnlessRoot(SourcePath)) + "build\release-audit\preprocessed.iss")
