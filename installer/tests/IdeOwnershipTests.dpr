program IdeOwnershipTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes;
var
  UserData, MachineData: TStringList;
  Mutations, FailAt, Passed: Integer;
  AddConcurrentOnFailure: Boolean;

function ID(const Key, Name: string): string;
begin Result := LowerCase(Key + #9 + Name); end;

function ReadStore(Store: TStringList; const Key, Name: string; var Value: string): Boolean;
var I: Integer;
begin
  I := Store.IndexOfName(ID(Key, Name));
  Result := I >= 0;
  Value := '';
  if Result then Value := Store.ValueFromIndex[I];
end;

function ORead(const Key, Name: string; var Value: string): Boolean;
begin Result := ReadStore(UserData, Key, Name, Value); end;
function OReadMachine(const Key, Name: string; var Value: string): Boolean;
begin Result := ReadStore(MachineData, Key, Name, Value); end;

procedure Put(const Key, Name, Value: string);
var I: Integer;
begin
  I := UserData.IndexOfName(ID(Key, Name));
  if I >= 0 then UserData[I] := ID(Key, Name) + '=' + Value
  else UserData.Add(ID(Key, Name) + '=' + Value);
end;

function CanMutate: Boolean;
var V: string;
begin
  Inc(Mutations);
  Result := Mutations <> FailAt;
  if not Result and AddConcurrentOnFailure then
  begin
    ORead('Software\Embarcadero\BDS\23.0\Library\Win32', 'Search Path', V);
    Put('Software\Embarcadero\BDS\23.0\Library\Win32', 'Search Path', V + ';D:\UserLater');
  end;
end;

function OWrite(const Key, Name, Value: string): Boolean;
begin Result := CanMutate; if Result then Put(Key, Name, Value); end;
function ODelete(const Key, Name: string): Boolean;
var I: Integer;
begin
  Result := CanMutate;
  if Result then
  begin
    I := UserData.IndexOfName(ID(Key, Name));
    if I >= 0 then UserData.Delete(I);
  end;
end;
procedure OLog(const Message: string);
begin { Fixture logging has no registry/file side effects. } end;
procedure RaiseException(const Message: string);
begin raise Exception.Create(Message); end;

{$I ..\IdeOwnership.inc}

const
  Src = 'C:\Program Files (x86)\VittixReport\source';
  Bpl = 'C:\Program Files (x86)\VittixReport\Bpl';
  Pkg = 'C:\Program Files (x86)\VittixReport\Bpl\VittixReportDesign.bpl';
  Known = 'Software\Embarcadero\BDS\23.0\Known Packages';

procedure Check(Condition: Boolean; const Message: string);
begin if not Condition then raise Exception.Create(Message); end;
function GetPath(const Version: string = '23.0'; const Platform: string = 'Win32'): string;
begin ORead(LibraryKey(Version, Platform), 'Search Path', Result); end;
procedure Reset;
begin
  EndOwnershipTransaction;
  UserData.Clear; MachineData.Clear; Mutations := 0; FailAt := 0;
  AddConcurrentOnFailure := False;
  OwnershipRoot := 'Fixture\OwnedV2\InstallA';
end;
procedure Install;
begin
  AddOwnedPath('23.0', 'Win32', 'source', Src);
  AddOwnedPath('23.0', 'Win32', 'Bpl', Bpl);
  AddOwnedPackage(Pkg);
end;
procedure Uninstall;
begin
  RemoveOwnedPath('23.0', 'Win32', 'source', Src);
  RemoveOwnedPath('23.0', 'Win32', 'Bpl', Bpl);
  RemoveOwnedPackage(Pkg);
end;
procedure Pass(const Name: string);
begin Inc(Passed); Writeln('PASS ', Name); end;

procedure Run;
var
  V, Snapshot, OwnerA: string;
  N, TotalWrites: Integer;
  Failed: Boolean;
begin
  Reset; BeginOwnershipTransaction; Install;
  Check(GetPath = Src + ';' + Bpl, 'clean registration');
  EndOwnershipTransaction; Pass('clean registration');

  Reset; Put(LibraryKey('23.0','Win32'), 'Search Path', ' Z:\First ;Y:\Second;');
  BeginOwnershipTransaction; Install; Uninstall;
  Check(GetPath = ' Z:\First ;Y:\Second;', 'existing path bytes/order');
  EndOwnershipTransaction; Pass('existing path preservation');

  Reset; BeginOwnershipTransaction; Install; Install;
  Check(GetPath = Src + ';' + Bpl, 'duplicate reinstall');
  Uninstall; Check(GetPath = '', 'reinstall ownership retained');
  EndOwnershipTransaction; Pass('duplicate prevention and reinstall uninstall');

  Reset; BeginOwnershipTransaction; Install; EndOwnershipTransaction;
  Put(LibraryKey('23.0','Win32'),'Search Path', GetPath + ';D:\UserLater');
  BeginOwnershipTransaction; Uninstall;
  Check(GetPath = 'D:\UserLater', 'later user path lost');
  EndOwnershipTransaction; Pass('user-added path survives uninstall');

  Reset; BeginOwnershipTransaction; Install; EndOwnershipTransaction;
  Put(LibraryKey('23.0','Win32'),'Search Path', GetPath + ';' + Src);
  BeginOwnershipTransaction; Uninstall;
  Check(GetPath = Src, 'uninstall removed independently added duplicate');
  EndOwnershipTransaction; Pass('remove only one owned occurrence of a duplicated user path');

  Reset; BeginOwnershipTransaction; Install; EndOwnershipTransaction;
  Put(LibraryKey('23.0','Win32'),'Search Path', 'D:\UserOnly');
  BeginOwnershipTransaction; Install;
  Check(GetPath = 'D:\UserOnly', 'reinstall restored manually removed paths');
  Uninstall; Check(GetPath = 'D:\UserOnly', 'uninstall restored removed entry');
  EndOwnershipTransaction; Pass('manual removal survives reinstall and uninstall');

  Reset; Put(LibraryKey('23.0','Win32'),'Search Path','X:\One;Y:\Two');
  BeginOwnershipTransaction; Install; EndOwnershipTransaction;
  Put(LibraryKey('23.0','Win32'),'Search Path',' Y:\Two ;' + Bpl + ';X:\One;' + Src);
  BeginOwnershipTransaction; Uninstall;
  Check(GetPath = ' Y:\Two ;X:\One', 'user reordering changed');
  EndOwnershipTransaction; Pass('user reorder and whitespace preservation');

  Reset; Put(Known, Pkg, 'Other owner'); Put(Known,'D:\Other.bpl','Other package');
  BeginOwnershipTransaction; Install; Uninstall;
  Check(ORead(Known, Pkg, V) and (V='Other owner'), 'preexisting package lost');
  Check(ORead(Known,'D:\Other.bpl',V), 'unrelated package lost');
  EndOwnershipTransaction; Pass('pre-existing Known Packages retained');

  Reset; BeginOwnershipTransaction; Install; EndOwnershipTransaction;
  Put(Known, Pkg, 'User replacement');
  BeginOwnershipTransaction; Install; Uninstall;
  Check(ORead(Known,Pkg,V) and (V='User replacement'), 'modified package lost');
  EndOwnershipTransaction; Pass('modified Known Packages retained');

  Reset; Put(Known,Pkg,OwnedPackageDescription);
  BeginOwnershipTransaction; Install; Uninstall;
  Check(ORead(Known,Pkg,V), 'identical non-owned package claimed');
  EndOwnershipTransaction; Pass('identical non-owned registration preserved');

  Reset; BeginOwnershipTransaction; Install; Uninstall;
  Check(not ORead(Known,Pkg,V), 'owned package not removed');
  EndOwnershipTransaction; Pass('owned package removed');

  Reset; Put(LibraryKey('23.0','Win32'),'Search Path',Src + ';' + Bpl);
  Put('Software\VittixReport\Installer\23.0\Win32','Original','X:\Legacy;' + Src);
  BeginOwnershipTransaction; Install; Uninstall;
  Check(GetPath = Src + ';' + Bpl, 'legacy snapshot restored/ownership guessed');
  EndOwnershipTransaction; Pass('legacy upgrade preserves ambiguous existing entries');

  Reset; BeginOwnershipTransaction; Install; EndOwnershipTransaction;
  BeginOwnershipTransaction; Install; EndOwnershipTransaction;
  BeginOwnershipTransaction; Uninstall; EndOwnershipTransaction;
  Check(GetPath='', 'v2 ownership lost on upgrade'); Pass('ownership-aware upgrade');

  Reset; MachineData.Values[ID(LibraryKey('23.0','Win32'),'Search Path')] := 'M:\Inherited';
  BeginOwnershipTransaction; Install; Uninstall;
  Check(GetPath='M:\Inherited','HKLM effective path lost');
  Check(MachineData.Count=1,'machine registry changed');
  EndOwnershipTransaction; Pass('HKLM inheritance preserved without HKLM writes');

  Reset; BeginOwnershipTransaction;
  AddOwnedPath('23.0','Win32','source',Src);
  AddOwnedPath('24.0','Win32','source',Src);
  AddOwnedPath('23.0','Win64','source',Src);
  RemoveOwnedPath('23.0','Win32','source',Src);
  Check(GetPath('24.0')=Src,'second IDE lost');
  Check(GetPath('23.0','Win64')=Src,'second platform lost');
  EndOwnershipTransaction; Pass('multiple IDE versions/platforms isolated');

  Reset; BeginOwnershipTransaction;
  IntegrateVersion('24.0', 'C:\Delphi13Install\');
  Check(GetPath('24.0')='C:\Delphi13Install\source','Delphi 12 binaries leaked into Delphi 13 search path');
  Check(not ORead(Known,'C:\Delphi13Install\Bpl\VittixReportDesign.bpl',V),'Delphi 12 package registered into unsupported IDE');
  IntegrateVersion('23.0','C:\Delphi12Install\');
  Check(HasPath(GetPath,'C:\Delphi12Install\Bpl'),'Delphi 12 Bpl missing');
  Check(ORead(Known,'C:\Delphi12Install\Bpl\VittixReportDesign.bpl',V),'Delphi 12 package missing');
  EndOwnershipTransaction; Pass('version dispatcher excludes Delphi 12 binaries from Delphi 13');

  Reset; BeginOwnershipTransaction; Install; EndOwnershipTransaction;
  OwnerA := OwnershipRoot; OwnershipRoot := 'Fixture\OwnedV2\InstallB';
  BeginOwnershipTransaction;
  AddOwnedPath('23.0','Win32','source','D:\InstallB\source');
  RemoveOwnedPath('23.0','Win32','source','D:\InstallB\source');
  Check(GetPath=Src+';'+Bpl,'separate installation ownership collision');
  EndOwnershipTransaction; OwnershipRoot := OwnerA;
  Pass('multiple installation directories isolated');

  Reset; BeginOwnershipTransaction; Install;
  TotalWrites := Mutations; EndOwnershipTransaction;
  for N := 1 to TotalWrites do
  begin
    Reset; Put(LibraryKey('23.0','Win32'),'Search Path','X:\Original');
    Put(Known,'D:\Other.bpl','Original');
    Snapshot := UserData.Text;
    BeginOwnershipTransaction; FailAt := N; Failed := False;
    try Install; except Failed := True; end;
    Check(Failed,'failure not injected');
    Check(RollbackOwnership,'rollback writes failed');
    { Registry ordering is not meaningful. }
    UserData.Sort;
    with TStringList.Create do
    try Text := Snapshot; Sort; Check(UserData.Text=Text,'partial rollback mismatch at '+IntToStr(N));
    finally Free; end;
    EndOwnershipTransaction;
  end;
  Pass('partial install rollback at every write boundary ('+IntToStr(TotalWrites)+')');

  for N := 1 to 6 do
  begin
    Reset; BeginOwnershipTransaction; Install; EndOwnershipTransaction;
    Put(LibraryKey('23.0','Win32'),'Search Path', GetPath + ';D:\UserLater');
    UserData.Sort; Snapshot := UserData.Text;
    Mutations := 0; FailAt := N; BeginOwnershipTransaction; Failed := False;
    try Uninstall; except Failed := True; end;
    Check(Failed,'uninstall failure not injected');
    Check(RollbackOwnership,'uninstall rollback failed');
    UserData.Sort; Check(UserData.Text=Snapshot,'uninstall rollback mismatch');
    EndOwnershipTransaction;
  end;
  Pass('partial uninstall rollback at every write boundary (6)');

  Reset; Put(LibraryKey('23.0','Win32'),'Search Path','X:\Original');
  BeginOwnershipTransaction; FailAt := 4; AddConcurrentOnFailure := True;
  try Install; except end;
  Check(RollbackOwnership,'concurrent rollback failed');
  Check(GetPath='X:\Original;D:\UserLater','rollback clobbered concurrent edit');
  EndOwnershipTransaction; Pass('rollback preserves concurrent user addition');

  Reset; BeginOwnershipTransaction; Install;
  Put(Known,Pkg,'User changed during install');
  Check(RollbackOwnership,'rollback with changed package failed');
  Check(ORead(Known,Pkg,V) and (V='User changed during install'),'rollback overwrote user package');
  EndOwnershipTransaction; Pass('rollback preserves changed package registration');

  Reset; BeginOwnershipTransaction; FailAt := 4;
  try Install; except end;
  FailAt := Mutations + 1;
  Check(not RollbackOwnership,'rollback failure not reported');
  Check(ORead(PathOwnerKey('23.0','Win32'),'source',V),'ownership lost after rollback write failure');
  FailAt := 0;
  Check(RollbackOwnership,'retry recovery failed');
  EndOwnershipTransaction; Pass('rollback write failure retains ownership for recovery');

  Reset; BeginOwnershipTransaction; Install; EndOwnershipTransaction;
  Put(PathOwnerKey('23.0','Win32'),'source','D:\Unrelated');
  BeginOwnershipTransaction; Uninstall;
  Check(HasPath(GetPath,Src),'tampered owner record trusted');
  EndOwnershipTransaction; Pass('unexpected ownership token does not redirect cleanup');

  Check(HasPath('"'+UpperCase(Src)+'\"',Src),'normalized duplicate comparison');
  Check(WithoutPath('A;;'+Src+'; B ;','C:\Absent')='A;;'+Src+'; B ;','empty segments changed');
  Pass('quoted/case/trailing slash comparison and empty segments');

  Reset; Put(LibraryKey('23.0','Win32'),'Search Path','"D:\Semi;' + Src + ';Colon";X:\Other');
  BeginOwnershipTransaction; Install; Uninstall;
  Check(GetPath='"D:\Semi;' + Src + ';Colon";X:\Other','quoted semicolon path was split/corrupted');
  EndOwnershipTransaction; Pass('quoted semicolon directory remains byte-for-byte intact');

  Reset; Put(LibraryKey('23.0','Win32'),'Search Path','"D:\Unbalanced');
  Snapshot := UserData.Text;
  BeginOwnershipTransaction; Failed := False;
  try Install; except Failed := True; end;
  Check(Failed and (UserData.Text=Snapshot),'malformed quoted path was changed');
  EndOwnershipTransaction; Pass('malformed quoted path fails without mutation');

  Reset; BeginOwnershipTransaction;
  IntegrateVersion('23.0','D:\Custom;Install\');
  Check(GetPath='"D:\Custom;Install\source";"D:\Custom;Install\Bpl"','custom semicolon install directory not quoted');
  RemoveOwnedPath('23.0','Win32','source','D:\Custom;Install\source');
  RemoveOwnedPath('23.0','Win32','Bpl','D:\Custom;Install\Bpl');
  Check(GetPath='','custom semicolon install path cleanup failed');
  EndOwnershipTransaction; Pass('custom install directory containing semicolon is quoted and removable');
end;

begin
  UserData := TStringList.Create; MachineData := TStringList.Create;
  try
    try Run; Writeln('RESULT: ',Passed,' scenarios PASS; failures 0; no live registry access');
    except on E: Exception do begin Writeln('FAIL: ',E.Message); ExitCode := 1; end; end;
  finally EndOwnershipTransaction; MachineData.Free; UserData.Free; end;
end.
