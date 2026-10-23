unit Vittix.Runner.Baseline.Policy;

{
  Phase 3F-5: runner baseline lifecycle and decision policy.

  Owns ONLY how the console runner uses the two already-extracted baseline
  implementations (Vittix.Runner.Baseline, Vittix.Runner.Baseline.Legacy):

    - resolving the baseline file path from the reports directory and an
      optional explicit --baseline path
    - strict-load failure reporting (builds the diagnostic the caller emits
      and halts on; the actual load stays in TRegressionBaseline)
    - the non-strict per-report decision: match / mismatch / auto-register

  Does NOT own:
    - the baseline objects themselves (Console owns TRegressionBaseline and
      TLegacyBaseline, frees them, and decides when to save)
    - CLI parsing, output, Halt, diagnostics, formatting, execution, GDI,
      discovery, script tracing
}

interface

uses
  System.SysUtils,
  System.IOUtils,
  Vittix.Runner.Baseline,
  Vittix.Runner.Baseline.Legacy;

type
  {
    Outcome of evaluating one report against the non-strict (legacy) baseline.
    The caller applies the decision to its own state; this record is pure
    data and mutates nothing.
  }
  TNonStrictReportDecision = record
    HasExpectedPages: Boolean;
    ExpectedPages: Integer;
    Mismatch: Boolean;
    ErrorMessage: string;
    ShouldRegister: Boolean;
  end;

{
  Resolve the baseline file path used by the runner.

  When an explicit baseline file is supplied (CLI --baseline), it is used as
 -is after normalization. Otherwise the path is
  <reports_dir>/regression_baselines.json (the same default the console
  runner has always used).
}
function ResolveBaselineFilePath(
  const AReportsPath, AExplicitBaselineFile: string): string;

{
  Attempt to load a strict baseline from AFileName.

  On success: ABaseline is set to a newly created TRegressionBaseline (owned
  by the caller, which must free it), ADiagnostic is empty, returns True.

  On failure: ABaseline is nil, ADiagnostic contains the loader diagnostic
  (the same two-line form the console runner emits), returns False.
}
function LoadStrictBaseline(
  const AFileName: string;
  out ABaseline: TRegressionBaseline;
  out ADiagnostic: string): Boolean;

{
  Evaluate one report against the non-strict (legacy/mutable) baseline.

  Pure decision only: it queries the baseline via TryGetExpectedPages and
  returns which path applies (match / mismatch / auto-register). It never
  mutates ALegacyBaseline or any caller state. The caller applies the
  decision (set TestFailed/ErrorMsg when Mismatch, call RegisterReport +
  BaselineModified := True when ShouldRegister).
}
function EvaluateNonStrictReport(
  const ALegacyBaseline: TLegacyBaseline;
  const AReportName: string;
  APageCount: Integer): TNonStrictReportDecision;

implementation

function ResolveBaselineFilePath(
  const AReportsPath, AExplicitBaselineFile: string): string;
begin
  if AExplicitBaselineFile <> '' then
    Result := TPath.GetFullPath(AExplicitBaselineFile)
  else
    Result := TPath.Combine(AReportsPath, 'regression_baselines.json');
end;

function LoadStrictBaseline(
  const AFileName: string;
  out ABaseline: TRegressionBaseline;
  out ADiagnostic: string): Boolean;
var
  Error: TBaselineParseError;
begin
  ABaseline := nil;
  ADiagnostic := '';
  if not TRegressionBaseline.LoadFromFile(AFileName, ABaseline, Error) then
  begin
    ADiagnostic := 'Error: strict regression baseline could not be loaded: ' +
      AFileName;
    if Error.Message <> '' then
      ADiagnostic := ADiagnostic + sLineBreak + 'Error: ' + Error.Message;
    Exit(False);
  end;
  Result := True;
end;

function EvaluateNonStrictReport(
  const ALegacyBaseline: TLegacyBaseline;
  const AReportName: string;
  APageCount: Integer): TNonStrictReportDecision;
var
  ExpectedPages: Integer;
begin
  Result := Default(TNonStrictReportDecision);
  Result.HasExpectedPages := ALegacyBaseline.TryGetExpectedPages(
    AReportName, ExpectedPages);
  if Result.HasExpectedPages then
  begin
    Result.ExpectedPages := ExpectedPages;
    Result.Mismatch := (ExpectedPages <> APageCount);
    if Result.Mismatch then
      Result.ErrorMessage := Format(
        'Pagination mismatch: Expected %d pages, got %d',
        [ExpectedPages, APageCount]);
  end
  else
    Result.ShouldRegister := True;
end;

end.