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
  Vcl.Imaging.pngimage,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.Context,
  Vittix.Report.Scripting,
  Vittix.Report.Engine,
  Vittix.Report.UserDataSet,
  Vittix.Report.Export.Commands,
  Vittix.Report.Export.VectorPDF,
  Vittix.Report.Export.VectorPDF.EMF,
  Vittix.Report.Export.HTML,
  Vittix.Report.Export.XLSX,
  Vittix.Report.Serializer,
  Vittix.Runner.Options,
  Vittix.Runner.Baseline,
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Objects.Table,
  Vittix.Report.Objects.CrossTab,
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
  // Retained for compatibility; Phase 3C-1 parsing is in Vittix.Runner.Options.
  Result := False;
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), ASwitch) then
      Exit(True);
end;

function BytesContainAscii(const ABytes: TBytes; const AText: AnsiString): Boolean;
var
  I: Integer;
  J: Integer;
begin
  Result := False;
  if (Length(ABytes) = 0) or (Length(AText) = 0) or
     (Length(ABytes) < Length(AText)) then
    Exit;

  for I := 0 to Length(ABytes) - Length(AText) do
  begin
    Result := True;
    for J := 1 to Length(AText) do
      if ABytes[I + J - 1] <> Ord(AText[J]) then
      begin
        Result := False;
        Break;
      end;
    if Result then
      Exit;
  end;
end;

function CountAsciiOccurrences(const ABytes: TBytes; const AText: AnsiString): Integer;
var
  I: Integer;
  J: Integer;
  Match: Boolean;
begin
  Result := 0;
  if (Length(ABytes) = 0) or (Length(AText) = 0) or
     (Length(ABytes) < Length(AText)) then
    Exit;

  for I := 0 to Length(ABytes) - Length(AText) do
  begin
    Match := True;
    for J := 1 to Length(AText) do
      if ABytes[I + J - 1] <> Ord(AText[J]) then
      begin
        Match := False;
        Break;
      end;
    if Match then
      Inc(Result);
  end;
end;

function PdfPointNumber(AValue: Integer): AnsiString;
begin
  Result := AnsiString(StringReplace(
    FormatFloat('0.###', AValue * (72 / 96)),
    FormatSettings.DecimalSeparator,
    '.',
    []));
end;

function ExportDocumentContainsText(ADocument: TReportExportDocument;
  const AText: string): Boolean;
var
  Page: TReportExportPage;
  Command: TReportExportCommand;
begin
  Result := False;
  if not Assigned(ADocument) then
    Exit;

  for Page in ADocument.Pages do
    for Command in Page.Commands do
      if (Command is TReportExportTextCommand) and
         ContainsText(TReportExportTextCommand(Command).Text, AText) then
        Exit(True);
end;

procedure RequireExportText(ADocument: TReportExportDocument; const AText: string);
begin
  if not ExportDocumentContainsText(ADocument, AText) then
    raise Exception.CreateFmt('Expected rendered dataset value not found: %s', [AText]);
end;

function CountExportTextCommands(ADocument: TReportExportDocument;
  const AText: string): Integer;
var
  Page: TReportExportPage;
  Command: TReportExportCommand;
begin
  Result := 0;
  if not Assigned(ADocument) then
    Exit;

  for Page in ADocument.Pages do
    for Command in Page.Commands do
      if (Command is TReportExportTextCommand) and
         SameText(TReportExportTextCommand(Command).Text, AText) then
        Inc(Result);
end;

function ExportDocumentContainsImageSource(ADocument: TReportExportDocument;
  const ASource: string): Boolean;
var
  Page: TReportExportPage;
  Command: TReportExportCommand;
begin
  Result := False;
  if not Assigned(ADocument) then
    Exit;

  for Page in ADocument.Pages do
    for Command in Page.Commands do
      if (Command is TReportExportImageCommand) and
         SameText(TReportExportImageCommand(Command).Source, ASource) then
        Exit(True);
end;

function CountExportImageCommands(ADocument: TReportExportDocument): Integer;
var
  Page: TReportExportPage;
  Command: TReportExportCommand;
begin
  Result := 0;
  if not Assigned(ADocument) then
    Exit;

  for Page in ADocument.Pages do
    for Command in Page.Commands do
      if Command is TReportExportImageCommand then
        Inc(Result);
end;

procedure CreateVerificationPNG(const AFileName: string; const AColor: TColor);
var
  Bitmap: TBitmap;
  PNG: TPngImage;
begin
  Bitmap := TBitmap.Create;
  PNG := TPngImage.Create;
  try
    Bitmap.SetSize(16, 16);
    Bitmap.Canvas.Brush.Color := AColor;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    PNG.Assign(Bitmap);
    PNG.SaveToFile(AFileName);
  finally
    PNG.Free;
    Bitmap.Free;
  end;
end;

function BuildImageBindingData(const ALogoFile, ASignatureFile,
  AMissingImageFile: string): TFDMemTable;
