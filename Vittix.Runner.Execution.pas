unit Vittix.Runner.Execution;

{
  Phase 3E-2: Runner Execution Service.

  Extracted from Vittix.Runner.Console.pas - pure report execution lifecycle
  without console I/O, CLI parsing, baseline reconciliation, GDI measurement,
  or exit-code policy.

  TVittixReportExecutor owns:
    - report loading and deserialization
    - dataset setup (using Vittix.Runner.DataSetup builders)
    - engine creation, Prepare, pagination
    - export smoke verification (Vector PDF, HTML, XLSX, image/text sentinels)
    - script execution and trace event notification
    - exception catching (returns resFailed with ErrorMessage)
    - TReportExecutionResult construction
    - resource cleanup (model, engine, datasets, temp streams/files)

  GDI measurement and leak classification stay in Console because the
  current priority order (exception > pagination mismatch > GDI leak > pass)
  requires Console to evaluate pagination BEFORE GDI classification.

  The executor does NOT:
    - parse CLI arguments (ParamStr / ParamCount)
    - call Halt
    - perform baseline reconciliation
    - modify baseline JSON / write baseline files
    - choose exit codes / create formatters
    - emit final run summaries / JSON / console diagnostics
    - measure GDI handles
    - classify GDI leaks
    - decide whether the entire run succeeded
}

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  System.Diagnostics,
  System.Classes,
  System.Generics.Collections,
  Winapi.Windows, // GetCurrentProcessId (temp export file naming)
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.StorageJSON,
  Vcl.Graphics,
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
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Objects.Table,
  Vittix.Report.Objects.CrossTab,
  Vittix.Report.ScriptHost.Adapter,
  Vittix.Runner.Results,
  Vittix.Runner.ExportVerification,
  Vittix.Runner.DataSetup,
  System.Zip;

type
  {
    Configuration for one report execution. Contains only what the
    executor needs; CLI parsing, baseline policy and formatting stay in
    the console runner.

    ScriptBeforeCount / ScriptAfterCount are the pre-computed occurrence
    counts of '"OnBeforePrint": "' / '"OnAfterPrint": "' in the report
    file. The console runner already reads the report text for
    --scripts / --script-trace filtering; the counts are passed through
    so the executor does not duplicate file I/O or counting policy.
  }
  TReportExecutionConfig = record
    FileName: string;
    ReportName: string;

    ScriptOnly: Boolean;
    ScriptTraceOnly: Boolean;
    ScriptBeforeCount: Integer;
    ScriptAfterCount: Integer;

    KeepVectorPDF: Boolean;
    VectorPdfOutputPath: string;
  end;

  {
    Script trace callback. Fired by the executor at exactly the point
    where the legacy console runner emitted its script trace block
    (after all export smoke verification, while the report model is
    still alive). The executor never writes to the console itself; the
    console supplies this callback and owns all Writeln output,
    including TraceScriptObject/TraceScriptTree.
  }
  TScriptTraceEvent = reference to procedure(const AReport: TReportModel);

  {
    Phase 3E-2: report execution service.

    Executes one .vrt report end-to-end and returns the existing
    TReportExecutionResult (Phase 3D semantics, unchanged):

      - resPassed with HasPageCount/PageCount on success
      - resFailed with ErrorMessage = 'EClass: message' on exception
        (HasPageCount/PageCount preserved when pagination succeeded)
      - ScriptTraceOnly runs always return resPassed and deliberately
        skip the temp export-file deletion, exactly matching the legacy
        Continue that bypassed the cleanup block.

    GDI measurement and [LEAK] classification intentionally stay in the
    console runner: the legacy priority order (exception >
    pagination mismatch > GDI leak > pass) requires the baseline
    pagination check to run before leak classification, and baseline
    policy must not move into the executor.

    The executor does not own the shared MemTable or ScriptAdapter
    passed to the constructor; the console runner keeps ownership.
  }
  TVittixReportExecutor = class
  private
    FMemTable: TFDMemTable;
    FScriptAdapter: TReportScriptHostAdapter;
    FLastElapsedMs: Int64;
    procedure FireScriptTrace(const AReport: TReportModel;
      const AConfig: TReportExecutionConfig;
      const ATraceEvent: TScriptTraceEvent);
  public
    constructor Create(AMemTable: TFDMemTable;
      AScriptAdapter: TReportScriptHostAdapter);

    function ExecuteReport(const AConfig: TReportExecutionConfig;
      const ATraceEvent: TScriptTraceEvent = nil): TReportExecutionResult;

    // Milliseconds measured around Engine.Prepare only (legacy timing
    // boundary preserved; used by the console's formatter observation).
    property LastElapsedMs: Int64 read FLastElapsedMs;
  end;

implementation

{ TVittixReportExecutor }

constructor TVittixReportExecutor.Create(AMemTable: TFDMemTable;
  AScriptAdapter: TReportScriptHostAdapter);
