unit Test.Vittix.Runner.Results;

{
  Phase 3D-1: unified regression result model tests.

  Pure DUnitX tests: no filesystem, no report execution, no process
  invocation. The canonical reports/regression_baselines.json is never
  touched; reconciliation results are built in memory via records only.
}

interface

uses
  DUnitX.TestFramework,
  Vittix.Runner.Baseline,
  Vittix.Runner.Results;

type
  [TestFixture]
  TRunnerResultsTests = class
  private
    class function MakePassed(const AName: string;
      APages: Integer): TReportExecutionResult; static;
    class function MakeFailedNoPages(const AName: string;
      const AError: string): TReportExecutionResult; static;
    class function MakeLeak(const AName: string; APages: Integer;
      ALeakDelta: Integer): TReportExecutionResult; static;
    class function MakeSkipped(const AName: string): TReportExecutionResult; static;
    class function MakeIssue(AKind: TBaselineIssueKind;
      const AName: string): TBaselineIssue; static;
    class function MakeReconciliation(
      const AIssues: array of TBaselineIssue): TBaselineReconciliationResult; static;
  public
    // 1. Passed report
    [Test] procedure Test_PassedReport_Counters;
    // 2. Failed before pagination
    [Test] procedure Test_FailedBeforePagination;
    // 3. Failed after pagination / GDI leak
    [Test] procedure Test_FailedAfterPagination_GdiLeak;
    // 4. Skipped
    [Test] procedure Test_SkippedReport;
    // 5. Expected page count (present and absent)
    [Test] procedure Test_ExpectedPageCount_Present;
    [Test] procedure Test_ExpectedPageCount_Absent;
    // 6. Error message preserved
    [Test] procedure Test_ErrorMessagePreserved;
    // 7. Mixed collection
    [Test] procedure Test_MixedCollection_Counters;
    // 8. Empty run
    [Test] procedure Test_EmptyRun;
    // 9. Non-strict success
    [Test] procedure Test_NonStrict_Success;
    [Test] procedure Test_NonStrict_BaselineUpdatedAloneIsSuccess;
    [Test] procedure Test_NonStrict_ExecutionFailureIsNotSuccess;
    // 10-14. Strict semantics
    [Test] procedure Test_Strict_Success;
    [Test] procedure Test_Strict_PageMismatch_Fails;
    [Test] procedure Test_Strict_MissingBaseline_Fails;
    [Test] procedure Test_Strict_OrphanBaseline_Fails;
    [Test] procedure Test_Strict_ExecutionFailure_Fails;
  end;

implementation

{ TRunnerResultsTests }

class function TRunnerResultsTests.MakePassed(const AName: string;
  APages: Integer): TReportExecutionResult;
begin
  // Default() initializes managed fields correctly (no FillChar).
  Result := Default(TReportExecutionResult);
  Result.ReportName := AName;
  Result.Status := resPassed;
  Result.PageCount := APages;
  Result.HasPageCount := True;
end;

class function TRunnerResultsTests.MakeFailedNoPages(const AName: string;
  const AError: string): TReportExecutionResult;
begin
  Result := Default(TReportExecutionResult);
  Result.ReportName := AName;
  Result.Status := resFailed;
  // Execution failed before pagination: no page count.
  Result.HasPageCount := False;
  Result.ErrorMessage := AError;
end;

class function TRunnerResultsTests.MakeLeak(const AName: string;
  APages: Integer; ALeakDelta: Integer): TReportExecutionResult;
begin
  Result := Default(TReportExecutionResult);
  Result.ReportName := AName;
  Result.Status := resFailed;
  // Report rendered successfully, then classified as GDI leak.
  Result.PageCount := APages;
  Result.HasPageCount := True;
  Result.GdiLeakDelta := ALeakDelta;
end;

class function TRunnerResultsTests.MakeSkipped(
  const AName: string): TReportExecutionResult;
begin
  Result := Default(TReportExecutionResult);
  Result.ReportName := AName;
  Result.Status := resSkipped;
  Result.HasPageCount := False;
end;

class function TRunnerResultsTests.MakeIssue(AKind: TBaselineIssueKind;
  const AName: string): TBaselineIssue;
begin
  Result := Default(TBaselineIssue);
  Result.Kind := AKind;
  Result.ReportName := AName;
end;

class function TRunnerResultsTests.MakeReconciliation(
  const AIssues: array of TBaselineIssue): TBaselineReconciliationResult;
var
  I: Integer;
begin
  Result := Default(TBaselineReconciliationResult);
  SetLength(Result.Issues, Length(AIssues));
  for I := 0 to High(AIssues) do
    Result.Issues[I] := AIssues[I];
end;

// 1. Passed report
procedure TRunnerResultsTests.Test_PassedReport_Counters;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  Run.ReportsDiscovered := 1;
  SetLength(Run.Reports, 1);
  Run.Reports[0] := MakePassed('01_basic.vrt', 3);

  Assert.AreEqual(TReportExecutionStatus.resPassed, Run.Reports[0].Status);
  Assert.IsTrue(Run.Reports[0].HasPageCount);
  Assert.AreEqual(3, Run.Reports[0].PageCount);
  Assert.AreEqual('', Run.Reports[0].ErrorMessage);

  Assert.AreEqual(1, Run.PassedCount);
  Assert.AreEqual(0, Run.ExecutionFailureCount);
  Assert.AreEqual(0, Run.SkippedCount);
  Assert.AreEqual(1, Run.ReportsCheckedCount);
