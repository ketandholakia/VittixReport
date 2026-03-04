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

// ---------------------------------------------------------------------------
// Variant helpers
// ---------------------------------------------------------------------------

/// <summary>
///   Returns True if V is Null, Unassigned, or an empty string.
///   Named VarIsBlank to avoid conflict with System.Variants.VarIsEmpty.
/// </summary>
function VarIsBlank(const V: Variant): Boolean;

// ---------------------------------------------------------------------------
// String helpers
// ---------------------------------------------------------------------------

/// <summary>
///   Returns S trimmed and with all internal consecutive whitespace
///   collapsed to a single space.
/// </summary>
function CollapseWhitespace(const S: string): string;

implementation

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

end.