begin
  Result := TFDMemTable.Create(nil);
  Result.FieldDefs.Add('LOGO_PATH', ftString, 260);
  Result.FieldDefs.Add('SIGNATURE_PATH', ftString, 260);
  Result.FieldDefs.Add('MISSING_IMAGE_PATH', ftString, 260);
  Result.CreateDataSet;
  Result.Append;
  Result.FieldByName('LOGO_PATH').AsString := ALogoFile;
  Result.FieldByName('SIGNATURE_PATH').AsString := ASignatureFile;
  Result.FieldByName('MISSING_IMAGE_PATH').AsString := AMissingImageFile;
  Result.Post;
  Result.First;
end;

function CreateInvoiceContractTable(const AValueField, AValue: string): TFDMemTable;
begin
  Result := TFDMemTable.Create(nil);
  Result.FieldDefs.Add('INVOICE_ID', ftInteger);
  Result.FieldDefs.Add(AValueField, ftString, 80);
  Result.CreateDataSet;
  Result.Append;
  Result.FieldByName('INVOICE_ID').AsInteger := 101;
  Result.FieldByName(AValueField).AsString := AValue;
  Result.Post;
  Result.First;
end;

procedure AddInvoiceContractDataSet(const AName, AValueField, AValue: string;
  ADataSets: TObjectList<TFDMemTable>;
  AUserDataSets: TObjectList<TVittixUserDataSet>;
  ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out AUserDataSet: TVittixUserDataSet);
var
  DataSet: TFDMemTable;
begin
  DataSet := CreateInvoiceContractTable(AValueField, AValue);
  ADataSets.Add(DataSet);
  AUserDataSet := TVittixUserDataSet.Create(nil);
  AUserDataSet.Name := AName;
  AUserDataSet.DataSet := DataSet;
  AUserDataSets.Add(AUserDataSet);
  ANamedDataSets.Add(AName, AUserDataSet);
end;

procedure BuildInvoiceContractData(out APrimaryDataSet: TVittixUserDataSet;
  out ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out ADataSets: TObjectList<TFDMemTable>;
  out AUserDataSets: TObjectList<TVittixUserDataSet>);
var
  UserDataSet: TVittixUserDataSet;
begin
  APrimaryDataSet := nil;
  ANamedDataSets := TDictionary<string, TVittixUserDataSet>.Create;
  ADataSets := TObjectList<TFDMemTable>.Create(True);
  AUserDataSets := TObjectList<TVittixUserDataSet>.Create(True);
  AddInvoiceContractDataSet('Invoice', 'INVOICE_NO_STR', 'VX-INVOICE-001',
    ADataSets, AUserDataSets, ANamedDataSets, APrimaryDataSet);
  AddInvoiceContractDataSet('Items', 'ITEM_NAME', 'VX-ITEM-LINE',
    ADataSets, AUserDataSets, ANamedDataSets, UserDataSet);
  AddInvoiceContractDataSet('Company', 'COMPANY_NAME', 'VX-COMPANY',
    ADataSets, AUserDataSets, ANamedDataSets, UserDataSet);
  AddInvoiceContractDataSet('Party', 'PARTY_NAME', 'VX-PARTY',
    ADataSets, AUserDataSets, ANamedDataSets, UserDataSet);
  AddInvoiceContractDataSet('InvoiceCustom', 'CUSTOM_TEXT', 'VX-INVOICE-CUSTOM',
    ADataSets, AUserDataSets, ANamedDataSets, UserDataSet);
  AddInvoiceContractDataSet('ItemCustom', 'CUSTOM_ITEM_TEXT', 'VX-ITEM-CUSTOM',
    ADataSets, AUserDataSets, ANamedDataSets, UserDataSet);
end;

procedure BuildInvoicePaginationData(out APrimaryDataSet: TVittixUserDataSet;
  out ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out ADataSets: TObjectList<TFDMemTable>;
  out AUserDataSets: TObjectList<TVittixUserDataSet>);
var
  InvoiceDataSet: TFDMemTable;
  ItemsDataSet: TFDMemTable;
  ItemsUserDataSet: TVittixUserDataSet;
  I: Integer;
begin
  ANamedDataSets := TDictionary<string, TVittixUserDataSet>.Create;
  ADataSets := TObjectList<TFDMemTable>.Create(True);
  AUserDataSets := TObjectList<TVittixUserDataSet>.Create(True);

  InvoiceDataSet := CreateInvoiceContractTable('INVOICE_NO_STR', 'VX-PAGED-INVOICE');
  ADataSets.Add(InvoiceDataSet);
  APrimaryDataSet := TVittixUserDataSet.Create(nil);
  APrimaryDataSet.Name := 'Invoice';
  APrimaryDataSet.DataSet := InvoiceDataSet;
  AUserDataSets.Add(APrimaryDataSet);
  ANamedDataSets.Add('Invoice', APrimaryDataSet);

  ItemsDataSet := TFDMemTable.Create(nil);
  ItemsDataSet.FieldDefs.Add('INVOICE_ID', ftInteger);
  ItemsDataSet.FieldDefs.Add('ITEM_NAME', ftString, 80);
  ItemsDataSet.FieldDefs.Add('QTY', ftInteger);
  ItemsDataSet.CreateDataSet;
  for I := 1 to 80 do
  begin
    ItemsDataSet.Append;
    ItemsDataSet.FieldByName('INVOICE_ID').AsInteger := 101;
    ItemsDataSet.FieldByName('ITEM_NAME').AsString := Format('VX-PAGED-ITEM-%2.2d', [I]);
    ItemsDataSet.FieldByName('QTY').AsInteger := I;
    ItemsDataSet.Post;
  end;
  ItemsDataSet.First;
  ADataSets.Add(ItemsDataSet);
  ItemsUserDataSet := TVittixUserDataSet.Create(nil);
  ItemsUserDataSet.Name := 'Items';
  ItemsUserDataSet.DataSet := ItemsDataSet;
  AUserDataSets.Add(ItemsUserDataSet);
  ANamedDataSets.Add('Items', ItemsUserDataSet);