begin
  inherited Create;
  // Not owned here: the console runner keeps ownership of the shared
  // sample-data table and the script host adapter.
  FMemTable := AMemTable;
  FScriptAdapter := AScriptAdapter;
  FLastElapsedMs := 0;
end;

procedure TVittixReportExecutor.FireScriptTrace(const AReport: TReportModel;
  const AConfig: TReportExecutionConfig;
  const ATraceEvent: TScriptTraceEvent);
begin
  // Legacy guard, preserved exactly: the trace block only ran for
  // script modes with at least one script object and a loaded report.
  if not Assigned(ATraceEvent) then
    Exit;
  if not (AConfig.ScriptOnly or AConfig.ScriptTraceOnly) then
    Exit;
  if not Assigned(AReport) then
    Exit;
  if (AConfig.ScriptBeforeCount <= 0) and (AConfig.ScriptAfterCount <= 0) then
    Exit;
  ATraceEvent(AReport);
end;

procedure VerifyXlsxSmoke(const AFileName, AExpectedText: string);
var
  Zip: TZipFile;
  Buffer: TBytes;
  Sheet: string;
begin
  // Phase 4I-7 smoke hardening: the XLSX output must exist, be a readable
  // ZIP package, contain the worksheet part and include expected report text.
  if not TFile.Exists(AFileName) then
    raise Exception.Create('XLSX smoke output was not created');
  Zip := TZipFile.Create;
  try
    try
      Zip.Open(AFileName, zmRead);
    except
      raise Exception.Create('XLSX smoke output is not a readable ZIP package');
    end;
    if Zip.IndexOf('xl/worksheets/sheet1.xml') < 0 then
      raise Exception.Create('XLSX smoke output has no worksheet part');
    Zip.Read('xl/worksheets/sheet1.xml', Buffer);
    Sheet := TEncoding.UTF8.GetString(Buffer);
  finally
    Zip.Free;
  end;
  if Pos(AExpectedText, Sheet) = 0 then
    raise Exception.Create('XLSX smoke output is missing expected report text');
end;

function TVittixReportExecutor.ExecuteReport(
  const AConfig: TReportExecutionConfig;
  const ATraceEvent: TScriptTraceEvent): TReportExecutionResult;
var
  Report: TReportModel;
  Engine: TReportEngine;
  ExportDoc: TReportExportDocument;
  Stopwatch: TStopwatch;
  PageCount: Integer;
  ExecFailed: Boolean;
  ErrorMsg: string;
  IsInvoiceContractReport: Boolean;
  IsRuntimeParameterReport: Boolean;
  IsImageBindingReport: Boolean;
  IsInvoicePaginationReport: Boolean;
  IsReportDataContractReport: Boolean;
  IsExportXLSXReport: Boolean;
  IsDetailBandsReport: Boolean;
  IsTwoPassReport: Boolean;
  IsExportHTMLReport: Boolean;
  InvoicePrimaryDataSet: TVittixUserDataSet;
  InvoiceNamedDataSets: TDictionary<string, TVittixUserDataSet>;
  InvoiceDataSets: TObjectList<TFDMemTable>;
  InvoiceUserDataSets: TObjectList<TVittixUserDataSet>;
  ImageBindingDataSet: TFDMemTable;
  LogoImageFile: string;
  SignatureImageFile: string;
  MissingImageFile: string;
  VectorPdfFile: string;
  XlsxFile: string;
  HtmlFile: string;
  Header: TBytes;
  StreamHeader: TBytes;
  VectorPdfStream: TMemoryStream;
