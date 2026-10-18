unit Vittix.Runner.Baseline;

{
  Phase 3C-2b-1: read-only pagination baseline loader.

  TRegressionBaseline is deliberately read-only: it has NO write, save,
  update, add or serialize API. The parsed TJSONObject is validated,
  its entries copied into owned value structures, and then freed before
  LoadFromFile / LoadFromString returns. No JSON object ever escapes.

  Ownership: the caller owns the returned TRegressionBaseline and must
  free it (prefer try/finally).
}

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.IOUtils,
  System.JSON,
  System.SysUtils;

type
  TBaselineParseError = record
    Line: Integer;
    Offset: Integer;
    Message: string;
  end;

  {
    Issue kinds produced by reconciliation.
    Malformed baseline input is NOT classified here: parsing/validation
    failures are already the responsibility of LoadFromFile/LoadFromString.
  }
  TBaselineIssueKind = (
    bikMissingBaseline,
    bikOrphanBaseline,
    bikPageCountMismatch
  );

  TBaselineIssue = record
    Kind: TBaselineIssueKind;
    ReportName: string;
    ExpectedPages: Integer;
    ActualPages: Integer;
    Message: string;
  end;

  {
    Value-based actual report result supplied by the caller (e.g. the
    console runner after executing a report). Reconciliation never
    executes reports or touches the filesystem itself.
  }
  TReportPageResult = record
    ReportName: string;
    PageCount: Integer;
  end;

  TBaselineReconciliationResult = record
    Issues: TArray<TBaselineIssue>;
    MatchingCount: Integer;
    MissingBaselineCount: Integer;
    OrphanBaselineCount: Integer;
    PageMismatchCount: Integer;
    function HasIssues: Boolean;
  end;

  TRegressionBaseline = class
  private
    FEntries: TDictionary<string, Integer>;
    FOrder: TArray<string>;

    constructor Create;

    class function LoadFromJSON(
      const AJSON: TJSONObject;
      out ABaseline: TRegressionBaseline;
      out AError: TBaselineParseError): Boolean; static;
  public
    destructor Destroy; override;

    {
      Pure reconciliation over (Reports ∪ Baseline).

      ABaseline is only read (never modified). AActualResults are the
      report page counts the caller produced; the caller decides which
      reports belong here (skip/filter policy lives outside this unit).

      Deterministic: issues are sorted by case-insensitive report name,
      then by issue kind. No filesystem access, no output, no mutation.
    }
    class function Reconcile(
      const ABaseline: TRegressionBaseline;
      const AActualResults: TArray<TReportPageResult>): TBaselineReconciliationResult; static;

    class function LoadFromFile(
      const FileName: string;
      out ABaseline: TRegressionBaseline;
      out AError: TBaselineParseError): Boolean; static;

    class function LoadFromString(
      const Content: string;
      out ABaseline: TRegressionBaseline;
      out AError: TBaselineParseError): Boolean; static;

    function TryGetExpectedPages(
      const ReportName: string;
      out ExpectedPages: Integer): Boolean;

    function ContainsReport(const ReportName: string): Boolean;

    function GetReportNames: TArray<string>;

    function Count: Integer;
  end;

  {
    Pure strict-mode failure policy (Phase 3C-2c-2).

    Strict validation fails when reconciliation found issues OR when any
    report execution failed. The console runner owns the final 0/1/2 exit
    decision; this function only owns the "is there a regression failure"
    boolean. No mutation, no I/O.
  }
  function StrictHasFailures(
    const AResult: TBaselineReconciliationResult;
    AExecutionFailures: Integer): Boolean;

implementation

{ TRegressionBaseline }

constructor TRegressionBaseline.Create;
begin
  inherited Create;
  // Case-insensitive report-name lookup preserves the existing
  // SameText-based semantics of the runner.
  FEntries := TDictionary<string, Integer>.Create(TOrdinalIStringComparer.Create);
end;

destructor TRegressionBaseline.Destroy;
begin
  FEntries.Free;
  inherited;
end;

class function TRegressionBaseline.LoadFromFile(
  const FileName: string;
  out ABaseline: TRegressionBaseline;
  out AError: TBaselineParseError): Boolean;
var
  Content: string;
begin
  ABaseline := nil;
  Result := False;
  AError.Line := -1;
  AError.Offset := -1;
  AError.Message := '';

  if not TFile.Exists(FileName) then
  begin
    AError.Message := Format('Baseline file not found: %s', [FileName]);
    Exit;
  end;

  try
    Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      AError.Message := Format('Cannot read baseline file: %s (%s)', [FileName, E.Message]);
      Exit;
    end;
  end;

  Result := LoadFromString(Content, ABaseline, AError);
end;

class function TRegressionBaseline.LoadFromString(
  const Content: string;
  out ABaseline: TRegressionBaseline;
  out AError: TBaselineParseError): Boolean;
var
  JSON: TJSONValue;
