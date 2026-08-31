unit Vittix.Runner.Console;

interface

type
  TVittixConsoleRunner = class
  public
    class procedure Run;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  System.Diagnostics,
  System.Classes,
  System.Generics.Collections,
  Winapi.Windows,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.StorageJSON,
  Vcl.Graphics, // Required to ensure GDI canvas is available for measurement
  Vcl.Imaging.pngimage,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.Context,
  Vittix.Report.Scripting,
  Vittix.Report.UserDataSet,
  Vittix.Runner.Options,
  Vittix.Runner.Discovery,
  Vittix.Runner.Baseline,
  Vittix.Runner.Baseline.Legacy,
  Vittix.Runner.Results,
  Vittix.Runner.Formatting,
  Vittix.Runner.TextFormatter,
  Vittix.Runner.JsonFormatter,
  Vittix.Runner.Execution,
  Vittix.Runner.ExportVerification,
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Objects.Table,
  Vittix.Report.Objects.CrossTab,
  Vittix.Report.ScriptHost.Adapter;

function HasExactSwitch(const ASwitch: string): Boolean;
var
  I: Integer;
begin
  // Retained for compatibility; Phase 3C-1 parsing is in Vittix.Runner.Options.
  Result := False;
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), ASwitch) then
      Exit(True);
end;

procedure WriteUsage;
begin
  Writeln('Usage: VittixRunner [options] [reportfile.vrt]');
  Writeln('');
  Writeln('Options:');
  Writeln('  --reports <dir>     Use <dir> as the reports directory (no probing).');
  Writeln('  --baseline <file>   Use <file> as the pagination baseline.');
  Writeln('  --sample-data <f>   Use <f> as the sample data file.');
  Writeln('  --output <dir>      Root directory for retained/export artifacts.');
  Writeln('  --filter <report>   Run only <report> (also: --filter=<report>).');
  Writeln('  --scripts           Run only script-bearing regression reports.');
  Writeln('  --script-trace      Print script trace diagnostics without pagination checks.');
  Writeln('  --keep-vector-pdf   Keep vector PDF smoke outputs under build\vector-pdf-smoke.');
  Writeln('  -pause              Keep console open after completion.');
  Writeln('  -h, --help          Show this help.');
end;

procedure TraceScriptObject(const AAdapter: TReportScriptHostAdapter; const AObject: TReportObject;
  const ALevel: Integer);
var
  Ctx: TExpressionContext;
  DummyCanPrint: Boolean;
  ResultBefore: TScriptHostCommandResult;
  ResultAfter: TScriptHostCommandResult;
  Indent: string;
  ObjName: string;
  TraceLine: string;
begin
  if not Assigned(AObject) then
    Exit;

  Indent := StringOfChar(' ', ALevel * 2);
  ObjName := AObject.ClassName;
  if AObject.Name <> '' then
    ObjName := ObjName + ' "' + AObject.Name + '"';

  DummyCanPrint := True;
  Ctx := Default(TExpressionContext);

  if AObject.OnBeforePrint <> '' then
  begin
    ResultBefore := AAdapter.ExecuteBeforeObject(AObject, AObject.OnBeforePrint, Ctx, DummyCanPrint);
    Writeln(Indent + '[Before] ' + ObjName);
    if ResultBefore.TraceMessage <> '' then
    begin
      TraceLine := StringReplace(ResultBefore.TraceMessage, sLineBreak, sLineBreak + Indent + '  ', [rfReplaceAll]);
      Writeln(Indent + '  ' + ObjName + ':');
      Writeln(Indent + '    ' + TraceLine);
    end;
  end;

  if AObject.OnAfterPrint <> '' then
  begin
    ResultAfter := AAdapter.ExecuteAfterObject(AObject, AObject.OnAfterPrint, Ctx);
    Writeln(Indent + '[After ] ' + ObjName);
    if ResultAfter.TraceMessage <> '' then
    begin
      TraceLine := StringReplace(ResultAfter.TraceMessage, sLineBreak, sLineBreak + Indent + '  ', [rfReplaceAll]);
      Writeln(Indent + '  ' + ObjName + ':');
      Writeln(Indent + '    ' + TraceLine);
    end;
  end;
