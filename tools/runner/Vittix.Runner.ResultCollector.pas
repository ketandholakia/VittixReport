unit Vittix.Runner.ResultCollector;

{
  Phase 3F-6: result aggregation boundary.

  TRunResultCollector isolates the mechanics of collecting/recording report
  execution observations into an existing TRegressionRunResult.

  This unit owns ONLY:
    - Result-array growth
    - Appending one result record
    - Initializing the run-result record
    - Setting ReportsDiscovered
    - Maintaining collection order

  This unit must NOT own:
    - Execution policy (report execution, engine creation, Prepare, exports,
      scripts, script tracing, exceptions)
    - Resource policy (GDI measurement, USER measurement, memory measurement,
      GDI leak threshold, leak classification)
    - Baseline policy (strict/tolerant loading, registration, reconciliation,
      baseline persistence, StrictHasFailures)
    - CLI (option parsing, ParamStr, Halt, exit codes)
    - Presentation (Writeln, formatting, JSON, text output, diagnostics)

  The collector receives an already-constructed TReportExecutionResult; it
  does NOT understand report execution semantics (no AppendPassed, AppendFailed,
  AppendLeak, AppendSkipped methods).

  Counter semantics are NOT duplicated: TRegressionRunResult.PassedCount,
  ExecutionFailureCount, SkippedCount, ReportsCheckedCount, and IsSuccessful
  remain authoritative and are derived from the Reports array.

  Ordering is preserved exactly: reports are appended in the order received,
  no sorting, no deduplication.

  ReportsDiscovered semantics are preserved: number of .vrt files discovered
  before filtering/classification, NOT number executed or recorded.
}

interface

uses
  Vittix.Runner.Results;

type
  TRunResultCollector = record
  public
    {
      Initialize sets ARunResult to an empty state and records the number of
      reports discovered before any filtering/classification.

      This must be called before any Append calls.
    }
    class procedure Initialize(
      var ARunResult: TRegressionRunResult;
      AReportsDiscovered: Integer); static;

    {
      Append appends a single report execution result to the run result's
      Reports array, preserving the exact order of calls.

      The caller is responsible for constructing AResult with all necessary
      fields (ReportName, Status, PageCount, HasPageCount, ExpectedPageCount,
      HasExpectedPageCount, ErrorMessage, GdiLeakDelta).

      The caller is also responsible for determining status (resPassed,
      resFailed, resSkipped) based on execution policy, baseline policy, and
      resource policy.
    }
    class procedure Append(
      var ARunResult: TRegressionRunResult;
      const AResult: TReportExecutionResult); static;

    {
      UpdateLast modifies the status and GDI leak delta of the most recently
      appended result. This is provided for cases where the final classification
      (e.g., leak detection) occurs after the result is initially appended.

      The caller must ensure that at least one result has been appended before
      calling this method.
    }
    class procedure UpdateLast(
      var ARunResult: TRegressionRunResult;
      AStatus: TReportExecutionStatus;
      AGdiLeakDelta: Integer); static;
  end;

implementation

{ TRunResultCollector }

class procedure TRunResultCollector.Initialize(
  var ARunResult: TRegressionRunResult;
  AReportsDiscovered: Integer);
begin
  ARunResult := Default(TRegressionRunResult);
  ARunResult.ReportsDiscovered := AReportsDiscovered;
end;

class procedure TRunResultCollector.Append(
  var ARunResult: TRegressionRunResult;
  const AResult: TReportExecutionResult);
var
  N: Integer;
begin
  N := Length(ARunResult.Reports);
  SetLength(ARunResult.Reports, N + 1);
  ARunResult.Reports[N] := AResult;
end;

class procedure TRunResultCollector.UpdateLast(
  var ARunResult: TRegressionRunResult;
  AStatus: TReportExecutionStatus;
  AGdiLeakDelta: Integer);
var
  LastIndex: Integer;
begin
  LastIndex := High(ARunResult.Reports);
  ARunResult.Reports[LastIndex].Status := AStatus;
  ARunResult.Reports[LastIndex].GdiLeakDelta := AGdiLeakDelta;
end;

end.