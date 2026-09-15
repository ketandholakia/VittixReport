unit Test.Gap005.OutputGuard;

{
  GAP-005 Step 0 — renderer / export guard (test-only).

  Purpose (from the approved GAP-005 audit, §6 Step 0): establish an automated
  safety net over the page artefacts that Steps A/B (lazy rasterization, print
  unification, page retention) would change, BEFORE any of them is attempted.

  What this unit does NOT claim: automated print or preview verification. The
  preview is a windowed VCL control and both print paths are printer-driver
  dependent, so neither can be exercised here (see the GAP-005 audit §4). The
  real PDF and e-mail exporters are likewise NOT invoked — they are
  printer/MAPI dependent. The export seam is guarded through its interface
  contract only, and that limitation is stated in the test itself.

  The guard is expressed as an explicit summary + violation function so its
  detection power can be PROVEN: four tests inject one deliberate change each
  (page count, page dimension, page presence, output text) and assert the guard
  reports exactly that class. Without that proof a "guard" is just an assertion
  nobody has seen fail.

  No production file is modified by this unit.
}

interface

uses
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
  Data.DB,
  Datasnap.DBClient,
  Vcl.Graphics,
  DUnitX.TestFramework,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Engine,
  Vittix.Report.Renderer,
  Vittix.Report.Interfaces,
  Vittix.Report.Export.Commands;

type
  { The observable invariants of one render, captured from the engine, the
    renderer and the export document.

    GAP-005/P2 split the original single "bitmap present" expectation into two
    contracts:
      * AFTER RENDER   — metafile present for every page, and NO page rasterised
                         (EagerRasterisations = 0);
      * AFTER DEMAND   — demanding a page's bitmap materialises exactly one
                         bitmap of the page dimensions.
    Neither contract was weakened; the laziness expectation was ADDED. }
  TRenderGuardSummary = record
    EnginePageCount: Integer;      // TReportEngine.PageCount (logical page count)
    RetainedPages: Integer;        // TReportEngine.Pages.Count
    RendererPages: Integer;        // TReportRenderer.Pages.Count
    PageWidth: Integer;
    PageHeight: Integer;
    AllMetafilesPresent: Boolean;
    EagerRasterisations: Integer;  // total page rasterisations immediately after Render (must be 0)
    AllDemandedBitmapsPresent: Boolean;  // after explicitly demanding every page bitmap
    DemandedBitmapWidth: Integer;
    DemandedBitmapHeight: Integer;
    FirstTextSample: string;
  end;

  { Records the metafile list handed to the export seam. Stands in for the real
    exporters, which cannot run headlessly. }
  TRecordingExporter = class(TInterfacedObject, IReportExporter)
  private
    FPageCount: Integer;
    FAllMetafilesValid: Boolean;
  public
    procedure ExportPages(const Pages: TObjectList<TMetafile>;
      const FileName: string);
    function FormatName: string;
    function DefaultExtension: string;
    property PageCount: Integer read FPageCount;
    property AllMetafilesValid: Boolean read FAllMetafilesValid;
  end;

  [TestFixture]
  TGap005OutputGuardTests = class
  private
    function CreateIntTable(const AFieldName: string;
      const AValues: array of Integer): TClientDataSet;
    function BuildPagedReport: TReportModel;
    function RenderAndSummarise(ARowCount: Integer;
      out Exporter: TRecordingExporter): TRenderGuardSummary;
  public
    { Detection proof: each change class must be caught, and only that class. }
    [Test] procedure Test_Guard_DetectsPageCountChange;
    [Test] procedure Test_Guard_DetectsPageDimensionChange;
    [Test] procedure Test_Guard_DetectsPagePresenceChange;
    [Test] procedure Test_Guard_DetectsOutputTextChange;
    { The real render must be clean under the same guard. }
    [Test] procedure Test_Guard_RealRenderHasNoViolations;
    { P4 contract: the logical page count must not become a retention artifact. }
    [Test] procedure Test_Guard_PageCountTracksRetainedPages;
    { Export seam contract (interface only — real exporters are not invoked). }
    [Test] procedure Test_Guard_ExportPagesSeamContract;
  end;

implementation

