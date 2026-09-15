unit Test.Gap005.LazyRaster;

{
  GAP-005 / P2 — lazy rasterisation contract (test-only unit).

  The P2 objective: `TReportRenderer.Render` must not allocate a full-page
  raster bitmap for every retained page. The METAFILE is the primary retained
  representation; the bitmap is materialised on first access and cached.

  Tests A–E below express that contract. Laziness is proven with the page's
  `RasterCount` instrumentation — NOT inferred from `Bitmap = nil`, which could
  have unrelated causes.

    A  Render does not eagerly rasterise any page
    B  A page bitmap materialises on demand with the correct dimensions
    C  Repeated access reuses the materialised bitmap (exactly one raster)
    D  Multi-page laziness: per-page materialisation happens exactly once
    E  Output compatibility: page count / dimensions / metafile presence /
       rendered text are unchanged, and demanded bitmaps carry page ink

  Manual-only boundaries (unchanged, see GAP-005 audit §4): the preview cannot be
  instantiated headlessly, and both print paths need a printer driver. Those are
  not faked here.

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
  Vittix.Report.Renderer;

type
  [TestFixture]
  TGap005LazyRasterTests = class
  private
    function CreateIntTable(const AFieldName: string;
      const AValues: array of Integer): TClientDataSet;
    function BuildPagedReport: TReportModel;
    function SumRasterCounts(ARenderer: TReportRenderer): Integer;
    function BitmapHasInk(ABitmap: TBitmap; AOriginX, AOriginY: Integer): Boolean;
    { Renders ARowCount rows, leaving the caller to own nothing: the renderer and
      engine are created and freed in the fixture helper. }
    procedure RenderRows(ARowCount: Integer; out Renderer: TReportRenderer;
      out Engine: TReportEngine; out DataSet: TClientDataSet; out Model: TReportModel);
  public
    [Test] procedure Test_A_RenderDoesNotEagerlyRasterise;
    [Test] procedure Test_B_BitmapMaterialisesOnDemand;
    [Test] procedure Test_C_RepeatedAccessReusesBitmap;
    [Test] procedure Test_D_MultiPageLazyPerPageOnce;
    [Test] procedure Test_E_OutputCompatibleAndDemandedBitmapsHaveInk;
    { F — the laziness property holds at scale (structural, not timing-based). }
    [Test] procedure Test_F_LargeMultiPageNoEagerRasterisation;
  end;

implementation

const
  PageRows = 120; // enough for multiple pages at the fixture band height

function TGap005LazyRasterTests.CreateIntTable(const AFieldName: string;
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

function TGap005LazyRasterTests.BuildPagedReport: TReportModel;
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

function TGap005LazyRasterTests.SumRasterCounts(ARenderer: TReportRenderer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ARenderer.Pages.Count - 1 do
    Inc(Result, ARenderer.Pages[I].RasterCount);
end;

{ The fixture draws its text near the band origin, which the engine places at the
  printable origin (inside the page margins). Scan a dense window around that
  origin so thin text strokes are not missed, instead of scanning the whole page
  (which would be ~900k pixel reads). }
function TGap005LazyRasterTests.BitmapHasInk(ABitmap: TBitmap;
  AOriginX, AOriginY: Integer): Boolean;
var
  X, Y: Integer;
begin
  Result := False;
  if not Assigned(ABitmap) then Exit;
  for Y := AOriginY - 4 to AOriginY + 24 do
  begin
    if (Y < 0) or (Y >= ABitmap.Height) then Continue;
    for X := AOriginX - 4 to AOriginX + 160 do
    begin
      if (X < 0) or (X >= ABitmap.Width) then Continue;
      if ABitmap.Canvas.Pixels[X, Y] <> clWhite then
        Exit(True);
    end;
  end;
end;

procedure TGap005LazyRasterTests.RenderRows(ARowCount: Integer;
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
  Renderer.Render(Engine, Model.PageSettings.PageWidth, Model.PageSettings.PageHeight);
end;

{ A — Render produces metafiles only; no page is rasterised. }
procedure TGap005LazyRasterTests.Test_A_RenderDoesNotEagerlyRasterise;
var
  Renderer: TReportRenderer;
  Engine: TReportEngine;
  DataSet: TClientDataSet;
  Model: TReportModel;
  I: Integer;
begin
  RenderRows(PageRows, Renderer, Engine, DataSet, Model);
  try
    Assert.IsTrue(Renderer.Pages.Count > 1,
      'The fixture must produce multiple pages.');
    Assert.AreEqual(Engine.PageCount, Renderer.Pages.Count,
      'One renderer page per engine page must still be retained.');

    for I := 0 to Renderer.Pages.Count - 1 do
    begin
      Assert.IsNotNull(Renderer.Pages[I].Metafile,
        'Every page must retain its metafile after Render.');
      Assert.IsTrue(Renderer.Pages[I].Metafile.Width > 0,
        'The retained metafile must be valid.');
    end;

    // Observable laziness: the instrumentation counter, not a nil check.
    Assert.AreEqual(0, SumRasterCounts(Renderer),
      'Render must not rasterise any page eagerly (P2).');
  finally
    Renderer.Free;
    Engine.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

{ B — the bitmap materialises on demand with the page dimensions. }
procedure TGap005LazyRasterTests.Test_B_BitmapMaterialisesOnDemand;
var
  Renderer: TReportRenderer;
  Engine: TReportEngine;
  DataSet: TClientDataSet;
  Model: TReportModel;
  Bmp: TBitmap;
begin
  RenderRows(PageRows, Renderer, Engine, DataSet, Model);
  try
    Assert.AreEqual(0, Renderer.Pages[0].RasterCount,
      'Precondition: page 0 must not be rasterised before it is requested.');

    Bmp := Renderer.Pages[0].Bitmap;

    Assert.IsNotNull(Bmp, 'The demanded bitmap must be materialised.');
    Assert.AreEqual(1, Renderer.Pages[0].RasterCount,
      'Exactly one rasterisation must have occurred.');
    Assert.AreEqual(Model.PageSettings.PageWidth, Bmp.Width,
      'Materialised bitmap width must equal the page width.');
    Assert.AreEqual(Model.PageSettings.PageHeight, Bmp.Height,
      'Materialised bitmap height must equal the page height.');
  finally
    Renderer.Free;
    Engine.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

{ C — repeated access reuses the cached bitmap; one raster only. }
procedure TGap005LazyRasterTests.Test_C_RepeatedAccessReusesBitmap;
var
  Renderer: TReportRenderer;
  Engine: TReportEngine;
  DataSet: TClientDataSet;
  Model: TReportModel;
  First, Second, Third: TBitmap;
begin
  RenderRows(PageRows, Renderer, Engine, DataSet, Model);
  try
    First  := Renderer.Pages[0].Bitmap;
    Second := Renderer.Pages[0].Bitmap;
    Third  := Renderer.Pages[0].Bitmap;

    Assert.IsTrue(First = Second, 'Repeated access must return the same instance.');
    Assert.IsTrue(Second = Third, 'Repeated access must return the same instance.');
    Assert.AreEqual(1, Renderer.Pages[0].RasterCount,
      'Repeated access must not rasterise again.');
    Assert.AreEqual(0, SumRasterCounts(Renderer) - Renderer.Pages[0].RasterCount,
      'No other page may be rasterised by demanding page 0.');
  finally
    Renderer.Free;
    Engine.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

{ D — multi-page: exactly one rasterisation per demanded page, none on re-demand. }
procedure TGap005LazyRasterTests.Test_D_MultiPageLazyPerPageOnce;
var
  Renderer: TReportRenderer;
  Engine: TReportEngine;
  DataSet: TClientDataSet;
  Model: TReportModel;
  I: Integer;
begin
  RenderRows(PageRows, Renderer, Engine, DataSet, Model);
  try
    Assert.IsTrue(Renderer.Pages.Count >= 2, 'Need at least two pages.');

    // Page 1.
    Renderer.Pages[0].Bitmap;
    Assert.AreEqual(1, SumRasterCounts(Renderer),
      'Demanding page 1 must rasterise exactly one page.');

    // Page 2.
    Renderer.Pages[1].Bitmap;
    Assert.AreEqual(2, SumRasterCounts(Renderer),
      'Demanding page 2 must add exactly one rasterisation.');

    // Page 1 again.
    Renderer.Pages[0].Bitmap;
    Assert.AreEqual(2, SumRasterCounts(Renderer),
      'Re-demanding page 1 must not rasterise again.');

    // Pages never demanded must stay unrasterised.
    for I := 2 to Renderer.Pages.Count - 1 do
      Assert.AreEqual(0, Renderer.Pages[I].RasterCount,
        Format('Page %d was never demanded and must not be rasterised.', [I]));
  finally
    Renderer.Free;
    Engine.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

{ E — output compatibility, then demanded-bitmap content. }
procedure TGap005LazyRasterTests.Test_E_OutputCompatibleAndDemandedBitmapsHaveInk;
var
  Renderer: TReportRenderer;
  Engine: TReportEngine;
  DataSet: TClientDataSet;
  Model: TReportModel;
  PageCountBefore, I: Integer;
  Bmp: TBitmap;
  TotalInk: Integer;
begin
  RenderRows(PageRows, Renderer, Engine, DataSet, Model);
  try
    // Output contract unchanged by P2: page count and page identity.
    PageCountBefore := Renderer.Pages.Count;
    Assert.AreEqual(Engine.PageCount, PageCountBefore,
      'Page count must be preserved.');
    Assert.AreEqual(Model.PageSettings.PageWidth, Renderer.Pages[0].Metafile.Width,
      'Page width must be preserved.');
    Assert.AreEqual(0, SumRasterCounts(Renderer),
      'Nothing may be rasterised before demand.');

    // Now demand every bitmap and verify the content contract.
    TotalInk := 0;
    for I := 0 to Renderer.Pages.Count - 1 do
    begin
      Bmp := Renderer.Pages[I].Bitmap;
      Assert.IsNotNull(Bmp, 'Demanded bitmap must exist.');
      Assert.AreEqual(Model.PageSettings.PageWidth, Bmp.Width);
      Assert.AreEqual(Model.PageSettings.PageHeight, Bmp.Height);
      if BitmapHasInk(Bmp, Model.PageSettings.Margins.Left,
        Model.PageSettings.Margins.Top) then
        Inc(TotalInk);
    end;

    Assert.AreEqual(Renderer.Pages.Count, SumRasterCounts(Renderer),
      'Exactly one rasterisation per page after demanding each once.');
    Assert.IsTrue(TotalInk > 0,
      'At least one demanded bitmap must contain rendered ink (the metafile ' +
      'must actually be drawn onto the raster).');
  finally
    Renderer.Free;
    Engine.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

{ F — structural scale check.

  Mirrors the Phase 5 benchmark intent (1000 rows) but asserts the P2 property
  structurally rather than by wall clock: a large multi-page report must still
  cost ZERO rasterisations after Render. Before P2 this was pages-many bitmaps
  (the renderer rasterised every page); after P2 it is zero. }
procedure TGap005LazyRasterTests.Test_F_LargeMultiPageNoEagerRasterisation;
var
  Renderer: TReportRenderer;
  Engine: TReportEngine;
  DataSet: TClientDataSet;
  Model: TReportModel;
begin
  RenderRows(1000, Renderer, Engine, DataSet, Model);
  try
    Assert.IsTrue(Renderer.Pages.Count > 10,
      'The 1000-row fixture must produce a materially multi-page report.');
    Assert.AreEqual(Engine.PageCount, Renderer.Pages.Count,
      'Page count must be preserved at scale.');
    Assert.AreEqual(0, SumRasterCounts(Renderer),
      Format('A %d-page report must perform 0 rasterisations after Render ' +
             '(was %d before P2).',
             [Renderer.Pages.Count, Renderer.Pages.Count]));
  finally
    Renderer.Free;
    Engine.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TGap005LazyRasterTests);

end.