end;

procedure BuildReportDataContractData(out APrimaryDataSet: TVittixUserDataSet;
  out ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out ADataSets: TObjectList<TFDMemTable>;
  out AUserDataSets: TObjectList<TVittixUserDataSet>);
var
  DataSet: TFDMemTable;
  I: Integer;
  RowValues: array[1..3] of string;
begin
  ANamedDataSets := TDictionary<string, TVittixUserDataSet>.Create;
  ADataSets := TObjectList<TFDMemTable>.Create(True);
  AUserDataSets := TObjectList<TVittixUserDataSet>.Create(True);

  DataSet := TFDMemTable.Create(nil);
  DataSet.FieldDefs.Add('PARTY_NAME', ftString, 80);
  DataSet.FieldDefs.Add('BALANCE_TEXT', ftString, 80);
  DataSet.CreateDataSet;
  RowValues[1] := 'VX-REPORTDATA-PARTY-A';
  RowValues[2] := 'VX-REPORTDATA-PARTY-B';
  RowValues[3] := 'VX-REPORTDATA-PARTY-C';
  for I := 1 to Length(RowValues) do
  begin
    DataSet.Append;
    DataSet.FieldByName('PARTY_NAME').AsString := RowValues[I];
    DataSet.FieldByName('BALANCE_TEXT').AsString := Format('VX-BALANCE-%d', [I]);
    DataSet.Post;
  end;
  DataSet.First;
  ADataSets.Add(DataSet);

  APrimaryDataSet := TVittixUserDataSet.Create(nil);
  APrimaryDataSet.Name := 'ReportData';
  APrimaryDataSet.DataSet := DataSet;
  AUserDataSets.Add(APrimaryDataSet);
  ANamedDataSets.Add('ReportData', APrimaryDataSet);
end;

procedure BuildDetailBandsData(out APrimaryDataSet: TVittixUserDataSet;
  out ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out ADataSets: TObjectList<TFDMemTable>;
  out AUserDataSets: TObjectList<TVittixUserDataSet>);
var
  MasterDS, DetailDS: TFDMemTable;
  UserDS: TVittixUserDataSet;
  I, J: Integer;
begin
  ANamedDataSets := TDictionary<string, TVittixUserDataSet>.Create;
  ADataSets := TObjectList<TFDMemTable>.Create(True);
  AUserDataSets := TObjectList<TVittixUserDataSet>.Create(True);

  MasterDS := TFDMemTable.Create(nil);
  MasterDS.FieldDefs.Add('InvoiceNo', ftString, 20);
  MasterDS.FieldDefs.Add('CustomerName', ftString, 80);
  MasterDS.CreateDataSet;

  DetailDS := TFDMemTable.Create(nil);
  DetailDS.FieldDefs.Add('InvoiceNo', ftString, 20);
  DetailDS.FieldDefs.Add('ItemName', ftString, 80);
  DetailDS.FieldDefs.Add('Amount', ftFloat);
  DetailDS.CreateDataSet;

  for I := 1 to 5 do
  begin
    MasterDS.AppendRecord(['INV-' + IntToStr(I), 'Customer ' + IntToStr(I)]);
    for J := 1 to 3 do
      DetailDS.AppendRecord(['INV-' + IntToStr(I), 'Item ' + IntToStr(I) + '-' + IntToStr(J), I * 10.5 * J]);
  end;
  MasterDS.First;
  DetailDS.First;

  ADataSets.Add(MasterDS);
  ADataSets.Add(DetailDS);

  APrimaryDataSet := TVittixUserDataSet.Create(nil);
  APrimaryDataSet.Name := 'MasterData';
  APrimaryDataSet.DataSet := MasterDS;
  AUserDataSets.Add(APrimaryDataSet);
  ANamedDataSets.Add('MasterData', APrimaryDataSet);

  UserDS := TVittixUserDataSet.Create(nil);
  UserDS.Name := 'DetailData';
  UserDS.DataSet := DetailDS;
  AUserDataSets.Add(UserDS);
  ANamedDataSets.Add('DetailData', UserDS);
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

function TryGetBaselinePageCount(ABaselineJSON: TJSONObject;
  const AReportName: string; out APageCount: Integer): Boolean;
var
  I: Integer;
  Pair: TJSONPair;