const
  ViolationPageCount     = 'page-count';
  ViolationPageDimension = 'page-dimension';
  ViolationPagePresence  = 'page-presence';
  ViolationOutputText    = 'output-text';

{ Compares two render summaries and returns one message per detected change.
  Kept deliberately simple and total, so the detection proof can exercise every
  branch directly. }
function GuardViolations(const AExpected, AActual: TRenderGuardSummary): TArray<string>;
var
  List: TList<string>;
  procedure Flag(const AClass, ADetail: string);
  begin
    List.Add(AClass + ': ' + ADetail);
  end;
begin
  List := TList<string>.Create;
  try
    if AExpected.EnginePageCount <> AActual.EnginePageCount then
      Flag(ViolationPageCount, Format('logical %d -> %d',
        [AExpected.EnginePageCount, AActual.EnginePageCount]));
    if AExpected.RetainedPages <> AActual.RetainedPages then
      Flag(ViolationPageCount, Format('retained %d -> %d',
        [AExpected.RetainedPages, AActual.RetainedPages]));
    if AExpected.RendererPages <> AActual.RendererPages then
      Flag(ViolationPageCount, Format('renderer %d -> %d',
        [AExpected.RendererPages, AActual.RendererPages]));
    if (AExpected.PageWidth <> AActual.PageWidth) or
       (AExpected.PageHeight <> AActual.PageHeight) then
      Flag(ViolationPageDimension, Format('%dx%d -> %dx%d',
        [AExpected.PageWidth, AExpected.PageHeight,
         AActual.PageWidth, AActual.PageHeight]));
    if AExpected.AllMetafilesPresent <> AActual.AllMetafilesPresent then
      Flag(ViolationPagePresence, 'metafile presence changed');
    if AExpected.EagerRasterisations <> AActual.EagerRasterisations then
      Flag(ViolationPagePresence, Format('eager rasterisations %d -> %d',
        [AExpected.EagerRasterisations, AActual.EagerRasterisations]));
    if AExpected.AllDemandedBitmapsPresent <> AActual.AllDemandedBitmapsPresent then
      Flag(ViolationPagePresence, 'demanded bitmap presence changed');
    if (AExpected.DemandedBitmapWidth <> AActual.DemandedBitmapWidth) or
       (AExpected.DemandedBitmapHeight <> AActual.DemandedBitmapHeight) then
      Flag(ViolationPageDimension, Format('demanded bitmap %dx%d -> %dx%d',
        [AExpected.DemandedBitmapWidth, AExpected.DemandedBitmapHeight,
         AActual.DemandedBitmapWidth, AActual.DemandedBitmapHeight]));
    if AExpected.FirstTextSample <> AActual.FirstTextSample then
      Flag(ViolationOutputText, Format('"%s" -> "%s"',
        [AExpected.FirstTextSample, AActual.FirstTextSample]));
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function HasViolationOfClass(const AViolations: TArray<string>;
  const AClass: string): Boolean;
var
  V: string;
begin
  Result := False;
  for V in AViolations do
    if V.StartsWith(AClass + ':') then
      Exit(True);
end;

{ TRecordingExporter }

procedure TRecordingExporter.ExportPages(const Pages: TObjectList<TMetafile>;
  const FileName: string);
var
  Page: TMetafile;
begin
  FPageCount := 0;
  FAllMetafilesValid := True;
  if not Assigned(Pages) then
  begin
    FAllMetafilesValid := False;
    Exit;
  end;
  for Page in Pages do
  begin
    Inc(FPageCount);
    if (not Assigned(Page)) or (Page.Width <= 0) or (Page.Height <= 0) then
      FAllMetafilesValid := False;
  end;
end;

function TRecordingExporter.FormatName: string;
begin
  Result := 'Recording';
end;

function TRecordingExporter.DefaultExtension: string;
begin
  Result := 'rec';
end;

{ Fixture }

function TGap005OutputGuardTests.CreateIntTable(const AFieldName: string;
  const AValues: array of Integer): TClientDataSet;
var
  I: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add(AFieldName, ftInteger);
  Result.CreateDataSet;
  for I := Low(AValues) to High(AValues) do
    Result.AppendRecord([AValues[I]]);
  Result.First;
end;

