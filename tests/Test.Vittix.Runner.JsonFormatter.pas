unit Test.Vittix.Runner.JsonFormatter;

interface

uses
  System.SysUtils,
  System.JSON,
  DUnitX.TestFramework,
  Vittix.Runner.Baseline,
  Vittix.Runner.Formatting,
  Vittix.Runner.Results,
  Vittix.Runner.JsonFormatter;

type
  [TestFixture]
  TJsonRunFormatterTests = class
  private
    Fmt: IRunResultFormatter;
    class function MakeReport(AStatus: TReportExecutionStatus;
      const AName: string; APages: Integer; AHasPages: Boolean;
      AExpectedPages: Integer; AHasExpected: Boolean;
      const AError: string; ALeakDelta: Integer): TReportExecutionResult; static;
    class function MakeObs(const AName: string; AElapsedMs: Int64;
      AGdiCacheDelta: Integer; AHtmlOk, AHasScripts: Boolean;
      ABefore, AAfter: Integer): TReportExecutionObservation; static;
    class function MakeIssue(AKind: TBaselineIssueKind;
      const AName: string; AExpected, AActual: Integer;
      const AMessage: string): TBaselineIssue; static;
    class function MakeReconciliation(AMatching, AMismatch, AMissing,
      AOrphan: Integer; const AIssues: array of TBaselineIssue): TBaselineReconciliationResult; static;
    class function MakeContext(const AObs: array of TReportExecutionObservation;
      AHasProcess: Boolean;
      AStartGDI, AEndGDI, AStartUser, AEndUser: Cardinal;
      AStartMem, AEndMem: Int64): TRunFormatContext; static;
    class function MakeRun(AReportsDiscovered: Integer;
      const AReports: array of TReportExecutionResult;
      ABaselineCompared: Boolean; ABaselineUpdated: Boolean;
      const AReconciliation: TBaselineReconciliationResult): TRegressionRunResult; static;
    class function ParseJson(const AJson: string): TJSONObject; static;
    function FormatRun(const AResult: TRegressionRunResult;
      const AContext: TRunFormatContext): string;
    procedure AssertContainsInOrder(const AJson, AFirst, ASecond: string);
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure Test_EmptyRun;
    [Test] procedure Test_AllPassed;
    [Test] procedure Test_MixedPassedFailedSkipped;
    [Test] procedure Test_Report_Passed;
    [Test] procedure Test_Report_Failed;
    [Test] procedure Test_Report_Skipped;
    [Test] procedure Test_Report_PageCountPresent;
    [Test] procedure Test_Report_PageCountNull;
    [Test] procedure Test_Report_ExpectedPageCountPresent;
    [Test] procedure Test_Report_ExpectedPageCountNull;
    [Test] procedure Test_Report_ErrorMessagePreserved;
    [Test] procedure Test_Report_GdiLeakDelta;
    [Test] procedure Test_Report_GdiCacheDelta;
    [Test] procedure Test_Report_ElapsedMs;
    [Test] procedure Test_Report_ScriptCounts;
    [Test] procedure Test_Report_ScriptCountsNull;
    [Test] procedure Test_Reconciliation_Matching;
    [Test] procedure Test_Reconciliation_PageCountMismatch;
    [Test] procedure Test_Reconciliation_MissingBaseline;
    [Test] procedure Test_Reconciliation_OrphanBaseline;
    [Test] procedure Test_Reconciliation_MultipleIssues;
    [Test] procedure Test_Reconciliation_Null;
    [Test] procedure Test_RunState_StrictSuccess;
    [Test] procedure Test_RunState_StrictReconciliationFailure;
    [Test] procedure Test_RunState_StrictExecutionFailure;
    [Test] procedure Test_RunState_NonStrictSuccess;
    [Test] procedure Test_RunState_NonStrictFailure;
    [Test] procedure Test_RunState_BaselineUpdatedOnlySuccess;
    [Test] procedure Test_Process_Present;
    [Test] procedure Test_Process_Null;
    [Test] procedure Test_Process_ResourceValues;
    [Test] procedure Test_JSON_Parses;
    [Test] procedure Test_JSON_NullHandling;
    [Test] procedure Test_JSON_QuoteEscaping;
    [Test] procedure Test_JSON_BackslashEscaping;
    [Test] procedure Test_JSON_ControlCharacterEscaping;
    [Test] procedure Test_JSON_Unicode;
    [Test] procedure Test_JSON_RootPropertyOrdering;
    [Test] procedure Test_JSON_ReportPropertyOrdering;
    [Test] procedure Test_JSON_IssuePropertyOrdering;
    [Test] procedure Test_JSON_ReportOrdering;
    [Test] procedure Test_JSON_IssueOrdering;
    [Test] procedure Test_JSON_InconsistentObservationsFail;
  end;

implementation

class function TJsonRunFormatterTests.MakeReport(AStatus: TReportExecutionStatus;
  const AName: string; APages: Integer; AHasPages: Boolean;
  AExpectedPages: Integer; AHasExpected: Boolean;
  const AError: string; ALeakDelta: Integer): TReportExecutionResult;
begin
  Result := Default(TReportExecutionResult);
  Result.ReportName := AName;
  Result.Status := AStatus;
  Result.PageCount := APages;
  Result.HasPageCount := AHasPages;
  Result.ExpectedPageCount := AExpectedPages;
  Result.HasExpectedPageCount := AHasExpected;
  Result.ErrorMessage := AError;
  Result.GdiLeakDelta := ALeakDelta;
