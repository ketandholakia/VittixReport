unit Vittix.Report.Utils;

{
  Vittix.Report.Utils
  ===================
  Shared utility routines used across multiple VittixReport units.

  All functions here must be stateless, side-effect-free helpers.
  No framework-level types are defined here — only primitives and RTL types
  are in scope so this unit can be used by any other unit without introducing
  circular dependencies.
}

interface

uses
  Data.DB,
  System.SysUtils,
  System.Variants;

// ---------------------------------------------------------------------------
// Dataset helpers
// ---------------------------------------------------------------------------

/// <summary>
///   Returns True if <c>ADataSet</c> supports bookmarks by probing the
///   GetBookmark / FreeBookmark API.  Works with any TDataSet descendant
///   (TClientDataSet, TADODataSet, TFDQuery, etc.) unlike the unreliable
///   CanBookmark pseudo-property.
/// </summary>
function DataSetSupportsBookmarks(ADataSet: TDataSet): Boolean;

/// <summary>
///   Safe wrapper around TDataSet.RecordCount.
///   Some datasets (e.g. unidirectional cursors) raise an exception when
///   RecordCount is accessed; this function returns 0 in that case.
/// </summary>
function SafeRecordCount(ADataSet: TDataSet): Integer;

/// <summary>
///   Safely resolves a dataset field by name.
///   Returns False when dataset is nil/inactive, field name is blank, field is
///   missing, or the lookup raises an exception.
/// </summary>
function TryGetField(ADataSet: TDataSet; const AFieldName: string; out AField: TField): Boolean;

/// <summary>
///   Safe field-value accessor.
///   Returns Null when dataset/field is unavailable, field value is null, or any
///   access step raises an exception.
/// </summary>
function SafeFieldValue(ADataSet: TDataSet; const AFieldName: string): Variant;

/// <summary>
///   Safe field-string accessor.
///   Returns '' when dataset/field is unavailable, field value is null/empty,
///   or any access step raises an exception.
/// </summary>
function SafeFieldAsString(ADataSet: TDataSet; const AFieldName: string): string;

/// <summary>
///   Returns True when either a TVittixUserDataSet source or TDataSet source
///   is active. AUserDataSet is TObject to keep Context decoupled.
/// </summary>
function SourceActive(ADataSet: TDataSet; AUserDataSet: TObject): Boolean;

/// <summary>
///   Reads from TVittixUserDataSet.GetValue when present, otherwise TDataSet.
/// </summary>
function SafeSourceFieldValue(ADataSet: TDataSet; AUserDataSet: TObject;
  const AFieldName: string): Variant;

function SafeSourceFieldAsString(ADataSet: TDataSet; AUserDataSet: TObject;
  const AFieldName: string): string;

{$IFDEF DEBUG}
procedure DebugLogDataFieldIssue(const AObjClass, AObjName, ADataField, AReason: string;
  ADataSet: TDataSet);
{$ENDIF}

// ---------------------------------------------------------------------------
// Variant helpers
// ---------------------------------------------------------------------------

/// <summary>
///   Returns True if V is Null, Unassigned, or an empty string.
///   Named VarIsBlank to avoid conflict with System.Variants.VarIsEmpty.
/// </summary>
function VarIsBlank(const V: Variant): Boolean;

/// <summary>
///   Strict condition coercion for PrintWhen/conditional expressions.
///   Null/empty => False; numbers => zero=False/non-zero=True;
///   strings map: 0/false/no/n/off => False, 1/true/yes/y/on => True;
///   unknown non-empty strings => False.
/// </summary>
function ConditionVariantToBool(const V: Variant): Boolean;

// ---------------------------------------------------------------------------
// String helpers
// ---------------------------------------------------------------------------

/// <summary>
///   Returns S trimmed and with all internal consecutive whitespace
///   collapsed to a single space.
/// </summary>
function CollapseWhitespace(const S: string): string;

implementation

uses
  System.Classes,
  Vittix.Report.UserDataSet
{$IFDEF DEBUG}
  , Winapi.Windows
{$ENDIF};

{$IFDEF DEBUG}
const
  CDataFieldDiagMaxMessages = 200;

var
  GDataFieldDiagSeen: TStringList;
  GDataFieldDiagCount: Integer;

function DataSetStateText(ADataSet: TDataSet): string;
begin
  if not Assigned(ADataSet) then
    Exit('dataset nil');
  if not ADataSet.Active then
    Exit('dataset inactive');
  Result := 'dataset active';
end;

procedure DebugLogDataFieldIssue(const AObjClass, AObjName, ADataField, AReason: string;
  ADataSet: TDataSet);
var
  Key: string;
  Msg: string;
begin
  if GDataFieldDiagCount >= CDataFieldDiagMaxMessages then
    Exit;

  if not Assigned(GDataFieldDiagSeen) then
  begin
    GDataFieldDiagSeen := TStringList.Create;
    GDataFieldDiagSeen.Sorted := True;
    GDataFieldDiagSeen.Duplicates := dupIgnore;
  end;

  Key := AObjClass + '|' + AObjName + '|' + ADataField + '|' + AReason;
  if GDataFieldDiagSeen.IndexOf(Key) >= 0 then
    Exit;

  GDataFieldDiagSeen.Add(Key);
  Inc(GDataFieldDiagCount);

  Msg := Format(
    '[VittixReport][DataField] %s "%s" DataField="%s": %s (%s); rendering fallback',
    [AObjClass, AObjName, ADataField, AReason, DataSetStateText(ADataSet)]);
  OutputDebugString(PChar(Msg));
end;
{$ENDIF}

// ---------------------------------------------------------------------------
// Dataset helpers
// ---------------------------------------------------------------------------

