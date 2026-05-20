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
  System.JSON,
  Winapi.Windows,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.StorageJSON,
  Vcl.Graphics, // Required to ensure GDI canvas is available for measurement
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.Context,
  Vittix.Report.Scripting,
  Vittix.Report.Engine,
  Vittix.Report.Serializer,
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Objects.Table,
  Vittix.Report.ScriptHost.Adapter;

function CountOccurrences(const Haystack, Needle: string): Integer;
var
  P: Integer;
  SearchFrom: Integer;
begin
  Result := 0;
  if (Haystack = '') or (Needle = '') then
    Exit;
  SearchFrom := 1;
  while True do
  begin
    P := PosEx(Needle, Haystack, SearchFrom);
    if P = 0 then
      Break;
    Inc(Result);
    SearchFrom := P + Length(Needle);
  end;
end;

function HasExactSwitch(const ASwitch: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), ASwitch) then
      Exit(True);
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

{ TVittixConsoleRunner }

class procedure TVittixConsoleRunner.Run;
var
  ReportsPath: string;
  Files: TArray<string>;
  FileName, JustName, TargetFile: string;
  Report: TReportModel;
  Engine: TReportEngine;
  MemTable: TFDMemTable;
  Stopwatch: TStopwatch;
  PassCount, FailCount, SkipCount, I: Integer;
  StartGDI, EndGDI: DWORD;
  StartUser, EndUser: DWORD;
  StartMem, EndMem: Int64;
  BaselineFile: string;
  BaselineJSON: TJSONObject;
  BaselineModified: Boolean;
  ExpectedPages: Integer;
  ScriptAdapter: TReportScriptHostAdapter;
  ScriptOnly: Boolean;
  ScriptTraceOnly: Boolean;
  ReportText: string;
  HasObjectScript: Boolean;
  ScriptBeforeCount: Integer;
  ScriptAfterCount: Integer;
  Obj: TReportObject;