end;

// 2. Failed before pagination
procedure TRunnerResultsTests.Test_FailedBeforePagination;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  SetLength(Run.Reports, 1);
  Run.Reports[0] := MakeFailedNoPages('02_broken.vrt',
    'EReportEngine: pagination failed');

  Assert.AreEqual(TReportExecutionStatus.resFailed, Run.Reports[0].Status);
  Assert.IsFalse(Run.Reports[0].HasPageCount);
  Assert.AreEqual(1, Run.ExecutionFailureCount);
  Assert.AreEqual(0, Run.PassedCount);
  Assert.AreEqual(0, Run.ReportsCheckedCount);
end;

// 3. Failed after pagination / GDI leak
procedure TRunnerResultsTests.Test_FailedAfterPagination_GdiLeak;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  SetLength(Run.Reports, 1);
  Run.Reports[0] := MakeLeak('03_leaky.vrt', 7, 42);

  Assert.AreEqual(TReportExecutionStatus.resFailed, Run.Reports[0].Status);
  // Page count is preserved even though the report is a leak failure.
  Assert.IsTrue(Run.Reports[0].HasPageCount);
  Assert.AreEqual(7, Run.Reports[0].PageCount);
  Assert.IsTrue(Run.Reports[0].GdiLeakDelta > 0);
  Assert.AreEqual(42, Run.Reports[0].GdiLeakDelta);
  Assert.AreEqual(1, Run.ExecutionFailureCount);
end;

// 4. Skipped
procedure TRunnerResultsTests.Test_SkippedReport;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  SetLength(Run.Reports, 1);
  Run.Reports[0] := MakeSkipped('test_excluded.vrt');

  Assert.AreEqual(TReportExecutionStatus.resSkipped, Run.Reports[0].Status);
  Assert.IsFalse(Run.Reports[0].HasPageCount);
  Assert.AreEqual(1, Run.SkippedCount);
  Assert.AreEqual(0, Run.PassedCount);
  Assert.AreEqual(0, Run.ExecutionFailureCount);
  // Skipped reports are never counted as checked.
  Assert.AreEqual(0, Run.ReportsCheckedCount);
end;

// 5a. Expected page count present (baseline compared value).
procedure TRunnerResultsTests.Test_ExpectedPageCount_Present;
var
  R: TReportExecutionResult;
begin
  R := Default(TReportExecutionResult);
  R.ReportName := '05_compared.vrt';
  R.Status := resPassed;
  R.PageCount := 4;
  R.HasPageCount := True;
  R.ExpectedPageCount := 5;
  R.HasExpectedPageCount := True;

  Assert.IsTrue(R.HasExpectedPageCount);
  Assert.AreEqual(5, R.ExpectedPageCount);
end;

// 5b. Expected page count absent (auto-registered non-strict report).
procedure TRunnerResultsTests.Test_ExpectedPageCount_Absent;
var
  R: TReportExecutionResult;
begin
  R := Default(TReportExecutionResult);
  R.ReportName := '05_new.vrt';
  R.Status := resPassed;
  R.PageCount := 2;
  R.HasPageCount := True;
  // No expected value is fabricated.
  R.HasExpectedPageCount := False;

  Assert.IsFalse(R.HasExpectedPageCount);
  Assert.AreEqual(2, R.PageCount);
end;

// 6. Error message preserved on failed reports.
procedure TRunnerResultsTests.Test_ErrorMessagePreserved;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  SetLength(Run.Reports, 1);
  Run.Reports[0] := MakeFailedNoPages('06_crash.vrt',
    'EFileNotFoundException: report file not found');

  Assert.AreEqual('EFileNotFoundException: report file not found',
    Run.Reports[0].ErrorMessage);

  // Passed and skipped reports carry no error message.
  Run.Reports[0] := MakePassed('06_ok.vrt', 1);
  Assert.AreEqual('', Run.Reports[0].ErrorMessage);
  Run.Reports[0] := MakeSkipped('06_skipped.vrt');
  Assert.AreEqual('', Run.Reports[0].ErrorMessage);
end;

// 7. Mixed collection: 2 passed, 1 failed, 1 skipped.
procedure TRunnerResultsTests.Test_MixedCollection_Counters;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  Run.ReportsDiscovered := 4;
  SetLength(Run.Reports, 4);
  Run.Reports[0] := MakePassed('07_a.vrt', 2);
  Run.Reports[1] := MakeLeak('07_b.vrt', 5, 30);
  Run.Reports[2] := MakeSkipped('test_excluded.vrt');
  Run.Reports[3] := MakePassed('07_d.vrt', 1);

  Assert.AreEqual(2, Run.PassedCount);
  Assert.AreEqual(1, Run.ExecutionFailureCount);
  Assert.AreEqual(1, Run.SkippedCount);
  Assert.AreEqual(2, Run.ReportsCheckedCount);
  Assert.AreEqual(4, Run.ReportsDiscovered);
