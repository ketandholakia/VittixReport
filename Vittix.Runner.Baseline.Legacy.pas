unit Vittix.Runner.Baseline.Legacy;

{
  Phase 3E-4: Tolerant (legacy / non-strict) baseline policy.

  Extracted from Vittix.Runner.Console.pas - the mutable TJSONObject
  baseline workflow used by non-strict runs:

    - tolerant load: existing file -> ParseJSONValue as TJSONObject;
      missing / malformed / non-object input -> empty TJSONObject
      (never raises for malformed/missing/non-object input)
    - legacy expected-page lookup (reverse scan, case-insensitive,
      last duplicate key wins, non-numeric value -> False)
    - missing-entry auto-registration (AddPair + TJSONNumber)
    - legacy JSON serialization (Format(2)) and save (TFile.WriteAllText
      with TEncoding.UTF8)

  This unit is SEPARATE from the strict/read-only TRegressionBaseline
  (Vittix.Runner.Baseline). It owns its internal TJSONObject; no JSON
  object ever escapes this unit. The decision whether to save
  (BaselineModified) and the page-count comparison / failure policy stay
  in the console runner.
}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  System.JSON;

type
  TLegacyBaseline = class
  private
    FJSON: TJSONObject;
    FModified: Boolean;
  public
    destructor Destroy; override;

    class function LoadOrEmpty(
      const AFileName: string): TLegacyBaseline; static;

    function TryGetExpectedPages(
      const AReportName: string;
      out APageCount: Integer): Boolean;

    procedure RegisterReport(
      const AReportName: string;
      APageCount: Integer);

    property Modified: Boolean read FModified;

    procedure SaveToFile(
      const AFileName: string);
  end;

implementation

class function TLegacyBaseline.LoadOrEmpty(
  const AFileName: string): TLegacyBaseline;
var
  Value: TJSONValue;
begin
  Result := TLegacyBaseline.Create;
  try
    Result.FModified := False;
    if TFile.Exists(AFileName) then
    begin
      Value := TJSONObject.ParseJSONValue(
        TFile.ReadAllText(AFileName, TEncoding.UTF8));
      if Value is TJSONObject then
        Result.FJSON := TJSONObject(Value)
      else
      begin
        // nil / malformed / non-object JSON: discard and use an empty
        // object (legacy tolerant behavior: never raises here).
        Value.Free;
        Result.FJSON := TJSONObject.Create;
      end;
    end
    else
      Result.FJSON := TJSONObject.Create;
  except
    Result.Free;
    raise;
  end;
end;

destructor TLegacyBaseline.Destroy;
begin
  FJSON.Free;
  inherited Destroy;
end;

function TLegacyBaseline.TryGetExpectedPages(
  const AReportName: string;
  out APageCount: Integer): Boolean;
var
  I: Integer;
  Pair: TJSONPair;
begin
  // Legacy lookup: reverse scan so the last duplicate key wins, and
  // case-insensitive name comparison (SameText). A missing key or a
  // non-numeric value yields False. Lookup never modifies the baseline.
  Result := False;
  if not Assigned(FJSON) then
    Exit;

  for I := FJSON.Count - 1 downto 0 do
  begin
    Pair := FJSON.Pairs[I];
    if SameText(Pair.JsonString.Value, AReportName) then
      Exit(TryStrToInt(Pair.JsonValue.Value, APageCount));
  end;
end;

procedure TLegacyBaseline.RegisterReport(
  const AReportName: string;
  APageCount: Integer);
begin
  // Legacy mutation: append the pair (property ordering preserved) and
  // mark the baseline modified. Deduplication is the caller's concern
  // (lookup-before-register flow stays in the console runner).
  FJSON.AddPair(AReportName, TJSONNumber.Create(APageCount));
  FModified := True;
end;

procedure TLegacyBaseline.SaveToFile(
  const AFileName: string);
begin
  // Legacy serialization exactly as previously done in Console:
  // 2-space indentation, TEncoding.UTF8, no schema/order/writer changes.
  TFile.WriteAllText(AFileName, FJSON.Format(2), TEncoding.UTF8);
end;

end.