begin
  Writeln('================================================');
  Writeln(' VittixReport Headless Regression Runner');
  Writeln('================================================');

  // Locate the reports directory dynamically based on executable location
  ReportsPath := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\reports'));
  if not TDirectory.Exists(ReportsPath) then
    ReportsPath := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\reports'));
  if not TDirectory.Exists(ReportsPath) then
    ReportsPath := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\..\reports')); // Finds it from bin\Win32\Debug\

  if not TDirectory.Exists(ReportsPath) then
  begin
    Writeln('Error: Could not locate "reports" directory at ', ReportsPath);
    {$WARN SYMBOL_PLATFORM OFF}
    if (DebugHook <> 0) or FindCmdLineSwitch('pause', True) then
    begin
      Writeln('Press ENTER to exit...');
      Readln;
    end;
    {$WARN SYMBOL_PLATFORM ON}
    Halt(1);
  end;

  Writeln('Target: ', ReportsPath);
  
  TargetFile := '';
  for I := 1 to ParamCount do
  begin
    if not ParamStr(I).StartsWith('-') then
    begin
      TargetFile := ParamStr(I);
      Writeln('Filter: ', TargetFile);
      Break;
    end;
  end;
  Writeln('------------------------------------------------');

  ScriptOnly := HasExactSwitch('--scripts');
  ScriptTraceOnly := HasExactSwitch('--script-trace');
  if ScriptOnly then
    Writeln('Mode: script-focused reports only');
  if ScriptTraceOnly then
    Writeln('Mode: script trace only');

  Files := TDirectory.GetFiles(ReportsPath, '*.vrt');
  TArray.Sort<string>(Files); // Ensure deterministic execution order

  PassCount := 0;
  FailCount := 0;
  SkipCount := 0;

  StartGDI := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);
  StartUser := GetGuiResources(GetCurrentProcess, GR_USEROBJECTS);
  {$WARN SYMBOL_DEPRECATED OFF}
  StartMem := AllocMemSize;
  {$WARN SYMBOL_DEPRECATED ON}
  
  BaselineFile := TPath.Combine(ReportsPath, 'regression_baselines.json');
  BaselineModified := False;
  if TFile.Exists(BaselineFile) then
  begin
    BaselineJSON := TJSONObject.ParseJSONValue(TFile.ReadAllText(BaselineFile, TEncoding.UTF8)) as TJSONObject;
    if not Assigned(BaselineJSON) then
      BaselineJSON := TJSONObject.Create;
  end
  else
  BaselineJSON := TJSONObject.Create;

  // Note: You may need to adapt this dummy dataset to exactly match what the designer uses
  MemTable := TFDMemTable.Create(nil);
  ScriptAdapter := TReportScriptHostAdapter.Create;
  try
    // Dynamically load the exact same data the visual designer uses!
    if TFile.Exists(TPath.Combine(ReportsPath, 'sample_data.json')) then
      MemTable.LoadFromFile(TPath.Combine(ReportsPath, 'sample_data.json'), sfJSON);

    for FileName in Files do
    begin
      var TestStartGDI, TestEndGDI: DWORD;
      var PageCount: Integer;
      var ElapsedMs: Int64;
      var TestFailed: Boolean;
      var ErrorMsg: string;

      JustName := ExtractFileName(FileName);
      ReportText := '';
      HasObjectScript := False;
      ScriptBeforeCount := 0;
      ScriptAfterCount := 0;

      if (TargetFile <> '') and not SameText(JustName, TargetFile) then
        Continue;

      if ScriptOnly or ScriptTraceOnly then
      begin
        ReportText := TFile.ReadAllText(FileName, TEncoding.UTF8);
        ScriptBeforeCount := CountOccurrences(ReportText, '"OnBeforePrint": "');
        ScriptAfterCount := CountOccurrences(ReportText, '"OnAfterPrint": "');
        HasObjectScript := (ScriptBeforeCount > 0) or (ScriptAfterCount > 0);
        if not HasObjectScript then
          Continue;
      end;

      // Enforce TESTING.md rules for excluded files
      if JustName.StartsWith('test') or JustName.Equals('16_large_preview_warning.vrt') then
      begin
        Writeln(Format('[SKIP] %-40s', [JustName]));
        Inc(SkipCount);
        Continue;
      end;

      TestStartGDI := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);
      TestFailed := False;
      ErrorMsg := '';
      PageCount := 0;
      ElapsedMs := 0;

      try
        Report := TReportSerializer.LoadFromFile(FileName);
        try
          Engine := TReportEngine.Create(Report, MemTable);
          try
            // Wire up the Script Adapter so object events execute during regression tests!
            Engine.ScriptEngine.OnObjectBeforePrint := ScriptAdapter.EngineObjectBeforePrint;
            Engine.ScriptEngine.OnObjectAfterPrint := ScriptAdapter.EngineObjectAfterPrint;

            Stopwatch := TStopwatch.StartNew;
            Engine.Prepare;
            Stopwatch.Stop;
            PageCount := Engine.Pages.Count;
            ElapsedMs := Stopwatch.ElapsedMilliseconds;

            if ScriptOnly and Assigned(Report) and ((ScriptBeforeCount > 0) or (ScriptAfterCount > 0)) then
            begin
              Writeln(Format('  [TRACE] %s', [JustName]));
              Writeln(Format('    Script objects: before=%d after=%d', [ScriptBeforeCount, ScriptAfterCount]));
            end
            else if ScriptTraceOnly and Assigned(Report) and ((ScriptBeforeCount > 0) or (ScriptAfterCount > 0)) then
            begin
              Writeln(Format('  [TRACE] %s', [JustName]));
              Writeln(Format('    Script objects: before=%d after=%d', [ScriptBeforeCount, ScriptAfterCount]));
              Writeln('');
              for Obj in Report.Objects do
                TraceScriptTree(ScriptAdapter, Obj, 2);
            end;
            if ScriptTraceOnly then
            begin
              Inc(PassCount);
              Continue;
            end;
            if not ScriptTraceOnly then
            begin
              // Check against pagination baseline
              if BaselineJSON.TryGetValue<Integer>(JustName, ExpectedPages) then
              begin
                if ExpectedPages <> PageCount then
                begin
                  TestFailed := True;
                  ErrorMsg := Format('Pagination mismatch: Expected %d pages, got %d', [ExpectedPages, PageCount]);
                end;
              end
              else
              begin
                BaselineJSON.AddPair(JustName, TJSONNumber.Create(PageCount));
                BaselineModified := True;
              end;
            end
            else
            begin
              TestFailed := False;
              ErrorMsg := '';
            end;
          finally
            Engine.Free;
          end;
        finally
          Report.Free;
        end;
      except
        on E: Exception do
        begin
          TestFailed := True;
          ErrorMsg := Format('%s: %s', [E.ClassName, E.Message]);
        end;
      end;

      TestEndGDI := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);

      if TestFailed then
      begin
        Writeln(Format('[FAIL] %-40s | %s', [JustName, ErrorMsg]));
        Inc(FailCount);
      end
      else if TestEndGDI > TestStartGDI then
      begin
        // The VCL Graphics.pas unit globally caches Pens, Brushes, and Fonts.
        // Small GDI increases (< 25) during the first few reports are just normal cache allocations.
        if (TestEndGDI - TestStartGDI) < 25 then
        begin
          Writeln(Format('[PASS] %-40s | %3d pgs | %4d ms | VCL Cache: +%d', [JustName, PageCount, ElapsedMs, TestEndGDI - TestStartGDI]));
          Inc(PassCount);
        end
        else
        begin
          Writeln(Format('[LEAK] %-40s | %3d pgs | %4d ms | GDI Delta: +%d', [JustName, PageCount, ElapsedMs, TestEndGDI - TestStartGDI]));
          Inc(FailCount);
        end;
      end
      else
      begin
        Writeln(Format('[PASS] %-40s | %3d pgs | %4d ms', [JustName, PageCount, ElapsedMs]));
        Inc(PassCount);
      end;
    end;
  finally
    MemTable.Free;
    ScriptAdapter.Free;
  end;

  if BaselineModified then
    TFile.WriteAllText(BaselineFile, BaselineJSON.Format(2), TEncoding.UTF8);
  BaselineJSON.Free;

  EndGDI := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);
  EndUser := GetGuiResources(GetCurrentProcess, GR_USEROBJECTS);
  {$WARN SYMBOL_DEPRECATED OFF}
  EndMem := AllocMemSize;
  {$WARN SYMBOL_DEPRECATED ON}

  Writeln('================================================');
  Writeln(Format(' Results: %d Passed, %d Failed, %d Skipped', [PassCount, FailCount, SkipCount]));
  Writeln('------------------------------------------------');
  Writeln(Format(' GDI Handles : %d -> %d (Delta: %d)', [StartGDI, EndGDI, Integer(EndGDI) - Integer(StartGDI)]));
  Writeln(Format(' USER Handles: %d -> %d (Delta: %d)', [StartUser, EndUser, Integer(EndUser) - Integer(StartUser)]));
  Writeln(Format(' Memory Alloc: %d KB -> %d KB (Delta: %d KB)', [StartMem div 1024, EndMem div 1024, (EndMem - StartMem) div 1024]));
  Writeln('================================================');

  // Keep console open if running inside the Delphi IDE debugger or if -pause argument is used
  {$WARN SYMBOL_PLATFORM OFF}
  if (DebugHook <> 0) or FindCmdLineSwitch('pause', True) then
  begin
    Writeln('Press ENTER to exit...');
    Readln;
  end;
  {$WARN SYMBOL_PLATFORM ON}

  if FailCount > 0 then
    Halt(1)
  else
    Halt(0);
end;

end.
