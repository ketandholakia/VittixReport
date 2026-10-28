{ Windows ACL and reparse-point checks shared by Setup and the NTFS probe. }
const
  INVALID_FILE_ATTRIBUTES = $FFFFFFFF;
  ERROR_FILE_NOT_FOUND = 2;
  ERROR_PATH_NOT_FOUND = 3;
  ERROR_INSUFFICIENT_BUFFER = 122;
  SE_FILE_OBJECT = 1;
  DACL_SECURITY_INFORMATION = $00000004;
  OWNER_SECURITY_INFORMATION = $00000001;
  GROUP_SECURITY_INFORMATION = $00000002;
  TOKEN_DUPLICATE = $00000002;
  TOKEN_IMPERSONATE = $00000004;
  TOKEN_QUERY = $00000008;
  TOKEN_ADJUST_DEFAULT = $00000080;
  DISABLE_MAX_PRIVILEGE = $00000001;
  SECURITY_IMPERSONATION = 2;
  TOKEN_IMPERSONATION = 2;
  FILE_WRITE_DATA = $00000002;
  FILE_APPEND_DATA = $00000004;
  FILE_WRITE_EA = $00000010;
  FILE_DELETE_CHILD = $00000040;
  FILE_WRITE_ATTRIBUTES = $00000100;
  DELETE_ACCESS = $00010000;
  WRITE_DAC_ACCESS = $00040000;
  WRITE_OWNER_ACCESS = $00080000;

type
  TSidIdentifierAuthority = record
    Value0, Value1, Value2, Value3, Value4, Value5: Byte;
  end;
  TSidAndAttributes = record
    Sid: Longint;
    Attributes: Cardinal;
  end;
  TTokenUserBuffer = record
    User: TSidAndAttributes;
    SidBytes: array[0..67] of Byte;
  end;
  TTokenOwner = record
    Sid: Longint;
  end;
  TGenericMapping = record
    GenericRead: Cardinal;
    GenericWrite: Cardinal;
    GenericExecute: Cardinal;
    GenericAll: Cardinal;
  end;

function GetFileAttributesW(FileName: string): Cardinal;
  external 'GetFileAttributesW@kernel32.dll stdcall';
function GetCurrentProcess: Integer;
  external 'GetCurrentProcess@kernel32.dll stdcall';
function OpenProcessToken(ProcessHandle: Integer; DesiredAccess: Cardinal;
  var TokenHandle: Integer): Boolean;
  external 'OpenProcessToken@advapi32.dll stdcall';
function AllocateAndInitializeSid(var IdentifierAuthority: TSidIdentifierAuthority;
  SubAuthorityCount: Byte; SubAuthority0, SubAuthority1, SubAuthority2,
  SubAuthority3, SubAuthority4, SubAuthority5, SubAuthority6,
  SubAuthority7: Cardinal; var Sid: Longint): Boolean;
  external 'AllocateAndInitializeSid@advapi32.dll stdcall';
function FreeSid(Sid: Longint): Longint;
  external 'FreeSid@advapi32.dll stdcall';
function IsValidSid(Sid: Longint): Boolean;
  external 'IsValidSid@advapi32.dll stdcall';
function CreateRestrictedToken(ExistingToken: Integer; Flags: Cardinal;
  DisableSidCount: Cardinal; var SidsToDisable: TSidAndAttributes;
  DeletePrivilegeCount: Cardinal; PrivilegesToDelete: Longint;
  RestrictedSidCount: Cardinal; SidsToRestrict: Longint;
  var NewToken: Integer): Boolean;
  external 'CreateRestrictedToken@advapi32.dll stdcall';
function GetTokenInformation(TokenHandle: Integer; TokenInformationClass: Cardinal;
  var TokenInformation: TSidAndAttributes; TokenInformationLength: Cardinal;
  var ReturnLength: Cardinal): Boolean;
  external 'GetTokenInformation@advapi32.dll stdcall';
function SetTokenInformation(TokenHandle: Integer; TokenInformationClass: Cardinal;
  var TokenInformation: TTokenOwner; TokenInformationLength: Cardinal): Boolean;
  external 'SetTokenInformation@advapi32.dll stdcall';
function DuplicateTokenEx(ExistingToken: Integer; DesiredAccess: Cardinal;
  TokenAttributes: Longint; ImpersonationLevel, TokenType: Integer;
  var NewToken: Integer): Boolean;
  external 'DuplicateTokenEx@advapi32.dll stdcall';