begin
  Result := False;
  if not Assigned(ABaselineJSON) then
    Exit;

  for I := ABaselineJSON.Count - 1 downto 0 do
  begin
    Pair := ABaselineJSON.Pairs[I];
    if SameText(Pair.JsonString.Value, AReportName) then
      Exit(TryStrToInt(Pair.JsonValue.Value, APageCount));
  end;
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
  Report: TReportModel;
  Engine: TReportEngine;
  ExportDoc: TReportExportDocument;
  MemTable: TFDMemTable;
  Stopwatch: TStopwatch;
  PassCount, FailCount, SkipCount, I: Integer;
  StartGDI, EndGDI: DWORD;
  StartUser, EndUser: DWORD;
  StartMem, EndMem: Int64;
  BaselineFile: string;
  BaselineJSON: TJSONObject;
  StrictBaseline: TRegressionBaseline;
  StrictParseError: TBaselineParseError;
  ActualResults: TArray<TReportPageResult>;
  Reconciled: TBaselineReconciliationResult;
  StrictIssue: TBaselineIssue;
  StrictFailed: Boolean;
  BaselineModified: Boolean;
  ExpectedPages: Integer;
  ScriptAdapter: TReportScriptHostAdapter;
  ScriptOnly: Boolean;
  ScriptTraceOnly: Boolean;
  KeepVectorPDF: Boolean;
  VectorPdfOutputPath: string;
  ReportText: string;
  HasObjectScript: Boolean;
  ScriptBeforeCount: Integer;
  ScriptAfterCount: Integer;
  Obj: TReportObject;
  VectorPdfFile: string;
  Header: TBytes;
  StreamHeader: TBytes;
  VectorPdfStream: TMemoryStream;
  InvoicePrimaryDataSet: TVittixUserDataSet;
  InvoiceNamedDataSets: TDictionary<string, TVittixUserDataSet>;
  InvoiceDataSets: TObjectList<TFDMemTable>;
  InvoiceUserDataSets: TObjectList<TVittixUserDataSet>;
  IsInvoiceContractReport: Boolean;
  IsRuntimeParameterReport: Boolean;
  IsImageBindingReport: Boolean;
  IsInvoicePaginationReport: Boolean;
  IsReportDataContractReport: Boolean;
  ImageBindingDataSet: TFDMemTable;
  LogoImageFile: string;
  SignatureImageFile: string;
  MissingImageFile: string;
