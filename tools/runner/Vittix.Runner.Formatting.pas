unit Vittix.Runner.Formatting;

{
  Phase 3D-4: formatter boundary (presentation only).

  Contract types shared by every result formatter and the console runner:

    TReportExecutionObservation - per-report presentation observations that
      the Results model intentionally does not carry: elapsed time, the
      small benign VCL GDI cache delta used by the PASS lines, the HTML
      smoke outcome and the script object counts.
    TProcessResourceSummary    - process-level GDI/USER/memory values
      supplied by the runner. The formatter NEVER queries the OS.
    TStrictRunSummary          - the already-computed strict verdict and
      the legacy FailCount (which includes [LEAK] classifications). The
      formatter only reports these values; it never re-derives strict
      semantics, reconciliation or exit-code decisions.
    TRunFormatContext          - everything presentation-only a formatter
      needs besides TRegressionRunResult.
    IRunResultFormatter        - the boundary itself.

  Purity rules (enforced by construction):
    - No ParamStr / ParamCount, no Halt, no console I/O (no Writeln).
    - No filesystem access (TDirectory / TFile), no report execution, no
      serializer / exporter execution.
    - No VCL / Winapi / FireDAC dependencies.
    - Formatting is deterministic for a given set of input records.

  Dependency direction (no cycles):
      TextFormatter
           |
           v
      Formatting
           |
           v
      Results / Baseline types (already-computed values only)

  Results.pas / Baseline types never depend on this unit, and no
  formatting methods are added to TRegressionRunResult.
}

interface

uses
  Vittix.Runner.Results;

const
  {
    Phase 3F-3: the single authoritative GDI leak threshold.

    Legacy semantic, unchanged: a per-report GDI handle delta of
    GdiLeakThreshold or more is classified as [LEAK] (a failed result).
    Both classification sites (the runner's RecLeakDelta computation and
    the text formatter's [LEAK] rendering) must use this constant; no
    production code keeps its own copy of the value.
  }
  GdiLeakThreshold = 25;

type
  {
    Process-level resource observations for the run summary. The runner
    measures GetGuiResources / AllocMemSize and stores the raw values
    here; the formatter only formats them.
  }
  TProcessResourceSummary = record
    HasData: Boolean;
    StartGDI: Cardinal;
    EndGDI: Cardinal;
    StartUser: Cardinal;
    EndUser: Cardinal;
    StartMem: Int64;
    EndMem: Int64;
  end;

  {
    Per-report presentation observation, kept parallel to
    TRegressionRunResult.Reports (same order, linked by ReportName).

    GdiCacheDelta is the measured per-report GDI handle delta used by the
    existing PASS / LEAK lines. It is NOT the Results model's
    GdiLeakDelta (the leak classification value); the two are never
    reinterpreted. HtmlSmokeOk is True exactly when the runner's HTML
    clone test succeeded for an HTML-capable report.
  }
  TReportExecutionObservation = record
    ReportName: string;
    ElapsedMs: Int64;
    GdiCacheDelta: Integer;
    HtmlSmokeOk: Boolean;
    HasScriptCounts: Boolean;
    ScriptBeforeCount: Integer;
    ScriptAfterCount: Integer;
  end;

  {
    The strict verdict (StrictHasFailures) and the legacy FailCount are
    computed by the runner before the formatter is invoked. The formatter
    only formats them; it must never recompute strict semantics.
  }
  TStrictRunSummary = record
    HasData: Boolean;
    Failed: Boolean;
    ExecutionErrorCount: Integer;
  end;

  TRunFormatContext = record
    ReportObservations: TArray<TReportExecutionObservation>;
    HasProcessSummary: Boolean;
    Process: TProcessResourceSummary;
    HasStrictSummary: Boolean;
    &Strict: TStrictRunSummary;
  end;

  IRunResultFormatter = interface
    function FormatReportLine(const AReport: TReportExecutionResult;
      const AContext: TRunFormatContext): string;
    function FormatRunSummary(const AResult: TRegressionRunResult;
      const AContext: TRunFormatContext): string;
    function FormatStrictSummary(const AResult: TRegressionRunResult;
      const AContext: TRunFormatContext): string;
  end;

implementation

end.