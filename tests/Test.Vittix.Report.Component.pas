unit Test.Vittix.Report.Component;

{
  Phase 4G-3: component-level engine configuration tests.

  TVittixReport.CreateEngine is the single engine-construction path used by
  Execute / Print / Export*.  These tests verify the wiring (parameters,
  two-pass flag, print events) without running a render pass, so they stay
  independent of datasets, GDI and the preview UI.
}

interface

uses
  DUnitX.TestFramework,
  Vittix.Report.Context,
  Vittix.Report.Objects,
  Vittix.Report.Component;

type
  [TestFixture]
  TReportComponentTests = class
  private
    FBeforeObjectCalls: Integer;
    procedure BeforeObjectHandler(Sender: TObject; AEngine: TObject;
      AObject: TReportObject; const Context: TExpressionContext;
      var ACanPrint: Boolean);
  public
    [Test] procedure Test_CreateEngine_WiresParameters;
    [Test] procedure Test_CreateEngine_WiresTwoPassRendering;
    [Test] procedure Test_CreateEngine_WiresPrintEvents;
    [Test] procedure Test_CreateEngine_NoDatasets_NoException;
    [Test] procedure Test_RendererPath_PropagatesTwoPassAndParameters;

    { Vector PDF migration (C-4a): ExportToPDF is the default native Vector PDF
      export; the printer-based implementation is preserved as
      ExportToPrinterPDF (compatibility). }
    [Test] procedure Test_ExportToPDF_RoutesToVectorExporter;
    [Test] procedure Test_ExportToPDF_ProducesValidPdfWithText;
    [Test] procedure Test_ExportToPDF_IndicFixture_EmbedsType0Font;
    [Test] procedure Test_ExportToPDF_RichMemoFixture_ContainsText;
    [Test] procedure Test_PrinterExporter_PreservedAsCompatibilityPath;

    { Source-level guard: the Preview window's default "Export PDF" action must
      stay on the Vector PDF writer. }
    [Test] procedure Test_PreviewDefaultExport_UsesVectorPdfOnly;

    { Email PDF: the renderer must be able to carry an export document so the
      e-mail attachment can be a Vector PDF without re-running the engine, and
      the Designer must actually use that overload. }
    [Test] procedure Test_Renderer_ExportDocument_CapturesVectorCommands;
    [Test] procedure Test_DesignerEmail_UsesVectorDocumentOverload;
  end;

{
  Standard Delphi test idiom: a descendant exposing protected members so the
  Execute/Print renderer-configuration seam can be exercised without adding
  public API to the component.
}
type
  TVittixReportAccess = class(TVittixReport);

implementation

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.IOUtils,
  Data.DB,
  Datasnap.DBClient,
  Vittix.Report.Engine,
  Vittix.Report.Renderer,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Serializer,
  Vittix.Report.Interfaces,
  Vittix.Report.Export.Commands,
  Vittix.Report.Export.VectorPDF,
  Vittix.Report.Export.PDF;

procedure TReportComponentTests.BeforeObjectHandler(Sender: TObject;
  AEngine: TObject; AObject: TReportObject; const Context: TExpressionContext;
  var ACanPrint: Boolean);
begin
  Inc(FBeforeObjectCalls);
end;

procedure TReportComponentTests.Test_CreateEngine_WiresParameters;
var
  Rpt   : TVittixReport;
  Model : TReportModel;
  Engine: TReportEngine;
begin
  Rpt := TVittixReport.Create(nil);
  try
    Rpt.Parameters.Text := 'Company=Acme';
    Model := Rpt.GetModel;
    try
      Engine := Rpt.CreateEngine(Model);
      try
        Assert.AreEqual('Company=Acme', Engine.Parameters.Text.Trim);
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    Rpt.Free;
  end;
end;

procedure TReportComponentTests.Test_CreateEngine_WiresTwoPassRendering;
var
  Rpt   : TVittixReport;
  Model : TReportModel;
  Engine: TReportEngine;
begin
  Rpt := TVittixReport.Create(nil);
  try
    Rpt.TwoPassRendering := False;
    Model := Rpt.GetModel;
    try
      Engine := Rpt.CreateEngine(Model);
      try
        Assert.IsFalse(Engine.TwoPassRendering);
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    Rpt.Free;
  end;
end;

procedure TReportComponentTests.Test_CreateEngine_WiresPrintEvents;
var
  Rpt   : TVittixReport;
  Model : TReportModel;
  Engine: TReportEngine;
