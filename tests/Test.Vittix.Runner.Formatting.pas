unit Test.Vittix.Runner.Formatting;

{
  Phase 3D-4: formatter boundary tests.

  Pure DUnitX tests over TTextRunFormatter against EXACT expected strings
  (the legacy format strings copied verbatim from Console.pas). No report
  execution, no filesystem, no process or VCL access.

  The canonical reports/regression_baselines.json is never touched:
  TRegressionRunResult / TRunFormatContext values are built in memory only.
}

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Vittix.Runner.Baseline,
  Vittix.Runner.Formatting,
  Vittix.Runner.Results,
  Vittix.Runner.TextFormatter;

type
  [TestFixture]
  TRunnerFormattingTests = class
  private
    Fmt: IRunResultFormatter;

    class function MakeReport(AStatus: TReportExecutionStatus;
      const AName: string; APages: Integer; AHasPages: Boolean;
      const AError: string; ALeakDelta: Integer): TReportExecutionResult; static;

    class function MakeObs(const AName: string; AElapsedMs: Int64;
      AGdiCacheDelta: Integer; AHtmlOk, AHasScripts: Boolean;
      ABefore, AAfter: Integer): TReportExecutionObservation; static;

    class function MakeIssue(AKind: TBaselineIssueKind;
      const AName: string; AExpected, AActual: Integer): TBaselineIssue; static;

    class function MakeReconciliation(AMatching: Integer;
      const AIssues: array of TBaselineIssue): TBaselineReconciliationResult; static;

    class function MakeContext(const AObs: array of TReportExecutionObservation;
      AHasProcess: Boolean;
      AStartGDI, AEndGDI, AStartUser, AEndUser: Cardinal;
      AStartMem, AEndMem: Int64;
      AHasStrict: Boolean; AStrictFailed: Boolean;
      AStrictErrors: Integer): TRunFormatContext; static;

    function MakeRun(AReportsDiscovered: Integer;
      const AReports: array of TReportExecutionResult;
      ABaselineCompared: Boolean; ABaselineUpdated: Boolean;
      const AReconciliation: TBaselineReconciliationResult): TRegressionRunResult;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    //  1. Empty run
    [Test] procedure Test_EmptyRun;
    //  2. All-passed run
    [Test] procedure Test_AllPassedRun;
    //  3. Mixed passed/failed/skipped
    [Test] procedure Test_MixedPassedFailedSkipped;
    //  4. Execution failure
    [Test] procedure Test_ExecutionFailure;
    //  5. GDI leak
    [Test] procedure Test_GdiLeak;
    //  6. GDI cache delta 1..24
    [Test] procedure Test_GdiCacheDeltaSmall;
    //  7. GDI delta 0
    [Test] procedure Test_GdiDeltaZero;
    //  8. HTML PASS variant
    [Test] procedure Test_HtmlPassVariant;
    //  9. Non-HTML PASS variant
    [Test] procedure Test_NonHtmlPassVariant;
    // 10. Non-strict pagination mismatch
    [Test] procedure Test_PaginationMismatch;
    // 11. Run summary
    [Test] procedure Test_RunSummary;
    // 12. Process GDI/USER/Memory summary
    [Test] procedure Test_ProcessResourceSummary;
    // 13. Strict success
    [Test] procedure Test_Strict_Success;
    // 14. Strict mismatch
    [Test] procedure Test_Strict_Mismatch;
    // 15. Strict missing baseline
    [Test] procedure Test_Strict_MissingBaseline;
    // 16. Strict orphan baseline
    [Test] procedure Test_Strict_OrphanBaseline;
    // 17. Strict baseline updated
    [Test] procedure Test_Strict_BaselineUpdated;
    // 18. Skipped report
    [Test] procedure Test_SkippedReport;
    // 19. Expected page count present
    [Test] procedure Test_ExpectedPageCountPresent;
    // 20. Expected page count absent
    [Test] procedure Test_ExpectedPageCountAbsent;
    // 21. Empty error message
    [Test] procedure Test_EmptyError;
    // 22. Exact error-message preservation
    [Test] procedure Test_ExactErrorPreservation;
  end;

const
  // The two 48-character separators, copied verbatim from Console.pas.
  SepLine = '================================================';
  DashLine = '------------------------------------------------';
  // Exactly 40 characters so %-40s inserts no padding and expected strings
  // stay exact and readable.
  Name40 = '1234567890123456789012345678901234567890';

