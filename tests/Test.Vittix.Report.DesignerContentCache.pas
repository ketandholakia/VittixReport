unit Test.Vittix.Report.DesignerContentCache;

{
  DP-35 / M-17: designer content-layer caching + live-fallback contract.

  The designer renders report content once into a logical (zoom-independent)
  metafile and re-uses it across repaints; a rebuild must happen only after a
  real model/content change.  Measured per-paint rebuild cost before the
  cache: ~7 ms (36 objects) to ~98 ms (480 objects) per repaint, versus
  ~1-10 ms for a plain StretchDraw of the existing layer.

  RED first: UpdateContentMetafile rebuilds unconditionally today, so every
  repaint pays a full rebuild (ContentLayer_NoChangePaints_DoNotRebuild and
  ContentLayer_SurvivesZoomChange fail), and the live fallback draws
  unscaled glyphs at non-100% zoom (LiveLayer_ContentScalesWithZoom fails).
}

interface

uses
  System.SysUtils,
  System.Math,
  System.Types,
  Winapi.Windows,
  Vcl.Graphics,
  DUnitX.TestFramework,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.PageSettings,
  Vittix.Report.DesignerInteractionController,
  Vittix.Report.DesignerControl;

type
  [TestFixture]
  TDesignerContentCacheTests = class
  private
    FDesigner: TVittixReportDesigner;
    function BuildModel: TReportModel;
    function FirstTextObject: TReportTextObject;
    function RenderInk(AZoom: Integer): TRect;
    function RenderLiveInk(AZoom: Integer): TRect;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ContentLayer_NoChangePaints_DoNotRebuild;

    [Test]
    procedure ContentLayer_Rebuilds_AfterModelEdit;

    [Test]
    procedure ContentLayer_SurvivesZoomChange;

    [Test]
    procedure InvalidateContent_MarksLayerStale;

    [Test]
    procedure LiveLayer_ContentScalesWithZoom;

    [Test]
    procedure LiveLayer_DoesNotMutateObjectBounds;
  end;

implementation

{ Scans a 32-bit bitmap and returns the bounding box of every non-white
  pixel; an empty rectangle when the bitmap is entirely white. }
function InkBounds(ABitmap: TBitmap): TRect;
var
  X, Y: Integer;
  Row : PRGBQuad;
  Pixel: TRGBQuad;
  Found: Boolean;
begin
  Result := Rect(MaxInt, MaxInt, -1, -1);
  Found := False;
  for Y := 0 to ABitmap.Height - 1 do
  begin
    Row := ABitmap.ScanLine[Y];
    for X := 0 to ABitmap.Width - 1 do
    begin
      Pixel := Row^;
      if (Pixel.rgbRed <> $FF) or (Pixel.rgbGreen <> $FF) or
         (Pixel.rgbBlue <> $FF) then
      begin
        if X < Result.Left then Result.Left := X;
        if Y < Result.Top then Result.Top := Y;
        if X > Result.Right then Result.Right := X;
        if Y > Result.Bottom then Result.Bottom := Y;
        Found := True;
      end;
      Inc(Row);
    end;
  end;
  if not Found then
    Result := Rect(0, 0, 0, 0);
end;

function TDesignerContentCacheTests.BuildModel: TReportModel;
var
  Band: TReportBand;
  Txt : TReportTextObject;
begin
  Result := TReportModel.Create;

  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := 60;

  Txt := TReportTextObject.Create;
  Txt.Bounds := Rect(12, 10, 320, 30);
  Txt.Text := 'Simple MasterData Report';
  Txt.Font.Name := 'Tahoma';
  Txt.Font.Size := 12;
  Txt.Font.Style := [fsBold];
  Band.Children.Add(Txt);

  Result.Objects.Add(Band);
end;

function TDesignerContentCacheTests.FirstTextObject: TReportTextObject;
begin
  Result := TReportTextObject(TReportBand(FDesigner.Report.Objects[0]).Children[0]);
end;

function TDesignerContentCacheTests.RenderInk(AZoom: Integer): TRect;
var
  SW, SH: Integer;
  Bmp: TBitmap;
begin
  SW := MulDiv(FDesigner.Report.PageSettings.PageWidth, AZoom, 100);
  SH := MulDiv(FDesigner.Report.PageSettings.PageHeight, AZoom, 100);
  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf32bit;
    Bmp.SetSize(SW, SH);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.Brush.Style := bsSolid;
    Bmp.Canvas.FillRect(Rect(0, 0, SW, SH));
    Assert.IsTrue(FDesigner.RenderContentTo(Bmp.Canvas, Rect(0, 0, SW, SH)),
      'content layer must render at zoom ' + IntToStr(AZoom));
    Result := InkBounds(Bmp);
  finally
    Bmp.Free;
  end;
end;

function TDesignerContentCacheTests.RenderLiveInk(AZoom: Integer): TRect;
var
  SW, SH: Integer;
  Bmp: TBitmap;