end;

class function TJsonRunFormatterTests.MakeObs(const AName: string;
  AElapsedMs: Int64; AGdiCacheDelta: Integer; AHtmlOk, AHasScripts: Boolean;
  ABefore, AAfter: Integer): TReportExecutionObservation;
begin
  Result := Default(TReportExecutionObservation);
  Result.ReportName := AName;
  Result.ElapsedMs := AElapsedMs;
  Result.GdiCacheDelta := AGdiCacheDelta;
  Result.HtmlSmokeOk := AHtmlOk;
  Result.HasScriptCounts := AHasScripts;
  Result.ScriptBeforeCount := ABefore;
  Result.ScriptAfterCount := AAfter;
end;

class function TJsonRunFormatterTests.MakeIssue(AKind: TBaselineIssueKind;
  const AName: string; AExpected, AActual: Integer;
  const AMessage: string): TBaselineIssue;
begin
  Result := Default(TBaselineIssue);
  Result.Kind := AKind;
  Result.ReportName := AName;
  Result.ExpectedPages := AExpected;
  Result.ActualPages := AActual;
  Result.Message := AMessage;
end;

class function TJsonRunFormatterTests.MakeReconciliation(AMatching, AMismatch,
  AMissing, AOrphan: Integer;
  const AIssues: array of TBaselineIssue): TBaselineReconciliationResult;
var
  I: Integer;
begin
  Result := Default(TBaselineReconciliationResult);
  Result.MatchingCount := AMatching;
  Result.PageMismatchCount := AMismatch;
  Result.MissingBaselineCount := AMissing;
  Result.OrphanBaselineCount := AOrphan;
  SetLength(Result.Issues, Length(AIssues));
  for I := 0 to High(AIssues) do
    Result.Issues[I] := AIssues[I];
end;

class function TJsonRunFormatterTests.MakeContext(const AObs: array of TReportExecutionObservation;
  AHasProcess: Boolean;
  AStartGDI, AEndGDI, AStartUser, AEndUser: Cardinal;
  AStartMem, AEndMem: Int64): TRunFormatContext;
var
  I: Integer;
begin
  Result := Default(TRunFormatContext);
  SetLength(Result.ReportObservations, Length(AObs));
  for I := 0 to High(AObs) do
    Result.ReportObservations[I] := AObs[I];
  Result.HasProcessSummary := AHasProcess;
  Result.Process.HasData := AHasProcess;
  Result.Process.StartGDI := AStartGDI;
  Result.Process.EndGDI := AEndGDI;
  Result.Process.StartUser := AStartUser;
  Result.Process.EndUser := AEndUser;
  Result.Process.StartMem := AStartMem;
  Result.Process.EndMem := AEndMem;
end;

class function TJsonRunFormatterTests.MakeRun(AReportsDiscovered: Integer;
  const AReports: array of TReportExecutionResult;
  ABaselineCompared: Boolean; ABaselineUpdated: Boolean;
  const AReconciliation: TBaselineReconciliationResult): TRegressionRunResult;
var
  I: Integer;
begin
  Result := Default(TRegressionRunResult);
  Result.ReportsDiscovered := AReportsDiscovered;
  SetLength(Result.Reports, Length(AReports));
  for I := 0 to High(AReports) do
    Result.Reports[I] := AReports[I];
  Result.BaselineCompared := ABaselineCompared;
  Result.BaselineUpdated := ABaselineUpdated;
  Result.Reconciliation := AReconciliation;
end;

class function TJsonRunFormatterTests.ParseJson(const AJson: string): TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  Assert.IsNotNull(Result, 'JSON document did not parse');
end;

function TJsonRunFormatterTests.FormatRun(const AResult: TRegressionRunResult;
  const AContext: TRunFormatContext): string;
begin
  Result := Fmt.FormatRunSummary(AResult, AContext);
end;

procedure TJsonRunFormatterTests.AssertContainsInOrder(const AJson, AFirst,
  ASecond: string);
var
  P1, P2: Integer;
begin
  P1 := Pos(AFirst, AJson);
  P2 := Pos(ASecond, AJson);
  Assert.IsTrue(P1 > 0, 'Expected first substring not found: ' + AFirst);
  Assert.IsTrue(P2 > 0, 'Expected second substring not found: ' + ASecond);
  Assert.IsTrue(P1 < P2, 'Expected substrings out of order');
end;

procedure TJsonRunFormatterTests.Setup;
begin
  Fmt := TJsonRunFormatter.Create;
end;

procedure TJsonRunFormatterTests.TearDown;
begin
    Fmt := nil;
end;

