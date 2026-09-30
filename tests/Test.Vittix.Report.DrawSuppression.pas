unit Test.Vittix.Report.DrawSuppression;

{
  DP-19 / M-10 - object Draw must honour Visible / PrintWhen.

  The engine's band path already guards its children through
  DrawReportObjectWithHooks, but that is not the only code that calls an
  object's Draw directly: the designer's content layer
  (TVittixReportDesigner.UpdateContentMetafile / DrawBandContentLive) draws
  band children with no hook context at all.  Every classic object class
  (text, memo, shape, line, image, barcode, table, subreport) therefore
  carries a ShouldPrintObject self-guard inside Draw; the chart, crosstab
  and unknown classes did not, so a hidden chart still painted its content
  wherever Draw was called directly.

  Contract pinned here:
    1. Directly drawing a chart / crosstab / unknown object with
       Visible=False or a falsy PrintWhen must leave the canvas untouched;
       an unsuppressed object must paint (so the negative checks cannot
       pass vacuously).
    2. The designer content layer must show no ink for a suppressed chart,
       consistent with the self-guarded classes.
    3. Engine export capture emits no image command for a suppressed chart
       (already true via the band guard - pinned so it stays that way).
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  Data.DB,
  Datasnap.DBClient,
  Vittix.Report.Context,
  Vittix.Report.Model,
  Vittix.Report.Engine,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Objects.Chart,
  Vittix.Report.Objects.CrossTab,
  Vittix.Report.Objects.Unknown,
  Vittix.Report.DesignerControl,
  Vittix.Report.Export.Commands;

type
  [TestFixture]
  TTestObjectDrawSuppression = class
  private
    function CreateDataSet: TClientDataSet;
    function RenderOnWhite(AObj: TReportObject; ADS: TDataSet;
      AWidth, AHeight: Integer): TBitmap;
    class function NonWhitePixelCount(ABmp: TBitmap): Integer;
  public
    [Test] procedure Test_Chart_Hidden_DoesNotDraw;
    [Test] procedure Test_CrossTab_Hidden_DoesNotDraw;
    [Test] procedure Test_Unknown_Hidden_DoesNotDraw;
  end;

  [TestFixture]
  TTestDesignerDrawSuppression = class
  private
    function BuildChartModel(AChartVisible: Boolean): TReportModel;
    class function InkBounds(ABitmap: TBitmap): TRect;
    class function RenderInkBounds(ADesigner: TVittixReportDesigner): TRect;
  public
    [Test] procedure Test_Designer_HiddenChart_NoInk;
  end;

  [TestFixture]
  TTestEngineCaptureSuppression = class
  private
    function CreateDataSet: TClientDataSet;
    class function CountImageCommands(ADoc: TReportExportDocument): Integer;
  public
    [Test] procedure Test_EngineCapture_HiddenChart_NoImageCommand;
  end;

implementation

{ TTestObjectDrawSuppression }

function TTestObjectDrawSuppression.CreateDataSet: TClientDataSet;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('Region', ftString, 20);
  Result.FieldDefs.Add('Product', ftString, 20);
  Result.FieldDefs.Add('Amount', ftFloat);
  Result.CreateDataSet;
  Result.AppendRecord(['East', 'A', 10.0]);
  Result.AppendRecord(['East', 'B', 20.0]);
  Result.AppendRecord(['West', 'A', 30.0]);
  Result.AppendRecord(['West', 'B', 40.0]);
  Result.First;
end;

function TTestObjectDrawSuppression.RenderOnWhite(AObj: TReportObject;
  ADS: TDataSet; AWidth, AHeight: Integer): TBitmap;
var
  Ctx: TExpressionContext;
begin
  Result := TBitmap.Create;
  try
    Result.PixelFormat := pf32bit;
    Result.SetSize(AWidth, AHeight);
    Result.Canvas.Brush.Color := clWhite;
    Result.Canvas.FillRect(Rect(0, 0, AWidth, AHeight));

    Ctx := Default(TExpressionContext);
    Ctx.DataSet := ADS;
    AObj.Draw(Result.Canvas, Ctx);
  except
    Result.Free;
    raise;
  end;
end;

class function TTestObjectDrawSuppression.NonWhitePixelCount(
  ABmp: TBitmap): Integer;
var
  X, Y: Integer;
  Row: PByteArray;
begin
  Result := 0;
  for Y := 0 to ABmp.Height - 1 do
  begin
    Row := ABmp.ScanLine[Y];
    for X := 0 to ABmp.Width - 1 do
      if (PCardinal(@Row[X * 4])^ and $00FFFFFF) <> $00FFFFFF then
        Inc(Result);
  end;
end;

procedure TTestObjectDrawSuppression.Test_Chart_Hidden_DoesNotDraw;
var
  Chart: TReportChartObject;
  Bmp: TBitmap;
begin
  Chart := TReportChartObject.Create;
  try
    Chart.Bounds := Rect(10, 10, 340, 240);

    // Control: an unsuppressed chart paints (demo data points without a
    // dataset binding).
    Bmp := RenderOnWhite(Chart, nil, 360, 260);
    try
      Assert.IsTrue(NonWhitePixelCount(Bmp) > 0,
        'control: a visible, unconditional chart must paint its content');
    finally
      Bmp.Free;
    end;

    // Visible=False must suppress the draw entirely.
    Chart.Visible := False;
    Bmp := RenderOnWhite(Chart, nil, 360, 260);
    try
      Assert.AreEqual(0, NonWhitePixelCount(Bmp),
        'a chart with Visible=False must not draw');
    finally
      Bmp.Free;
    end;

    // A falsy PrintWhen must suppress the draw the same way.
    Chart.Visible := True;
    Chart.PrintWhen := '0';
    Bmp := RenderOnWhite(Chart, nil, 360, 260);
    try
      Assert.AreEqual(0, NonWhitePixelCount(Bmp),
        'a chart with PrintWhen=0 must not draw');
    finally
      Bmp.Free;
    end;
  finally
    Chart.Free;
  end;
end;

procedure TTestObjectDrawSuppression.Test_CrossTab_Hidden_DoesNotDraw;
var
  DS: TClientDataSet;
  CT: TReportCrossTabObject;
  Bmp: TBitmap;
begin
  DS := CreateDataSet;
  try
    CT := TReportCrossTabObject.Create;
    try
      CT.Bounds := Rect(10, 10, 340, 240);
      CT.RowField := 'Region';
      CT.ColumnField := 'Product';
      CT.CellField := 'Amount';

      // Control: an unsuppressed crosstab paints its grid.
      Bmp := RenderOnWhite(CT, DS, 360, 260);
      try
        Assert.IsTrue(NonWhitePixelCount(Bmp) > 0,
          'control: a visible, unconditional crosstab must paint its grid');
      finally
        Bmp.Free;
      end;

      // Visible=False must suppress the draw entirely.
      CT.Visible := False;
      Bmp := RenderOnWhite(CT, DS, 360, 260);
      try
        Assert.AreEqual(0, NonWhitePixelCount(Bmp),
          'a crosstab with Visible=False must not draw');
      finally
        Bmp.Free;
      end;

      // A falsy PrintWhen must suppress the draw the same way.
      CT.Visible := True;
      CT.PrintWhen := '0';
      Bmp := RenderOnWhite(CT, DS, 360, 260);
      try
        Assert.AreEqual(0, NonWhitePixelCount(Bmp),
          'a crosstab with PrintWhen=0 must not draw');
      finally
        Bmp.Free;
      end;
    finally
      CT.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TTestObjectDrawSuppression.Test_Unknown_Hidden_DoesNotDraw;
var
  U: TReportUnknownObject;
  Bmp: TBitmap;
begin
  U := TReportUnknownObject.Create;
  try
    U.Bounds := Rect(10, 10, 340, 120);
    U.OriginalClassName := 'FutureObject';

    // Control: an unsuppressed unknown object paints its placeholder.
    Bmp := RenderOnWhite(U, nil, 360, 140);
    try
      Assert.IsTrue(NonWhitePixelCount(Bmp) > 0,
        'control: a visible, unconditional unknown object must paint');
    finally
      Bmp.Free;
    end;

    // Visible=False must suppress the draw entirely.
    U.Visible := False;
    Bmp := RenderOnWhite(U, nil, 360, 140);
    try
      Assert.AreEqual(0, NonWhitePixelCount(Bmp),
        'an unknown object with Visible=False must not draw');
    finally
      Bmp.Free;
    end;

    // A falsy PrintWhen must suppress the draw the same way.
    U.Visible := True;
    U.PrintWhen := '0';
    Bmp := RenderOnWhite(U, nil, 360, 140);
    try
      Assert.AreEqual(0, NonWhitePixelCount(Bmp),
        'an unknown object with PrintWhen=0 must not draw');
    finally
      Bmp.Free;
    end;
  finally
    U.Free;
  end;
end;

{ TTestDesignerDrawSuppression }

function TTestDesignerDrawSuppression.BuildChartModel(
  AChartVisible: Boolean): TReportModel;
var
  Band: TReportBand;
  Chart: TReportChartObject;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btPageHeader;
  Band.Height := 200;

  Chart := TReportChartObject.Create;
  Chart.Bounds := Rect(12, 10, 320, 180);
  Chart.Visible := AChartVisible;
  Band.Children.Add(Chart);
  Result.Objects.Add(Band);
end;

class function TTestDesignerDrawSuppression.InkBounds(
  ABitmap: TBitmap): TRect;
var
  X, Y: Integer;
  Row: PByteArray;
  Pixel: Cardinal;
  Found: Boolean;
begin
  Result := Rect(MaxInt, MaxInt, -1, -1);
  Found := False;
  for Y := 0 to ABitmap.Height - 1 do
  begin
    Row := ABitmap.ScanLine[Y];
    for X := 0 to ABitmap.Width - 1 do
    begin
      Pixel := PCardinal(@Row[X * 4])^ and $00FFFFFF;
      if Pixel <> $00FFFFFF then
      begin
        if X < Result.Left then Result.Left := X;
        if Y < Result.Top then Result.Top := Y;
        if X > Result.Right then Result.Right := X;
        if Y > Result.Bottom then Result.Bottom := Y;
        Found := True;
      end;
    end;
  end;
  if not Found then
    Result := Rect(0, 0, 0, 0);
end;

class function TTestDesignerDrawSuppression.RenderInkBounds(
  ADesigner: TVittixReportDesigner): TRect;
var
  SW, SH: Integer;
  Bmp: TBitmap;
begin
  SW := ADesigner.Report.PageSettings.PageWidth;
  SH := ADesigner.Report.PageSettings.PageHeight;
  Assert.IsTrue((SW > 0) and (SH > 0), 'page size must be positive');

  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf32bit;
    Bmp.SetSize(SW, SH);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.Brush.Style := bsSolid;
    Bmp.Canvas.FillRect(Rect(0, 0, SW, SH));

    Assert.IsTrue(ADesigner.RenderContentTo(Bmp.Canvas, Rect(0, 0, SW, SH)),
      'designer content layer must render');

    Result := InkBounds(Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure TTestDesignerDrawSuppression.Test_Designer_HiddenChart_NoInk;
var
  D: TVittixReportDesigner;
  Model: TReportModel;
  InkVisible, InkHidden: TRect;
begin
  D := TVittixReportDesigner.Create(nil);
  try
    // Control: a visible chart produces ink in the designer content layer.
    Model := BuildChartModel(True);
    try
      D.LoadReport(Model, True);
    except
      Model.Free;
      raise;
    end;
    InkVisible := RenderInkBounds(D);
    Assert.IsTrue((InkVisible.Right > InkVisible.Left) and
                  (InkVisible.Bottom > InkVisible.Top),
      'control: a visible chart must render ink in the designer');

    // A hidden chart must show no ink, consistent with the self-guarded
    // classes (text, memo, shape, ...).
    Model := BuildChartModel(False);
    try
      D.LoadReport(Model, True);
    except
      Model.Free;
      raise;
    end;
    InkHidden := RenderInkBounds(D);
    Assert.IsTrue((InkHidden.Right <= InkHidden.Left) or
                  (InkHidden.Bottom <= InkHidden.Top),
      'a chart with Visible=False must not render ink in the designer content layer');
  finally
    D.Free;
  end;
end;

{ TTestEngineCaptureSuppression }

function TTestEngineCaptureSuppression.CreateDataSet: TClientDataSet;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('Region', ftString, 20);
  Result.FieldDefs.Add('Product', ftString, 20);
  Result.FieldDefs.Add('Amount', ftFloat);
  Result.CreateDataSet;
  Result.AppendRecord(['East', 'A', 10.0]);
  Result.AppendRecord(['East', 'B', 20.0]);
  Result.First;
end;

class function TTestEngineCaptureSuppression.CountImageCommands(
  ADoc: TReportExportDocument): Integer;
var
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
begin
  Result := 0;
  for Page in ADoc.Pages do
    for Cmd in Page.Commands do
      if Cmd is TReportExportImageCommand then
        Inc(Result);
end;

procedure TTestEngineCaptureSuppression.Test_EngineCapture_HiddenChart_NoImageCommand;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Band: TReportBand;
  Chart: TReportChartObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  HiddenCount, VisibleCount: Integer;
begin
  DS := CreateDataSet;
  try
    Model := TReportModel.Create;
    try
      Band := TReportBand.Create;
      Band.BandType := btPageHeader;
      Band.Height := 260;

      Chart := TReportChartObject.Create;
      Chart.Bounds := Rect(10, 10, 310, 210);
      Chart.Title := 'Capture pin';
      // Unregistered name -> no named dataset -> the chart draws its
      // built-in demo points; capture must still run for a drawn chart.
      Chart.DataSetName := '__demo__';
      Band.Children.Add(Chart);
      Model.Objects.Add(Band);

      Engine := TReportEngine.Create(Model, DS, nil, nil);
      try
        Doc := TReportExportDocument.Create;
        try
          Chart.Visible := False;
          Engine.ExportDocument := Doc;
          Engine.Prepare;
          HiddenCount := CountImageCommands(Doc);
        finally
          Doc.Free;
        end;

        Doc := TReportExportDocument.Create;
        try
          Chart.Visible := True;
          Engine.ExportDocument := Doc;
          Engine.Prepare;
          VisibleCount := CountImageCommands(Doc);
        finally
          Doc.Free;
        end;
      finally
        Engine.Free;
      end;

      Assert.AreEqual(0, HiddenCount,
        'a hidden chart must not be captured as an image command');
      Assert.AreEqual(1, VisibleCount,
        'control: a visible chart must be captured as one image command');
    finally
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestObjectDrawSuppression);
  TDUnitX.RegisterTestFixture(TTestDesignerDrawSuppression);
  TDUnitX.RegisterTestFixture(TTestEngineCaptureSuppression);

end.
