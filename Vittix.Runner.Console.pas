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

procedure WriteUsage;
begin
  Writeln('Usage: VittixRunner [options] [reportfile.vrt]');
  Writeln('');
  Writeln('Options:');
  Writeln('  --scripts          Run only script-bearing regression reports.');
  Writeln('  --script-trace     Print script trace diagnostics without pagination checks.');
  Writeln('  --keep-vector-pdf  Keep vector PDF smoke outputs under build\vector-pdf-smoke.');
  Writeln('  -pause             Keep console open after completion.');
  Writeln('  -h, --help         Show this help.');
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
  ImageBindingDataSet: TFDMemTable;
  LogoImageFile: string;
  SignatureImageFile: string;
  MissingImageFile: string;
begin
  Writeln('================================================');
  Writeln(' VittixReport Headless Regression Runner');
  Writeln('================================================');

  if HasExactSwitch('--help') or HasExactSwitch('-h') then
  begin
    WriteUsage;
    Halt(0);
  end;

  RegisterBuiltInReportObjects;

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
  KeepVectorPDF := HasExactSwitch('--keep-vector-pdf');
  if ScriptOnly then
    Writeln('Mode: script-focused reports only');
  if ScriptTraceOnly then
    Writeln('Mode: script trace only');
  if KeepVectorPDF then
  begin
    VectorPdfOutputPath := TPath.GetFullPath(TPath.Combine(
      ExtractFilePath(ParamStr(0)), '..\vector-pdf-smoke'));
    TDirectory.CreateDirectory(VectorPdfOutputPath);
    Writeln('Vector PDF output: ', VectorPdfOutputPath);
  end
  else
    VectorPdfOutputPath := '';

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
      VectorPdfFile := '';
      IsInvoiceContractReport := SameText(JustName, '30_invoice_named_datasets_contract.vrt');
      IsRuntimeParameterReport := SameText(JustName, '31_runtime_parameter_values.vrt');
      IsImageBindingReport := SameText(JustName, '32_image_binding_values.vrt');
      InvoicePrimaryDataSet := nil;
      InvoiceNamedDataSets := nil;
      InvoiceDataSets := nil;
      InvoiceUserDataSets := nil;
      ImageBindingDataSet := nil;
      LogoImageFile := '';
      SignatureImageFile := '';
      MissingImageFile := '';

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
                    IntToStr(ExportDoc.Pages[0].Width) + ' ' +
                    IntToStr(ExportDoc.Pages[0].Height) + ']')) <> PageCount) then
              raise Exception.CreateFmt(
                'Vector PDF MediaBox mismatch: expected %d page(s) sized %dx%d',
                [PageCount, ExportDoc.Pages[0].Width, ExportDoc.Pages[0].Height]);
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