end;

procedure TraceScriptTree(const AAdapter: TReportScriptHostAdapter; const AObject: TReportObject;
  const ALevel: Integer);
var
  Band: TReportBand;
  Child: TReportObject;
begin
  if not Assigned(AObject) then
    Exit;

  TraceScriptObject(AAdapter, AObject, ALevel);
  if AObject is TReportBand then
  begin
    Band := TReportBand(AObject);
    for Child in Band.Children do
      TraceScriptTree(AAdapter, Child, ALevel + 1);
  end;
end;

procedure RegisterBuiltInReportObjects;
begin
  RegisterReportObject(TReportBand);
  RegisterReportObject(TReportTextObject);
  RegisterReportObject(TReportLabelObject);
  RegisterReportObject(TReportFieldObject);
  RegisterReportObject(TReportShapeObject);
  RegisterReportObject(TReportImageObject);
  RegisterReportObject(TReportMemoObject);
  RegisterReportObject(TReportSubReportObject);
  RegisterReportObject(TReportLineObject);
  RegisterReportObject(TReportBarcodeObject);
  RegisterReportObject(TReportTableObject);
end;

{ TVittixConsoleRunner }

class procedure TVittixConsoleRunner.Run;
var
  Options: TRunnerOptions;
  Args: TArray<string>;
  SampleDataFile: string;
  ReportsPath: string;
  Files: TArray<string>;
  FileName, JustName, TargetFile: string;
  MemTable: TFDMemTable;
  PassCount, FailCount, SkipCount, I: Integer;
  StartGDI, EndGDI: DWORD;
  StartUser, EndUser: DWORD;
  StartMem, EndMem: Int64;
  BaselineFile: string;
  LegacyBaseline: TLegacyBaseline;
  StrictBaseline: TRegressionBaseline;
  StrictParseError: TBaselineParseError;
  ActualResults: TArray<TReportPageResult>;
  Reconciled: TBaselineReconciliationResult;
  StrictFailed: Boolean;
  // Phase 3D-4: formatter boundary. Formatter owns no state and never
  // executes or queries anything; it only renders supplied values.
  Formatter: IRunResultFormatter;
  FmtContext: TRunFormatContext;
  IsJsonMode: Boolean;
  BaselineModified: Boolean;
  ExpectedPages: Integer;
  ScriptAdapter: TReportScriptHostAdapter;
  ScriptOnly: Boolean;
  ScriptTraceOnly: Boolean;
  KeepVectorPDF: Boolean;
  VectorPdfOutputPath: string;
  ReportText: string;
  ScriptBeforeCount: Integer;
  ScriptAfterCount: Integer;
  Classif: TReportClassification;
  RunMode: TReportRunMode;
  Obj: TReportObject;
  // Phase 3E-2: report execution is delegated to TVittixReportExecutor.
  // The executor owns the report model, engine, datasets and temp export
  // files; the console keeps GDI measurement, baseline policy, formatting
  // and console output.
  Executor: TVittixReportExecutor;
  Config: TReportExecutionConfig;
  TraceCallback: TScriptTraceEvent;
  // Phase 3D-2: structured result recording (see Vittix.Runner.Results).
  // Initialized with Default() below; FillChar must never be used here
  // because the record contains managed fields (string / dynamic arrays).
  RunResult: TRegressionRunResult;
  Rec: TReportExecutionResult;

  // Phase 3D-2: appends exactly one structured result per processed
  // report, preserving the existing processing order. No second counter
  // system: counts stay derived from RunResult.Reports.
  procedure AppendReportResult(var ARunResult: TRegressionRunResult;
    const AResult: TReportExecutionResult);
  var
    N: Integer;
  begin
    N := Length(ARunResult.Reports);
    SetLength(ARunResult.Reports, N + 1);
    ARunResult.Reports[N] := AResult;
  end;

  // Phase 3D-4: appends the presentation observation for the report that
  // was just appended to RunResult.Reports (lock-step, same index). The
  // context is presentation-only; result semantics stay in Results.pas.
  procedure AppendObservation(const AReport: TReportExecutionResult;
    var AContext: TRunFormatContext;
    AElapsedMs: Int64;
    AGdiCacheDelta: Integer;
    AHtmlSmokeOk: Boolean;
    AHasScriptCounts: Boolean;
    AScriptBeforeCount: Integer;
    AScriptAfterCount: Integer);
  var
    N: Integer;
  begin
    N := Length(AContext.ReportObservations);
    SetLength(AContext.ReportObservations, N + 1);
    AContext.ReportObservations[N].ReportName := AReport.ReportName;
    AContext.ReportObservations[N].ElapsedMs := AElapsedMs;
    AContext.ReportObservations[N].GdiCacheDelta := AGdiCacheDelta;
    AContext.ReportObservations[N].HtmlSmokeOk := AHtmlSmokeOk;
    AContext.ReportObservations[N].HasScriptCounts := AHasScriptCounts;
    AContext.ReportObservations[N].ScriptBeforeCount := AScriptBeforeCount;
    AContext.ReportObservations[N].ScriptAfterCount := AScriptAfterCount;
  end;

  // Phase 3D-5: diagnostic routing helper. In JSON mode pre-run errors must
  // not pollute stdout; they are routed to stderr. Text mode keeps stdout.
  procedure WriteDiagnostic(const Msg: string);
  begin
    if IsJsonMode then
      WriteLn(ErrOutput, Msg)
    else
      Writeln(Msg);
  end;