//  1. Empty run
procedure TJsonRunFormatterTests.Test_EmptyRun;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
begin
  Run := Default(TRegressionRunResult);
  Run.ReportsDiscovered := 0;
  Ctx := Default(TRunFormatContext);
  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Assert.AreEqual(1, Root.GetValue<Integer>('schema_version'));
    Assert.AreEqual(0, Root.GetValue<Integer>('reports_discovered'));
    Assert.AreEqual(0, Root.GetValue<Integer>('reports_checked'));
    Assert.AreEqual(0, Root.GetValue<Integer>('passed'));
    Assert.AreEqual(0, Root.GetValue<Integer>('failed'));
    Assert.AreEqual(0, Root.GetValue<Integer>('skipped'));
    Assert.AreEqual(0, Root.GetValue<Integer>('execution_failures'));
    Assert.IsFalse((Root.GetValue('baseline_compared') as TJSONBool).AsBoolean);
    Assert.IsFalse((Root.GetValue('baseline_updated') as TJSONBool).AsBoolean);
    Assert.IsTrue((Root.GetValue('successful') as TJSONBool).AsBoolean);
    Assert.IsTrue(Root.GetValue('reports') is TJSONArray);
    Assert.AreEqual(0, TJSONArray(Root.GetValue('reports')).Count);
    Assert.IsTrue(Root.GetValue('reconciliation') is TJSONNull);
    Assert.IsTrue(Root.GetValue('process') is TJSONNull);
  finally
    Root.Free;
  end;
end;