begin
  ABaseline := nil;
  Result := False;
  AError.Line := -1;
  AError.Offset := -1;
  AError.Message := '';

  // Delphi's JSON parser does not report line/offset positions,
  // so errors are reported via descriptive messages only.
  if Trim(Content) = '' then
  begin
    AError.Message := 'Baseline is empty.';
    Exit;
  end;

  JSON := TJSONObject.ParseJSONValue(Content);
  try
    if JSON = nil then
    begin
      AError.Message := 'Malformed JSON: content could not be parsed as JSON.';
      Exit;
    end;
    if not (JSON is TJSONObject) then
    begin
      AError.Message := Format('Wrong root type: root must be a JSON object, got %s.',
        [JSON.ClassName]);
      Exit;
    end;
    Result := LoadFromJSON(TJSONObject(JSON), ABaseline, AError);
  finally
    // The parsed JSON object never escapes this unit.
    JSON.Free;
  end;
end;

class function TRegressionBaseline.LoadFromJSON(
  const AJSON: TJSONObject;
  out ABaseline: TRegressionBaseline;
  out AError: TBaselineParseError): Boolean;
var
  Baseline: TRegressionBaseline;
  I: Integer;
  Pair: TJSONPair;
  Key: string;
  PageCount: Integer;
begin
  Result := False;
  ABaseline := nil;
  AError.Line := -1;
  AError.Offset := -1;
  AError.Message := '';

  if AJSON = nil then
  begin
    AError.Message := 'Wrong root type: root must be a JSON object.';
    Exit;
  end;

  Baseline := TRegressionBaseline.Create;
  try
    for I := 0 to AJSON.Count - 1 do
    begin
      Pair := AJSON.Pairs[I];
      Key := Pair.JsonString.Value;

      // Rule 5: keys must reference .vrt report files.
      if not Key.ToLower.EndsWith('.vrt') then
      begin
        AError.Message := Format('Invalid report key: "%s" does not end with ".vrt".', [Key]);
        Baseline.Free;
        ABaseline := nil;
        Exit;
      end;

      // Rule 10: detect duplicate keys while iterating the original
      // JSON pairs (the parser may preserve duplicate pairs).
      if Baseline.FEntries.ContainsKey(Key) then
      begin
        AError.Message := Format('Duplicate report key: "%s".', [Key]);
        Baseline.Free;
        ABaseline := nil;
        Exit;
      end;

      // Rule 6: value must be a JSON number (not string/bool/null/object/array).
      if not (Pair.JsonValue is TJSONNumber) then
      begin
        AError.Message := Format('Invalid page count for "%s": value must be a JSON number, got %s.',
          [Key, Pair.JsonValue.ClassName]);
        Baseline.Free;
        ABaseline := nil;
        Exit;
      end;

      // Rule 7: value must represent an integer (rejects 10.5 and fractional forms).
      if not TryStrToInt(Pair.JsonValue.Value, PageCount) then
      begin
        AError.Message := Format('Invalid page count for "%s": value is not an integer.', [Key]);
        Baseline.Free;
        ABaseline := nil;
        Exit;
      end;

      // Rules 8 + 9: negative page counts and zero page counts are invalid.
      // Investigation: no legitimate zero-page report exists in the current
      // regression suite or canonical baseline (the runner only records page
      // counts after a successful prepare that produced at least one page).
      if PageCount < 1 then
      begin
        AError.Message := Format('Invalid page count for "%s": value must be a positive integer, got %d.',
          [Key, PageCount]);
        Baseline.Free;
        ABaseline := nil;
        Exit;
      end;

      Baseline.FEntries.Add(Key, PageCount);
    end;

    // Preserve document order for enumeration.
    SetLength(Baseline.FOrder, AJSON.Count);
    for I := 0 to AJSON.Count - 1 do
      Baseline.FOrder[I] := AJSON.Pairs[I].JsonString.Value;

    ABaseline := Baseline;
    Result := True;
  except
    Baseline.Free;
    ABaseline := nil;
    raise;
  end;
end;

function TRegressionBaseline.TryGetExpectedPages(
  const ReportName: string;
  out ExpectedPages: Integer): Boolean;
begin
  Result := FEntries.TryGetValue(ReportName, ExpectedPages);
end;

function TRegressionBaseline.ContainsReport(const ReportName: string): Boolean;
begin
  Result := FEntries.ContainsKey(ReportName);
end;

function TRegressionBaseline.GetReportNames: TArray<string>;
begin
  Result := Copy(FOrder);
end;

function TRegressionBaseline.Count: Integer;
begin
  Result := FEntries.Count;
end;

function TBaselineReconciliationResult.HasIssues: Boolean;
begin
  Result := Length(Issues) > 0;
end;

{ Sorts names deterministically using case-insensitive comparison. }
procedure SortNamesCaseInsensitive(var ANames: TArray<string>);
var
  I, J: Integer;
  Temp: string;