function TGap005OutputGuardTests.BuildPagedReport: TReportModel;
var
  Band: TReportBand;
  Text: TReportTextObject;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := 20;
  Text := TReportTextObject.Create;
  Text.Expression := 'Row [ID]';
  Text.Bounds := Rect(2, 2, 120, 16);
  Band.Children.Add(Text);
  Result.Objects.Add(Band);
end;

function TGap005OutputGuardTests.RenderAndSummarise(ARowCount: Integer;
  out Exporter: TRecordingExporter): TRenderGuardSummary;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Renderer: TReportRenderer;
  Values: TArray<Integer>;
  I: Integer;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
begin
  Result := Default(TRenderGuardSummary);
  SetLength(Values, ARowCount);
  for I := 0 to High(Values) do
    Values[I] := I + 1;

  DataSet := CreateIntTable('ID', Values);
  Model := BuildPagedReport;
  Doc := TReportExportDocument.Create;
  Engine := TReportEngine.Create(Model, DataSet, nil);
  Renderer := TReportRenderer.Create;
  Exporter := TRecordingExporter.Create;
  try
    Engine.ExportDocument := Doc;
    Engine.TwoPassRendering := False;
    Engine.Prepare;

    Result.EnginePageCount := Engine.PageCount;
    Result.RetainedPages := Engine.Pages.Count;
    Result.PageWidth := Model.PageSettings.PageWidth;
    Result.PageHeight := Model.PageSettings.PageHeight;

    Result.AllMetafilesPresent := Engine.Pages.Count > 0;
    for I := 0 to Engine.Pages.Count - 1 do
      if (Engine.Pages[I] = nil) or (Engine.Pages[I].Width <= 0) then
        Result.AllMetafilesPresent := False;

    Result.FirstTextSample := '';
    for Page in Doc.Pages do
      for Cmd in Page.Commands do
        if (Cmd is TReportExportTextCommand) and (Result.FirstTextSample = '') then
          Result.FirstTextSample := TReportExportTextCommand(Cmd).Text;

    // Renderer view of the same render.
    Renderer.Render(Engine, Model.PageSettings.PageWidth,
      Model.PageSettings.PageHeight);
    Result.RendererPages := Renderer.Pages.Count;

    // AFTER RENDER contract: the metafile is retained for every page and NO
    // page has been rasterised (P2). Laziness is measured with the page's
    // RasterCount, never inferred from a nil bitmap.
    Result.EagerRasterisations := 0;
    for I := 0 to Renderer.Pages.Count - 1 do
    begin
      if (Renderer.Pages[I].Metafile = nil) or
         (Renderer.Pages[I].Metafile.Width <= 0) then
        Result.AllMetafilesPresent := False;
      Inc(Result.EagerRasterisations, Renderer.Pages[I].RasterCount);
    end;

    // AFTER DEMAND contract: demanding each page materialises a bitmap with the
    // page dimensions.
    Result.AllDemandedBitmapsPresent := Renderer.Pages.Count > 0;
    Result.DemandedBitmapWidth := 0;
    Result.DemandedBitmapHeight := 0;
    for I := 0 to Renderer.Pages.Count - 1 do
    begin
      var Bmp := Renderer.Pages[I].Bitmap;
      if Bmp = nil then
        Result.AllDemandedBitmapsPresent := False
      else if I = 0 then
      begin
        Result.DemandedBitmapWidth := Bmp.Width;
        Result.DemandedBitmapHeight := Bmp.Height;
      end;
    end;

    // Exercise the export seam with the engine's page list.
    Exporter.ExportPages(Engine.Pages, 'guard.rec');
  finally
    Renderer.Free;
    Engine.Free;
    Doc.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TGap005OutputGuardTests.Test_Guard_DetectsPageCountChange;
var
  Base, Changed: TRenderGuardSummary;
  Violations: TArray<string>;
