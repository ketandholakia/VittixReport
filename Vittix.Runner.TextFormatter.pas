unit Vittix.Runner.TextFormatter;

{
  Phase 3D-4: legacy text formatter.

  TTextRunFormatter reproduces the legacy console result text byte-for-byte
  (only the elapsed-ms values are inherently nondeterministic). Every
  format string below is copied VERBATIM from Vittix.Runner.Console.pas and
  must not be "improved" - no whitespace, capitalization, punctuation or
  wording changes.

  The returned strings NEVER include a trailing line break. The runner
  keeps calling Writeln(FormatterResult), so line ending behavior is
  identical to the legacy inline Writeln calls.

  Emission-point note: FormatReportLine is called at the same logical
  points where the legacy Writeln calls existed:
    - [SKIP]  for skipped reports
    - [FAIL]  for failed reports
    - [LEAK]  for the legacy GDI leak classification (delta >= 25)
    - [PASS]  for every success branch (VCL Cache: +N for delta 1..24,
              optional "| HTML OK", plain pass for delta 0)
  No PASS/FAIL ordering or Continue behavior is changed.

  GDI semantics preserved exactly:
    delta >= 25 -> [LEAK]
    delta 1..24 -> [PASS] ... | VCL Cache: +N  (plus "| HTML OK" when the
                   HTML smoke succeeded)
    delta 0     -> plain [PASS] (plus "| HTML OK" for the HTML report)
}

interface

uses
  System.SysUtils,
  Vittix.Runner.Formatting,
  Vittix.Runner.Results,
  Vittix.Runner.Baseline;

type
  TTextRunFormatter = class(TInterfacedObject, IRunResultFormatter)
  public
    function FormatReportLine(const AReport: TReportExecutionResult;
      const AContext: TRunFormatContext): string;
    function FormatRunSummary(const AResult: TRegressionRunResult;
      const AContext: TRunFormatContext): string;
    function FormatStrictSummary(const AResult: TRegressionRunResult;
      const AContext: TRunFormatContext): string;
  end;

implementation

{ TTextRunFormatter }

function TTextRunFormatter.FormatReportLine(const AReport: TReportExecutionResult;
  const AContext: TRunFormatContext): string;
var
  Obs: TReportExecutionObservation;
  I: Integer;
begin
  // Locate the presentation observation captured for this report
  // (observations are collected in lock-step with RunResult.Reports and
  // linked by report name). A missing observation degrades to zero values.
  Obs := Default(TReportExecutionObservation);
  for I := 0 to High(AContext.ReportObservations) do
    if SameText(AContext.ReportObservations[I].ReportName, AReport.ReportName) then
    begin
      Obs := AContext.ReportObservations[I];
      Break;
    end;

  case AReport.Status of
    resSkipped:
      Result := Format('[SKIP] %-40s', [AReport.ReportName]);
    resFailed:
      if AReport.GdiLeakDelta > 0 then
        // Legacy [LEAK] classification (the threshold is unchanged).
        Result := Format('[LEAK] %-40s | %3d pgs | %4d ms | GDI Delta: +%d',
          [AReport.ReportName, AReport.PageCount, Obs.ElapsedMs,
           AReport.GdiLeakDelta])
      else
        // Exact legacy [FAIL] text; the full ErrorMessage is preserved.
        Result := Format('[FAIL] %-40s | %s',
          [AReport.ReportName, AReport.ErrorMessage]);
  else { resPassed }
    if Obs.GdiCacheDelta >= 25 then
      // Legacy [LEAK] classification (the threshold is unchanged).
      Result := Format('[LEAK] %-40s | %3d pgs | %4d ms | GDI Delta: +%d',
        [AReport.ReportName, AReport.PageCount, Obs.ElapsedMs,
         Obs.GdiCacheDelta])
    else if Obs.GdiCacheDelta > 0 then
    begin
      // The VCL Graphics.pas unit globally caches Pens, Brushes, and Fonts.
      // Small GDI increases (1..24) are normal cache allocations.
      if Obs.HtmlSmokeOk then
        Result := Format(
          '[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK | HTML OK | VCL Cache: +%d',
          [AReport.ReportName, AReport.PageCount, Obs.ElapsedMs,
           Obs.GdiCacheDelta])
      else
        Result := Format(
          '[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK | VCL Cache: +%d',
          [AReport.ReportName, AReport.PageCount, Obs.ElapsedMs,
           Obs.GdiCacheDelta]);
    end
    else if Obs.HtmlSmokeOk then
      Result := Format(
        '[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK | HTML OK',
        [AReport.ReportName, AReport.PageCount, Obs.ElapsedMs])
    else
      Result := Format(
        '[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK',
        [AReport.ReportName, AReport.PageCount, Obs.ElapsedMs]);
  end;