function GetNamedSecurityInfoW(ObjectName: string; ObjectType: Cardinal;
  SecurityInfo: Cardinal; var Owner, Group, Dacl, Sacl, SecurityDescriptor: Longint): Cardinal;
  external 'GetNamedSecurityInfoW@advapi32.dll stdcall';
function AccessCheck(SecurityDescriptor: Longint; ClientToken: Integer;
  DesiredAccess: Cardinal; var GenericMapping: TGenericMapping;
  var PrivilegeSet: Cardinal; var PrivilegeSetLength, GrantedAccess,
  AccessStatus: Cardinal): Boolean;
  external 'AccessCheck@advapi32.dll stdcall';
function LocalFree(Memory: Longint): Longint;
  external 'LocalFree@kernel32.dll stdcall';
function CloseHandle(Handle: Integer): Boolean;
  external 'CloseHandle@kernel32.dll stdcall';

function CanonicalPath(const Value: string): string;
begin
  Result := RemoveBackslashUnlessRoot(ExpandFileName(Value));
end;

function IsSamePath(const A, B: string): Boolean;
begin
  Result := CompareText(CanonicalPath(A), CanonicalPath(B)) = 0;
end;

function IsExpectedInstallPath(const Candidate: string): Boolean;
var
  Expected: string;
begin
  Expected := AddBackslash(CanonicalPath(ExpandConstant('{commonpf}'))) +
    'VittixReport';
  Result := IsSamePath(Candidate, Expected);
end;

function CreateStandardUserCheckToken(var CheckToken: Integer): Boolean;
var
  ProcessToken, RestrictedToken: Integer;
  AdminSid: Longint;
  AdminSidRecord, TokenUser: TSidAndAttributes;
  NtAuthority: TSidIdentifierAuthority;
  TokenOwner: TTokenOwner;
  RequiredTokenInfoLength, ReturnedTokenInfoLength: Cardinal;
  TokenUserBuffer: TTokenUserBuffer;