begin
  Result := Default(TReportExecutionResult);
  Result.ReportName := AConfig.ReportName;
  Result.Status := resPassed;
  Result.HasPageCount := False;
  Result.PageCount := 0;
  Result.HasExpectedPageCount := False;
  Result.ExpectedPageCount := 0;
  Result.ErrorMessage := '';
  Result.GdiLeakDelta := 0;

  FLastElapsedMs := 0;
  PageCount := 0;
  ExecFailed := False;
  ErrorMsg := '';
  VectorPdfFile := '';
  HtmlFile := '';
  InvoicePrimaryDataSet := nil;
  InvoiceNamedDataSets := nil;
  InvoiceDataSets := nil;
  InvoiceUserDataSets := nil;
  ImageBindingDataSet := nil;
  LogoImageFile := '';
  SignatureImageFile := '';
  MissingImageFile := '';

  IsInvoiceContractReport := SameText(AConfig.ReportName, '30_invoice_named_datasets_contract.vrt');
  IsRuntimeParameterReport := SameText(AConfig.ReportName, '31_runtime_parameter_values.vrt');
  IsImageBindingReport := SameText(AConfig.ReportName, '32_image_binding_values.vrt');
  IsInvoicePaginationReport := SameText(AConfig.ReportName, '33_invoice_multipage_contract.vrt');
  IsReportDataContractReport := SameText(AConfig.ReportName, '34_reportdata_contract.vrt');
  IsExportXLSXReport := SameText(AConfig.ReportName, '40_export_xlsx.vrt');
  IsDetailBandsReport := SameText(AConfig.ReportName, '39_detail_bands.vrt');
  IsTwoPassReport := SameText(AConfig.ReportName, '41_twopass_totalpages.vrt');
  IsExportHTMLReport := IsHtmlSmokeReport(AConfig.ReportName);

  try
    Report := TReportSerializer.LoadFromFile(AConfig.FileName);
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
        Engine := TReportEngine.Create(Report, FMemTable);
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
        Engine.ScriptEngine.OnObjectBeforePrint := FScriptAdapter.EngineObjectBeforePrint;
        Engine.ScriptEngine.OnObjectAfterPrint := FScriptAdapter.EngineObjectAfterPrint;

        // Legacy timing boundary preserved: the stopwatch brackets
        // Engine.Prepare only (nothing else).
        Stopwatch := TStopwatch.StartNew;
        Engine.Prepare;
        Stopwatch.Stop;
        PageCount := Engine.Pages.Count;
        FLastElapsedMs := Stopwatch.ElapsedMilliseconds;

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

        if AConfig.KeepVectorPDF then
          VectorPdfFile := TPath.Combine(AConfig.VectorPdfOutputPath,
            TPath.GetFileNameWithoutExtension(AConfig.ReportName) + '_vector.pdf')
        else
          VectorPdfFile := TPath.Combine(TPath.GetTempPath,
            TPath.GetFileNameWithoutExtension(AConfig.ReportName) + '_' +
            IntToStr(GetCurrentProcessId) + '_headless_vector_smoke.pdf');
        TReportVectorPDFExporter.ExportDocument(ExportDoc, VectorPdfFile);
        if not TFile.Exists(VectorPdfFile) then
          raise Exception.Create('Vector PDF smoke output was not created');
        if IsExportXLSXReport then
        begin
          XlsxFile := TPath.Combine(AConfig.VectorPdfOutputPath,
            ExtractFileName(AConfig.FileName) + '.xlsx');
          TReportXLSXExporter.ExportToFile(ExportDoc.Pages, XlsxFile);
          VerifyXlsxSmoke(XlsxFile, 'Simple MasterData Report');
        end;
        Header := TFile.ReadAllBytes(VectorPdfFile);
        if (Length(Header) < 5) or
           (TEncoding.ASCII.GetString(Header, 0, 5) <> '%PDF-') then
          raise Exception.Create('Vector PDF smoke output has invalid header');
        if not BytesContainAscii(Header, '%%EOF') or
           not BytesContainAscii(Header, 'xref') then
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
          if AConfig.KeepVectorPDF then
            HtmlFile := TPath.Combine(AConfig.VectorPdfOutputPath,
              TPath.GetFileNameWithoutExtension(AConfig.ReportName) + '.html')
          else
            HtmlFile := TPath.Combine(TPath.GetTempPath,
              TPath.GetFileNameWithoutExtension(AConfig.ReportName) + '_' +
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

        // Phase 3E-2: script trace moved behind a callback. The console
        // supplies the trace rendering (Writeln/TraceScriptTree); the
        // executor only fires the callback at the exact legacy point.
        FireScriptTrace(Report, AConfig, ATraceEvent);

        if AConfig.ScriptTraceOnly then
        begin
          // Legacy behavior preserved: --script-trace reports passed
          // before reaching the legacy cleanup block below; the Continue
          // skipped the temporary PDF/HTML deletion and the GDI
          // end-measurement. This Exit reproduces exactly that.
          Result.Status := resPassed;
          Result.HasPageCount := True;
          Result.PageCount := PageCount;
          Exit;
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
      ExecFailed := True;
      ErrorMsg := Format('%s: %s', [E.ClassName, E.Message]);
    end;
  end;

  // Legacy cleanup order preserved: temporary smoke outputs are deleted
  // after the try/except block, on both success and failure paths
  // (KeepVectorPDF retains them under the smoke output directory).
  if not AConfig.KeepVectorPDF and (VectorPdfFile <> '') and TFile.Exists(VectorPdfFile) then
    TFile.Delete(VectorPdfFile);
  if not AConfig.KeepVectorPDF and (HtmlFile <> '') and TFile.Exists(HtmlFile) then
    TFile.Delete(HtmlFile);

  if ExecFailed then
  begin
    Result.Status := resFailed;
    Result.HasPageCount := PageCount > 0;
    Result.PageCount := PageCount;
    Result.ErrorMessage := ErrorMsg;
    Result.GdiLeakDelta := 0;
    Exit;
  end;

  Result.Status := resPassed;
  Result.HasPageCount := True;
  Result.PageCount := PageCount;
  Result.ErrorMessage := '';
  Result.GdiLeakDelta := 0;
end;

end.