end;

// 8. Empty run.
procedure TRunnerResultsTests.Test_EmptyRun;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  Run.ReportsDiscovered := 0;

  Assert.AreEqual(0, Length(Run.Reports));
  Assert.AreEqual(0, Run.PassedCount);
  Assert.AreEqual(0, Run.ExecutionFailureCount);
  Assert.AreEqual(0, Run.SkippedCount);
  Assert.AreEqual(0, Run.ReportsCheckedCount);
end;

// 9. Non-strict: no failures -> successful even without baseline compare.
procedure TRunnerResultsTests.Test_NonStrict_Success;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  Run.BaselineCompared := False;
  Run.BaselineUpdated := True;
  SetLength(Run.Reports, 2);
  Run.Reports[0] := MakePassed('09_a.vrt', 3);
  Run.Reports[1] := MakePassed('09_b.vrt', 2);

  Assert.IsTrue(Run.IsSuccessful);
end;

// 9b. BaselineUpdated = True alone never means failure.
procedure TRunnerResultsTests.Test_NonStrict_BaselineUpdatedAloneIsSuccess;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  Run.BaselineCompared := False;
  Run.BaselineUpdated := True;
  SetLength(Run.Reports, 1);
  Run.Reports[0] := MakePassed('09_new.vrt', 1);

  Assert.AreEqual(0, Run.ExecutionFailureCount);
  Assert.IsTrue(Run.IsSuccessful);
end;

// 9c. Non-strict: a failure is not successful (legacy Halt(1) semantics).
procedure TRunnerResultsTests.Test_NonStrict_ExecutionFailureIsNotSuccess;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  Run.BaselineCompared := False;
  Run.BaselineUpdated := True;
  SetLength(Run.Reports, 2);
  Run.Reports[0] := MakePassed('09_a.vrt', 3);
  Run.Reports[1] := MakeFailedNoPages('09_b.vrt',
    'EPaginationError: layout failed');

  Assert.AreEqual(1, Run.ExecutionFailureCount);
  Assert.IsFalse(Run.IsSuccessful);
end;

// 10. Strict: compared, no issues, no failures -> successful.
procedure TRunnerResultsTests.Test_Strict_Success;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  Run.BaselineCompared := True;
  Run.Reconciliation := MakeReconciliation([]);
  SetLength(Run.Reports, 2);
  Run.Reports[0] := MakePassed('10_a.vrt', 3);
  Run.Reports[1] := MakePassed('10_b.vrt', 2);

  Assert.IsFalse(Run.Reconciliation.HasIssues);
  Assert.AreEqual(0, Run.ExecutionFailureCount);
  Assert.IsTrue(Run.IsSuccessful);
end;

// 11. Strict: page count mismatch -> not successful.
procedure TRunnerResultsTests.Test_Strict_PageMismatch_Fails;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  Run.BaselineCompared := True;
  Run.Reconciliation := MakeReconciliation([
    MakeIssue(bikPageCountMismatch, '11_mismatch.vrt')]);
  SetLength(Run.Reports, 1);
  // The report itself executed fine; the mismatch is a reconciliation issue.
  Run.Reports[0] := MakePassed('11_mismatch.vrt', 4);

  Assert.AreEqual(0, Run.ExecutionFailureCount);
  Assert.IsTrue(Run.Reconciliation.HasIssues);
  Assert.IsFalse(Run.IsSuccessful);
end;

// 12. Strict: missing baseline -> not successful.
procedure TRunnerResultsTests.Test_Strict_MissingBaseline_Fails;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  Run.BaselineCompared := True;
  Run.Reconciliation := MakeReconciliation([
    MakeIssue(bikMissingBaseline, '12_missing.vrt')]);

  Assert.IsFalse(Run.IsSuccessful);
end;

// 13. Strict: orphan baseline -> not successful.
procedure TRunnerResultsTests.Test_Strict_OrphanBaseline_Fails;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  Run.BaselineCompared := True;
  Run.Reconciliation := MakeReconciliation([
    MakeIssue(bikOrphanBaseline, '13_orphan.vrt')]);

  Assert.IsFalse(Run.IsSuccessful);
end;

// 14. Strict: execution failure with clean reconciliation -> not successful.
procedure TRunnerResultsTests.Test_Strict_ExecutionFailure_Fails;
var
  Run: TRegressionRunResult;
begin
  Run := Default(TRegressionRunResult);
  Run.BaselineCompared := True;
  Run.Reconciliation := MakeReconciliation([]);
  SetLength(Run.Reports, 1);
  Run.Reports[0] := MakeFailedNoPages('14_crash.vrt',
    'EReportEngine: engine crashed');

  Assert.IsFalse(Run.Reconciliation.HasIssues);
  Assert.AreEqual(1, Run.ExecutionFailureCount);
  Assert.IsFalse(Run.IsSuccessful);
end;

end.
