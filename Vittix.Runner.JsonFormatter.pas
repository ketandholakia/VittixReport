unit Vittix.Runner.JsonFormatter;

{
  Phase 3D-5: pure JSON result formatter.

  TJsonRunFormatter implements IRunResultFormatter and emits a single,
  complete JSON document via FormatRunSummary. The formatter is presentation-only:
  it has no filesystem, process, VCL, Windows API, or report-execution behavior.
  It does not call ParamStr/ParamCount, Halt, or Writeln, and it does not
  compute exit codes or strict semantics.

  FormatReportLine and FormatStrictSummary return empty strings; the console
  must never concatenate them into the final output.

  Serialization uses System.JSON (TJSONObject/TJSONArray/TJSONNumber/
  TJSONString/TJSONBool/TJSONNull). JSON property ordering is deterministic
  because TJSONObject.AddPair appends in insertion order.
}

interface

uses
  System.SysUtils,
  System.JSON,
  Vittix.Runner.Baseline,
  Vittix.Runner.Formatting,
  Vittix.Runner.Results;

type
  TJsonRunFormatter = class(TInterfacedObject, IRunResultFormatter)
  public
    function FormatReportLine(const AReport: TReportExecutionResult;
      const AContext: TRunFormatContext): string;
    function FormatRunSummary(const AResult: TRegressionRunResult;
      const AContext: TRunFormatContext): string;
    function FormatStrictSummary(const AResult: TRegressionRunResult;
      const AContext: TRunFormatContext): string;
  end;

implementation

{ TJsonRunFormatter }

function StatusToString(const AStatus: TReportExecutionStatus): string;
begin
  case AStatus of
    resPassed:  Result := 'passed';
    resFailed:  Result := 'failed';
    resSkipped: Result := 'skipped';
  else
    Result := 'failed';
  end;
end;

function IssueKindToString(const AKind: TBaselineIssueKind): string;
begin
  case AKind of
    bikMissingBaseline:   Result := 'missing_baseline';
    bikOrphanBaseline:    Result := 'orphan_baseline';
    bikPageCountMismatch: Result := 'page_count_mismatch';
  else
    Result := 'unknown';
  end;
end;

function FindObservation(const AName: string;
  const AObservations: TArray<TReportExecutionObservation>): TReportExecutionObservation;
var
  I: Integer;
begin
  Result := Default(TReportExecutionObservation);
  for I := 0 to High(AObservations) do
    if SameText(AObservations[I].ReportName, AName) then
    begin
      Result := AObservations[I];
      Break;
    end;
end;

procedure ValidateObservations(const AResult: TRegressionRunResult;
  const AContext: TRunFormatContext);
var
  I: Integer;
  Expected, Actual: string;
begin
  if Length(AResult.Reports) <> Length(AContext.ReportObservations) then
    raise Exception.CreateFmt(
      'Vittix JSON formatter: observation count mismatch (reports=%d, observations=%d)',
      [Length(AResult.Reports), Length(AContext.ReportObservations)]);

  for I := 0 to High(AResult.Reports) do
  begin
    Expected := AResult.Reports[I].ReportName;
    Actual := AContext.ReportObservations[I].ReportName;
    if not SameText(Expected, Actual) then
      raise Exception.CreateFmt(
        'Vittix JSON formatter: observation mismatch at index %d (report="%s", observation="%s")',
        [I, Expected, Actual]);
  end;
end;

function AddNumberOrNull(AHasValue: Boolean; AValue: Int64): TJSONValue;
begin
  if AHasValue then
    Result := TJSONNumber.Create(AValue)
  else
    Result := TJSONNull.Create;
end;
function BuildScriptsObject(const AObs: TReportExecutionObservation): TJSONValue;
begin
  if not AObs.HasScriptCounts then
    Exit(TJSONNull.Create);

  Result := TJSONObject.Create;
  TJSONObject(Result).AddPair('before', TJSONNumber.Create(AObs.ScriptBeforeCount));
  TJSONObject(Result).AddPair('after', TJSONNumber.Create(AObs.ScriptAfterCount));
