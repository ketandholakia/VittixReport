unit Vittix.Runner.Results;

{
  Phase 3D-1: unified regression result model.

  Pure value/model unit:

    Report execution
          |
    TReportExecutionResult[]
          |
    TRegressionRunResult
          |
    future formatters (text / JSON / JUnit)

  This unit contains NO process access (ParamStr/ParamCount), no Halt,
  no console I/O, no filesystem I/O (TDirectory/TFile), no report
  execution and no JSON/JUnit. Reconciliation types
  (TBaselineReconciliationResult / TBaselineIssue) are reused from
  Vittix.Runner.Baseline and are NOT duplicated here. Reconcile() is
  never called from this unit; the caller assigns an already-computed
  reconciliation result.

  Memory safety: the records use managed fields (string / dynamic
  arrays) and rely on normal Delphi initialization semantics.
  FillChar must never be used on these records; Default(T...) is the
  supported way to obtain an empty value.

  ---------------------------------------------------------------------------
  Semantics (mirrors Vittix.Runner.Console.pas, which is NOT modified here):

  Status:
    resPassed   - report executed successfully. It may still have a
                  baseline mismatch (strict mode records mismatches as
                  reconciliation issues; the execution status stays
                  resPassed).
    resFailed   - execution failed (ErrorMessage = 'EClass: message'),
                  or the existing runner leak detection classified the
                  report as failed ([LEAK], GdiLeakDelta > 0). In that
                  case HasPageCount = True and PageCount is preserved.
    resSkipped  - report intentionally skipped. Never represented as
                  passed.

  Page counts:
    HasPageCount = True only when an actual page count was produced
    (skipped and failed-before-pagination reports have
    HasPageCount = False). ExpectedPageCount is valid only when
    HasExpectedPageCount = True (e.g. a compared baseline value); for
    newly auto-registered non-strict reports it is False. Page counts
    are never fabricated.

  Non-strict legacy compatibility:
    In the current console runner (non-strict) a baseline page-count
    mismatch increments FailCount ('Pagination mismatch: Expected %d
    pages, got %d'). To preserve that exact behavior, the CALLER maps
    such a report to Status = resFailed with that ErrorMessage. This
    unit itself never changes an execution status because of a baseline
    mismatch. With that mapping, ExecutionFailureCount reproduces the
    legacy FailCount exactly, and non-strict IsSuccessful
    (ExecutionFailureCount = 0) reproduces 'Halt(1) iff FailCount > 0'.

  Strict compatibility:
    StrictFailed in the console is Reconciliation.HasIssues OR
    (FailCount > 0). Strict IsSuccessful below is exactly its negation:
    BaselineCompared AND no reconciliation issues AND no execution
    failures.

  BaselineUpdated = True by itself never means failure (non-strict
  auto-registration of new baselines is not a failure in the console).

  Counters are derived helpers, never duplicate counters:
    PassedCount           = reports with Status = resPassed
    ExecutionFailureCount = reports with Status = resFailed
    SkippedCount          = reports with Status = resSkipped
    ReportsCheckedCount   = PassedCount  (strict semantics: only
                            successfully executed reports were checked)
}

interface

uses
  Vittix.Runner.Baseline;

type
  TReportExecutionStatus = (
    resPassed,
    resFailed,
    resSkipped
  );

  TReportExecutionResult = record
    ReportName: string;
    Status: TReportExecutionStatus;

    // Actual page count; valid only when HasPageCount = True.
    PageCount: Integer;
    HasPageCount: Boolean;

    // Baseline/expected page count; valid only when
    // HasExpectedPageCount = True. Never fabricated.
    ExpectedPageCount: Integer;
    HasExpectedPageCount: Boolean;

    // For failed reports: 'EClass: message' when available.
    // Empty for passed/skipped reports.
    ErrorMessage: string;

    // Raw GDI handle delta observed for this report. Positive means the
    // existing runner semantics classify the report as execution-failed.
    GdiLeakDelta: Integer;
  end;

  TRegressionRunResult = record
    ReportsDiscovered: Integer;
    Reports: TArray<TReportExecutionResult>;

    // True when reconciliation against a baseline was performed.
    // When False, Reconciliation must be treated as empty/zeroed.
    BaselineCompared: Boolean;
    Reconciliation: TBaselineReconciliationResult;

    // True when the run auto-registered new baseline entries
    // (non-strict). Never a failure by itself.
    BaselineUpdated: Boolean;

    function PassedCount: Integer;
    function ExecutionFailureCount: Integer;
    function SkippedCount: Integer;
    function ReportsCheckedCount: Integer;
    function IsSuccessful: Boolean;
  end;

implementation

function TRegressionRunResult.PassedCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(Reports) do
    if Reports[I].Status = resPassed then
      Inc(Result);
end;

function TRegressionRunResult.ExecutionFailureCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(Reports) do
    if Reports[I].Status = resFailed then
      Inc(Result);
end;

function TRegressionRunResult.SkippedCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(Reports) do
    if Reports[I].Status = resSkipped then
      Inc(Result);
end;

{
  Strict semantics preserved: reports checked = successfully executed
  reports. Skipped and failed-before-pagination reports are not counted.
}
function TRegressionRunResult.ReportsCheckedCount: Integer;
begin
  Result := PassedCount;
end;

{
  Strict (BaselineCompared = True):
    successful iff no reconciliation issues AND no execution failures.
    This is exactly the negation of the console's StrictHasFailures
    (Reconciliation.HasIssues OR FailCount > 0).

  Non-strict (BaselineCompared = False):
    successful iff no execution failures, reproducing the legacy
    'Halt(1) iff FailCount > 0' behavior. BaselineUpdated = True by
    itself does NOT mean failure.
}
function TRegressionRunResult.IsSuccessful: Boolean;
begin
  if BaselineCompared then
    Result := (not Reconciliation.HasIssues) and (ExecutionFailureCount = 0)
  else
    Result := ExecutionFailureCount = 0;
end;

end.