implementation

{ TRunnerFormattingTests }

procedure TRunnerFormattingTests.Setup;
begin
  Fmt := TTextRunFormatter.Create;
end;

procedure TRunnerFormattingTests.TearDown;
begin
  Fmt := nil;
end;

class function TRunnerFormattingTests.MakeReport(AStatus: TReportExecutionStatus;
  const AName: string; APages: Integer; AHasPages: Boolean;
  const AError: string; ALeakDelta: Integer): TReportExecutionResult;
begin
  Result := Default(TReportExecutionResult);
  Result.ReportName := AName;
  Result.Status := AStatus;
  Result.PageCount := APages;
  Result.HasPageCount := AHasPages;
  Result.ErrorMessage := AError;
  Result.GdiLeakDelta := ALeakDelta;
end;

class function TRunnerFormattingTests.MakeObs(const AName: string;
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

class function TRunnerFormattingTests.MakeIssue(AKind: TBaselineIssueKind;
  const AName: string; AExpected, AActual: Integer): TBaselineIssue;
begin
  Result := Default(TBaselineIssue);
  Result.Kind := AKind;
  Result.ReportName := AName;
  Result.ExpectedPages := AExpected;
  Result.ActualPages := AActual;
end;

class function TRunnerFormattingTests.MakeReconciliation(AMatching: Integer;
  const AIssues: array of TBaselineIssue): TBaselineReconciliationResult;
var
  I: Integer;
begin
  Result := Default(TBaselineReconciliationResult);
  Result.MatchingCount := AMatching;
  SetLength(Result.Issues, Length(AIssues));
  for I := 0 to High(AIssues) do
    Result.Issues[I] := AIssues[I];
  for I := 0 to High(AIssues) do
    case AIssues[I].Kind of
      bikPageCountMismatch: Inc(Result.PageMismatchCount);
      bikMissingBaseline: Inc(Result.MissingBaselineCount);
      bikOrphanBaseline: Inc(Result.OrphanBaselineCount);
    end;
end;

class function TRunnerFormattingTests.MakeContext(
  const AObs: array of TReportExecutionObservation;
  AHasProcess: Boolean;
  AStartGDI, AEndGDI, AStartUser, AEndUser: Cardinal;
  AStartMem, AEndMem: Int64;
  AHasStrict: Boolean; AStrictFailed: Boolean;
  AStrictErrors: Integer): TRunFormatContext;
var
  I: Integer;
begin
  Result := Default(TRunFormatContext);
  SetLength(Result.ReportObservations, Length(AObs));
  for I := 0 to High(AObs) do
    Result.ReportObservations[I] := AObs[I];
  Result.HasProcessSummary := AHasProcess;
  Result.Process.StartGDI := AStartGDI;
  Result.Process.EndGDI := AEndGDI;
  Result.Process.StartUser := AStartUser;
  Result.Process.EndUser := AEndUser;
  Result.Process.StartMem := AStartMem;
  Result.Process.EndMem := AEndMem;
  Result.HasStrictSummary := AHasStrict;
  Result.&Strict.Failed := AStrictFailed;
  Result.&Strict.ExecutionErrorCount := AStrictErrors;
end;

function TRunnerFormattingTests.MakeRun(AReportsDiscovered: Integer;
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

//  1. Empty run: zero reports produce the exact zeroed legacy summary.
procedure TRunnerFormattingTests.Test_EmptyRun;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
begin
  Run := MakeRun(0, [], False, False, Default(TBaselineReconciliationResult));
  Ctx := MakeContext([], True, 16, 16, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    SepLine + sLineBreak +
    ' Results: 0 Passed, 0 Failed, 0 Skipped' + sLineBreak +
    DashLine + sLineBreak +
    ' GDI Handles : 16 -> 16 (Delta: 0)' + sLineBreak +
    ' USER Handles: 10 -> 10 (Delta: 0)' + sLineBreak +
    ' Memory Alloc: 0 KB -> 0 KB (Delta: 0 KB)' + sLineBreak +
    SepLine,
    Fmt.FormatRunSummary(Run, Ctx));
end;

//  2. All-passed run: plain PASS line (delta 0) plus the 1/0/0 summary.
procedure TRunnerFormattingTests.Test_AllPassedRun;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  Rep: TReportExecutionResult;
begin
  Rep := MakeReport(resPassed, '01_simple_masterdata.vrt', 6, True, '', 0);
  Run := MakeRun(1, [Rep], False, False, Default(TBaselineReconciliationResult));
  Ctx := MakeContext([
    MakeObs('01_simple_masterdata.vrt', 27, 0, False, False, 0, 0)],
    True, 16, 24, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    '[PASS] 01_simple_masterdata.vrt                 |   6 pgs |   27 ms | Vector PDF OK',
    Fmt.FormatReportLine(Rep, Ctx));

  Assert.AreEqual(
    SepLine + sLineBreak +
    ' Results: 1 Passed, 0 Failed, 0 Skipped' + sLineBreak +
    DashLine + sLineBreak +
    ' GDI Handles : 16 -> 24 (Delta: 8)' + sLineBreak +
    ' USER Handles: 10 -> 10 (Delta: 0)' + sLineBreak +
    ' Memory Alloc: 0 KB -> 0 KB (Delta: 0 KB)' + sLineBreak +
    SepLine,
    Fmt.FormatRunSummary(Run, Ctx));
end;

//  3. Mixed passed/failed/skipped: every report line and the 1/1/1 summary.
procedure TRunnerFormattingTests.Test_MixedPassedFailedSkipped;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  P, F, S: TReportExecutionResult;
begin
  P := MakeReport(resPassed, '09_passed.vrt', 5, True, '', 0);
  F := MakeReport(resFailed, '10_failed.vrt', 0, False,
    'EReportEngine: engine crashed', 0);
  S := MakeReport(resSkipped, '11_skipped.vrt', 0, False, '', 0);
  Run := MakeRun(3, [P, F, S], False, False,
    Default(TBaselineReconciliationResult));
  Ctx := MakeContext([
    MakeObs('09_passed.vrt', 15, 0, False, False, 0, 0),
    MakeObs('10_failed.vrt', 0, 0, False, False, 0, 0),
    MakeObs('11_skipped.vrt', 0, 0, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK',
      ['09_passed.vrt', 5, 15]),
    Fmt.FormatReportLine(P, Ctx));
  Assert.AreEqual(
    Format('[FAIL] %-40s | %s', ['10_failed.vrt', 'EReportEngine: engine crashed']),
    Fmt.FormatReportLine(F, Ctx));
  Assert.AreEqual(
    Format('[SKIP] %-40s', ['11_skipped.vrt']),
    Fmt.FormatReportLine(S, Ctx));

  Assert.IsTrue(Pos(' Results: 1 Passed, 1 Failed, 1 Skipped',
    Fmt.FormatRunSummary(Run, Ctx)) > 0);
end;

//  4. Execution failure: exact [FAIL] line with the error text.
procedure TRunnerFormattingTests.Test_ExecutionFailure;
var
  Ctx: TRunFormatContext;
  Rep: TReportExecutionResult;
begin
  Rep := MakeReport(resFailed, '04_crash.vrt', 0, False,
    'EReportEngine: engine crashed', 0);
  Ctx := MakeContext([
    MakeObs('04_crash.vrt', 0, 0, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[FAIL] %-40s | %s',
      ['04_crash.vrt', 'EReportEngine: engine crashed']),
    Fmt.FormatReportLine(Rep, Ctx));
end;

//  5. GDI leak: delta >= 25 renders the exact [LEAK] line. The report is
//  recorded the way the runner records it (resPassed with GdiLeakDelta and
//  a matching observation delta >= 25).
procedure TRunnerFormattingTests.Test_GdiLeak;
var
  Ctx: TRunFormatContext;
  Rep: TReportExecutionResult;
begin
  Rep := MakeReport(resPassed, '06_leak.vrt', 6, True, '', 31);
  Ctx := MakeContext([
    MakeObs('06_leak.vrt', 25, 31, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[LEAK] %-40s | %3d pgs | %4d ms | GDI Delta: +%d',
      ['06_leak.vrt', 6, 25, 31]),
    Fmt.FormatReportLine(Rep, Ctx));
end;

//  6. GDI cache delta 1..24: PASS lines annotated with | VCL Cache: +N.
procedure TRunnerFormattingTests.Test_GdiCacheDeltaSmall;
var
  Ctx1, Ctx24: TRunFormatContext;
  Rep1, Rep24: TReportExecutionResult;
begin
  Rep1 := MakeReport(resPassed, '07_cache.vrt', 6, True, '', 0);
  Rep24 := MakeReport(resPassed, '07_cache_24.vrt', 7, True, '', 0);
  Ctx1 := MakeContext([
    MakeObs('07_cache.vrt', 25, 1, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);
  Ctx24 := MakeContext([
    MakeObs('07_cache_24.vrt', 34, 24, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK | VCL Cache: +%d',
      ['07_cache.vrt', 6, 25, 1]),
    Fmt.FormatReportLine(Rep1, Ctx1));
  Assert.AreEqual(
    Format('[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK | VCL Cache: +%d',
      ['07_cache_24.vrt', 7, 34, 24]),
    Fmt.FormatReportLine(Rep24, Ctx24));
end;

//  7. GDI delta 0: plain PASS line without the VCL cache annotation.
procedure TRunnerFormattingTests.Test_GdiDeltaZero;
var
  Ctx: TRunFormatContext;
  Rep: TReportExecutionResult;
begin
  Rep := MakeReport(resPassed, '08_plain.vrt', 6, True, '', 0);
  Ctx := MakeContext([
    MakeObs('08_plain.vrt', 25, 0, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK',
      ['08_plain.vrt', 6, 25]),
    Fmt.FormatReportLine(Rep, Ctx));
end;
//  8. HTML PASS variant: delta 0 with HtmlSmokeOk renders | HTML OK.
procedure TRunnerFormattingTests.Test_HtmlPassVariant;
var
  Ctx: TRunFormatContext;
  Rep: TReportExecutionResult;
begin
  Rep := MakeReport(resPassed, '38_export_html.vrt', 1, True, '', 0);
  Ctx := MakeContext([
    MakeObs('38_export_html.vrt', 3, 0, True, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK | HTML OK',
      ['38_export_html.vrt', 1, 3]),
    Fmt.FormatReportLine(Rep, Ctx));
end;

//  9. Non-HTML PASS variant: delta 0 without HtmlSmokeOk stays plain.
procedure TRunnerFormattingTests.Test_NonHtmlPassVariant;
var
  Ctx: TRunFormatContext;
  Rep: TReportExecutionResult;
begin
  Rep := MakeReport(resPassed, '01_simple_masterdata.vrt', 6, True, '', 0);
  Ctx := MakeContext([
    MakeObs('01_simple_masterdata.vrt', 27, 0, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK',
      ['01_simple_masterdata.vrt', 6, 27]),
    Fmt.FormatReportLine(Rep, Ctx));
end;

// 10. Non-strict pagination mismatch: the exact legacy error text is kept.
procedure TRunnerFormattingTests.Test_PaginationMismatch;
var
  Ctx: TRunFormatContext;
  Rep: TReportExecutionResult;
begin
  Rep := MakeReport(resFailed, '33_invoice_multipage_contract.vrt', 8, True,
    'Pagination mismatch: Expected 9 pages, got 8', 0);
  Ctx := MakeContext([
    MakeObs('33_invoice_multipage_contract.vrt', 14, 0, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[FAIL] %-40s | %s',
      ['33_invoice_multipage_contract.vrt',
       'Pagination mismatch: Expected 9 pages, got 8']),
    Fmt.FormatReportLine(Rep, Ctx));
end;

// 11. Run summary: mixed counts and the exact separator/process block.
procedure TRunnerFormattingTests.Test_RunSummary;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
  P1, P2, F, S: TReportExecutionResult;
begin
  P1 := MakeReport(resPassed, '01_passed.vrt', 5, True, '', 0);
  P2 := MakeReport(resPassed, '02_passed.vrt', 6, True, '', 0);
  F := MakeReport(resFailed, '03_failed.vrt', 0, False, 'EDemo: failed', 0);
  S := MakeReport(resSkipped, '04_skipped.vrt', 0, False, '', 0);
  Run := MakeRun(4, [P1, P2, F, S], False, False,
    Default(TBaselineReconciliationResult));
  Ctx := MakeContext([], True, 16, 24, 10, 17, 1024, 5120,
    False, False, 0);

  Assert.AreEqual(
    SepLine + sLineBreak +
    ' Results: 2 Passed, 1 Failed, 1 Skipped' + sLineBreak +
    DashLine + sLineBreak +
    ' GDI Handles : 16 -> 24 (Delta: 8)' + sLineBreak +
    ' USER Handles: 10 -> 17 (Delta: 7)' + sLineBreak +
    ' Memory Alloc: 1 KB -> 5 KB (Delta: 4 KB)' + sLineBreak +
    SepLine,
    Fmt.FormatRunSummary(Run, Ctx));
end;

// 12. Process resource summary: exact GDI/USER/Memory lines for given
//  Start/End values (memory deltas are integer KB divisions).
procedure TRunnerFormattingTests.Test_ProcessResourceSummary;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
begin
  Run := MakeRun(0, [], False, False, Default(TBaselineReconciliationResult));
  Ctx := MakeContext([], True, 100, 125, 5, 9, 6144, 10240,
    False, False, 0);

  Assert.AreEqual(
    SepLine + sLineBreak +
    ' Results: 0 Passed, 0 Failed, 0 Skipped' + sLineBreak +
    DashLine + sLineBreak +
    ' GDI Handles : 100 -> 125 (Delta: 25)' + sLineBreak +
    ' USER Handles: 5 -> 9 (Delta: 4)' + sLineBreak +
    ' Memory Alloc: 6 KB -> 10 KB (Delta: 4 KB)' + sLineBreak +
    SepLine,
    Fmt.FormatRunSummary(Run, Ctx));
end;
// 13. Strict success: all reports matched, no issues, no failures.
procedure TRunnerFormattingTests.Test_Strict_Success;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, '01_simple.vrt', 6, True, '', 0)],
    True, False,
    MakeReconciliation(1, []));
  Ctx := MakeContext([], True, 16, 24, 10, 10, 0, 0,
    True, False, 0);

  Assert.AreEqual(
    SepLine + sLineBreak +
    ' Strict Baseline Validation' + sLineBreak +
    DashLine + sLineBreak +
    ' Reports discovered : 1' + sLineBreak +
    ' Reports checked    : 1' + sLineBreak +
    ' Matched            : 1' + sLineBreak +
    ' Mismatches         : 0' + sLineBreak +
    ' Missing baseline   : 0' + sLineBreak +
    ' Orphan baseline    : 0' + sLineBreak +
    ' Skipped            : 0' + sLineBreak +
    ' Execution errors   : 0' + sLineBreak +
    DashLine + sLineBreak +
    DashLine + sLineBreak +
    ' Strict result: PASS' + sLineBreak +
    SepLine,
    Fmt.FormatStrictSummary(Run, Ctx));
end;

// 14. Strict mismatch: page count mismatch issue rendered exactly.
procedure TRunnerFormattingTests.Test_Strict_Mismatch;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, '02_mismatch.vrt', 5, True, '', 0)],
    True, False,
    MakeReconciliation(0, [
      MakeIssue(bikPageCountMismatch, '02_mismatch.vrt', 6, 5)]));
  Ctx := MakeContext([], True, 16, 24, 10, 10, 0, 0,
    True, True, 0);

  Assert.IsTrue(Pos(
    Format('[FAIL] %-40s | Expected pages: %d, actual pages: %d',
      ['02_mismatch.vrt', 6, 5]),
    Fmt.FormatStrictSummary(Run, Ctx)) > 0);
  Assert.IsTrue(Pos(' Strict result: FAIL', Fmt.FormatStrictSummary(Run, Ctx)) > 0);
end;

// 15. Strict missing baseline issue rendered exactly.
procedure TRunnerFormattingTests.Test_Strict_MissingBaseline;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, '03_new.vrt', 2, True, '', 0)],
    True, False,
    MakeReconciliation(0, [
      MakeIssue(bikMissingBaseline, '03_new.vrt', 0, 2)]));
  Ctx := MakeContext([], True, 16, 24, 10, 10, 0, 0,
    True, True, 0);

  Assert.IsTrue(Pos(
    Format('[FAIL] %-40s | Missing baseline entry (actual pages: %d)',
      ['03_new.vrt', 2]),
    Fmt.FormatStrictSummary(Run, Ctx)) > 0);
  Assert.IsTrue(Pos(' Strict result: FAIL', Fmt.FormatStrictSummary(Run, Ctx)) > 0);
end;

// 16. Strict orphan baseline issue rendered exactly.
procedure TRunnerFormattingTests.Test_Strict_OrphanBaseline;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
begin
  Run := MakeRun(0, [], True, False,
    MakeReconciliation(0, [
      MakeIssue(bikOrphanBaseline, '04_orphan.vrt', 5, 0)]));
  Ctx := MakeContext([], True, 16, 24, 10, 10, 0, 0,
    True, True, 0);

  Assert.IsTrue(Pos(
    Format('[FAIL] %-40s | Orphan baseline entry (expected pages: %d)',
      ['04_orphan.vrt', 5]),
    Fmt.FormatStrictSummary(Run, Ctx)) > 0);
  Assert.IsTrue(Pos(' Strict result: FAIL', Fmt.FormatStrictSummary(Run, Ctx)) > 0);
end;

// 17. Strict baseline updated: a clean run with baseline updates is PASS.
procedure TRunnerFormattingTests.Test_Strict_BaselineUpdated;
var
  Run: TRegressionRunResult;
  Ctx: TRunFormatContext;
begin
  Run := MakeRun(1, [
    MakeReport(resPassed, '05_updated.vrt', 6, True, '', 0)],
    True, True,
    MakeReconciliation(1, []));
  Ctx := MakeContext([], True, 16, 24, 10, 10, 0, 0,
    True, False, 0);

  Assert.IsTrue(Pos(' Strict result: PASS', Fmt.FormatStrictSummary(Run, Ctx)) > 0);
end;
// 18. Skipped report: exact [SKIP] line.
procedure TRunnerFormattingTests.Test_SkippedReport;
var
  Ctx: TRunFormatContext;
  Rep: TReportExecutionResult;
begin
  Rep := MakeReport(resSkipped, '16_large_preview_warning.vrt', 0, False, '', 0);
  Ctx := MakeContext([
    MakeObs('16_large_preview_warning.vrt', 0, 0, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[SKIP] %-40s', ['16_large_preview_warning.vrt']),
    Fmt.FormatReportLine(Rep, Ctx));
end;

// 19. Expected page count present: model carries it, formatter does not
//  emit it (presentation-only).
procedure TRunnerFormattingTests.Test_ExpectedPageCountPresent;
var
  Ctx: TRunFormatContext;
  Rep: TReportExecutionResult;
begin
  Rep := MakeReport(resPassed, '09_with_expected.vrt', 6, True, '', 0);
  Rep.HasExpectedPageCount := True;
  Rep.ExpectedPageCount := 5;
  Ctx := MakeContext([
    MakeObs('09_with_expected.vrt', 25, 0, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK',
      ['09_with_expected.vrt', 6, 25]),
    Fmt.FormatReportLine(Rep, Ctx));
end;

// 20. Expected page count absent: report line is identical to present case.
procedure TRunnerFormattingTests.Test_ExpectedPageCountAbsent;
var
  Ctx: TRunFormatContext;
  Rep: TReportExecutionResult;
begin
  Rep := MakeReport(resPassed, '10_without_expected.vrt', 6, True, '', 0);
  Rep.HasExpectedPageCount := False;
  Ctx := MakeContext([
    MakeObs('10_without_expected.vrt', 25, 0, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK',
      ['10_without_expected.vrt', 6, 25]),
    Fmt.FormatReportLine(Rep, Ctx));
end;

// 21. Empty error message: [FAIL] preserves an empty error string.
procedure TRunnerFormattingTests.Test_EmptyError;
var
  Ctx: TRunFormatContext;
  Rep: TReportExecutionResult;
begin
  Rep := MakeReport(resFailed, '11_empty_err.vrt', 0, False, '', 0);
  Ctx := MakeContext([
    MakeObs('11_empty_err.vrt', 0, 0, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[FAIL] %-40s | ', ['11_empty_err.vrt']),
    Fmt.FormatReportLine(Rep, Ctx));
end;

// 22. Exact error-message preservation: error text is kept unchanged.
procedure TRunnerFormattingTests.Test_ExactErrorPreservation;
var
  Ctx: TRunFormatContext;
  Rep: TReportExecutionResult;
begin
  Rep := MakeReport(resFailed, '12_crash.vrt', 0, False,
    'EReportEngine: File not found: "test.vrt"', 0);
  Ctx := MakeContext([
    MakeObs('12_crash.vrt', 0, 0, False, False, 0, 0)],
    True, 16, 20, 10, 10, 0, 0, False, False, 0);

  Assert.AreEqual(
    Format('[FAIL] %-40s | %s',
      ['12_crash.vrt', 'EReportEngine: File not found: "test.vrt"']),
    Fmt.FormatReportLine(Rep, Ctx));
end;

initialization
  TDUnitX.RegisterTestFixture(TRunnerFormattingTests);

end.