end;
function TTextRunFormatter.FormatRunSummary(const AResult: TRegressionRunResult;
  const AContext: TRunFormatContext): string;
begin
  Result := '================================================' + sLineBreak;
  Result := Result +
    Format(' Results: %d Passed, %d Failed, %d Skipped',
      [AResult.PassedCount, AResult.ExecutionFailureCount,
       AResult.SkippedCount]) + sLineBreak;
  Result := Result + '------------------------------------------------' + sLineBreak;
  if AContext.HasProcessSummary then
    Result := Result
      + Format(' GDI Handles : %d -> %d (Delta: %d)',
          [AContext.Process.StartGDI, AContext.Process.EndGDI,
           Integer(AContext.Process.EndGDI) -
             Integer(AContext.Process.StartGDI)]) + sLineBreak
      + Format(' USER Handles: %d -> %d (Delta: %d)',
          [AContext.Process.StartUser, AContext.Process.EndUser,
           Integer(AContext.Process.EndUser) -
             Integer(AContext.Process.StartUser)]) + sLineBreak
      + Format(' Memory Alloc: %d KB -> %d KB (Delta: %d KB)',
          [AContext.Process.StartMem div 1024, AContext.Process.EndMem div 1024,
           (AContext.Process.EndMem - AContext.Process.StartMem) div 1024])
          + sLineBreak;
  Result := Result + '================================================';
end;

function TTextRunFormatter.FormatStrictSummary(const AResult: TRegressionRunResult;
  const AContext: TRunFormatContext): string;
var
  Issue: TBaselineIssue;
begin
  Result := '================================================' + sLineBreak;
  Result := Result + ' Strict Baseline Validation' + sLineBreak;
  Result := Result + '------------------------------------------------' + sLineBreak;
  Result := Result +
    Format(' Reports discovered : %d', [AResult.ReportsDiscovered]) + sLineBreak;
  Result := Result +
    Format(' Reports checked    : %d', [AResult.ReportsCheckedCount]) + sLineBreak;
  Result := Result +
    Format(' Matched            : %d', [AResult.Reconciliation.MatchingCount]) + sLineBreak;
  Result := Result +
    Format(' Mismatches         : %d', [AResult.Reconciliation.PageMismatchCount]) + sLineBreak;
  Result := Result +
    Format(' Missing baseline   : %d', [AResult.Reconciliation.MissingBaselineCount]) + sLineBreak;
  Result := Result +
    Format(' Orphan baseline    : %d', [AResult.Reconciliation.OrphanBaselineCount]) + sLineBreak;
  Result := Result +
    Format(' Skipped            : %d', [AResult.SkippedCount]) + sLineBreak;
  // The runner computed the legacy FailCount (it includes [LEAK]
  // classifications); the formatter only formats it.
  Result := Result +
    Format(' Execution errors   : %d', [AContext.&Strict.ExecutionErrorCount]) + sLineBreak;
  Result := Result + '------------------------------------------------' + sLineBreak;
  // Exact legacy strict reconciliation issue lines, in reconciliation order.
  for Issue in AResult.Reconciliation.Issues do
    case Issue.Kind of
      bikPageCountMismatch:
        Result := Result + Format(
          '[FAIL] %-40s | Expected pages: %d, actual pages: %d',
          [Issue.ReportName, Issue.ExpectedPages, Issue.ActualPages]) + sLineBreak;
      bikMissingBaseline:
        Result := Result + Format(
          '[FAIL] %-40s | Missing baseline entry (actual pages: %d)',
          [Issue.ReportName, Issue.ActualPages]) + sLineBreak;
      bikOrphanBaseline:
        Result := Result + Format(
          '[FAIL] %-40s | Orphan baseline entry (expected pages: %d)',
          [Issue.ReportName, Issue.ExpectedPages]) + sLineBreak;
    end;
  Result := Result + '------------------------------------------------' + sLineBreak;
  // The runner computed StrictHasFailures; the formatter only reports it.
  if AContext.&Strict.Failed then
    Result := Result + ' Strict result: FAIL' + sLineBreak
  else
    Result := Result + ' Strict result: PASS' + sLineBreak;
  Result := Result + '================================================';
end;

end.