end;

function BuildReportObject(const AReport: TReportExecutionResult;
  const AContext: TRunFormatContext): TJSONObject;
var
  Obs: TReportExecutionObservation;
  ScriptsValue: TJSONValue;
begin
  Obs := FindObservation(AReport.ReportName, AContext.ReportObservations);

  Result := TJSONObject.Create;
  try
    Result.AddPair('report', TJSONString.Create(AReport.ReportName));
    Result.AddPair('status', TJSONString.Create(StatusToString(AReport.Status)));
    Result.AddPair('page_count', AddNumberOrNull(AReport.HasPageCount, AReport.PageCount));
    Result.AddPair('expected_page_count',
      AddNumberOrNull(AReport.HasExpectedPageCount, AReport.ExpectedPageCount));
    Result.AddPair('error_message', TJSONString.Create(AReport.ErrorMessage));
    Result.AddPair('elapsed_ms', TJSONNumber.Create(Obs.ElapsedMs));
    Result.AddPair('gdi_leak_delta', TJSONNumber.Create(AReport.GdiLeakDelta));
    Result.AddPair('gdi_cache_delta', TJSONNumber.Create(Obs.GdiCacheDelta));

    ScriptsValue := BuildScriptsObject(Obs);
    Result.AddPair('scripts', ScriptsValue);
  except
    Result.Free;
    raise;
  end;
end;

function BuildIssueObject(const AIssue: TBaselineIssue): TJSONObject;
var
  ExpectedPages, ActualPages: TJSONValue;
begin
  case AIssue.Kind of
    bikMissingBaseline:
      begin
        ExpectedPages := TJSONNull.Create;
        ActualPages := AddNumberOrNull(True, AIssue.ActualPages);
      end;
    bikOrphanBaseline:
      begin
        ExpectedPages := AddNumberOrNull(True, AIssue.ExpectedPages);
        ActualPages := TJSONNull.Create;
      end;
    bikPageCountMismatch:
      begin
        ExpectedPages := AddNumberOrNull(True, AIssue.ExpectedPages);
        ActualPages := AddNumberOrNull(True, AIssue.ActualPages);
      end;
  else
    ExpectedPages := TJSONNull.Create;
    ActualPages := TJSONNull.Create;
  end;

  Result := TJSONObject.Create;
  try
    Result.AddPair('kind', TJSONString.Create(IssueKindToString(AIssue.Kind)));
    Result.AddPair('report', TJSONString.Create(AIssue.ReportName));
    Result.AddPair('expected_pages', ExpectedPages);
    Result.AddPair('actual_pages', ActualPages);
    Result.AddPair('message', TJSONString.Create(AIssue.Message));
  except
    ExpectedPages.Free;
    ActualPages.Free;
    Result.Free;
    raise;
  end;
end;

function BuildReconciliationObject(const AResult: TRegressionRunResult): TJSONValue;
var
  Issues: TJSONArray;
  Issue: TBaselineIssue;
  Rec: TJSONObject;
begin
  if not AResult.BaselineCompared then
    Exit(TJSONNull.Create);

  Issues := TJSONArray.Create;
  try
    for Issue in AResult.Reconciliation.Issues do
      Issues.AddElement(BuildIssueObject(Issue));

    Rec := TJSONObject.Create;
    Rec.AddPair('matching', TJSONNumber.Create(AResult.Reconciliation.MatchingCount));
    Rec.AddPair('page_count_mismatches', TJSONNumber.Create(AResult.Reconciliation.PageMismatchCount));
    Rec.AddPair('missing_baselines', TJSONNumber.Create(AResult.Reconciliation.MissingBaselineCount));
    Rec.AddPair('orphan_baselines', TJSONNumber.Create(AResult.Reconciliation.OrphanBaselineCount));
    Rec.AddPair('issues', Issues);
    Result := Rec;
  except
    Issues.Free;
    raise;
  end;
end;

function BuildProcessObject(const AContext: TRunFormatContext): TJSONValue;
var
  Proc: TJSONObject;
  GDI, User, Mem: TJSONObject;
  Delta: Int64;
  DeltaGDI, DeltaUser: Integer;