//  2. All-passed run
procedure TJsonRunFormatterTests.Test_AllPassed;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  Reports: TJSONArray;
begin
  Run := MakeRun(2, [
    MakeReport(resPassed, 'report1.vrt', 5, True, 0, False, '', 0),
    MakeReport(resPassed, 'report2.vrt', 3, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('report1.vrt', 100, 0, False, False, 0, 0),
    MakeObs('report2.vrt', 200, 0, False, False, 0, 0)
  ], False, 100, 120, 50, 60, 1024*1024, 2048*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Assert.AreEqual(2, Root.GetValue<Integer>('reports_discovered'));
    Assert.AreEqual(2, Root.GetValue<Integer>('passed'));
    Assert.AreEqual(0, Root.GetValue<Integer>('failed'));
    Assert.AreEqual(0, Root.GetValue<Integer>('skipped'));
    Assert.AreEqual(2, Root.GetValue<Integer>('reports_checked'));
    Assert.IsTrue((Root.GetValue('successful') as TJSONBool).AsBoolean);
    Assert.IsFalse((Root.GetValue('baseline_compared') as TJSONBool).AsBoolean);

    Reports := TJSONArray(Root.GetValue('reports'));
    Assert.AreEqual(2, Reports.Count);

    Assert.AreEqual('report1.vrt', TJSONObject(Reports.Items[0]).GetValue<string>('report', ''));
    Assert.AreEqual('passed', TJSONObject(Reports.Items[0]).GetValue<string>('status', ''));
    Assert.AreEqual(5, TJSONNumber(TJSONObject(Reports.Items[0]).GetValue('page_count')).AsInt);

    Assert.AreEqual('report2.vrt', TJSONObject(Reports.Items[1]).GetValue<string>('report', ''));
    Assert.AreEqual('passed', TJSONObject(Reports.Items[1]).GetValue<string>('status', ''));
        Assert.AreEqual(3, TJSONNumber(TJSONObject(Reports.Items[1]).GetValue('page_count')).AsInt);
  finally
    Root.Free;
  end;
end;

//  3. Mixed passed/failed/skipped
procedure TJsonRunFormatterTests.Test_MixedPassedFailedSkipped;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  Reports: TJSONArray;
begin
  Run := MakeRun(3, [
    MakeReport(resPassed, 'passed.vrt', 4, True, 0, False, '', 0),
    MakeReport(resFailed, 'failed.vrt', 0, False, 0, False, 'Test error', 0),
    MakeReport(resSkipped, 'skipped.vrt', 0, False, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('passed.vrt', 150, 0, False, False, 0, 0),
    MakeObs('failed.vrt', 50, 0, False, False, 0, 0),
    MakeObs('skipped.vrt', 0, 0, False, False, 0, 0)
  ], False, 100, 120, 50, 60, 1024*1024, 2048*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Assert.AreEqual(3, Root.GetValue<Integer>('reports_discovered'));
    Assert.AreEqual(1, Root.GetValue<Integer>('passed'));
    Assert.AreEqual(1, Root.GetValue<Integer>('failed'));
    Assert.AreEqual(1, Root.GetValue<Integer>('skipped'));
    Assert.IsFalse((Root.GetValue('successful') as TJSONBool).AsBoolean);

    Reports := TJSONArray(Root.GetValue('reports'));
    Assert.AreEqual(3, Reports.Count);

    Assert.AreEqual('passed', TJSONObject(Reports.Items[0]).GetValue<string>('status', ''));
    Assert.AreEqual('failed', TJSONObject(Reports.Items[1]).GetValue<string>('status', ''));
    Assert.AreEqual('skipped', TJSONObject(Reports.Items[2]).GetValue<string>('status', ''));
  finally
    Root.Free;
  end;
end;

//  4. Report passed
procedure TJsonRunFormatterTests.Test_Report_Passed;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 10, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('test.vrt', 250, 5, True, False, 0, 0)
  ], False, 100, 120, 50, 60, 1024*1024, 2048*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.AreEqual('test.vrt', ReportObj.GetValue<string>('report', ''));
    Assert.AreEqual('passed', ReportObj.GetValue<string>('status', ''));
    Assert.AreEqual(10, TJSONNumber(ReportObj.GetValue('page_count')).AsInt);
    Assert.AreEqual(250, TJSONNumber(ReportObj.GetValue('elapsed_ms')).AsInt);
        Assert.AreEqual(5, TJSONNumber(ReportObj.GetValue('gdi_cache_delta')).AsInt);
  finally
    Root.Free;
  end;
end;

//  5. Report failed
procedure TJsonRunFormatterTests.Test_Report_Failed;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resFailed, 'error.vrt', 0, False, 0, False, 'EClass: message', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('error.vrt', 100, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.AreEqual('error.vrt', ReportObj.GetValue<string>('report', ''));
    Assert.AreEqual('failed', ReportObj.GetValue<string>('status', ''));
    Assert.AreEqual('EClass: message', ReportObj.GetValue<string>('error_message', ''));
  finally
    Root.Free;
  end;
end;

//  6. Report skipped
procedure TJsonRunFormatterTests.Test_Report_Skipped;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resSkipped, 'skip.vrt', 0, False, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('skip.vrt', 0, 0, False, False, 0, 0)
  ], False, 100, 100, 50, 50, 1024*1024, 1024*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.AreEqual('skip.vrt', ReportObj.GetValue<string>('report', ''));
        Assert.AreEqual('skipped', ReportObj.GetValue<string>('status', ''));
  finally
    Root.Free;
  end;
end;

//  7. Report page count present
procedure TJsonRunFormatterTests.Test_Report_PageCountPresent;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'pages.vrt', 7, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('pages.vrt', 200, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.IsNotNull(ReportObj.GetValue('page_count'));
    Assert.IsTrue(ReportObj.GetValue('page_count') is TJSONNumber);
    Assert.AreEqual(7, TJSONNumber(ReportObj.GetValue('page_count')).AsInt);
  finally
    Root.Free;
  end;
end;

//  8. Report page count null
procedure TJsonRunFormatterTests.Test_Report_PageCountNull;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resFailed, 'no_pages.vrt', 0, False, 0, False, 'Error', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('no_pages.vrt', 50, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.IsTrue(ReportObj.GetValue('page_count') is TJSONNull);
  finally
    Root.Free;
  end;
end;

//  9. Report expected page count present
procedure TJsonRunFormatterTests.Test_Report_ExpectedPageCountPresent;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'expected.vrt', 5, True, 3, True, '', 0)
  ], True, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('expected.vrt', 200, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.IsNotNull(ReportObj.GetValue('expected_page_count'));
    Assert.IsTrue(ReportObj.GetValue('expected_page_count') is TJSONNumber);
        Assert.AreEqual(3, TJSONNumber(ReportObj.GetValue('expected_page_count')).AsInt);
  finally
    Root.Free;
  end;
end;

// 10. Report expected page count null
procedure TJsonRunFormatterTests.Test_Report_ExpectedPageCountNull;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'no_expected.vrt', 5, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('no_expected.vrt', 200, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.IsTrue(ReportObj.GetValue('expected_page_count') is TJSONNull);
  finally
    Root.Free;
  end;
end;

// 11. Report error message preserved
procedure TJsonRunFormatterTests.Test_Report_ErrorMessagePreserved;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resFailed, 'err.vrt', 0, False, 0, False, 'Custom error message', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('err.vrt', 100, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.AreEqual('Custom error message', ReportObj.GetValue<string>('error_message', ''));
  finally
    Root.Free;
  end;
end;

// 12. Report GDI leak delta
procedure TJsonRunFormatterTests.Test_Report_GdiLeakDelta;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resFailed, 'leak.vrt', 5, True, 0, False, '', 25)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('leak.vrt', 200, 10, False, False, 0, 0)
  ], False, 100, 120, 50, 60, 1024*1024, 2048*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.AreEqual(25, TJSONNumber(ReportObj.GetValue('gdi_leak_delta')).AsInt);
    Assert.AreEqual(10, TJSONNumber(ReportObj.GetValue('gdi_cache_delta')).AsInt);
  finally
    Root.Free;
  end;
end;

// 13. Report GDI cache delta
procedure TJsonRunFormatterTests.Test_Report_GdiCacheDelta;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'cache.vrt', 3, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('cache.vrt', 150, 15, False, False, 0, 0)
  ], False, 100, 115, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
        Assert.AreEqual(15, TJSONNumber(ReportObj.GetValue('gdi_cache_delta')).AsInt);
  finally
    Root.Free;
  end;
end;

// 14. Report elapsed ms
procedure TJsonRunFormatterTests.Test_Report_ElapsedMs;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'time.vrt', 2, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('time.vrt', 999, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.AreEqual(999, TJSONNumber(ReportObj.GetValue('elapsed_ms')).AsInt);
  finally
    Root.Free;
  end;
end;

// 15. Report script counts
procedure TJsonRunFormatterTests.Test_Report_ScriptCounts;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
  ScriptsObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'script.vrt', 3, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('script.vrt', 150, 0, False, True, 2, 3)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.IsTrue(ReportObj.GetValue('scripts') is TJSONObject);

    ScriptsObj := TJSONObject(ReportObj.GetValue('scripts'));
    Assert.AreEqual(2, TJSONNumber(ScriptsObj.GetValue('before')).AsInt);
    Assert.AreEqual(3, TJSONNumber(ScriptsObj.GetValue('after')).AsInt);
  finally
    Root.Free;
  end;
end;

// 16. Report script counts null
procedure TJsonRunFormatterTests.Test_Report_ScriptCountsNull;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'no_script.vrt', 3, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('no_script.vrt', 150, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
        Assert.IsTrue(ReportObj.GetValue('scripts') is TJSONNull);
  finally
    Root.Free;
  end;
end;

// 17. Reconciliation matching
procedure TJsonRunFormatterTests.Test_Reconciliation_Matching;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  RecObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 5, True, 5, True, '', 0)
  ], True, False, MakeReconciliation(1, 0, 0, 0, []));

  Ctx := MakeContext([
    MakeObs('test.vrt', 200, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    RecObj := TJSONObject(Root.GetValue('reconciliation'));
    Assert.AreEqual(1, TJSONNumber(RecObj.GetValue('matching')).AsInt);
    Assert.AreEqual(0, TJSONArray(RecObj.GetValue('issues')).Count);
  finally
    Root.Free;
  end;
end;

// 18. Reconciliation page count mismatch
procedure TJsonRunFormatterTests.Test_Reconciliation_PageCountMismatch;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  RecObj: TJSONObject;
  IssueObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'mismatch.vrt', 5, True, 3, True, '', 0)
  ], True, False, MakeReconciliation(0, 1, 0, 0, [
    MakeIssue(bikPageCountMismatch, 'mismatch.vrt', 3, 5, 'Mismatch')
  ]));

  Ctx := MakeContext([
    MakeObs('mismatch.vrt', 200, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    RecObj := TJSONObject(Root.GetValue('reconciliation'));
    Assert.AreEqual(1, TJSONNumber(RecObj.GetValue('page_count_mismatches')).AsInt);

    IssueObj := TJSONObject(TJSONArray(RecObj.GetValue('issues')).Items[0]);
    Assert.AreEqual('page_count_mismatch', IssueObj.GetValue<string>('kind', ''));
    Assert.AreEqual(3, TJSONNumber(IssueObj.GetValue('expected_pages')).AsInt);
    Assert.AreEqual(5, TJSONNumber(IssueObj.GetValue('actual_pages')).AsInt);
  finally
    Root.Free;
  end;
end;

// 19. Reconciliation missing baseline
procedure TJsonRunFormatterTests.Test_Reconciliation_MissingBaseline;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  RecObj: TJSONObject;
  IssueObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'new.vrt', 3, True, 0, False, '', 0)
  ], True, False, MakeReconciliation(0, 0, 1, 0, [
    MakeIssue(bikMissingBaseline, 'new.vrt', 0, 3, 'Missing baseline')
  ]));

  Ctx := MakeContext([
    MakeObs('new.vrt', 200, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    RecObj := TJSONObject(Root.GetValue('reconciliation'));
    Assert.AreEqual(1, TJSONNumber(RecObj.GetValue('missing_baselines')).AsInt);

    IssueObj := TJSONObject(TJSONArray(RecObj.GetValue('issues')).Items[0]);
    Assert.AreEqual('missing_baseline', IssueObj.GetValue<string>('kind', ''));
    Assert.IsTrue(IssueObj.GetValue('expected_pages') is TJSONNull);
    Assert.AreEqual(3, TJSONNumber(IssueObj.GetValue('actual_pages')).AsInt);
  finally
    Root.Free;
  end;
end;

// 20. Reconciliation orphan baseline
procedure TJsonRunFormatterTests.Test_Reconciliation_OrphanBaseline;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  RecObj: TJSONObject;
  IssueObj: TJSONObject;
begin
  Run := MakeRun(0, [], True, False, MakeReconciliation(0, 0, 0, 1, [
    MakeIssue(bikOrphanBaseline, 'orphan.vrt', 5, 0, 'Orphan baseline')
  ]));

  Ctx := MakeContext([
  ], False, 100, 100, 50, 50, 1024*1024, 1024*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    RecObj := TJSONObject(Root.GetValue('reconciliation'));
    Assert.AreEqual(1, TJSONNumber(RecObj.GetValue('orphan_baselines')).AsInt);

    IssueObj := TJSONObject(TJSONArray(RecObj.GetValue('issues')).Items[0]);
    Assert.AreEqual('orphan_baseline', IssueObj.GetValue<string>('kind', ''));
    Assert.AreEqual(5, TJSONNumber(IssueObj.GetValue('expected_pages')).AsInt);
    Assert.IsTrue(IssueObj.GetValue('actual_pages') is TJSONNull);
  finally
    Root.Free;
  end;
end;

// 21. Reconciliation multiple issues
procedure TJsonRunFormatterTests.Test_Reconciliation_MultipleIssues;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  RecObj: TJSONObject;
  Issues: TJSONArray;
begin
  Run := MakeRun(2, [
    MakeReport(resPassed, 'report1.vrt', 5, True, 3, True, '', 0),
    MakeReport(resPassed, 'report2.vrt', 2, True, 0, False, '', 0)
  ], True, False, MakeReconciliation(1, 1, 1, 0, [
    MakeIssue(bikPageCountMismatch, 'report1.vrt', 3, 5, 'Mismatch'),
    MakeIssue(bikMissingBaseline, 'report2.vrt', 0, 2, 'Missing')
  ]));

  Ctx := MakeContext([
    MakeObs('report1.vrt', 200, 0, False, False, 0, 0),
    MakeObs('report2.vrt', 100, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    RecObj := TJSONObject(Root.GetValue('reconciliation'));
    Issues := TJSONArray(RecObj.GetValue('issues'));
    Assert.AreEqual(2, Issues.Count);
  finally
    Root.Free;
  end;
end;

// 22. Reconciliation null (non-strict)
procedure TJsonRunFormatterTests.Test_Reconciliation_Null;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 5, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('test.vrt', 200, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Assert.IsFalse((Root.GetValue('baseline_compared') as TJSONBool).AsBoolean);
        Assert.IsTrue(Root.GetValue('reconciliation') is TJSONNull);
  finally
    Root.Free;
  end;
end;

// 23. RunState strict success
procedure TJsonRunFormatterTests.Test_RunState_StrictSuccess;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 5, True, 5, True, '', 0)
  ], True, False, MakeReconciliation(1, 0, 0, 0, []));

  Ctx := MakeContext([
    MakeObs('test.vrt', 200, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Assert.IsTrue((Root.GetValue('baseline_compared') as TJSONBool).AsBoolean);
    Assert.IsTrue((Root.GetValue('successful') as TJSONBool).AsBoolean);
    Assert.IsFalse(Root.GetValue('reconciliation') is TJSONNull);
  finally
    Root.Free;
  end;
end;

// 24. RunState strict reconciliation failure
procedure TJsonRunFormatterTests.Test_RunState_StrictReconciliationFailure;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 5, True, 3, True, '', 0)
  ], True, False, MakeReconciliation(0, 1, 0, 0, [
    MakeIssue(bikPageCountMismatch, 'test.vrt', 3, 5, 'Mismatch')
  ]));

  Ctx := MakeContext([
    MakeObs('test.vrt', 200, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Assert.IsFalse((Root.GetValue('successful') as TJSONBool).AsBoolean);
    Assert.AreEqual(1, TJSONNumber(TJSONObject(Root.GetValue('reconciliation')).GetValue('page_count_mismatches')).AsInt);
  finally
    Root.Free;
  end;
end;

// 25. RunState strict execution failure
procedure TJsonRunFormatterTests.Test_RunState_StrictExecutionFailure;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resFailed, 'test.vrt', 0, False, 0, False, 'Execution error', 0)
  ], True, False, MakeReconciliation(0, 0, 0, 0, []));

  Ctx := MakeContext([
    MakeObs('test.vrt', 100, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Assert.IsFalse((Root.GetValue('successful') as TJSONBool).AsBoolean);
    Assert.AreEqual(1, Root.GetValue<Integer>('failed'));
  finally
    Root.Free;
  end;
end;

// 26. RunState non-strict success
procedure TJsonRunFormatterTests.Test_RunState_NonStrictSuccess;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 5, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('test.vrt', 200, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Assert.IsFalse((Root.GetValue('baseline_compared') as TJSONBool).AsBoolean);
    Assert.IsTrue((Root.GetValue('successful') as TJSONBool).AsBoolean);
    Assert.IsTrue(Root.GetValue('reconciliation') is TJSONNull);
  finally
    Root.Free;
  end;
end;

// 27. RunState non-strict failure
procedure TJsonRunFormatterTests.Test_RunState_NonStrictFailure;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resFailed, 'test.vrt', 0, False, 0, False, 'Error', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('test.vrt', 100, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Assert.IsFalse((Root.GetValue('successful') as TJSONBool).AsBoolean);
    Assert.AreEqual(1, Root.GetValue<Integer>('failed'));
  finally
    Root.Free;
  end;
end;

// 28. RunState baseline updated only success
procedure TJsonRunFormatterTests.Test_RunState_BaselineUpdatedOnlySuccess;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'new.vrt', 3, True, 0, False, '', 0)
  ], False, True, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('new.vrt', 200, 0, False, False, 0, 0)
  ], False, 100, 110, 50, 55, 1024*1024, 1500*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Assert.IsFalse((Root.GetValue('baseline_compared') as TJSONBool).AsBoolean);
    Assert.IsTrue((Root.GetValue('baseline_updated') as TJSONBool).AsBoolean);
        Assert.IsTrue((Root.GetValue('successful') as TJSONBool).AsBoolean);
  finally
    Root.Free;
  end;
end;

// 29. Process present
procedure TJsonRunFormatterTests.Test_Process_Present;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ProcObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 5, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('test.vrt', 200, 0, False, False, 0, 0)
  ], True, 100, 120, 50, 60, 1024*1024, 2048*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Assert.IsTrue(Root.GetValue('process') is TJSONObject);

    ProcObj := TJSONObject(Root.GetValue('process'));
    Assert.IsNotNull(ProcObj.GetValue('gdi_handles'));
    Assert.IsNotNull(ProcObj.GetValue('user_handles'));
    Assert.IsNotNull(ProcObj.GetValue('memory_bytes'));
  finally
    Root.Free;
  end;
end;

// 30. Process null
procedure TJsonRunFormatterTests.Test_Process_Null;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 5, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

    Ctx := MakeContext([
    MakeObs('test.vrt', 200, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Assert.IsTrue(Root.GetValue('process') is TJSONNull);
  finally
    Root.Free;
  end;
end;

// 31. Process resource values
procedure TJsonRunFormatterTests.Test_Process_ResourceValues;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ProcObj: TJSONObject;
  GdiObj: TJSONObject;
  UserObj: TJSONObject;
  MemObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 5, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('test.vrt', 200, 0, False, False, 0, 0)
  ], True, 100, 120, 50, 60, 1024*1024, 2048*1024);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ProcObj := TJSONObject(Root.GetValue('process'));

    GdiObj := TJSONObject(ProcObj.GetValue('gdi_handles'));
    Assert.AreEqual(100, TJSONNumber(GdiObj.GetValue('start')).AsInt);
    Assert.AreEqual(120, TJSONNumber(GdiObj.GetValue('end')).AsInt);
    Assert.AreEqual(20, TJSONNumber(GdiObj.GetValue('delta')).AsInt);

    UserObj := TJSONObject(ProcObj.GetValue('user_handles'));
    Assert.AreEqual(50, TJSONNumber(UserObj.GetValue('start')).AsInt);
    Assert.AreEqual(60, TJSONNumber(UserObj.GetValue('end')).AsInt);
    Assert.AreEqual(10, TJSONNumber(UserObj.GetValue('delta')).AsInt);

    MemObj := TJSONObject(ProcObj.GetValue('memory_bytes'));
    Assert.AreEqual(1024*1024, TJSONNumber(MemObj.GetValue('start')).AsInt);
    Assert.AreEqual(2048*1024, TJSONNumber(MemObj.GetValue('end')).AsInt);
        Assert.AreEqual(1024*1024, TJSONNumber(MemObj.GetValue('delta')).AsInt);
  finally
    Root.Free;
  end;
end;

// 32. JSON parses
procedure TJsonRunFormatterTests.Test_JSON_Parses;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 1, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('test.vrt', 100, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  Assert.IsNotNull(Root);
  Root.Free;
end;

// 33. JSON null handling
procedure TJsonRunFormatterTests.Test_JSON_NullHandling;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resFailed, 'null.vrt', 0, False, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('null.vrt', 0, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
        Assert.IsTrue(ReportObj.GetValue('page_count') is TJSONNull);
    Assert.IsTrue(ReportObj.GetValue('expected_page_count') is TJSONNull);
  finally
    Root.Free;
  end;
end;

// 34. JSON quote escaping
procedure TJsonRunFormatterTests.Test_JSON_QuoteEscaping;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resFailed, 'quote.vrt', 0, False, 0, False, 'Message with "quotes"', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('quote.vrt', 100, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.AreEqual('Message with "quotes"', ReportObj.GetValue<string>('error_message', ''));
  finally
    Root.Free;
  end;
end;

// 35. JSON backslash escaping
procedure TJsonRunFormatterTests.Test_JSON_BackslashEscaping;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resFailed, 'backslash.vrt', 0, False, 0, False, 'Path\with\backslash', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('backslash.vrt', 100, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.AreEqual('Path\with\backslash', ReportObj.GetValue<string>('error_message', ''));
  finally
    Root.Free;
  end;
end;

// 36. JSON control character escaping
procedure TJsonRunFormatterTests.Test_JSON_ControlCharacterEscaping;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resFailed, 'control.vrt', 0, False, 0, False, 'Line1'#10'Line2', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('control.vrt', 100, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
    Assert.AreEqual('Line1'#10'Line2', ReportObj.GetValue<string>('error_message', ''));
  finally
    Root.Free;
  end;
end;

// 37. JSON unicode
procedure TJsonRunFormatterTests.Test_JSON_Unicode;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Root: TJSONObject;
  ReportObj: TJSONObject;
begin
  Run := MakeRun(1, [
    MakeReport(resFailed, 'unicode.vrt', 0, False, 0, False, 'Caf\u00E9 - \u00E9', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('unicode.vrt', 100, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    ReportObj := TJSONObject(TJSONArray(Root.GetValue('reports')).Items[0]);
        Assert.AreEqual('Caf\u00E9 - \u00E9', ReportObj.GetValue<string>('error_message', ''));
  finally
    Root.Free;
  end;
end;

// 38. JSON root property ordering
procedure TJsonRunFormatterTests.Test_JSON_RootPropertyOrdering;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 1, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('test.vrt', 100, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);

  AssertContainsInOrder(Json, '"schema_version"', '"reports_discovered"');
  AssertContainsInOrder(Json, '"reports_discovered"', '"reports_checked"');
  AssertContainsInOrder(Json, '"reports_checked"', '"passed"');
  AssertContainsInOrder(Json, '"passed"', '"failed"');
  AssertContainsInOrder(Json, '"failed"', '"skipped"');
  AssertContainsInOrder(Json, '"skipped"', '"execution_failures"');
  AssertContainsInOrder(Json, '"execution_failures"', '"baseline_compared"');
  AssertContainsInOrder(Json, '"baseline_compared"', '"baseline_updated"');
  AssertContainsInOrder(Json, '"baseline_updated"', '"successful"');
  AssertContainsInOrder(Json, '"successful"', '"reports"');
  AssertContainsInOrder(Json, '"reports"', '"reconciliation"');
  AssertContainsInOrder(Json, '"reconciliation"', '"process"');
end;

// 39. JSON report property ordering
procedure TJsonRunFormatterTests.Test_JSON_ReportPropertyOrdering;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  StartIdx, EndIdx: Integer;
  ReportSection: string;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 1, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('test.vrt', 100, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);

  StartIdx := Pos('"report":', Json);
  EndIdx := Pos('}],"reconciliation"', Json);
  Assert.IsTrue(StartIdx > 0, 'Report section not found');
  Assert.IsTrue(EndIdx > StartIdx, 'Process section not found after report');
  Delete(Json, EndIdx, Length(Json) - EndIdx + 1);
  Delete(Json, 1, StartIdx - 1);
  ReportSection := Json;

  AssertContainsInOrder(ReportSection, '"report"', '"status"');
  AssertContainsInOrder(ReportSection, '"status"', '"page_count"');
  AssertContainsInOrder(ReportSection, '"page_count"', '"expected_page_count"');
  AssertContainsInOrder(ReportSection, '"expected_page_count"', '"error_message"');
  AssertContainsInOrder(ReportSection, '"error_message"', '"elapsed_ms"');
  AssertContainsInOrder(ReportSection, '"elapsed_ms"', '"gdi_leak_delta"');
  AssertContainsInOrder(ReportSection, '"gdi_leak_delta"', '"gdi_cache_delta"');
  AssertContainsInOrder(ReportSection, '"gdi_cache_delta"', '"scripts"');
end;

// 40. JSON issue property ordering
procedure TJsonRunFormatterTests.Test_JSON_IssuePropertyOrdering;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  RecObj: TJSONObject;
  Issues: TJSONArray;
  IssueObj: TJSONObject;
  IssueJson: string;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 5, True, 3, True, '', 0)
  ], True, False, MakeReconciliation(0, 1, 0, 0, [
    MakeIssue(bikPageCountMismatch, 'test.vrt', 3, 5, 'Mismatch')
  ]));

  Ctx := MakeContext([
    MakeObs('test.vrt', 200, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  RecObj := TJSONObject(ParseJson(Json));
  try
    Issues := TJSONArray(TJSONObject(RecObj.GetValue('reconciliation')).GetValue('issues'));
    IssueObj := TJSONObject(Issues.Items[0]);

    IssueJson := IssueObj.ToJSON;
    AssertContainsInOrder(IssueJson, '"kind"', '"report"');
    AssertContainsInOrder(IssueJson, '"report"', '"expected_pages"');
    AssertContainsInOrder(IssueJson, '"expected_pages"', '"actual_pages"');
        AssertContainsInOrder(IssueJson, '"actual_pages"', '"message"');
  finally
    RecObj.Free;
  end;
end;

// 41. JSON report ordering
procedure TJsonRunFormatterTests.Test_JSON_ReportOrdering;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  Reports: TJSONArray;
  Root: TJSONObject;
begin
  Run := MakeRun(3, [
    MakeReport(resPassed, 'first.vrt', 1, True, 0, False, '', 0),
    MakeReport(resPassed, 'second.vrt', 2, True, 0, False, '', 0),
    MakeReport(resPassed, 'third.vrt', 3, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('first.vrt', 100, 0, False, False, 0, 0),
    MakeObs('second.vrt', 200, 0, False, False, 0, 0),
    MakeObs('third.vrt', 300, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  Root := ParseJson(Json);
  try
    Reports := TJSONArray(Root.GetValue('reports'));
    Assert.AreEqual('first.vrt', TJSONObject(Reports.Items[0]).GetValue<string>('report', ''));
    Assert.AreEqual('second.vrt', TJSONObject(Reports.Items[1]).GetValue<string>('report', ''));
    Assert.AreEqual('third.vrt', TJSONObject(Reports.Items[2]).GetValue<string>('report', ''));
  finally
    Root.Free;
  end;
end;

// 42. JSON issue ordering
procedure TJsonRunFormatterTests.Test_JSON_IssueOrdering;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Json: string;
  RecObj: TJSONObject;
  Issues: TJSONArray;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'test.vrt', 5, True, 3, True, '', 0)
  ], True, False, MakeReconciliation(0, 1, 0, 0, [
    MakeIssue(bikPageCountMismatch, 'test.vrt', 3, 5, 'First issue'),
    MakeIssue(bikMissingBaseline, 'test.vrt', 0, 5, 'Second issue')
  ]));

  Ctx := MakeContext([
    MakeObs('test.vrt', 200, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  Json := FormatRun(Run, Ctx);
  RecObj := TJSONObject(ParseJson(Json));
  try
    Issues := TJSONArray(TJSONObject(RecObj.GetValue('reconciliation')).GetValue('issues'));
    Assert.AreEqual(2, Issues.Count);
    Assert.AreEqual('page_count_mismatch', TJSONObject(Issues.Items[0]).GetValue<string>('kind', ''));
    Assert.AreEqual('missing_baseline', TJSONObject(Issues.Items[1]).GetValue<string>('kind', ''));
  finally
    RecObj.Free;
  end;
end;

// 43. JSON inconsistent observations fail
procedure TJsonRunFormatterTests.Test_JSON_InconsistentObservationsFail;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, 'report1.vrt', 1, True, 0, False, '', 0)
  ], False, False, Default(TBaselineReconciliationResult));

  Ctx := MakeContext([
    MakeObs('report2.vrt', 100, 0, False, False, 0, 0)
  ], False, 0, 0, 0, 0, 0, 0);

  try
    FormatRun(Run, Ctx);
    Assert.Fail('Expected exception for inconsistent observations');
  except
    on E: Exception do
    begin
      Assert.IsTrue(E.Message.Contains('mismatch') or E.Message.Contains('observation'),
        'Expected observation mismatch error, got: ' + E.Message);
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TJsonRunFormatterTests);

end.