begin
  // Simple selection sort: deterministic and dependency-free.
  for I := 0 to High(ANames) do
    for J := I + 1 to High(ANames) do
      if AnsiCompareText(ANames[J], ANames[I]) < 0 then
      begin
        Temp := ANames[I];
        ANames[I] := ANames[J];
        ANames[J] := Temp;
      end;
end;

class function TRegressionBaseline.Reconcile(
  const ABaseline: TRegressionBaseline;
  const AActualResults: TArray<TReportPageResult>): TBaselineReconciliationResult;
var
  Issues: TList<TBaselineIssue>;
  ActualByName: TDictionary<string, Integer>;
  BaselineNames, ActualNames: TArray<string>;
  I, J: Integer;
  Issue: TBaselineIssue;
  ActualPages, ExpectedPages: Integer;
  TempIssue: TBaselineIssue;
begin
  Issues := TList<TBaselineIssue>.Create;
  ActualByName := TDictionary<string, Integer>.Create(TOrdinalIStringComparer.Create);
  try
    Result.Issues := nil;
    Result.MatchingCount := 0;
    Result.MissingBaselineCount := 0;
    Result.OrphanBaselineCount := 0;
    Result.PageMismatchCount := 0;

    if ABaseline = nil then
      Exit;

    // Index actual results by case-insensitive report name.
    for I := 0 to High(AActualResults) do
      ActualByName.AddOrSetValue(AActualResults[I].ReportName, AActualResults[I].PageCount);

    // Pass 1: reports side of the union (sorted by name for determinism).
    SetLength(ActualNames, Length(AActualResults));
    for I := 0 to High(AActualResults) do
      ActualNames[I] := AActualResults[I].ReportName;
    SortNamesCaseInsensitive(ActualNames);

    for I := 0 to High(ActualNames) do
    begin
      ActualPages := ActualByName[ActualNames[I]];
      if ABaseline.TryGetExpectedPages(ActualNames[I], ExpectedPages) then
      begin
        if ActualPages <> ExpectedPages then
        begin
          Issue.Kind := bikPageCountMismatch;
          Issue.ReportName := ActualNames[I];
          Issue.ExpectedPages := ExpectedPages;
          Issue.ActualPages := ActualPages;
          Issue.Message := Format('Page count mismatch for "%s": expected %d, got %d.',
            [ActualNames[I], ExpectedPages, ActualPages]);
          Issues.Add(Issue);
          Result.PageMismatchCount := Result.PageMismatchCount + 1;
        end
        else
          Result.MatchingCount := Result.MatchingCount + 1;
      end
      else
      begin
        // Missing baseline: never create a baseline entry here.
        Issue.Kind := bikMissingBaseline;
        Issue.ReportName := ActualNames[I];
        Issue.ExpectedPages := 0;
        Issue.ActualPages := ActualPages;
        Issue.Message := Format('Missing baseline entry for report "%s".', [ActualNames[I]]);
        Issues.Add(Issue);
        Result.MissingBaselineCount := Result.MissingBaselineCount + 1;
      end;
    end;

    // Pass 2: baseline side of the union (orphans; sorted by name).
    BaselineNames := ABaseline.GetReportNames;
    SortNamesCaseInsensitive(BaselineNames);

    for I := 0 to High(BaselineNames) do
    begin
      if not ActualByName.ContainsKey(BaselineNames[I]) then
      begin
        // Orphan baseline: never remove a baseline entry here.
        ABaseline.TryGetExpectedPages(BaselineNames[I], ExpectedPages);
        Issue.Kind := bikOrphanBaseline;
        Issue.ReportName := BaselineNames[I];
        Issue.ExpectedPages := ExpectedPages;
        Issue.ActualPages := 0;
        Issue.Message := Format('Orphan baseline entry: report "%s" was not executed.', [BaselineNames[I]]);
        Issues.Add(Issue);
        Result.OrphanBaselineCount := Result.OrphanBaselineCount + 1;
      end;
    end;

    // Final deterministic ordering: report name (case-insensitive), then kind.
    for I := 0 to Issues.Count - 2 do
      for J := I + 1 to Issues.Count - 1 do
      begin
        if (AnsiCompareText(Issues[J].ReportName, Issues[I].ReportName) < 0) or
           ((AnsiCompareText(Issues[J].ReportName, Issues[I].ReportName) = 0) and
            (Issues[J].Kind < Issues[I].Kind)) then
        begin
          TempIssue := Issues[I];
          Issues[I] := Issues[J];
          Issues[J] := TempIssue;
        end;
      end;

    Result.Issues := Issues.ToArray;
  finally
    ActualByName.Free;
    Issues.Free;
  end;
end;

function StrictHasFailures(
  const AResult: TBaselineReconciliationResult;
  AExecutionFailures: Integer): Boolean;
begin
  Result := AResult.HasIssues or (AExecutionFailures > 0);
end;

end.