begin
  Result := False;
  CheckToken := 0;
  ProcessToken := 0;
  RestrictedToken := 0;
  AdminSid := 0;
  RequiredTokenInfoLength := 0;
  ReturnedTokenInfoLength := 0;
  NtAuthority.Value0 := 0; NtAuthority.Value1 := 0; NtAuthority.Value2 := 0;
  NtAuthority.Value3 := 0; NtAuthority.Value4 := 0; NtAuthority.Value5 := 5;
  TokenUser.Sid := 0;
  TokenUser.Attributes := 0;
  TokenOwner.Sid := 0;
  try
    if not AllocateAndInitializeSid(NtAuthority, 2, 32, 544,
      0, 0, 0, 0, 0, 0, AdminSid) then Exit;
    AdminSidRecord.Sid := AdminSid;
    AdminSidRecord.Attributes := 0;
    if not OpenProcessToken(GetCurrentProcess,
      TOKEN_DUPLICATE or TOKEN_QUERY or TOKEN_ADJUST_DEFAULT, ProcessToken) then Exit;
    { Disable only Administrators, preserving all ordinary user groups. }
    if not CreateRestrictedToken(ProcessToken, DISABLE_MAX_PRIVILEGE, 1,
      AdminSidRecord, 0, 0, 0, 0, RestrictedToken) then Exit;
    { Elevated tokens can default object ownership to Administrators. Use the
      logged-on user's SID so WRITE_DAC ownership checks match standard mode. }
    { TOKEN_USER is variable length: the fixed SID_AND_ATTRIBUTES structure
      contains a pointer to SID bytes that follow it in the returned buffer. }
    if GetTokenInformation(RestrictedToken, 1, TokenUserBuffer.User, 0,
      RequiredTokenInfoLength) then Exit;
    if (DLLGetLastError <> ERROR_INSUFFICIENT_BUFFER) or
       (RequiredTokenInfoLength < SizeOf(TokenUser)) or
       (RequiredTokenInfoLength > 65536) then Exit;
    if RequiredTokenInfoLength > SizeOf(TokenUserBuffer) then Exit;
    { A SID is at most 68 bytes. Keep the TOKEN_USER structure and the complete
      SID tail contiguous and alive until SetTokenInformation has copied it. }
    if not GetTokenInformation(RestrictedToken, 1, TokenUserBuffer.User,
      RequiredTokenInfoLength, ReturnedTokenInfoLength) then Exit;
    if (ReturnedTokenInfoLength < SizeOf(TokenUser)) or
       (ReturnedTokenInfoLength > RequiredTokenInfoLength) then Exit;
    TokenUser := TokenUserBuffer.User;
    if (TokenUser.Sid = 0) or not IsValidSid(TokenUser.Sid) then Exit;
    TokenOwner.Sid := TokenUser.Sid;
    if not SetTokenInformation(RestrictedToken, 4, TokenOwner,
      SizeOf(TokenOwner)) then Exit;
    if not DuplicateTokenEx(RestrictedToken, TOKEN_QUERY or TOKEN_IMPERSONATE,
      0, SECURITY_IMPERSONATION, TOKEN_IMPERSONATION, CheckToken) then Exit;
    Result := True;
  finally
    if RestrictedToken <> 0 then CloseHandle(RestrictedToken);
    if ProcessToken <> 0 then CloseHandle(ProcessToken);
    if AdminSid <> 0 then FreeSid(AdminSid);
  end;
end;

function StandardTokenHasAccess(const Path: string; IsDirectory,
  CheckChildCreation: Boolean; var ApiOK: Boolean): Boolean;
var
  Owner, Group, Dacl, Sacl, SecurityDescriptor: Longint;
  PrivilegeSet: array[0..255] of Cardinal;
  CheckToken: Integer;
  Rights: array[0..7] of Cardinal;
  RightsCount, I: Integer;
  Mapping: TGenericMapping;
  PrivilegeSetLength, GrantedAccess, AccessStatus: Cardinal;
begin
  Result := True;
  ApiOK := False;
  Owner := 0; Group := 0; Dacl := 0; Sacl := 0;
  SecurityDescriptor := 0; CheckToken := 0;
  { AccessCheck requires a descriptor with valid owner/group SIDs as well as
    the DACL. Request all three; DACL-only descriptors produced ERROR_INVALID_SECURITY_DESCR. }
  if GetNamedSecurityInfoW(Path, SE_FILE_OBJECT,
    DACL_SECURITY_INFORMATION or OWNER_SECURITY_INFORMATION or GROUP_SECURITY_INFORMATION,
    Owner, Group, Dacl, Sacl, SecurityDescriptor) <> 0 then Exit;
  try
    if (Owner = 0) or (Group = 0) or (Dacl = 0) or
       not IsValidSid(Owner) or not IsValidSid(Group) or
       not CreateStandardUserCheckToken(CheckToken) then Exit;
    Mapping.GenericRead := $00120089;
    Mapping.GenericWrite := $00120116;
    Mapping.GenericExecute := $001200A0;
    Mapping.GenericAll := $001F01FF;
    if IsDirectory then
    begin
      Rights[0] := DELETE_ACCESS;
      Rights[1] := WRITE_DAC_ACCESS;
      Rights[2] := WRITE_OWNER_ACCESS;
      Rights[3] := FILE_DELETE_CHILD;
      RightsCount := 4;
      if CheckChildCreation then
      begin
        Rights[4] := FILE_WRITE_DATA;
        Rights[5] := FILE_APPEND_DATA;
        Rights[6] := FILE_WRITE_EA;
        Rights[7] := FILE_WRITE_ATTRIBUTES;
        RightsCount := 8;
      end;
    end
    else
    begin
      Rights[0] := FILE_WRITE_DATA;
      Rights[1] := FILE_APPEND_DATA;
      Rights[2] := FILE_WRITE_EA;
      Rights[3] := FILE_WRITE_ATTRIBUTES;
      Rights[4] := DELETE_ACCESS;
      Rights[5] := WRITE_DAC_ACCESS;
      Rights[6] := WRITE_OWNER_ACCESS;
      RightsCount := 7;
    end;
    for I := 0 to RightsCount - 1 do
    begin
      PrivilegeSetLength := 1024;
      GrantedAccess := 0;
      AccessStatus := 0;
      if not AccessCheck(SecurityDescriptor, CheckToken, Rights[I], Mapping,
        PrivilegeSet[0], PrivilegeSetLength, GrantedAccess, AccessStatus) then Exit;
      if AccessStatus <> 0 then
      begin
        Result := True;
        ApiOK := True;
        Exit;
      end;
    end;
    Result := False;
    ApiOK := True;
  finally
    if CheckToken <> 0 then CloseHandle(CheckToken);
    if SecurityDescriptor <> 0 then LocalFree(SecurityDescriptor);
  end;
end;

function DirectoryIsProtected(const Path: string; IsInstallNode: Boolean;
  var Failure: string): Boolean;
var
  HasAccess, ApiOK: Boolean;
  Attributes: Cardinal;
begin
  Result := False;
  Attributes := GetFileAttributesW(Path);
  if Attributes = INVALID_FILE_ATTRIBUTES then
  begin
    Failure := 'Cannot inspect directory attributes: ' + Path;
    Exit;
  end;
  if (Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then
  begin
    Failure := 'Expected a directory: ' + Path;
    Exit;
  end;
  if (Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
  begin
    Failure := 'A junction or reparse point is not allowed: ' + Path;
    Exit;
  end;
  HasAccess := StandardTokenHasAccess(Path, True, IsInstallNode, ApiOK);
  if not ApiOK then
  begin
    Failure := 'Windows could not verify the directory DACL: ' + Path;
    Exit;
  end;
  if HasAccess then
  begin
    Failure := 'A standard-user token can modify or redirect the directory: ' + Path;
    Exit;
  end;
  Result := True;
end;

function FileIsProtected(const Path: string; var Failure: string): Boolean;
var
  Attributes: Cardinal;
  HasAccess, ApiOK: Boolean;
begin
  Result := False;
  Attributes := GetFileAttributesW(Path);
  if Attributes = INVALID_FILE_ATTRIBUTES then
  begin
    Failure := 'Cannot inspect the design package: ' + Path;
    Exit;
  end;
  if (Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
  begin
    Failure := 'Design package path is not a file: ' + Path;
    Exit;
  end;
  if (Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
  begin
    Failure := 'The design package is a reparse point: ' + Path;
    Exit;
  end;
  HasAccess := StandardTokenHasAccess(Path, False, False, ApiOK);
  if not ApiOK then
  begin
    Failure := 'Windows could not verify the design package DACL: ' + Path;
    Exit;
  end;
  if HasAccess then
  begin
    Failure := 'A standard-user token can modify, replace, or delete the design package.';
    Exit;
  end;
  Result := True;
end;

function ValidateInstallLocation(const Candidate: string; RequireBpl: Boolean;
  var Failure: string): Boolean;
var
  CommonRoot, InstallRoot, BplRoot, BplPath, Current, Parent: string;
  Attributes, BplAttributes, LastError: Cardinal;
  IsInstallNode: Boolean;
begin
  Result := False;
  Failure := '';
  CommonRoot := CanonicalPath(ExpandConstant('{commonpf}'));
  InstallRoot := CanonicalPath(Candidate);
  if not IsExpectedInstallPath(InstallRoot) then
  begin
    Failure := 'Only the fixed Program Files\\VittixReport location is supported.';
    Exit;
  end;

  { Inspect each existing ancestor from the fixed root to the volume root. }
  Current := CommonRoot;
  while Current <> '' do
  begin
    Attributes := GetFileAttributesW(Current);
    if Attributes = INVALID_FILE_ATTRIBUTES then
    begin
      LastError := DLLGetLastError;
      Failure := 'Cannot inspect an installation ancestor (Windows error ' +
        IntToStr(LastError) + '): ' + Current;
      Exit;
    end;
    IsInstallNode := CompareText(Current, CommonRoot) = 0;
    if not DirectoryIsProtected(Current, IsInstallNode, Failure) then Exit;
    Parent := RemoveBackslashUnlessRoot(ExtractFileDir(Current));
    if (Parent = '') or (CompareText(Parent, Current) = 0) then Break;
    Current := Parent;
  end;

  Attributes := GetFileAttributesW(InstallRoot);
  if Attributes <> INVALID_FILE_ATTRIBUTES then
  begin
    if not DirectoryIsProtected(InstallRoot, True, Failure) then Exit;
  end
  else if DLLGetLastError <> ERROR_FILE_NOT_FOUND then
  begin
    Failure := 'Cannot verify the fixed installation directory.';
    Exit;
  end;

  BplRoot := AddBackslash(InstallRoot) + 'Bpl';
  Attributes := GetFileAttributesW(BplRoot);
  if Attributes <> INVALID_FILE_ATTRIBUTES then
  begin
    if not DirectoryIsProtected(BplRoot, True, Failure) then Exit;
  end
  else if DLLGetLastError <> ERROR_FILE_NOT_FOUND then
  begin
    Failure := 'Cannot verify the package directory.';
    Exit;
  end;

  BplPath := AddBackslash(BplRoot) + 'VittixReportDesign.bpl';
  BplAttributes := GetFileAttributesW(BplPath);
  if BplAttributes <> INVALID_FILE_ATTRIBUTES then
  begin
    if not FileIsProtected(BplPath, Failure) then Exit;
  end;
  if RequireBpl then
    if BplAttributes = INVALID_FILE_ATTRIBUTES then
    begin
      Failure := 'The protected design package does not exist.';
      Exit;
    end;
  Result := True;
end;