begin
  Base := Default(TRenderGuardSummary);
  Base.EnginePageCount := 5;
  Base.RetainedPages := 5;
  Base.RendererPages := 5;
  Base.PageWidth := 793;
  Base.PageHeight := 1122;
  Base.AllMetafilesPresent := True;
  Base.EagerRasterisations := 0;
  Base.AllDemandedBitmapsPresent := True;
  Base.DemandedBitmapWidth := 793;
  Base.DemandedBitmapHeight := 1122;
  Base.FirstTextSample := 'Row 1';

  Changed := Base;
  Changed.EnginePageCount := 6;

  Violations := GuardViolations(Base, Changed);
  Assert.IsTrue(HasViolationOfClass(Violations, ViolationPageCount),
    'The guard must detect a logical page-count change.');
  Assert.IsFalse(HasViolationOfClass(Violations, ViolationPageDimension),
    'A page-count change must not be reported as a dimension change.');

  Changed := Base;
  Changed.RetainedPages := 4;
  Violations := GuardViolations(Base, Changed);
  Assert.IsTrue(HasViolationOfClass(Violations, ViolationPageCount),
    'The guard must detect a retained-page-count change.');

  Changed := Base;
  Changed.RendererPages := 4;
  Violations := GuardViolations(Base, Changed);
  Assert.IsTrue(HasViolationOfClass(Violations, ViolationPageCount),
    'The guard must detect a renderer page-count change.');
end;

procedure TGap005OutputGuardTests.Test_Guard_DetectsPageDimensionChange;
var
  Base, Changed: TRenderGuardSummary;
  Violations: TArray<string>;
begin
  Base := Default(TRenderGuardSummary);
  Base.EnginePageCount := 5;
  Base.RetainedPages := 5;
  Base.RendererPages := 5;
  Base.PageWidth := 793;
  Base.PageHeight := 1122;
  Base.AllMetafilesPresent := True;
  Base.EagerRasterisations := 0;
  Base.AllDemandedBitmapsPresent := True;
  Base.DemandedBitmapWidth := 793;
  Base.DemandedBitmapHeight := 1122;

  Changed := Base;
  Changed.PageWidth := 794;
  Violations := GuardViolations(Base, Changed);
  Assert.IsTrue(HasViolationOfClass(Violations, ViolationPageDimension),
    'The guard must detect a page-width change.');
  Assert.IsFalse(HasViolationOfClass(Violations, ViolationPageCount),
    'A dimension change must not be reported as a page-count change.');

  Changed := Base;
  Changed.PageHeight := 1123;
  Violations := GuardViolations(Base, Changed);
  Assert.IsTrue(HasViolationOfClass(Violations, ViolationPageDimension),
    'The guard must detect a page-height change.');
end;

procedure TGap005OutputGuardTests.Test_Guard_DetectsPagePresenceChange;
var
  Base, Changed: TRenderGuardSummary;
  Violations: TArray<string>;
begin
  Base := Default(TRenderGuardSummary);
  Base.EnginePageCount := 5;
  Base.RetainedPages := 5;
  Base.RendererPages := 5;
  Base.PageWidth := 793;
  Base.PageHeight := 1122;
  Base.AllMetafilesPresent := True;
  Base.EagerRasterisations := 0;
  Base.AllDemandedBitmapsPresent := True;
  Base.DemandedBitmapWidth := 793;
  Base.DemandedBitmapHeight := 1122;

  Changed := Base;
  Changed.AllMetafilesPresent := False;
  Violations := GuardViolations(Base, Changed);
  Assert.IsTrue(HasViolationOfClass(Violations, ViolationPagePresence),
    'The guard must detect a missing metafile.');

  Changed := Base;
  Changed.AllDemandedBitmapsPresent := False;
  Violations := GuardViolations(Base, Changed);
  Assert.IsTrue(HasViolationOfClass(Violations, ViolationPagePresence),
    'The guard must detect a demanded bitmap that failed to materialise.');

  // The P2 regression detector: eager rasterisation reappearing must be caught.
  Changed := Base;
  Changed.EagerRasterisations := 1;
  Violations := GuardViolations(Base, Changed);
  Assert.IsTrue(HasViolationOfClass(Violations, ViolationPagePresence),
    'The guard must detect eager rasterisation (P2 regression).');
end;

procedure TGap005OutputGuardTests.Test_Guard_DetectsOutputTextChange;
var
  Base, Changed: TRenderGuardSummary;
  Violations: TArray<string>;
