unit Test.Vittix.Report.PreviewRetention;

{
  DP-32 / M-18 - preview retention contract (test-only unit).

  Before this fix `TVittixReportPreview.LoadFromRenderer` forced every
  renderer page's lazy raster (`Pages[I].Bitmap`) and then retained TWO
  copies per page: a full-page bitmap AND a metafile.  With the renderer's
  own raster still alive during the copy that is a transient ~3x raster
  footprint; steady state is one bitmap + one metafile per page - for a
  75-page report that is hundreds of MB that the vector pages alone would
  not need.

  Contract pinned here:
    A. Loading the preview must NOT rasterise any renderer page - the
       control retains the vector (metafile) form only.  Laziness is proven
       with the renderer's `RasterCount` instrumentation (GAP-005/P2), not
       inferred from memory readings.
    B. Page count is preserved through the load.
    C. `TVittixReportPreview.EstimateRetainedBytes` reports the retained
       vector footprint (sum of the pages' metafile byte sizes) so the
       large-report warning dialog counts what is actually retained.

  The preview must be driven WITHOUT a parent window here (console DUnitX);
  this unit therefore also pins that the load path is safe to drive
  headlessly (any Invalidate is handle-guarded).
}

interface

uses
  System.SysUtils,
  System.Types,
  Data.DB,
  Datasnap.DBClient,
  Vcl.Graphics,
  Winapi.Windows,
  DUnitX.TestFramework,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Engine,
  Vittix.Report.Renderer,
  Vittix.Report.Preview;

type
  [TestFixture]
  TPreviewRetentionTests = class
  private
    function CreateIntTable(const AFieldName: string;
      const AValues: array of Integer): TClientDataSet;
    function BuildPagedReport: TReportModel;
    function SumRasterCounts(ARenderer: TReportRenderer): Integer;
    function SumMetafileBytes(ARenderer: TReportRenderer): Int64;
    procedure RenderRows(ARowCount: Integer; out Renderer: TReportRenderer;
      out Engine: TReportEngine; out DataSet: TClientDataSet;
      out Model: TReportModel);
  public
    [Test] procedure Test_A_LoadDoesNotRasteriseRendererPages;
    [Test] procedure Test_B_LoadPreservesPageCount;
    [Test] procedure Test_C_EstimateRetainedBytes_CountsMetafileData;
    [Test] procedure Test_D_HeadlessDrive_IsSafe;
  end;

implementation

const
  PageRows = 120;

function TPreviewRetentionTests.CreateIntTable(const AFieldName: string;
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

function TPreviewRetentionTests.BuildPagedReport: TReportModel;
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

function TPreviewRetentionTests.SumRasterCounts(
  ARenderer: TReportRenderer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ARenderer.Pages.Count - 1 do
    Inc(Result, ARenderer.Pages[I].RasterCount);
end;

function TPreviewRetentionTests.SumMetafileBytes(
  ARenderer: TReportRenderer): Int64;
var
  I: Integer;
  Hdr: ENHMETAHEADER;
begin
  Result := 0;
  for I := 0 to ARenderer.Pages.Count - 1 do
    if Assigned(ARenderer.Pages[I].Metafile) and
       (ARenderer.Pages[I].Metafile.Handle <> 0) and
       (GetEnhMetaFileHeader(ARenderer.Pages[I].Metafile.Handle,
          SizeOf(Hdr), @Hdr) > 0) then
      Inc(Result, Hdr.nBytes);
end;

procedure TPreviewRetentionTests.RenderRows(ARowCount: Integer;
  out Renderer: TReportRenderer; out Engine: TReportEngine;
  out DataSet: TClientDataSet; out Model: TReportModel);
var
  Values: TArray<Integer>;
  I: Integer;
begin
  SetLength(Values, ARowCount);
  for I := 0 to High(Values) do
    Values[I] := I + 1;

  DataSet := CreateIntTable('ID', Values);
  Model := BuildPagedReport;
  Engine := TReportEngine.Create(Model, DataSet, nil);
  Renderer := TReportRenderer.Create;
  Renderer.Render(Engine, Model.PageSettings.PageWidth,
    Model.PageSettings.PageHeight);
end;

{ A - the load must keep the renderer's pages lazy and retain vector only. }
procedure TPreviewRetentionTests.Test_A_LoadDoesNotRasteriseRendererPages;
var
  Renderer: TReportRenderer;
  Engine: TReportEngine;
  DataSet: TClientDataSet;
  Model: TReportModel;
  Preview: TVittixReportPreview;
begin
  RenderRows(PageRows, Renderer, Engine, DataSet, Model);
  try
    Assert.IsTrue(Renderer.Pages.Count > 1,
      'The fixture must produce multiple pages.');
    Assert.AreEqual(0, SumRasterCounts(Renderer),
      'Precondition: the renderer must be fully lazy before the load.');

    Preview := TVittixReportPreview.Create(nil);
    try
      Preview.LoadFromRenderer(Renderer);

      Assert.AreEqual(0, SumRasterCounts(Renderer),
        Format('Loading the preview must not rasterise renderer pages ' +
          '(%d page(s) rasterised; DP-32 keeps the vector form only).',
          [SumRasterCounts(Renderer)]));
    finally
      Preview.Free;
    end;

    // Clear must stay raster-free as well.
    Preview := TVittixReportPreview.Create(nil);
    try
      Preview.LoadFromRenderer(Renderer);
      Preview.Clear;
      Assert.AreEqual(0, SumRasterCounts(Renderer),
        'Clear must not rasterise renderer pages.');
    finally
      Preview.Free;
    end;
  finally
    Renderer.Free;
    Engine.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

{ B - page count survives the load. }
procedure TPreviewRetentionTests.Test_B_LoadPreservesPageCount;
var
  Renderer: TReportRenderer;
  Engine: TReportEngine;
  DataSet: TClientDataSet;
  Model: TReportModel;
  Preview: TVittixReportPreview;
begin
  RenderRows(PageRows, Renderer, Engine, DataSet, Model);
  try
    Preview := TVittixReportPreview.Create(nil);
    try
      Assert.AreEqual(0, Preview.PageCount, 'A fresh preview holds no pages.');
      Preview.LoadFromRenderer(Renderer);
      Assert.AreEqual(Renderer.Pages.Count, Preview.PageCount,
        'The preview must retain one page per renderer page.');
      Preview.Clear;
      Assert.AreEqual(0, Preview.PageCount, 'Clear discards the retained pages.');
    finally
      Preview.Free;
    end;
  finally
    Renderer.Free;
    Engine.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

{ C - the warning estimate counts the retained vector bytes. }
procedure TPreviewRetentionTests.Test_C_EstimateRetainedBytes_CountsMetafileData;
var
  Renderer: TReportRenderer;
  Engine: TReportEngine;
  DataSet: TClientDataSet;
  Model: TReportModel;
  Estimated, Actual, RasterEquivalent: Int64;
begin
  RenderRows(PageRows, Renderer, Engine, DataSet, Model);
  try
    Estimated := TVittixReportPreview.EstimateRetainedBytes(Renderer);
    Actual := SumMetafileBytes(Renderer);

    Assert.IsTrue(Estimated > 0,
      'The retained-bytes estimate must be positive for a rendered report.');
    Assert.AreEqual(Actual, Estimated,
      'The estimate must equal the sum of the pages'' metafile byte sizes.');

    // Sanity: the point of the fix - the vector footprint is materially
    // smaller than the raster footprint the old dialog assumed per page.
    RasterEquivalent := Int64(Renderer.Pages.Count) *
      Int64(Model.PageSettings.PageWidth) *
      Int64(Model.PageSettings.PageHeight) * 4;
    Assert.IsTrue(Estimated < RasterEquivalent,
      Format('The retained vector footprint (%d bytes) must be smaller than ' +
        'the raster equivalent (%d bytes) for a text-only report.',
        [Estimated, RasterEquivalent]));
  finally
    Renderer.Free;
    Engine.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

{ D - the control can be created and driven without a parent window (console
  DUnitX hosts).  This pins the DP-32 handle-gating in the load/drive paths. }
procedure TPreviewRetentionTests.Test_D_HeadlessDrive_IsSafe;
var
  Preview: TVittixReportPreview;
begin
  Preview := TVittixReportPreview.Create(nil);
  try
    Preview.Clear;      // must not demand a window handle
    Preview.FitPage;    // no pages: no-op
    Preview.FirstPage;  // no pages: no-op
    Preview.LastPage;   // no pages: no-op
    Assert.AreEqual(0, Preview.PageCount,
      'An empty preview reports zero pages.');
  finally
    Preview.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPreviewRetentionTests);

end.