begin
  SW := MulDiv(FDesigner.Report.PageSettings.PageWidth, AZoom, 100);
  SH := MulDiv(FDesigner.Report.PageSettings.PageHeight, AZoom, 100);
  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf32bit;
    Bmp.SetSize(SW, SH);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.Brush.Style := bsSolid;
    Bmp.Canvas.FillRect(Rect(0, 0, SW, SH));
    Assert.IsTrue(FDesigner.RenderContentLiveTo(Bmp.Canvas, Rect(0, 0, SW, SH)),
      'live layer must render at zoom ' + IntToStr(AZoom));
    Result := InkBounds(Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure TDesignerContentCacheTests.Setup;
begin
  FDesigner := TVittixReportDesigner.Create(nil);
  FDesigner.LoadReport(BuildModel, True);
end;

procedure TDesignerContentCacheTests.TearDown;
begin
  FDesigner.Free;
end;

procedure TDesignerContentCacheTests.ContentLayer_NoChangePaints_DoNotRebuild;
var
  Builds: Integer;
begin
  Assert.IsTrue(FDesigner.UpdateContentMetafile);
  Builds := FDesigner.ContentBuildCount;
  Assert.IsTrue(Builds >= 1, 'first update must have built the content layer');

  Assert.IsTrue(FDesigner.UpdateContentMetafile);
  Assert.AreEqual(Builds, FDesigner.ContentBuildCount,
    'no-change repaint must re-use the cached content layer');
end;

procedure TDesignerContentCacheTests.ContentLayer_Rebuilds_AfterModelEdit;
var
  Builds: Integer;
  WBefore, WAfter: Integer;
begin
  Assert.IsTrue(FDesigner.UpdateContentMetafile);
  WBefore := RenderInk(100).Width;
  Builds := FDesigner.ContentBuildCount;

  FirstTextObject.Text := 'Simple MasterData Report - with a much longer text';

  // External model mutations request a layout rebuild (the designer app
  // contract); this must also mark the content layer stale.
  FDesigner.RebuildLayout;

  Assert.IsTrue(FDesigner.UpdateContentMetafile);
  Assert.AreEqual(Builds + 1, FDesigner.ContentBuildCount,
    'a model edit must rebuild the content layer exactly once');

  WAfter := RenderInk(100).Width;
  Assert.IsTrue(WAfter > WBefore,
    Format('rebuilt layer must reflect the longer text (before=%d after=%d)',
      [WBefore, WAfter]));
end;

procedure TDesignerContentCacheTests.ContentLayer_SurvivesZoomChange;
var
  Builds: Integer;
begin
  Assert.IsTrue(FDesigner.UpdateContentMetafile);
  Builds := FDesigner.ContentBuildCount;

  // The layer is logical (zoom-independent), so zooming is a pure view
  // change: it must not invalidate the cache.
  FDesigner.Zoom := 400;

  Assert.IsTrue(FDesigner.UpdateContentMetafile);
  Assert.AreEqual(Builds, FDesigner.ContentBuildCount,
    'zoom changes must not rebuild the content layer');
end;

procedure TDesignerContentCacheTests.InvalidateContent_MarksLayerStale;
var
  Builds: Integer;
begin
  Assert.IsTrue(FDesigner.UpdateContentMetafile);
  Builds := FDesigner.ContentBuildCount;

  // The interaction controller calls this on every drag frame that mutates
  // object geometry (via IDesignerSurface):
  (FDesigner as IDesignerSurface).InvalidateContent;

  Assert.IsTrue(FDesigner.UpdateContentMetafile);
  Assert.AreEqual(Builds + 1, FDesigner.ContentBuildCount,
    'InvalidateContent must mark the layer stale');
end;

procedure TDesignerContentCacheTests.LiveLayer_ContentScalesWithZoom;
var
  Ink51, Ink100, Ink151: TRect;
  W51, W100, W151: Integer;
begin
  Ink51  := RenderLiveInk(51);
  Ink100 := RenderLiveInk(100);
  Ink151 := RenderLiveInk(151);

  W51  := Ink51.Right  - Ink51.Left;
  W100 := Ink100.Right - Ink100.Left;
  W151 := Ink151.Right - Ink151.Left;

  Assert.IsTrue(W51 > 0,  'no live text ink at 51%');
  Assert.IsTrue(W100 > 0, 'no live text ink at 100%');
  Assert.IsTrue(W151 > 0, 'no live text ink at 151%');

  // The live fallback must scale text metrics with zoom, matching the
  // primary metafile layer (StretchDraw scales everything uniformly).
  Assert.IsTrue(Abs(W51 * 100 - W100 * 51) <= W100 * 12,
    Format('live text ink width not ~0.51x at 51%% (51%%=%d, 100%%=%d)', [W51, W100]));
  Assert.IsTrue(Abs(W151 * 100 - W100 * 151) <= W100 * 12,
    Format('live text ink width not ~1.51x at 151%% (151%%=%d, 100%%=%d)', [W151, W100]));
end;

procedure TDesignerContentCacheTests.LiveLayer_DoesNotMutateObjectBounds;
var
  Obj: TReportTextObject;
  B0: TRect;
begin
  Obj := FirstTextObject;
  B0 := Obj.Bounds;

  RenderLiveInk(151);

  Assert.IsTrue(Obj.Bounds = B0,
    'live rendering must not leave model bounds mutated');
end;

initialization
  TDUnitX.RegisterTestFixture(TDesignerContentCacheTests);

end.
