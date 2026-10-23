unit Vittix.Runner.Discovery;

{
  Phase 3E-3: Report Discovery / Classification Service.

  Extracted from Vittix.Runner.Console.pas - pure report enumeration and
  classification without console I/O, CLI parsing, baseline policy, or
  report execution.

  TReportDiscovery owns:
    - deterministic .vrt report enumeration
    - per-report classification (filter / script-mode / skip policy)

  Classification precedence (must match the legacy runner exactly):

    1. Filter mismatch
       -> raExcluded
       -> the report file is NOT read

    2. Script-only / script-trace mode with no matching script objects
       -> raExcluded

    3. TESTING.md skip policy
       -> report name starts with "test"
       OR report name equals "16_large_preview_warning.vrt"
       -> raSkip

    4. Otherwise
       -> raRun

  The unit does NOT:
    - parse CLI arguments (ParamStr / ParamCount)
    - call Halt
    - perform baseline reconciliation / mutate baselines
    - measure GDI handles / classify leaks
    - execute reports
    - emit console output / final summaries / JSON
    - choose exit codes
}

interface

type
  TReportRunMode = (rmAll, rmScriptOnly, rmScriptTraceOnly);

  TReportAction = (raRun, raSkip, raExcluded);

  TReportClassification = record
    FileName: string;
    ReportName: string;
    Action: TReportAction;
    ScriptBeforeCount: Integer;
    ScriptAfterCount: Integer;
  end;

  TReportDiscovery = class
  public
    class function EnumerateReports(
      const AReportsPath: string): TArray<string>; static;

    class function ClassifyReport(
      const AFileName, AFilter: string;
      AMode: TReportRunMode): TReportClassification; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  System.Generics.Collections,
  Vittix.Runner.ExportVerification;

class function TReportDiscovery.EnumerateReports(
  const AReportsPath: string): TArray<string>;
begin
  // Preserve the legacy runner behavior: collect all *.vrt files in the
  // directory, then sort deterministically for stable execution order.
  // The caller guarantees the directory has already been validated.
  Result := TDirectory.GetFiles(AReportsPath, '*.vrt');
  TArray.Sort<string>(Result);
end;

class function TReportDiscovery.ClassifyReport(
  const AFileName, AFilter: string;
  AMode: TReportRunMode): TReportClassification;
var
  ReportText: string;
begin
  Result := Default(TReportClassification);
  Result.FileName := AFileName;
  Result.ReportName := ExtractFileName(AFileName);

  // 1. Filter mismatch -> raExcluded. The report file is not read.
  if (AFilter <> '') and not SameText(Result.ReportName, AFilter) then
  begin
    Result.Action := raExcluded;
    Exit;
  end;

  // 2. Script-only / script-trace mode with no matching script objects
  //    -> raExcluded. The report text is read (UTF-8) only to count
  //    OnBeforePrint / OnAfterPrint occurrences; the counts are reused
  //    by the caller (no duplicate file I/O or counting policy).
  if AMode in [rmScriptOnly, rmScriptTraceOnly] then
  begin
    ReportText := TFile.ReadAllText(AFileName, TEncoding.UTF8);
    Result.ScriptBeforeCount := CountOccurrences(ReportText, '"OnBeforePrint": "');
    Result.ScriptAfterCount := CountOccurrences(ReportText, '"OnAfterPrint": "');
    if (Result.ScriptBeforeCount = 0) and (Result.ScriptAfterCount = 0) then
    begin
      Result.Action := raExcluded;
      Exit;
    end;
  end;

  // 3. TESTING.md skip policy -> raSkip.
  if Result.ReportName.StartsWith('test') or
     Result.ReportName.Equals('16_large_preview_warning.vrt') then
    Result.Action := raSkip
  else
    // 4. Otherwise -> raRun.
    Result.Action := raRun;
end;

end.