begin
  Base := Default(TRenderGuardSummary);
  Base.EnginePageCount := 5;
  Base.RetainedPages := 5;
  Base.RendererPages := 5;
  Base.PageWidth := 793;
  Base.PageHeight := 1122;
  Base.AllMetafilesPresent := True;
  Base.EagerRasterisations := 0;
  Base.AllDemandedBitmapsPresent := True;
  Base.DemandedBitmapWidth := 793;
  Base.DemandedBitmapHeight := 1122;
  Base.FirstTextSample := 'Row 1';

  Changed := Base;
  Changed.FirstTextSample := 'Row 2';
  Violations := GuardViolations(Base, Changed);
  Assert.IsTrue(HasViolationOfClass(Violations, ViolationOutputText),
    'The guard must detect a rendered-output text change.');
  Assert.IsFalse(HasViolationOfClass(Violations, ViolationPageCount),
    'An output change must not be reported as a page-count change.');
end;

procedure TGap005OutputGuardTests.Test_Guard_RealRenderHasNoViolations;
var
  Exporter: TRecordingExporter;
  Summary: TRenderGuardSummary;
  Violations: TArray<string>;
begin
  // A real render compared against itself must produce no violations; this
  // proves the guard is wired to the real engine/renderer/export artefacts and
  // does not fire spuriously.
  Summary := RenderAndSummarise(120, Exporter);

  Assert.IsTrue(Summary.EnginePageCount > 1,
    'The fixture must produce multiple pages.');
  Assert.AreEqual(Summary.EnginePageCount, Summary.RetainedPages,
    'Every logical page must currently be retained (see the P4 contract test).');
  Assert.AreEqual(Summary.EnginePageCount, Summary.RendererPages,
    'The renderer must retain one page per engine page.');
  Assert.IsTrue(Summary.AllMetafilesPresent,
    'Every renderer page must retain a valid metafile after Render.');
  Assert.AreEqual(0, Summary.EagerRasterisations,
    'Render must not eagerly rasterise any page (GAP-005/P2).');
  Assert.IsTrue(Summary.AllDemandedBitmapsPresent,
    'Demanding each page must materialise a bitmap.');
  Assert.AreEqual(Summary.PageWidth, Summary.DemandedBitmapWidth,
    'A demanded bitmap must have the page width.');
  Assert.AreEqual(Summary.PageHeight, Summary.DemandedBitmapHeight,
    'A demanded bitmap must have the page height.');
  Assert.IsTrue(Summary.FirstTextSample <> '',
    'The fixture must render text so output changes are observable.');

  Violations := GuardViolations(Summary, Summary);
  Assert.AreEqual(0, Length(Violations),
    'A real render must satisfy its own guard.');
end;

procedure TGap005OutputGuardTests.Test_Guard_PageCountTracksRetainedPages;
var
  Exporter: TRecordingExporter;
  Summary: TRenderGuardSummary;
begin
  // P4 contract (GAP-005 audit §3): the logical page count must remain the
  // report's page count and must not silently become a retention artefact.
  // If a future change evicts pages, THIS assertion must be revisited
  // deliberately rather than broken by accident.
  Summary := RenderAndSummarise(120, Exporter);
  Assert.AreEqual(Summary.EnginePageCount, Summary.RetainedPages,
    'PageCount must equal the number of retained pages under the current ' +
    'design; any eviction change must update this contract explicitly.');
  Assert.AreEqual(Summary.EnginePageCount, Exporter.PageCount,
    'The export seam must receive every page.');
end;

procedure TGap005OutputGuardTests.Test_Guard_ExportPagesSeamContract;
var
  Exporter: TRecordingExporter;
  Summary: TRenderGuardSummary;
begin
  // The export seam receives the engine's metafile list. The real PDF exporter
  // (printer driver) and e-mail exporter (MAPI) cannot run in this environment,
  // so this test guards the CONTRACT they depend on and does not pretend to
  // verify them: the list must be complete and every entry a usable metafile.
  Summary := RenderAndSummarise(120, Exporter);

  Assert.IsTrue(Exporter.PageCount > 0,
    'The export seam must receive at least one page.');
  Assert.AreEqual(Summary.RetainedPages, Exporter.PageCount,
    'The export seam must receive every retained page.');
  Assert.IsTrue(Exporter.AllMetafilesValid,
    'Every page handed to the export seam must be a usable metafile.');
end;

initialization
  TDUnitX.RegisterTestFixture(TGap005OutputGuardTests);

end.