begin
  Rpt := TVittixReport.Create(nil);
  try
    Rpt.OnBeforeObject := BeforeObjectHandler;
    Model := Rpt.GetModel;
    try
      Engine := Rpt.CreateEngine(Model);
      try
        // The engine must carry the component's handler, not its own default.
        Assert.IsTrue(
          (TMethod(Engine.OnBeforeObject).Code = TMethod(Rpt.OnBeforeObject).Code) and
          (TMethod(Engine.OnBeforeObject).Data = TMethod(Rpt.OnBeforeObject).Data),
          'OnBeforeObject was not relayed to the engine');
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    Rpt.Free;
  end;
end;

procedure TReportComponentTests.Test_CreateEngine_NoDatasets_NoException;
var
  Rpt   : TVittixReport;
  Model : TReportModel;
  Engine: TReportEngine;
begin
  Rpt := TVittixReport.Create(nil);
  try
    Model := Rpt.GetModel;
    try
      Engine := Rpt.CreateEngine(Model);
      try
        Assert.IsNotNull(Engine);
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    Rpt.Free;
  end;
end;

procedure TReportComponentTests.Test_RendererPath_PropagatesTwoPassAndParameters;
{
  Regression test for the Phase 4G-3 pre-commit audit finding: Execute and
  Print configure the renderer through TVittixReport.ConfigureRenderer, and
  TReportRenderer.Render overwrites the engine's TwoPassRendering from the
  renderer's own flag.  If the component's setting stops being mirrored onto
  the renderer, this test fails — CreateEngine alone was already correct, so
  the seam under test here is the renderer-configuration step itself.
}
var
  Rpt: TVittixReport;
  R  : TReportRenderer;
begin
  Rpt := TVittixReport.Create(nil);
  try
    Rpt.Parameters.Text := 'Company=Acme';

    // Component says two-pass OFF — the renderer must end up OFF too.
    Rpt.TwoPassRendering := False;
    R := TReportRenderer.Create;
    try
      TVittixReportAccess(Rpt).ConfigureRenderer(R);
      Assert.IsFalse(R.TwoPassRendering,
        'Renderer.TwoPassRendering was not set from the component');
      Assert.AreEqual('Company=Acme', R.Parameters.Text.Trim,
        'Renderer.Parameters was not set from the component');
    finally
      R.Free;
    end;

    // Default/True case must keep working as well.
    Rpt.TwoPassRendering := True;
    R := TReportRenderer.Create;
    try
      TVittixReportAccess(Rpt).ConfigureRenderer(R);
      Assert.IsTrue(R.TwoPassRendering);
    finally
      R.Free;
    end;
  finally
    Rpt.Free;
  end;
end;

{ ===================== Vector PDF migration (C-4a) ===================== }

{ A minimal report with a literal-text title band, so it renders without any
  data-bound objects. }
function BuildTinyReportJSON: string;
var
  Model: TReportModel;
  Band : TReportBand;
  Txt  : TReportTextObject;
begin
  Model := TReportModel.Create;
  try
    Model.Title := 'Migration Test';
    Band := TReportBand.Create;
    Band.BandType := btReportTitle;
    Band.Height := 60;
    Txt := TReportTextObject.Create;
    Txt.Text := 'Vector PDF default export';
    Txt.Bounds := Rect(20, 10, 400, 40);
    Band.Children.Add(Txt);
    Model.Objects.Add(Band);
    Result := TReportSerializer.SaveToJSON(Model);
  finally
    Model.Free;
  end;
end;

function MakeReport(const AJSON: string): TVittixReport;
var
  DS: TClientDataSet;
  Src: TDataSource;
begin
  Result := TVittixReport.Create(nil);
  DS := TClientDataSet.Create(Result);
  DS.FieldDefs.Add('Name', ftString, 20);
  DS.CreateDataSet;
  DS.AppendRecord(['row1']);
  DS.First;
  Src := TDataSource.Create(Result);
  Src.DataSet := DS;
  Result.DataSource := Src;
  Result.ReportJSON := AJSON;
end;

function ReadFileBytes(const APath: string): TBytes;
begin
  Result := TFile.ReadAllBytes(APath);
end;

function StartsWithPdfHeader(const ABytes: TBytes): Boolean;
begin
  Result := (Length(ABytes) >= 5) and (ABytes[0] = Ord('%')) and
    (ABytes[1] = Ord('P')) and (ABytes[2] = Ord('D')) and
    (ABytes[3] = Ord('F')) and (ABytes[4] = Ord('-'));
end;

function BytesToAnsi(const ABytes: TBytes): AnsiString;
begin
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], Result[1], Length(ABytes));
end;

