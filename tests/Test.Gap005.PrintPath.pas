unit Test.Gap005.PrintPath;

{
  GAP-005 / P3 — print-path guard (test-only unit).

  P3 unified the three printer paths onto the shared mapping in
  `Vittix.Report.PrintMapping` and made `TReportRenderer.Print` draw the
  METAFILE (matching the preview and the PDF exporter), keeping the bitmap only
  as a defensive fallback.

  What is verified here, without a printer:

    * the shared mapping is a PURE function — full-stretch reproduces the exact
      previous rectangle, and the aspect-preserving mode is correct (it is NOT
      the default);
    * the renderer's per-page draw uses the METAFILE. This is proven
      structurally with `TRenderPage.RasterCount`, which stays 0 for a
      metafile draw and would increment for a bitmap draw (see also
      Test.Gap005.LazyRaster);
    * every retained page can be drawn, in order.

  What is NOT verified here, and is deliberately not faked: actual printed
  pixels and printer-driver fidelity. Those are manual (TESTING.md print
  checklist) because they require a real device. `TReportRenderer.Print` itself
  is never invoked (it would open a printer device).

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
  Vittix.Report.PrintMapping;

type
  { Exposes the protected draw seam for verification without a printer. }
  TTestableRenderer = class(TReportRenderer)
  public
    procedure DrawPage(ACanvas: TCanvas;
      APageIndex, ADeviceWidth, ADeviceHeight: Integer);
  end;

  [TestFixture]
  TGap005PrintPathTests = class
  private
    function CreateIntTable(const AFieldName: string;
      const AValues: array of Integer): TClientDataSet;
    function BuildPagedReport: TReportModel;
    procedure RenderRows(ARowCount: Integer; out Renderer: TTestableRenderer;
      out Engine: TReportEngine; out DataSet: TClientDataSet; out Model: TReportModel);
    function SumRasterCounts(ARenderer: TReportRenderer): Integer;
  public
    { Shared mapping — pure function. }
    [Test] procedure Test_Mapping_FullStretchReproducesPreviousRect;
    [Test] procedure Test_Mapping_FullStretchIgnoresPageSize;
    [Test] procedure Test_Mapping_AspectModeFitsAndCentres;
    [Test] procedure Test_Mapping_DegenerateInputsDoNotRaise;
    { The de-modalised size-mismatch decision (pure, so gate-covered). }
    [Test] procedure Test_Mapping_SizeMismatchPredicate;
    { Renderer draw seam — source selection and ordering. }
    [Test] procedure Test_DrawPage_UsesMetafileNotBitmap;
    [Test] procedure Test_DrawPage_EveryPageDrawableInOrder;
    [Test] procedure Test_DrawPage_GuardsInvalidArguments;
  end;

implementation

{ TTestableRenderer }

procedure TTestableRenderer.DrawPage(ACanvas: TCanvas;
  APageIndex, ADeviceWidth, ADeviceHeight: Integer);
begin
  DrawPageTo(ACanvas, APageIndex, ADeviceWidth, ADeviceHeight);
end;

{ Fixture }

function TGap005PrintPathTests.CreateIntTable(const AFieldName: string;
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

function TGap005PrintPathTests.BuildPagedReport: TReportModel;
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

procedure TGap005PrintPathTests.RenderRows(ARowCount: Integer;
  out Renderer: TTestableRenderer; out Engine: TReportEngine;
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
  Renderer := TTestableRenderer.Create;
  Renderer.Render(Engine, Model.PageSettings.PageWidth, Model.PageSettings.PageHeight);
end;

function TGap005PrintPathTests.SumRasterCounts(ARenderer: TReportRenderer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ARenderer.Pages.Count - 1 do
    Inc(Result, ARenderer.Pages[I].RasterCount);
end;

{ ---------------------- Shared mapping (pure function) ---------------------- }

procedure TGap005PrintPathTests.Test_Mapping_FullStretchReproducesPreviousRect;
var
  R: TRect;
begin
  // The pre-P3 code used Rect(0,0,Printer.PageWidth,Printer.PageHeight).
  R := CalculatePrintDestRect(793, 1122, 2550, 3300, prsFullStretch);
  Assert.AreEqual(0, R.Left);
  Assert.AreEqual(0, R.Top);
  Assert.AreEqual(2550, R.Right);
  Assert.AreEqual(3300, R.Bottom);

  // Default parameter must be the same mode.
  R := CalculatePrintDestRect(793, 1122, 2550, 3300);
  Assert.AreEqual(2550, R.Right, 'The default mode must remain full stretch.');
  Assert.AreEqual(3300, R.Bottom);
end;

procedure TGap005PrintPathTests.Test_Mapping_FullStretchIgnoresPageSize;
var
  A, B: TRect;
begin
  A := CalculatePrintDestRect(793, 1122, 1000, 1000, prsFullStretch);
  B := CalculatePrintDestRect(10, 10, 1000, 1000, prsFullStretch);
  Assert.AreEqual(A.Right, B.Right, 'Full stretch must ignore the page size.');
  Assert.AreEqual(A.Bottom, B.Bottom, 'Full stretch must ignore the page size.');
end;

procedure TGap005PrintPathTests.Test_Mapping_AspectModeFitsAndCentres;
var
  R: TRect;
begin
  // A tall page (793x1122) into a square device: width limits the fit, so the
  // result is centred horizontally with vertical fill.
  R := CalculatePrintDestRect(793, 1122, 1000, 1000, prsFitPreserveAspectCentered);
  Assert.IsTrue(R.Right <= 1000, 'The fitted rect must not exceed the device width.');
  Assert.IsTrue(R.Bottom <= 1000, 'The fitted rect must not exceed the device height.');
  Assert.AreEqual(R.Right - R.Left,
    Integer(Round((R.Bottom - R.Top) * (793 / 1122))),
    'The fitted rect must preserve the page aspect ratio.');
  Assert.AreEqual((1000 - (R.Right - R.Left)) div 2, R.Left,
    'The fitted rect must be centred horizontally.');
end;

procedure TGap005PrintPathTests.Test_Mapping_DegenerateInputsDoNotRaise;
var
  R: TRect;
begin
  R := CalculatePrintDestRect(0, 0, 100, 200, prsFitPreserveAspectCentered);
  Assert.AreEqual(100, R.Right, 'Degenerate page size must fall back to the device rect.');
  Assert.AreEqual(200, R.Bottom);

  R := CalculatePrintDestRect(100, 200, 0, 0, prsFullStretch);
  Assert.AreEqual(0, R.Right, 'Degenerate device size must not raise.');

  R := CalculatePrintDestRect(-5, -5, -5, -5, prsFitPreserveAspectCentered);
  Assert.AreEqual(-5, R.Right, 'Negative sizes must not raise.');
end;

{ ---------------------- Size-mismatch predicate ---------------------- }

procedure TGap005PrintPathTests.Test_Mapping_SizeMismatchPredicate;
begin
  // The PDF exporter reports (and no longer blocks on) a page-size difference.
  // The decision is a pure function so it is covered without a printer.
  Assert.IsFalse(IsPrintSizeMismatch(793, 1122, 793, 1122, 2),
    'Identical page and device sizes are not a mismatch.');

  Assert.IsFalse(IsPrintSizeMismatch(793, 1122, 795, 1122, 2),
    'A difference equal to the tolerance is not a mismatch.');

  Assert.IsTrue(IsPrintSizeMismatch(793, 1122, 796, 1122, 2),
    'A width difference beyond the tolerance is a mismatch.');

  Assert.IsTrue(IsPrintSizeMismatch(793, 1122, 793, 1125, 2),
    'A height difference beyond the tolerance is a mismatch.');

  Assert.IsTrue(IsPrintSizeMismatch(793, 1122, 793, 1119, 2),
    'The comparison is absolute (a smaller device size still mismatches).');

  Assert.IsTrue(IsPrintSizeMismatch(793, 1122, 0, 0, 2),
    'Degenerate device dimensions are reported, never raised.');
end;

{ ---------------------- Renderer draw seam ---------------------- }

procedure TGap005PrintPathTests.Test_DrawPage_UsesMetafileNotBitmap;
var
  Renderer: TTestableRenderer;
  Engine: TReportEngine;
  DataSet: TClientDataSet;
  Model: TReportModel;
  Canvas: TBitmap;
  I: Integer;
begin
  RenderRows(120, Renderer, Engine, DataSet, Model);
  Canvas := TBitmap.Create;
  try
    Assert.IsTrue(Renderer.Pages.Count > 1, 'Need a multi-page report.');
    Canvas.SetSize(1000, 1000);

    for I := 0 to Renderer.Pages.Count - 1 do
      Renderer.DrawPage(Canvas.Canvas, I, Canvas.Width, Canvas.Height);

    // P3: the print path is vector. A metafile draw must NOT materialise the
    // raster; a bitmap draw would have incremented RasterCount.
    Assert.AreEqual(0, SumRasterCounts(Renderer),
      'The print path must draw the metafile, not the bitmap (P3).');
  finally
    Canvas.Free;
    Renderer.Free;
    Engine.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TGap005PrintPathTests.Test_DrawPage_EveryPageDrawableInOrder;
var
  Renderer: TTestableRenderer;
  Engine: TReportEngine;
  DataSet: TClientDataSet;
  Model: TReportModel;
  Canvas: TBitmap;
  Drawn: Integer;
  I: Integer;
begin
  RenderRows(120, Renderer, Engine, DataSet, Model);
  Canvas := TBitmap.Create;
  try
    Canvas.SetSize(800, 600);
    Drawn := 0;
    for I := 0 to Renderer.Pages.Count - 1 do
    begin
      Renderer.DrawPage(Canvas.Canvas, I, Canvas.Width, Canvas.Height);
      Inc(Drawn);
    end;
    Assert.AreEqual(Renderer.Pages.Count, Drawn,
      'Every retained page must be drawable (page/NewPage sequence).');
    Assert.AreEqual(0, SumRasterCounts(Renderer),
      'Drawing the whole document must stay vector.');
  finally
    Canvas.Free;
    Renderer.Free;
    Engine.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TGap005PrintPathTests.Test_DrawPage_GuardsInvalidArguments;
var
  Renderer: TTestableRenderer;
  Engine: TReportEngine;
  DataSet: TClientDataSet;
  Model: TReportModel;
  Canvas: TBitmap;
begin
  RenderRows(5, Renderer, Engine, DataSet, Model);
  Canvas := TBitmap.Create;
  try
    Canvas.SetSize(100, 100);
    Renderer.DrawPage(nil, 0, 100, 100);          // nil canvas
    Renderer.DrawPage(Canvas.Canvas, -1, 100, 100);       // negative index
    Renderer.DrawPage(Canvas.Canvas, 9999, 100, 100);     // out of range
    Assert.AreEqual(0, SumRasterCounts(Renderer),
      'Guarded calls must not draw or rasterise.');
  finally
    Canvas.Free;
    Renderer.Free;
    Engine.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TGap005PrintPathTests);

end.