begin
  if not AContext.HasProcessSummary then
    Exit(TJSONNull.Create);

  Proc := TJSONObject.Create;
  try
    GDI := TJSONObject.Create;
    GDI.AddPair('start', TJSONNumber.Create(AContext.Process.StartGDI));
    GDI.AddPair('end', TJSONNumber.Create(AContext.Process.EndGDI));
    DeltaGDI := Integer(AContext.Process.EndGDI) - Integer(AContext.Process.StartGDI);
    GDI.AddPair('delta', TJSONNumber.Create(DeltaGDI));
    Proc.AddPair('gdi_handles', GDI);

    User := TJSONObject.Create;
    User.AddPair('start', TJSONNumber.Create(AContext.Process.StartUser));
    User.AddPair('end', TJSONNumber.Create(AContext.Process.EndUser));
    DeltaUser := Integer(AContext.Process.EndUser) - Integer(AContext.Process.StartUser);
    User.AddPair('delta', TJSONNumber.Create(DeltaUser));
    Proc.AddPair('user_handles', User);

    Mem := TJSONObject.Create;
    Mem.AddPair('start', TJSONNumber.Create(AContext.Process.StartMem));
    Mem.AddPair('end', TJSONNumber.Create(AContext.Process.EndMem));
    Delta := AContext.Process.EndMem - AContext.Process.StartMem;
    Mem.AddPair('delta', TJSONNumber.Create(Delta));
    Proc.AddPair('memory_bytes', Mem);

    Result := Proc;
  except
    Proc.Free;
    raise;
  end;
end;

function TJsonRunFormatter.FormatReportLine(const AReport: TReportExecutionResult;
  const AContext: TRunFormatContext): string;
begin
  // JSON mode emits a single document via FormatRunSummary; no per-line output.
  Result := '';
end;

function TJsonRunFormatter.FormatRunSummary(const AResult: TRegressionRunResult;
  const AContext: TRunFormatContext): string;
var
  Root, ReportObj: TJSONObject;
  Reports: TJSONArray;
  Rec: TJSONValue;
  I: Integer;
begin
  ValidateObservations(AResult, AContext);

  Root := TJSONObject.Create;
  try
    Root.AddPair('schema_version', TJSONNumber.Create(1));
    Root.AddPair('reports_discovered', TJSONNumber.Create(AResult.ReportsDiscovered));
    Root.AddPair('reports_checked', TJSONNumber.Create(AResult.ReportsCheckedCount));
    Root.AddPair('passed', TJSONNumber.Create(AResult.PassedCount));
    Root.AddPair('failed', TJSONNumber.Create(AResult.ExecutionFailureCount));
    Root.AddPair('skipped', TJSONNumber.Create(AResult.SkippedCount));
    Root.AddPair('execution_failures', TJSONNumber.Create(AResult.ExecutionFailureCount));
    Root.AddPair('baseline_compared', TJSONBool.Create(AResult.BaselineCompared));
    Root.AddPair('baseline_updated', TJSONBool.Create(AResult.BaselineUpdated));
    Root.AddPair('successful', TJSONBool.Create(AResult.IsSuccessful));

    Reports := TJSONArray.Create;
    try
      for I := 0 to High(AResult.Reports) do
      begin
        ReportObj := BuildReportObject(AResult.Reports[I], AContext);
        Reports.AddElement(ReportObj);
      end;
      Root.AddPair('reports', Reports);
    except
      Reports.Free;
      raise;
    end;

    Rec := BuildReconciliationObject(AResult);
    Root.AddPair('reconciliation', Rec);

    Rec := BuildProcessObject(AContext);
    Root.AddPair('process', Rec);

    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TJsonRunFormatter.FormatStrictSummary(const AResult: TRegressionRunResult;
  const AContext: TRunFormatContext): string;
begin
  // Strict reconciliation is included in the single JSON document produced by
  // FormatRunSummary; no separate strict summary is emitted.
  Result := '';
end;

end.