procedure TReportComponentTests.Test_ExportToPDF_RoutesToVectorExporter;
var
  Rpt: TVittixReport;
  DefaultFile, VectorFile: string;
  DefaultBytes, VectorBytes: TBytes;
begin
  DefaultFile := TPath.Combine(TPath.GetTempPath, 'vittix_mig_default.pdf');
  VectorFile  := TPath.Combine(TPath.GetTempPath, 'vittix_mig_vector.pdf');
  Rpt := MakeReport(BuildTinyReportJSON);
  try
    Rpt.ExportToPDF(DefaultFile);
    Rpt.ExportToVectorPDF(VectorFile);

    DefaultBytes := ReadFileBytes(DefaultFile);
    VectorBytes  := ReadFileBytes(VectorFile);

    Assert.IsTrue(StartsWithPdfHeader(DefaultBytes), 'ExportToPDF must write a PDF');
    Assert.IsTrue(Length(DefaultBytes) > 200, 'exported PDF is implausibly small');
    Assert.AreEqual(Length(VectorBytes), Length(DefaultBytes),
      'ExportToPDF must route to the same writer as ExportToVectorPDF');
    Assert.IsTrue(CompareMem(VectorBytes, DefaultBytes, Length(DefaultBytes)),
      'ExportToPDF output must be byte-identical to ExportToVectorPDF output');
  finally
    Rpt.Free;
    if FileExists(DefaultFile) then TFile.Delete(DefaultFile);
    if FileExists(VectorFile) then TFile.Delete(VectorFile);
  end;
end;

procedure TReportComponentTests.Test_ExportToPDF_ProducesValidPdfWithText;
var
  Rpt: TVittixReport;
  FileName: string;
  Pdf: AnsiString;
begin
  FileName := TPath.Combine(TPath.GetTempPath, 'vittix_mig_text.pdf');
  Rpt := MakeReport(BuildTinyReportJSON);
  try
    Rpt.ExportToPDF(FileName);
    Pdf := BytesToAnsi(ReadFileBytes(FileName));
    // DP-30 / M-14: the title renders through the embedded-font pipeline
    // now; verify through the embedded font + its ToUnicode map, and ensure
    // it is no longer emitted as a Helvetica literal.
    Assert.IsTrue(Pos('%%EOF', string(Pdf)) > 0, 'PDF must be terminated');
    Assert.IsTrue(Pos('/Type0', string(Pdf)) > 0,
      'the title must render through the embedded font');
    Assert.IsTrue(Pos('/ToUnicode', string(Pdf)) > 0,
      'title text must remain extractable');
    Assert.IsTrue(Pos('Vector PDF default export', string(Pdf)) = 0,
      'the title must not be drawn as an ANSI Helvetica literal');
  finally
    Rpt.Free;
    if FileExists(FileName) then TFile.Delete(FileName);
  end;
end;

procedure TReportComponentTests.Test_ExportToPDF_IndicFixture_EmbedsType0Font;
var
  Rpt: TVittixReport;
  Fixture, FileName: string;
  Pdf: AnsiString;
begin
  Fixture := TPath.Combine(GetCurrentDir, 'tests\indic_hindi.vrt');
  Assert.IsTrue(FileExists(Fixture), 'Indic fixture missing: ' + Fixture);
  FileName := TPath.Combine(TPath.GetTempPath, 'vittix_mig_indic.pdf');

  Rpt := MakeReport(TFile.ReadAllText(Fixture));
  try
    Rpt.ExportToPDF(FileName);
    Pdf := BytesToAnsi(ReadFileBytes(FileName));
    Assert.IsTrue(Pos('/Type0', string(Pdf)) > 0,
      'Indic report must export an embedded Type0 font through the default path');
    Assert.IsTrue(Pos('/FontFile2', string(Pdf)) > 0, 'expected an embedded font file');
  finally
    Rpt.Free;
    if FileExists(FileName) then TFile.Delete(FileName);
  end;
end;

procedure TReportComponentTests.Test_ExportToPDF_RichMemoFixture_ContainsText;
var
  Rpt: TVittixReport;
  Fixture, FileName: string;
  Pdf: AnsiString;