begin
  Writeln('================================================');
  Writeln(' VittixReport Headless Regression Runner');
  Writeln('================================================');

  // Phase 3C-1: all CLI parsing is delegated to Vittix.Runner.Options.
  // Arguments are acquired here (process-global state stays in the console
  // entry point); parsing itself is deterministic and unit-tested.
  SetLength(Args, ParamCount);
  for I := 1 to ParamCount do
    Args[I - 1] := ParamStr(I);

  if not ParseOptions(Args, Options) then
  begin
    Writeln(Options.ErrorMessage);
    Writeln('Run VittixRunner --help for usage information.');
    // Phase 3C-2c-2: a strict run that fails CLI validation is a strict
    // configuration error (exit 2). Non-strict parse failures keep the
    // existing exit code 1.
    if Options.&Strict then
      Halt(2)
    else
      Halt(1);
  end;

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
      Writeln('Error: --reports directory not found: ', ReportsPath);
      Writeln('Run VittixRunner --help for usage information.');
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
  end;

  Writeln('Target: ', ReportsPath);

  TargetFile := Options.Filter;
  if TargetFile <> '' then
    Writeln('Filter: ', TargetFile);
  Writeln('------------------------------------------------');

  ScriptOnly := Options.ScriptOnly;
  ScriptTraceOnly := Options.ScriptTraceOnly;
  KeepVectorPDF := Options.KeepVectorPDF;
  if ScriptOnly then
    Writeln('Mode: script-focused reports only');
  if ScriptTraceOnly then
    Writeln('Mode: script trace only');
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
  if KeepVectorPDF then
    Writeln('Vector PDF output: ', VectorPdfOutputPath);

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
  if Options.BaselineFile <> '' then
    BaselineFile := TPath.GetFullPath(Options.BaselineFile);
  BaselineModified := False;
  BaselineJSON := nil;
  StrictBaseline := nil;
  StrictFailed := False;
  // Phase 3C-2c-2: strict mode uses the validated read-only baseline loader
  // (TRegressionBaseline.LoadFromFile), never the tolerant raw TJSONObject
  // path below, and never fabricates an empty baseline object. A missing,
  // empty, malformed or invalid baseline is a strict configuration error
  // (exit 2); no reports are executed in that case.
  if Options.&Strict then
  begin
    if not TRegressionBaseline.LoadFromFile(BaselineFile, StrictBaseline, StrictParseError) then
    begin
      Writeln('Error: strict regression baseline could not be loaded: ', BaselineFile);
      if StrictParseError.Message <> '' then
        Writeln('Error: ', StrictParseError.Message);
      Halt(2);
    end;
  end
  else
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
    // Phase 3C-1: --sample-data overrides the default; an explicit file
    // must exist.
    SampleDataFile := TPath.Combine(ReportsPath, 'sample_data.json');
    if Options.SampleDataFile <> '' then
    begin
      SampleDataFile := TPath.GetFullPath(Options.SampleDataFile);
      if not TFile.Exists(SampleDataFile) then
      begin
        Writeln('Error: --sample-data file not found: ', SampleDataFile);
        Writeln('Run VittixRunner --help for usage information.');
        Halt(1);
      end;
    end;
    if TFile.Exists(SampleDataFile) then
      MemTable.LoadFromFile(SampleDataFile, sfJSON);

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
      VectorPdfFile := '';
      IsInvoiceContractReport := SameText(JustName, '30_invoice_named_datasets_contract.vrt');
      IsRuntimeParameterReport := SameText(JustName, '31_runtime_parameter_values.vrt');
      IsImageBindingReport := SameText(JustName, '32_image_binding_values.vrt');
      IsInvoicePaginationReport := SameText(JustName, '33_invoice_multipage_contract.vrt');
      IsReportDataContractReport := SameText(JustName, '34_reportdata_contract.vrt');
      var IsExportXLSXReport := SameText(JustName, '40_export_xlsx.vrt');
      var IsDetailBandsReport := SameText(JustName, '39_detail_bands.vrt');
      var IsTwoPassReport := SameText(JustName, '41_twopass_totalpages.vrt');
      var IsExportHTMLReport := SameText(JustName, '38_export_html.vrt');
      InvoicePrimaryDataSet := nil;
      InvoiceNamedDataSets := nil;
      InvoiceDataSets := nil;
      InvoiceUserDataSets := nil;
      ImageBindingDataSet := nil;
      LogoImageFile := '';
      SignatureImageFile := '';
      MissingImageFile := '';
      var HtmlFile := '';

      try
        Report := TReportSerializer.LoadFromFile(FileName);
        try
          ExportDoc := nil;
          if IsInvoiceContractReport then
          begin
            BuildInvoiceContractData(InvoicePrimaryDataSet, InvoiceNamedDataSets,
              InvoiceDataSets, InvoiceUserDataSets);
            Engine := TReportEngine.Create(Report, InvoicePrimaryDataSet,
              InvoiceNamedDataSets, nil);
          end
          else if IsInvoicePaginationReport then
          begin
            BuildInvoicePaginationData(InvoicePrimaryDataSet, InvoiceNamedDataSets,
              InvoiceDataSets, InvoiceUserDataSets);
            Engine := TReportEngine.Create(Report, InvoicePrimaryDataSet,
              InvoiceNamedDataSets, nil);
          end
          else if IsReportDataContractReport then
          begin
            BuildReportDataContractData(InvoicePrimaryDataSet, InvoiceNamedDataSets,
              InvoiceDataSets, InvoiceUserDataSets);
            Engine := TReportEngine.Create(Report, InvoicePrimaryDataSet,
              InvoiceNamedDataSets, nil);
          end
          else if IsDetailBandsReport then
          begin
            BuildDetailBandsData(InvoicePrimaryDataSet, InvoiceNamedDataSets,
              InvoiceDataSets, InvoiceUserDataSets);
            Engine := TReportEngine.Create(Report, InvoicePrimaryDataSet,
              InvoiceNamedDataSets, nil);
          end
          else if IsImageBindingReport then
          begin
            LogoImageFile := TPath.Combine(TPath.GetTempPath,
              Format('vittix_logo_%d.png', [GetCurrentProcessId]));
            SignatureImageFile := TPath.Combine(TPath.GetTempPath,
              Format('vittix_signature_%d.png', [GetCurrentProcessId]));
            MissingImageFile := TPath.Combine(TPath.GetTempPath,
              Format('vittix_missing_%d.png', [GetCurrentProcessId]));
            if TFile.Exists(MissingImageFile) then
              TFile.Delete(MissingImageFile);
            CreateVerificationPNG(LogoImageFile, clNavy);
            CreateVerificationPNG(SignatureImageFile, clGreen);
            ImageBindingDataSet := BuildImageBindingData(LogoImageFile,
              SignatureImageFile, MissingImageFile);
            Engine := TReportEngine.Create(Report, ImageBindingDataSet);
          end
          else
            Engine := TReportEngine.Create(Report, MemTable);
          try
            ExportDoc := TReportExportDocument.Create;
            Engine.ExportDocument := ExportDoc;
            if IsRuntimeParameterReport then
            begin
              Engine.Parameters.Values['ReportTitle'] := 'VX-RUNTIME-TITLE';
              Engine.Parameters.Values['AmountInWords'] := 'VX-AMOUNT-WORDS';
              Engine.Parameters.Values['BankText'] := 'VX-BANK-TEXT';
              Engine.Parameters.Values['FilterSummary'] := 'VX-FILTER-SUMMARY';
            end;
            if IsReportDataContractReport then
            begin
              Engine.Parameters.Values['ReportTitle'] := 'VX-GENERAL-REPORT-TITLE';
              Engine.Parameters.Values['FilterSummary'] := 'VX-GENERAL-FILTER-SUMMARY';
            end;
            // Wire up the Script Adapter so object events execute during regression tests!
            Engine.ScriptEngine.OnObjectBeforePrint := ScriptAdapter.EngineObjectBeforePrint;
            Engine.ScriptEngine.OnObjectAfterPrint := ScriptAdapter.EngineObjectAfterPrint;

            Stopwatch := TStopwatch.StartNew;
            Engine.Prepare;
            Stopwatch.Stop;
            PageCount := Engine.Pages.Count;
            ElapsedMs := Stopwatch.ElapsedMilliseconds;

            if IsInvoiceContractReport then
            begin
              RequireExportText(ExportDoc, 'VX-INVOICE-001');
              RequireExportText(ExportDoc, 'VX-ITEM-LINE');
              RequireExportText(ExportDoc, 'VX-COMPANY');
              RequireExportText(ExportDoc, 'VX-PARTY');
              RequireExportText(ExportDoc, 'VX-INVOICE-CUSTOM');
              RequireExportText(ExportDoc, 'VX-ITEM-CUSTOM');
            end;

            if IsRuntimeParameterReport then
            begin
              RequireExportText(ExportDoc, 'VX-RUNTIME-TITLE');
              RequireExportText(ExportDoc, 'VX-AMOUNT-WORDS');
              RequireExportText(ExportDoc, 'VX-BANK-TEXT');
              RequireExportText(ExportDoc, 'VX-FILTER-SUMMARY');
              RequireExportText(ExportDoc, 'VX-TEMPLATE-TITLE');
            end;

            if IsImageBindingReport then
            begin
              if not ExportDocumentContainsImageSource(ExportDoc, LogoImageFile) then
                raise Exception.Create('Expected logo image export command not found');
              if not ExportDocumentContainsImageSource(ExportDoc, SignatureImageFile) then
                raise Exception.Create('Expected signature image export command not found');
              if ExportDocumentContainsImageSource(ExportDoc, MissingImageFile) then
                raise Exception.Create('Missing image unexpectedly produced an export command');
              if CountExportImageCommands(ExportDoc) <> 2 then
                raise Exception.CreateFmt('Expected 2 bound images, got %d',
                  [CountExportImageCommands(ExportDoc)]);
            end;

            if IsInvoicePaginationReport then
            begin
              if PageCount < 2 then
                raise Exception.CreateFmt('Expected multipage invoice output, got %d page(s)',
                  [PageCount]);
              RequireExportText(ExportDoc, 'VX-PAGED-INVOICE');
              RequireExportText(ExportDoc, 'VX-PAGED-ITEM-80');
              if CountExportTextCommands(ExportDoc, 'VX-INVOICE-PAGE-HEADER') <> PageCount then
                raise Exception.CreateFmt('Invoice page header mismatch: pages=%d headers=%d',
                  [PageCount, CountExportTextCommands(ExportDoc, 'VX-INVOICE-PAGE-HEADER')]);
              if CountExportTextCommands(ExportDoc, 'VX-INVOICE-PAGE-FOOTER') <> PageCount then
                raise Exception.CreateFmt('Invoice page footer mismatch: pages=%d footers=%d',
                  [PageCount, CountExportTextCommands(ExportDoc, 'VX-INVOICE-PAGE-FOOTER')]);
            end;

            if IsReportDataContractReport then
            begin
              RequireExportText(ExportDoc, 'VX-GENERAL-REPORT-TITLE');
              RequireExportText(ExportDoc, 'VX-GENERAL-FILTER-SUMMARY');
              RequireExportText(ExportDoc, 'VX-REPORTDATA-PARTY-A');
              RequireExportText(ExportDoc, 'VX-REPORTDATA-PARTY-C');
              RequireExportText(ExportDoc, 'VX-BALANCE-3');
            end;

            if IsTwoPassReport then
            begin
              // Assert the page header token was evaluated (not left as a literal).
              RequireExportText(ExportDoc, 'Page 1 of');
              // Assert TotalPages was NOT resolved as 0 on any page.
              // A resolved [TotalPages] must equal the actual page count (>0).
              if ExportDocumentContainsText(ExportDoc, 'of 0') then
                raise Exception.Create(
                  'Two-pass failure: [TotalPages] was rendered as 0 on at least one page');
              if PageCount < 2 then
                raise Exception.CreateFmt(
                  'Two-pass report expected at least 2 pages, got %d', [PageCount]);
            end;

            if ExportDoc.Pages.Count <> PageCount then
              raise Exception.CreateFmt(
                'Vector PDF command page mismatch: engine=%d command=%d',
                [PageCount, ExportDoc.Pages.Count]);

            if KeepVectorPDF then
              VectorPdfFile := TPath.Combine(VectorPdfOutputPath,
                TPath.GetFileNameWithoutExtension(JustName) + '_vector.pdf')
            else
              VectorPdfFile := TPath.Combine(TPath.GetTempPath,
                TPath.GetFileNameWithoutExtension(JustName) + '_' +
                IntToStr(GetCurrentProcessId) + '_headless_vector_smoke.pdf');
            TReportVectorPDFExporter.ExportDocument(ExportDoc, VectorPdfFile);
            if not TFile.Exists(VectorPdfFile) then
              raise Exception.Create('Vector PDF smoke output was not created');
            if IsExportXLSXReport then
              TReportXLSXExporter.ExportToFile(ExportDoc.Pages,
                TPath.Combine(VectorPdfOutputPath, ExtractFileName(FileName) + '.xlsx'));
            Header := TFile.ReadAllBytes(VectorPdfFile);
            if (Length(Header) < 5) or
               (TEncoding.ASCII.GetString(Header, 0, 5) <> '%PDF-') then
              raise Exception.Create('Vector PDF smoke output has invalid header');
            if not BytesContainAscii(Header, '%%EOF') then
              raise Exception.Create('Vector PDF smoke output has invalid EOF marker');
            if not BytesContainAscii(Header, 'xref') then
              raise Exception.Create('Vector PDF smoke output has no xref table');
            if not BytesContainAscii(Header, 'trailer') then
              raise Exception.Create('Vector PDF smoke output has no trailer');
            if CountAsciiOccurrences(Header, '/Type /Page ') <> PageCount then
              raise Exception.CreateFmt(
                'Vector PDF page object mismatch: engine=%d pdf=%d',
                [PageCount, CountAsciiOccurrences(Header, '/Type /Page ')]);
            if not BytesContainAscii(Header, AnsiString('/Count ' + IntToStr(PageCount))) then
              raise Exception.CreateFmt(
                'Vector PDF page tree count mismatch: expected /Count %d',
                [PageCount]);
            if (PageCount > 0) and
               (CountAsciiOccurrences(Header,
                  AnsiString('/MediaBox [0 0 ' +
                    string(PdfPointNumber(ExportDoc.Pages[0].Width)) + ' ' +
                    string(PdfPointNumber(ExportDoc.Pages[0].Height)) + ']')) <> PageCount) then
              raise Exception.CreateFmt(
                'Vector PDF MediaBox mismatch: expected %d page(s) sized %s x %s points',
                [PageCount,
                 string(PdfPointNumber(ExportDoc.Pages[0].Width)),
                 string(PdfPointNumber(ExportDoc.Pages[0].Height))]);
            if CountAsciiOccurrences(Header, '/Contents ') <> PageCount then
              raise Exception.CreateFmt(
                'Vector PDF page content mismatch: engine=%d pdf=%d',
                [PageCount, CountAsciiOccurrences(Header, '/Contents ')]);

            VectorPdfStream := TMemoryStream.Create;
            try
              TReportVectorPDFExporter.ExportDocument(ExportDoc, VectorPdfStream);
              SetLength(StreamHeader, Integer(VectorPdfStream.Size));
              VectorPdfStream.Position := 0;
              if Length(StreamHeader) > 0 then
                VectorPdfStream.ReadBuffer(StreamHeader[0], Length(StreamHeader));
            finally
              VectorPdfStream.Free;
            end;
            if (Length(StreamHeader) < 5) or
               (TEncoding.ASCII.GetString(StreamHeader, 0, 5) <> '%PDF-') then
              raise Exception.Create('Vector PDF stream output has invalid header');
            if not BytesContainAscii(StreamHeader, '%%EOF') or
               not BytesContainAscii(StreamHeader, 'xref') or
               not BytesContainAscii(StreamHeader, 'trailer') then
              raise Exception.Create('Vector PDF stream output has invalid structure');
            if CountAsciiOccurrences(StreamHeader, '/Type /Page ') <> PageCount then
              raise Exception.CreateFmt(
                'Vector PDF stream page mismatch: engine=%d stream=%d',
                [PageCount, CountAsciiOccurrences(StreamHeader, '/Type /Page ')]);

            // -- HTML export smoke test --
            if IsExportHTMLReport then
            begin
              if KeepVectorPDF then
                HtmlFile := TPath.Combine(VectorPdfOutputPath,
                  TPath.GetFileNameWithoutExtension(JustName) + '.html')
              else
                HtmlFile := TPath.Combine(TPath.GetTempPath,
                  TPath.GetFileNameWithoutExtension(JustName) + '_' +
                  IntToStr(GetCurrentProcessId) + '_headless_html_smoke.html');
              TReportHTMLExporter.ExportDocument(ExportDoc, HtmlFile);
              if not TFile.Exists(HtmlFile) then
                raise Exception.Create('HTML smoke output was not created');
              var HtmlContent := TFile.ReadAllText(HtmlFile, TEncoding.UTF8);
              if not ContainsText(HtmlContent, '<!DOCTYPE html>') then
                raise Exception.Create('HTML smoke output has invalid header (missing DOCTYPE)');
              if not ContainsText(HtmlContent, '<html>') then
                raise Exception.Create('HTML smoke output has invalid header (missing <html>)');
              if not ContainsText(HtmlContent, 'This is a test') then
                raise Exception.Create(
                  'HTML smoke output is missing expected sentinel text: "This is a test"');
            end;
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
              if not Options.&Strict then
              begin
                // Non-strict: existing tolerant baseline comparison and
                // auto-registration behavior (unchanged).
                // Check against pagination baseline
                if TryGetBaselinePageCount(BaselineJSON, JustName, ExpectedPages) then
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
                // Phase 3C-2c-2: strict mode bypasses the legacy mutable
                // baseline path entirely. Only successful executions reach
                // this point; failures are handled by the exception handler
                // below and never produce an actual result.
                SetLength(ActualResults, Length(ActualResults) + 1);
                ActualResults[High(ActualResults)].ReportName := JustName;
                ActualResults[High(ActualResults)].PageCount := PageCount;
              end;
            end
            else
            begin
              TestFailed := False;
              ErrorMsg := '';
            end;
          finally
            ExportDoc.Free;
            Engine.Free;
          end;
        finally
          Report.Free;
          InvoiceNamedDataSets.Free;
          InvoiceUserDataSets.Free;
          InvoiceDataSets.Free;
          ImageBindingDataSet.Free;
          if (LogoImageFile <> '') and TFile.Exists(LogoImageFile) then
            TFile.Delete(LogoImageFile);
          if (SignatureImageFile <> '') and TFile.Exists(SignatureImageFile) then
            TFile.Delete(SignatureImageFile);
        end;
      except
        on E: Exception do
        begin
          TestFailed := True;
          ErrorMsg := Format('%s: %s', [E.ClassName, E.Message]);
        end;
      end;
      if not KeepVectorPDF and (VectorPdfFile <> '') and TFile.Exists(VectorPdfFile) then
        TFile.Delete(VectorPdfFile);
      if not KeepVectorPDF and (HtmlFile <> '') and TFile.Exists(HtmlFile) then
        TFile.Delete(HtmlFile);

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
          if IsExportHTMLReport then
            Writeln(Format('[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK | HTML OK | VCL Cache: +%d', [JustName, PageCount, ElapsedMs, TestEndGDI - TestStartGDI]))
          else
            Writeln(Format('[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK | VCL Cache: +%d', [JustName, PageCount, ElapsedMs, TestEndGDI - TestStartGDI]));
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
        if IsExportHTMLReport then
          Writeln(Format('[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK | HTML OK', [JustName, PageCount, ElapsedMs]))
        else
          Writeln(Format('[PASS] %-40s | %3d pgs | %4d ms | Vector PDF OK', [JustName, PageCount, ElapsedMs]));
        Inc(PassCount);
      end;
    end;
  finally
    MemTable.Free;
    ScriptAdapter.Free;
  end;

  if BaselineModified then
    TFile.WriteAllText(BaselineFile, BaselineJSON.Format(2), TEncoding.UTF8);
  // Phase 3C-2c-2: BaselineJSON stays nil in strict mode, so strict runs
  // can never write or free it (structurally read-only).
  if Assigned(BaselineJSON) then
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

  // Phase 3C-2c-2: strict-only summary. Reconciliation uses the existing
  // deterministic TRegressionBaseline.Reconcile implementation; the strict
  // baseline object is freed here (it owns its internal dictionary).
  if Options.&Strict then
  begin
    try
      Reconciled := TRegressionBaseline.Reconcile(StrictBaseline, ActualResults);
      StrictFailed := StrictHasFailures(Reconciled, FailCount);

      Writeln('================================================');
      Writeln(' Strict Baseline Validation');
      Writeln('------------------------------------------------');
      Writeln(Format(' Reports discovered : %d', [Length(Files)]));
      Writeln(Format(' Reports checked    : %d', [Length(ActualResults)]));
      Writeln(Format(' Matched            : %d', [Reconciled.MatchingCount]));
      Writeln(Format(' Mismatches         : %d', [Reconciled.PageMismatchCount]));
      Writeln(Format(' Missing baseline   : %d', [Reconciled.MissingBaselineCount]));
      Writeln(Format(' Orphan baseline    : %d', [Reconciled.OrphanBaselineCount]));
      Writeln(Format(' Skipped            : %d', [SkipCount]));
      Writeln(Format(' Execution errors   : %d', [FailCount]));
      Writeln('------------------------------------------------');
      for StrictIssue in Reconciled.Issues do
        case StrictIssue.Kind of
          bikPageCountMismatch:
            Writeln(Format('[FAIL] %-40s | Expected pages: %d, actual pages: %d',
              [StrictIssue.ReportName, StrictIssue.ExpectedPages, StrictIssue.ActualPages]));
          bikMissingBaseline:
            Writeln(Format('[FAIL] %-40s | Missing baseline entry (actual pages: %d)',
              [StrictIssue.ReportName, StrictIssue.ActualPages]));
          bikOrphanBaseline:
            Writeln(Format('[FAIL] %-40s | Orphan baseline entry (expected pages: %d)',
              [StrictIssue.ReportName, StrictIssue.ExpectedPages]));
        end;
      Writeln('------------------------------------------------');
      if StrictFailed then
        Writeln(' Strict result: FAIL')
      else
        Writeln(' Strict result: PASS');
      Writeln('================================================');
    finally
      StrictBaseline.Free;
      StrictBaseline := nil;
    end;
  end;

  // Keep console open if running inside the Delphi IDE debugger or if -pause argument is used
  {$WARN SYMBOL_PLATFORM OFF}
  if (DebugHook <> 0) or Options.Pause then
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
