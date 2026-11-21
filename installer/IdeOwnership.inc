{ Shared by Inno Setup and the Delphi in-memory regression harness.
  ORead/OWrite/ODelete/OReadMachine/OLog are the only registry boundary.
  No whole-key deletion. Legacy Original snapshots are NEVER restored. }
const
  OwnedPackageDescription = 'Vittix Report design-time package (palette page: Vittix Reporting)';
var
  OwnershipRoot: string;
  OwnershipJournal: TStringList;

function PathIdentity(S: string): string;
begin
  S := Trim(S);
  if (Length(S) >= 2) and (Copy(S, 1, 1) = '"') and
     (Copy(S, Length(S), 1) = '"') then
    S := Copy(S, 2, Length(S) - 2);
  while (Length(S) > 3) and (Copy(S, Length(S), 1) = '\') do
    Delete(S, Length(S), 1);
  Result := Lowercase(S);
end;

function HasPath(const Paths, Token: string): Boolean;
var
  Start, I: Integer;
  Quoted: Boolean;
begin
  Result := False;
  Quoted := False;
  Start := 1;
  for I := 1 to Length(Paths) + 1 do
  begin
    if Copy(Paths, I, 1) = '"' then Quoted := not Quoted;
    if (I > Length(Paths)) or ((Copy(Paths, I, 1) = ';') and (not Quoted)) then
    begin
      if PathIdentity(Copy(Paths, Start, I - Start)) = PathIdentity(Token) then
        Result := True;
      Start := I + 1;
    end;
  end;
end;

function WithoutPath(const Paths, Token: string): string;
var
  Start, I: Integer;
  Part: string;
  HavePart, Removed, Quoted: Boolean;
begin
  Result := '';
  HavePart := False;
  Removed := False;
  Quoted := False;
  Start := 1;
  for I := 1 to Length(Paths) + 1 do
  begin
    if Copy(Paths, I, 1) = '"' then Quoted := not Quoted;
    if (I > Length(Paths)) or ((Copy(Paths, I, 1) = ';') and (not Quoted)) then
    begin
      Part := Copy(Paths, Start, I - Start);
      if (not Removed) and (PathIdentity(Part) = PathIdentity(Token)) then
        Removed := True
      else
      begin
        if HavePart then Result := Result + ';';
        Result := Result + Part;
        HavePart := True;
      end;
      Start := I + 1;
    end;
  end;
end;

function BalancedPathQuotes(const Paths: string): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 1 to Length(Paths) do
    if Copy(Paths, I, 1) = '"' then Result := not Result;
end;

function LibraryKey(const Version, Platform: string): string;
begin
  Result := 'Software\Embarcadero\BDS\' + Version + '\Library\' + Platform;
end;

function PathOwnerKey(const Version, Platform: string): string;
begin
  Result := OwnershipRoot + '\Paths\' + Version + '\' + Platform;
end;

procedure BeginOwnershipTransaction;
begin
  OwnershipJournal := TStringList.Create;
end;

procedure ChangeValue(const Key, Name: string; Exists: Boolean;
  const Value, AddedToken: string);
var
  BeforeValue: string;
  BeforeExists, OK: Boolean;
begin
  BeforeExists := ORead(Key, Name, BeforeValue);
  if (BeforeExists = Exists) and ((not Exists) or (BeforeValue = Value)) then Exit;
  { Journal before attempting mutation: write failure can be injected safely. }
  OwnershipJournal.Add(Key);
  OwnershipJournal.Add(Name);
  if BeforeExists then OwnershipJournal.Add('1') else OwnershipJournal.Add('0');
  OwnershipJournal.Add(BeforeValue);
  if Exists then OwnershipJournal.Add('1') else OwnershipJournal.Add('0');
  OwnershipJournal.Add(Value);
  OwnershipJournal.Add(AddedToken);
  if Exists then OK := OWrite(Key, Name, Value) else OK := ODelete(Key, Name);
  if not OK then RaiseException('Cannot update installer-managed registry value: ' + Key + '\' + Name);
end;

function RollbackOwnership: Boolean;
var
  I: Integer;
  Current, Reduced: string;
  Exists, ExpectedExists, OK: Boolean;
begin
  Result := True;
  if OwnershipJournal = nil then Exit;
  I := OwnershipJournal.Count - 7;
  while I >= 0 do
  begin
    Exists := ORead(OwnershipJournal[I], OwnershipJournal[I+1], Current);
    ExpectedExists := OwnershipJournal[I+4] = '1';
    OK := True;
    if (Exists = ExpectedExists) and
       ((not Exists) or (Current = OwnershipJournal[I+5])) then
    begin
      if OwnershipJournal[I+2] = '1' then
        OK := OWrite(OwnershipJournal[I], OwnershipJournal[I+1], OwnershipJournal[I+3])
      else
        OK := ODelete(OwnershipJournal[I], OwnershipJournal[I+1]);
    end
    else if Exists and (OwnershipJournal[I+6] <> '') then
    begin
      { Concurrent user additions/reordering: remove just our inserted token. }
      Reduced := WithoutPath(Current, OwnershipJournal[I+6]);
      if Reduced <> Current then
        OK := OWrite(OwnershipJournal[I], OwnershipJournal[I+1], Reduced);
    end;
    if not OK then
    begin
      Result := False;
      OLog('Registry rollback failed; ownership record retained for recovery.');
      { Stop before undoing the earlier durable owner record. }
      Exit;
    end;
    I := I - 7;
  end;
end;

procedure EndOwnershipTransaction;
begin
  if OwnershipJournal <> nil then OwnershipJournal.Free;
  OwnershipJournal := nil;
end;

procedure AddOwnedPath(const Version, Platform, Slot, Token: string);
var
  Key, State, Current, Owned, ListToken: string;
begin
  Key := LibraryKey(Version, Platform);
  State := PathOwnerKey(Version, Platform);
  if not ORead(Key, 'Search Path', Current) then
    if not OReadMachine(Key, 'Search Path', Current) then Current := '';
  if not BalancedPathQuotes(Current) then
    RaiseException('Unbalanced quotes in IDE Search Path; preserving existing settings: ' + Key);
  if HasPath(Current, Token) then
  begin
    { Existing entries are not claimed. Reinstall retains prior ownership. }
    if not ORead(State, Slot, Owned) then
      OLog('Preserving pre-existing/unproven path without claiming ownership: ' + Token);
    Exit;
  end;
  { A manually removed owned path is not reintroduced on reinstall. }
  if ORead(State, Slot, Owned) then Exit;
  ChangeValue(State, Slot, True, Token, '');
  ListToken := Token;
  if Pos(';', Token) > 0 then ListToken := '"' + Token + '"';
  if Current = '' then Current := ListToken else Current := Current + ';' + ListToken;
  ChangeValue(Key, 'Search Path', True, Current, Token);
end;

procedure RemoveOwnedPath(const Version, Platform, Slot, ExpectedToken: string);
var
  Key, State, Current, Owned, Reduced: string;
begin
  Key := LibraryKey(Version, Platform);
  State := PathOwnerKey(Version, Platform);
  if not ORead(State, Slot, Owned) then Exit;
  { Do not trust a redirected/malformed ownership record. }
  if Owned <> ExpectedToken then
  begin
    OLog('Preserving unexpected path ownership record: ' + State);
    Exit;
  end;
  if ORead(Key, 'Search Path', Current) then
  begin
    Reduced := WithoutPath(Current, Owned);
    if Reduced <> Current then
      ChangeValue(Key, 'Search Path', True, Reduced, '');
  end;
  ChangeValue(State, Slot, False, '', '');
end;

procedure AddOwnedPackage(const PackagePath: string);
var
  Key, Current, Owned: string;
begin
  Key := 'Software\Embarcadero\BDS\23.0\Known Packages';
  { Preserve any existing registration, including a non-owned identical one. }
  if ORead(Key, PackagePath, Current) then Exit;
  { Do not reintroduce a registration manually removed after our install. }
  if ORead(OwnershipRoot, 'Package', Owned) then Exit;
  ChangeValue(OwnershipRoot, 'Package', True, OwnedPackageDescription, '');
  ChangeValue(Key, PackagePath, True, OwnedPackageDescription, '');
end;

procedure RemoveOwnedPackage(const PackagePath: string);
var
  Key, Current, Owned: string;
begin
  Key := 'Software\Embarcadero\BDS\23.0\Known Packages';
  if not ORead(OwnershipRoot, 'Package', Owned) then Exit;
  if Owned <> OwnedPackageDescription then Exit;
  if ORead(Key, PackagePath, Current) then
    if Current = Owned then ChangeValue(Key, PackagePath, False, '', '');
  ChangeValue(OwnershipRoot, 'Package', False, '', '');
end;

procedure IntegrateVersion(const Version, AppDir: string);
begin
  AddOwnedPath(Version, 'Win32', 'source', AppDir + 'source');
  { Delphi 12 DCP/BPL must never enter Delphi 13's compiler search path. }
  if Version = '23.0' then
    AddOwnedPath(Version, 'Win32', 'Bpl', AppDir + 'Bpl');
  AddOwnedPath(Version, 'Win64', 'source', AppDir + 'source');
  if Version = '23.0' then
    AddOwnedPackage(AppDir + 'Bpl\VittixReportDesign.bpl');
end;