begin
  Fixture := TPath.Combine(GetCurrentDir, 'reports\43_memo_html.vrt');
  Assert.IsTrue(FileExists(Fixture), 'rich memo fixture missing: ' + Fixture);
  FileName := TPath.Combine(TPath.GetTempPath, 'vittix_mig_memo.pdf');

  Rpt := MakeReport(TFile.ReadAllText(Fixture));
  try
    Rpt.ExportToPDF(FileName);
    Pdf := BytesToAnsi(ReadFileBytes(FileName));
    // DP-30 / M-14: rich ANSI segments now embed the report font as well;
    // the literal-text check becomes an embedded-pipeline check.
    Assert.IsTrue(Pos('/Type0', string(Pdf)) > 0,
      'rich memo fixture must export its text through the embedded font pipeline');
    Assert.IsTrue(Pos('Normal text', string(Pdf)) = 0,
      'rich segments must not be drawn as ANSI Helvetica literals');
  finally
    Rpt.Free;
    if FileExists(FileName) then TFile.Delete(FileName);
  end;
end;

procedure TReportComponentTests.Test_PrinterExporter_PreservedAsCompatibilityPath;
var
  Exporter: IReportExporter;
begin
  { The printer implementation must remain reachable and unchanged.  Its
    ExportPages needs the "Microsoft Print to PDF" device (and may show a
    save dialog), so the actual print is deliberately NOT exercised here -
    only the preserved public surface is asserted. }
  Exporter := TReportPDFExporter.Create;
  Assert.AreEqual('PDF Document', Exporter.FormatName);
  Assert.AreEqual('pdf', Exporter.DefaultExtension);
end;

procedure TReportComponentTests.Test_PreviewDefaultExport_UsesVectorPdfOnly;
var
  Path, Src: string;
begin
  { Frm.Preview.pas belongs to the designer project, which the test project does
    not link, so the smallest appropriate coverage is a source-level guard: it
    fails if the printer exporter is reintroduced on the Preview default path. }
  Path := TPath.Combine(GetCurrentDir, 'vittixdesigner\Frm.Preview.pas');
  Assert.IsTrue(FileExists(Path), 'Preview unit not found: ' + Path);
  Src := TFile.ReadAllText(Path);

  Assert.IsTrue(Pos('TReportVectorPDFExporter', Src) > 0,
    'Frm.Preview.pas must export through the Vector PDF writer');
  Assert.IsFalse(Pos('TReportPDFExporter', Src) > 0,
    'Frm.Preview.pas must not reference the printer exporter (its default export must be Vector PDF)');
end;

procedure TReportComponentTests.Test_Renderer_ExportDocument_CapturesVectorCommands;
var
  Rpt: TVittixReport;
  R  : TReportRenderer;
  Model: TReportModel;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Ms: TBytesStream;
begin
  { The e-mail attachment path relies on the renderer carrying an export
    document: Render() frees the engine internally, so a document captured
    during Render is the only way to produce a Vector PDF afterwards. }
  Rpt := MakeReport(BuildTinyReportJSON);
  Model := nil;
  Doc := nil;
  R := nil;
  try
    Model := TReportSerializer.LoadFromJSON(BuildTinyReportJSON);
    Doc := TReportExportDocument.Create;
    R := TReportRenderer.Create;
    try
      R.ExportDocument := Doc;

      Engine := TVittixReportAccess(Rpt).CreateEngine(Model);
      try
        R.Render(Engine, Model.PageSettings.PageWidth, Model.PageSettings.PageHeight);
      finally
        Engine.Free;
      end;

      Assert.IsTrue(Doc.Pages.Count >= 1,
        'Renderer must capture the assigned export document during Render');
      Assert.IsTrue(Doc.Pages[0].Commands.Count >= 1,
        'captured export page must contain commands');

      // The captured document must be usable for Vector PDF without a printer.
      Ms := TBytesStream.Create;
      try
        TReportVectorPDFExporter.ExportDocument(Doc, Ms);
        Assert.IsTrue(Ms.Size > 200, 'captured document must export a Vector PDF');
      finally
        Ms.Free;
      end;
    finally
      R.Free;
      Doc.Free;
      Model.Free;
    end;
  finally
    Rpt.Free;
  end;
end;

procedure TReportComponentTests.Test_DesignerEmail_UsesVectorDocumentOverload;
var
  Src: string;
begin
  { Frm.Main.pas is not linked into the test project, so this is a
    source-level guard that the Designer's e-mail action attaches a Vector PDF
    (the document overload) rather than the printer-backed Pages overload. }
  Src := TFile.ReadAllText(TPath.Combine(GetCurrentDir, 'vittixdesigner\Frm.Main.pas'));
  Assert.IsTrue(Pos('SendEmailWithReport(ExportDoc', Src) > 0,
    'Designer e-mail must attach a Vector PDF export document');
  Assert.IsFalse(Pos('SendEmailWithReport(Eng.Pages', Src) > 0,
    'Designer e-mail must not use the printer-backed Pages overload');
end;

initialization
  TDUnitX.RegisterTestFixture(TReportComponentTests);

end.