begin
  if not IsJsonMode then
  begin
    Writeln('================================================');
    Writeln(' VittixReport Headless Regression Runner');
    Writeln('================================================');
  end;

  // Phase 3C-1: all CLI parsing is delegated to Vittix.Runner.Options.
  // Arguments are acquired here (process-global state stays in the console
  // entry point); parsing itself is deterministic and unit-tested.
  SetLength(Args, ParamCount);
  for I := 1 to ParamCount do
    Args[I - 1] := ParamStr(I);

  if not ParseOptions(Args, Options) then
  begin
    IsJsonMode := Options.OutputFormat = ofJson;
    WriteDiagnostic(Options.ErrorMessage);
    WriteDiagnostic('Run VittixRunner --help for usage information.');
    // Phase 3C-2c-2: a strict run that fails CLI validation is a strict
    // configuration error (exit 2). Non-strict parse failures keep the
    // existing exit code 1.
    if Options.&Strict then
      Halt(2)
    else
      Halt(1);
  end;

  IsJsonMode := Options.OutputFormat = ofJson;

  if Options.Help then
  begin
    WriteUsage;
    Halt(0);
  end;

  RegisterBuiltInReportObjects;

  // Reports directory: explicit --reports is used exclusively (no probing).
  if Options.ReportsPath <> '' then
  begin
    ReportsPath := TPath.GetFullPath(Options.ReportsPath);
    if not TDirectory.Exists(ReportsPath) then
    begin
      WriteDiagnostic('Error: --reports directory not found: ' + ReportsPath);
      WriteDiagnostic('Run VittixRunner --help for usage information.');
      Halt(1);
    end;
  end
  else
  begin
    // Locate the reports directory dynamically based on executable location
    ReportsPath := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\reports'));
    if not TDirectory.Exists(ReportsPath) then
      ReportsPath := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\reports'));
    if not TDirectory.Exists(ReportsPath) then
      ReportsPath := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\..\reports')); // Finds it from bin\Win32\Debug\

    if not TDirectory.Exists(ReportsPath) then
    begin
      WriteDiagnostic('Error: Could not locate "reports" directory at ' + ReportsPath);
      {$WARN SYMBOL_PLATFORM OFF}
      if not IsJsonMode and ((DebugHook <> 0) or FindCmdLineSwitch('pause', True)) then
      begin
        Writeln('Press ENTER to exit...');
        Readln;
      end;
      {$WARN SYMBOL_PLATFORM ON}
      Halt(1);
    end;
  end;

  ScriptOnly := Options.ScriptOnly;
  ScriptTraceOnly := Options.ScriptTraceOnly;
  KeepVectorPDF := Options.KeepVectorPDF;

  if ScriptTraceOnly then
    RunMode := rmScriptTraceOnly
  else if ScriptOnly then
    RunMode := rmScriptOnly
  else
    RunMode := rmAll;

  if not IsJsonMode then
  begin
    Writeln('Target: ', ReportsPath);

    TargetFile := Options.Filter;
    if TargetFile <> '' then
      Writeln('Filter: ', TargetFile);
    Writeln('------------------------------------------------');

    if ScriptOnly then
      Writeln('Mode: script-focused reports only');
    if ScriptTraceOnly then
      Writeln('Mode: script trace only');
  end;

  // Runner-owned output directory for all smoke/export artifacts.
  // Determined relative to the executable (never the process CWD) and
  // created unconditionally so export smoke tests work from any CWD.
  // Phase 3C-1: --output overrides the default root.
  if Options.OutputPath <> '' then
    VectorPdfOutputPath := TPath.GetFullPath(Options.OutputPath)
  else
    VectorPdfOutputPath := TPath.GetFullPath(TPath.Combine(
      ExtractFilePath(ParamStr(0)), '..\vector-pdf-smoke'));
  TDirectory.CreateDirectory(VectorPdfOutputPath);
  if KeepVectorPDF and not IsJsonMode then
    Writeln('Vector PDF output: ', VectorPdfOutputPath);

  Files := TReportDiscovery.EnumerateReports(ReportsPath);

  PassCount := 0;
  FailCount := 0;
  SkipCount := 0;

  // Phase 3D-2: structured result recording. ReportsDiscovered is the
  // number of .vrt files found before any skip/filter handling.
  RunResult := Default(TRegressionRunResult);
  RunResult.ReportsDiscovered := Length(Files);

  // Phase 3D-4: formatter boundary. The context is presentation-only and
  // starts empty; observations are appended in lock-step with
  // RunResult.Reports during the loop below.
  if IsJsonMode then
    Formatter := TJsonRunFormatter.Create
  else
    Formatter := TTextRunFormatter.Create;
  FmtContext := Default(TRunFormatContext);

  StartGDI := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);
  StartUser := GetGuiResources(GetCurrentProcess, GR_USEROBJECTS);
  {$WARN SYMBOL_DEPRECATED OFF}
  StartMem := AllocMemSize;
  {$WARN SYMBOL_DEPRECATED ON}
  
  BaselineFile := TPath.Combine(ReportsPath, 'regression_baselines.json');
  if Options.BaselineFile <> '' then
    BaselineFile := TPath.GetFullPath(Options.BaselineFile);
  BaselineModified := False;
  LegacyBaseline := nil;
  StrictBaseline := nil;
  StrictFailed := False;
  // Phase 3C-2c-2: strict mode uses the validated read-only baseline loader
  // (TRegressionBaseline.LoadFromFile), never the tolerant TLegacyBaseline
  // path below, and never fabricates an empty baseline object. A missing,
  // empty, malformed or invalid baseline is a strict configuration error
  // (exit 2); no reports are executed in that case.
  if Options.&Strict then
  begin
    if not TRegressionBaseline.LoadFromFile(BaselineFile, StrictBaseline, StrictParseError) then
    begin
      WriteDiagnostic('Error: strict regression baseline could not be loaded: ' + BaselineFile);
      if StrictParseError.Message <> '' then
        WriteDiagnostic('Error: ' + StrictParseError.Message);
      Halt(2);
    end;
  end
  else
    // Phase 3E-4: tolerant load moved to TLegacyBaseline.LoadOrEmpty.
    LegacyBaseline := TLegacyBaseline.LoadOrEmpty(BaselineFile);

  // Note: You may need to adapt this dummy dataset to exactly match what the designer uses
  MemTable := TFDMemTable.Create(nil);
  ScriptAdapter := TReportScriptHostAdapter.Create;
  // Phase 3E-2: the executor does not own MemTable/ScriptAdapter; they
  // outlive every ExecuteReport call below.
  Executor := TVittixReportExecutor.Create(MemTable, ScriptAdapter);
  try
    // Dynamically load the exact same data the visual designer uses!
    // Phase 3C-1: --sample-data overrides the default; an explicit file
    // must exist.
    SampleDataFile := TPath.Combine(ReportsPath, 'sample_data.json');
    if Options.SampleDataFile <> '' then
    begin
      SampleDataFile := TPath.GetFullPath(Options.SampleDataFile);
      if not TFile.Exists(SampleDataFile) then
      begin
        WriteDiagnostic('Error: --sample-data file not found: ' + SampleDataFile);
        WriteDiagnostic('Run VittixRunner --help for usage information.');
        Halt(1);
      end;
    end;
    if TFile.Exists(SampleDataFile) then
      MemTable.LoadFromFile(SampleDataFile, sfJSON);

    for FileName in Files do
    begin
      var TestStartGDI, TestEndGDI: DWORD;
      var PageCount: Integer;
      var TestFailed: Boolean;
      var ErrorMsg: string;
      // Phase 3D-2: per-report recording state.
      var HasRecExpectedPages: Boolean;
      var RecExpectedPages: Integer;
      var RecLeakDelta: Integer;

      // Phase 3D-5: reset per-iteration leak delta so it does not
      // carry forward from a previous leak-classified report into
      // the structured-result status of the next report (which may
      // have no leak at all). Legacy leak detection (TestEndGDI -
      // TestStartGDI) is unaffected and remains the sole source of
      // truth for [LEAK] classification and FailCount.
      RecLeakDelta := 0;

      Classif := TReportDiscovery.ClassifyReport(FileName, TargetFile, RunMode);
      JustName := Classif.ReportName;
      ScriptBeforeCount := Classif.ScriptBeforeCount;
      ScriptAfterCount := Classif.ScriptAfterCount;

      // Phase 3E-3: excluded reports are dropped before any skip
      // recording, output, or execution (legacy precedence preserved).
      if Classif.Action = raExcluded then
        Continue;

      // Enforce TESTING.md rules for excluded files
      if Classif.Action = raSkip then
      begin
        // Phase 3D-2: record skipped report. No page counts are fabricated.
        Rec := Default(TReportExecutionResult);
        Rec.ReportName := JustName;
        Rec.Status := resSkipped;
        Rec.HasPageCount := False;
        Rec.HasExpectedPageCount := False;
        AppendReportResult(RunResult, Rec);
        // Phase 3D-4: emit the [SKIP] line at the same logical point via
        // the formatter (same text, same position relative to SkipCount).
        AppendObservation(Rec, FmtContext, 0, 0, False, False, 0, 0);
        if not IsJsonMode then
          Writeln(Formatter.FormatReportLine(Rec, FmtContext));
        Inc(SkipCount);
        Continue;
      end;

      // Phase 3E-3: raRun falls through to the existing execution path.

      TestStartGDI := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);
      TestFailed := False;
      ErrorMsg := '';
      PageCount := 0;
      HasRecExpectedPages := False;
      RecExpectedPages := 0;
      RecLeakDelta := 0;
      var IsExportHTMLReport := SameText(JustName, '38_export_html.vrt');

      // Phase 3E-2: report execution delegated to TVittixReportExecutor
      // (Vittix.Runner.Execution). GDI start measurement above, baseline
      // policy, reconciliation, formatting and console output stay here.
      Config := Default(TReportExecutionConfig);
      Config.FileName := FileName;
      Config.ReportName := JustName;
      Config.ScriptOnly := ScriptOnly;
      Config.ScriptTraceOnly := ScriptTraceOnly;
      Config.ScriptBeforeCount := ScriptBeforeCount;
      Config.ScriptAfterCount := ScriptAfterCount;
      Config.KeepVectorPDF := KeepVectorPDF;
      Config.VectorPdfOutputPath := VectorPdfOutputPath;

      // Phase 3E-2: script trace rendering moved behind a callback. The
      // executor fires this at the exact legacy point (after export smoke
      // verification, while the report model is alive). Branch structure,
      // text and ordering are identical to the former inline block; the
      // executor itself never writes to stdout.
      TraceCallback := procedure(const AReport: TReportModel)
      begin
        if not IsJsonMode then
        begin
          Writeln(Format('  [TRACE] %s', [JustName]));
          Writeln(Format('    Script objects: before=%d after=%d', [ScriptBeforeCount, ScriptAfterCount]));
          if ScriptTraceOnly then
          begin
            Writeln('');
            for var LObj in AReport.Objects do
              TraceScriptTree(ScriptAdapter, LObj, 2);
          end;
        end;
      end;

      Rec := Executor.ExecuteReport(Config, TraceCallback);
      TestFailed := Rec.Status = resFailed;
      ErrorMsg := Rec.ErrorMessage;
      PageCount := Rec.PageCount;

      // Legacy --script-trace pass: recorded before the temporary export
      // cleanup and the GDI end-measurement, exactly as the former
      // Continue bypassed that block.
      if ScriptTraceOnly and (Rec.Status = resPassed) then
      begin
        Inc(PassCount);
        // Phase 3D-2: script-trace reports pass without reaching the
        // legacy classification block below; record before continuing.
        AppendReportResult(RunResult, Rec);
        // Phase 3D-4: presentation observation for the trace-passed
        // report. No [PASS] line is emitted in script-trace mode
        // (legacy ordering preserved); the observation is still kept
        // in lock-step with RunResult.Reports.
        AppendObservation(Rec, FmtContext, Executor.LastElapsedMs,
          0, IsExportHTMLReport,
          True, ScriptBeforeCount, ScriptAfterCount);
        Continue;
      end;

      if not ScriptTraceOnly then
      begin
        if not Options.&Strict then
        begin
          // Non-strict: existing tolerant baseline comparison and
          // auto-registration behavior (unchanged).
          // Check against pagination baseline
          if LegacyBaseline.TryGetExpectedPages(JustName, ExpectedPages) then
          begin
            if ExpectedPages <> PageCount then
            begin
              TestFailed := True;
              ErrorMsg := Format('Pagination mismatch: Expected %d pages, got %d', [ExpectedPages, PageCount]);
            end;
            // Phase 3D-2: a baseline comparison actually occurred;
            // record the existing baseline value (never fabricated).
            HasRecExpectedPages := True;
            RecExpectedPages := ExpectedPages;
          end
          else
          begin
            LegacyBaseline.RegisterReport(JustName, PageCount);
            BaselineModified := True;
          end;
        end
        else
        begin
          // Phase 3C-2c-2: strict mode bypasses the legacy mutable
          // baseline path entirely. Only successful executions reach
          // this point; failures are handled by the exception handler
          // below and never produce an actual result.
          SetLength(ActualResults, Length(ActualResults) + 1);
          ActualResults[High(ActualResults)].ReportName := JustName;
          ActualResults[High(ActualResults)].PageCount := PageCount;
          // Phase 3D-2: strict reconciliation compares this report
          // against the baseline after the loop; capture the expected
          // value if the baseline contains it (read-only lookup).
          HasRecExpectedPages :=
            StrictBaseline.TryGetExpectedPages(JustName, RecExpectedPages);
        end;
      end
      else
      begin
        TestFailed := False;
        ErrorMsg := '';
      end;

      TestEndGDI := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);

      // Phase 3D-4: the legacy [LEAK] classification value is determined by
      // the exact conditions used by the output block below. It is captured
      // before building the structured result so the result model keeps
      // carrying GdiLeakDelta (Phase 3D-2 semantics, never reinterpreted).
      if (not TestFailed) and (TestEndGDI > TestStartGDI) and
         ((TestEndGDI - TestStartGDI) >= 25) then
        RecLeakDelta := Integer(TestEndGDI - TestStartGDI)
      else
        RecLeakDelta := 0;

      // Phase 3D-2: record the structured execution result, mirroring the
      // legacy classification exactly (no behavior change). A legacy
      // failure keeps its exact ErrorMessage ('EClass: message' or the
      // non-strict 'Pagination mismatch: ...' text). Page counts are
      // preserved when pagination had already succeeded.
      Rec := Default(TReportExecutionResult);
      Rec.ReportName := JustName;
      if TestFailed then
      begin
        Rec.Status := resFailed;
        Rec.HasPageCount := PageCount > 0;
        Rec.PageCount := PageCount;
        Rec.ErrorMessage := ErrorMsg;
        Rec.GdiLeakDelta := 0;
      end
      else
      begin
        if RecLeakDelta > 0 then
          Rec.Status := resFailed
        else
          Rec.Status := resPassed;
        Rec.HasPageCount := True;
        Rec.PageCount := PageCount;
        Rec.ErrorMessage := '';
        Rec.GdiLeakDelta := RecLeakDelta;
      end;
      Rec.HasExpectedPageCount := HasRecExpectedPages;
      Rec.ExpectedPageCount := RecExpectedPages;
      AppendReportResult(RunResult, Rec);

      // Phase 3D-4: presentation observation captured at the existing
      // computation points. ElapsedMs, the measured GDI cache delta, the
      // HTML smoke outcome and the script counts are supplied to the
      // formatter; the formatter never re-measures or re-executes anything.
      AppendObservation(Rec, FmtContext, Executor.LastElapsedMs,
        Integer(TestEndGDI - TestStartGDI),
        IsExportHTMLReport and not TestFailed,
        ScriptOnly or ScriptTraceOnly,
        ScriptBeforeCount, ScriptAfterCount);

      // Phase 3D-4: every legacy classification emission point is preserved
      // exactly (same branch structure, same ordering, same PASS/FAIL/LEAK
      // text). Only the rendering moved into the formatter.
      if TestFailed then
      begin
        if not IsJsonMode then
          Writeln(Formatter.FormatReportLine(Rec, FmtContext));
        Inc(FailCount);
      end
      else if TestEndGDI > TestStartGDI then
      begin
        // The VCL Graphics.pas unit globally caches Pens, Brushes, and Fonts.
        // Small GDI increases (< 25) during the first few reports are just normal cache allocations.
        if (TestEndGDI - TestStartGDI) < 25 then
        begin
          if not IsJsonMode then
            Writeln(Formatter.FormatReportLine(Rec, FmtContext));
          Inc(PassCount);
        end
        else
        begin
          if not IsJsonMode then
            Writeln(Formatter.FormatReportLine(Rec, FmtContext));
          Inc(FailCount);
          // Phase 3D-2: preserve the measured leak delta; the page count
          // stays recorded (never erased by leak classification).
          RecLeakDelta := Integer(TestEndGDI - TestStartGDI);
          // Phase 3D-5: correct the structured result for this report.
          // The report was appended before leak detection with
          // Status=resPassed and GdiLeakDelta=0. Update it so
          // TRegressionRunResult accurately reflects the legacy [LEAK]
          // classification (Status=resFailed, actual GDI delta preserved).
          RunResult.Reports[High(RunResult.Reports)].Status := resFailed;
          RunResult.Reports[High(RunResult.Reports)].GdiLeakDelta := RecLeakDelta;
        end;
      end
      else
      begin
        if not IsJsonMode then
          Writeln(Formatter.FormatReportLine(Rec, FmtContext));
        Inc(PassCount);
      end;
    end;
  finally
    Executor.Free;
    MemTable.Free;
    ScriptAdapter.Free;
  end;

  try
    // Phase 3E-4: the save decision (BaselineModified) stays here; the
    // serialization itself belongs to TLegacyBaseline. LegacyBaseline is
    // nil in strict mode, so strict runs can never write or free it
    // (structurally read-only).
    if BaselineModified then
      LegacyBaseline.SaveToFile(BaselineFile);
  finally
    LegacyBaseline.Free;
  end;

  // Phase 3D-2: record non-strict baseline auto-registration. This flag
  // alone never turns the run into a failure. Strict runs keep it False:
  // LegacyBaseline stays nil and BaselineModified is never set in strict
  // mode (structurally read-only).
  RunResult.BaselineUpdated := BaselineModified;

  EndGDI := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);
  EndUser := GetGuiResources(GetCurrentProcess, GR_USEROBJECTS);
  {$WARN SYMBOL_DEPRECATED OFF}
  EndMem := AllocMemSize;
  {$WARN SYMBOL_DEPRECATED ON}

  // Phase 3D-4: the runner supplies the process resource values; the
  // formatter only renders them (it never queries the OS itself).
  FmtContext.HasProcessSummary := True;
  FmtContext.Process.StartGDI := StartGDI;
  FmtContext.Process.EndGDI := EndGDI;
  FmtContext.Process.StartUser := StartUser;
  FmtContext.Process.EndUser := EndUser;
  FmtContext.Process.StartMem := StartMem;
  FmtContext.Process.EndMem := EndMem;

  // Phase 3D-5: strict reconciliation must be complete before the JSON
  // document is emitted because the document includes the reconciliation
  // object. Text mode keeps its original two-part summary order.
  if Options.&Strict then
  begin
    Reconciled := TRegressionBaseline.Reconcile(StrictBaseline, ActualResults);
    StrictFailed := StrictHasFailures(Reconciled, FailCount);

    // Phase 3D-2: expose the strict reconciliation through the
    // structured result. Reconciliation itself is unchanged.
    RunResult.BaselineCompared := True;
    RunResult.Reconciliation := Reconciled;

    // Phase 3D-4: the runner already computed the strict verdict
    // (StrictHasFailures) and the legacy FailCount (which includes
    // [LEAK] classifications). The formatter only reports those values;
    // exit-code and strict-semantics decisions stay below / unchanged.
    FmtContext.HasStrictSummary := True;
    FmtContext.&Strict.Failed := StrictFailed;
    FmtContext.&Strict.ExecutionErrorCount := FailCount;
  end;

  try
    if IsJsonMode then
    begin
      // Phase 3D-5: build the complete JSON string before writing anything.
      // Formatter failures are caught so stdout never receives partial JSON.
      try
        ReportText := Formatter.FormatRunSummary(RunResult, FmtContext);
      except
        on E: Exception do
        begin
          WriteLn(ErrOutput, 'Error: JSON formatter failed: ' + E.Message);
          Halt(1);
        end;
      end;
      Writeln(ReportText);
    end
    else
    begin
      Writeln(Formatter.FormatRunSummary(RunResult, FmtContext));
      if Options.&Strict then
        Writeln(Formatter.FormatStrictSummary(RunResult, FmtContext));
    end;
  finally
    if Options.&Strict and Assigned(StrictBaseline) then
    begin
      StrictBaseline.Free;
      StrictBaseline := nil;
    end;
  end;

  // Keep console open if running inside the Delphi IDE debugger or if -pause argument is used.
  // In JSON mode stdout must contain only the JSON document, so the prompt is suppressed.
  {$WARN SYMBOL_PLATFORM OFF}
  if not IsJsonMode and ((DebugHook <> 0) or Options.Pause) then
  begin
    Writeln('Press ENTER to exit...');
    Readln;
  end;
  {$WARN SYMBOL_PLATFORM ON}

  if Options.&Strict then
  begin
    // Phase 3C-2c-2: strict regression failure (reconciliation issues,
    // execution failures, or [LEAK]) -> exit 1. Configuration errors
    // already exited with 2 above.
    if StrictFailed then
      Halt(1)
    else
      Halt(0);
  end
  else if FailCount > 0 then
    Halt(1)
  else
    Halt(0);
end;

end.