function DataSetSupportsBookmarks(ADataSet: TDataSet): Boolean;
var
  BM: TBookmark;
begin
  Result := False;
  if not Assigned(ADataSet) or not ADataSet.Active then
    Exit;

  BM := nil;
  try
    BM := ADataSet.GetBookmark;
    Result := Assigned(BM);
  except
    Result := False;
  end;

  if Result and Assigned(BM) then
  try
    ADataSet.FreeBookmark(BM);
  except
    // Ignore — we already know bookmarks are supported; just clean up best-effort
  end;
end;

function SafeRecordCount(ADataSet: TDataSet): Integer;
begin
  Result := 0;
  if not Assigned(ADataSet) or not ADataSet.Active then
    Exit;
  try
    Result := ADataSet.RecordCount;
  except
    Result := 0;
  end;
end;

function TryGetField(ADataSet: TDataSet; const AFieldName: string; out AField: TField): Boolean;
begin
  AField := nil;
  Result := False;

  if not Assigned(ADataSet) or not ADataSet.Active then
    Exit;
  if Trim(AFieldName) = '' then
    Exit;

  try
    AField := ADataSet.FindField(AFieldName);
    Result := Assigned(AField);
  except
    AField := nil;
    Result := False;
  end;
end;

function SafeFieldValue(ADataSet: TDataSet; const AFieldName: string): Variant;
var
  F: TField;
begin
  Result := Null;
  if not TryGetField(ADataSet, AFieldName, F) then
    Exit;

  try
    Result := F.Value;
    if VarIsNull(Result) or System.Variants.VarIsEmpty(Result) then
      Result := Null;
  except
    Result := Null;
  end;
end;

function SafeFieldAsString(ADataSet: TDataSet; const AFieldName: string): string;
var
  V: Variant;
begin
  Result := '';
  V := SafeFieldValue(ADataSet, AFieldName);
  if VarIsNull(V) or System.Variants.VarIsEmpty(V) then
    Exit;

  try
    Result := VarToStr(V);
  except
    Result := '';
  end;
end;

function SourceActive(ADataSet: TDataSet; AUserDataSet: TObject): Boolean;
begin
  if AUserDataSet is TVittixUserDataSet then
    Exit(TVittixUserDataSet(AUserDataSet).Active);

  Result := Assigned(ADataSet) and ADataSet.Active;
end;

function SafeSourceFieldValue(ADataSet: TDataSet; AUserDataSet: TObject;
  const AFieldName: string): Variant;
begin
  Result := Null;
  if Trim(AFieldName) = '' then
    Exit;

  if AUserDataSet is TVittixUserDataSet then
  begin
    try
      Result := TVittixUserDataSet(AUserDataSet).GetValue(AFieldName);
      if VarIsNull(Result) or System.Variants.VarIsEmpty(Result) then
        Result := Null;
    except
      Result := Null;
    end;
    Exit;
  end;

  Result := SafeFieldValue(ADataSet, AFieldName);
end;

function SafeSourceFieldAsString(ADataSet: TDataSet; AUserDataSet: TObject;
  const AFieldName: string): string;
var
  V: Variant;
begin
  Result := '';
  V := SafeSourceFieldValue(ADataSet, AUserDataSet, AFieldName);
  if VarIsNull(V) or System.Variants.VarIsEmpty(V) then
    Exit;

  try
    Result := VarToStr(V);
  except
    Result := '';
  end;
end;

// ---------------------------------------------------------------------------
// Variant helpers
// ---------------------------------------------------------------------------

function VarIsBlank(const V: Variant): Boolean;
var
  VT: TVarType;
begin
  VT := VarType(V);
  Result := VarIsNull(V)
         or System.Variants.VarIsEmpty(V)
         or ((VT = varString) or (VT = varUString)) and (V = '');
end;

function ConditionVariantToBool(const V: Variant): Boolean;
var
  VT: TVarType;
  S: string;
  D: Double;
begin
  Result := False;

  if VarIsNull(V) or System.Variants.VarIsEmpty(V) then
    Exit(False);

  try
    VT := VarType(V) and varTypeMask;

    if VT = varBoolean then
      Exit(Boolean(V));

    if VT in [varSmallint, varInteger, varSingle, varDouble, varCurrency,
              varShortInt, varByte, varWord, varLongWord, varInt64] then
    begin
      D := VarAsType(V, varDouble);
      Exit(D <> 0);
    end;

    S := Trim(LowerCase(VarToStr(V)));
    if S = '' then Exit(False);

    if (S = '0') or (S = 'false') or (S = 'no') or (S = 'n') or (S = 'off') then
      Exit(False);
    if (S = '1') or (S = 'true') or (S = 'yes') or (S = 'y') or (S = 'on') then
      Exit(True);

    if TryStrToFloat(S, D) then
      Exit(D <> 0);

    Result := False;
  except
    Result := False;
  end;
end;

// ---------------------------------------------------------------------------
// String helpers
// ---------------------------------------------------------------------------

function CollapseWhitespace(const S: string): string;
var
  i: Integer;
  LastWasSpace: Boolean;
begin
  Result := '';
  LastWasSpace := False;

  for i := 1 to Length(S) do
  begin
    if S[i] <= ' ' then
    begin
      if not LastWasSpace and (Result <> '') then
        Result := Result + ' ';
      LastWasSpace := True;
    end
    else
    begin
      Result := Result + S[i];
      LastWasSpace := False;
    end;
  end;

  Result := Trim(Result);
end;

{$IFDEF DEBUG}
initialization

finalization
  GDataFieldDiagSeen.Free;
{$ENDIF}

end.
