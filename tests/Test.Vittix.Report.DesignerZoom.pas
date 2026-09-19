unit Test.Vittix.Report.DesignerZoom;

{
  Regression coverage for the designer's uniform-zoom rendering contract.

  The designer renders report content at 1:1 logical coordinates and then
  scales it uniformly into the canvas (see TVittixReportDesigner.RenderContentTo
  / UpdateContentMetafile).  Object rectangles are produced by
  DesignerObjScreenRect / ObjScreenRectInternal using boundary scaling:

      screenLeft  = MulDiv(logicalLeft,  zoom, 100)
      screenRight = MulDiv(logicalRight, zoom, 100)
      screenWidth = screenRight - screenLeft

  These tests pin that contract and the content-scaling behaviour.
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Types, System.Math, System.Generics.Collections,
  Winapi.Windows,
  Vcl.Graphics,
  Vittix.Report.Model, Vittix.Report.Objects, Vittix.Report.Bands,
  Vittix.Report.PageSettings,
  Vittix.Report.DesignerInteraction,
  Vittix.Report.DesignerControl;

type
  [TestFixture]
  TDesignerZoomTransformTests = class
  public
    [Test] procedure AdjacentObjects_StayAdjacent_AtAllZooms;
    [Test] procedure ObjectWidth_ScalesProportionally_AtAllZooms;
    [Test] procedure BandBodyOrigin_MatchesHeaderBottom_AtAllZooms;
    [Test] procedure ScreenToPage_RoundTrips_AtAllZooms;
  end;

  [TestFixture]
  TDesignerUniformContentTests = class
  public
    [Test] procedure ContentLayer_IsLogicalSize_ZoomIndependent;
    [Test] procedure Content_TextInk_ScalesWithZoom;
  end;

implementation

const
  ZOOMS: array[0..8] of Integer = (25, 50, 51, 75, 100, 150, 151, 200, 400);
  CONTENT_ZOOMS: array[0..2] of Integer = (51, 100, 151);

  PAGE_LEFT  = 20;   // ruler strip offset used by the designer
  PAGE_TOP   = 20;
  MARGIN_L   = 40;
  BAND_Y     = 40;   // first band Y (== top margin in BuildBandLayouts)
  BAND_HDR_H = 14;   // mirrors Vittix.Report.DesignerControl.BAND_HDR_H (logical)

type
  { Minimal IBandOwner/IBandLayoutIndex provider for DesignerObjScreenRect. }
  TBandLookup = class
  public
    Band: TReportBand;
    function Owner(AObj: TReportObject): TReportBand;
    function Index(ABand: TReportBand): Integer;
  end;

function TBandLookup.Owner(AObj: TReportObject): TReportBand;
begin
  Result := Band;
end;

function TBandLookup.Index(ABand: TReportBand): Integer;
begin
  Result := 0;
end;

function SingleBandLayouts(ABand: TReportBand): TDesignerBandLayouts;
begin
  SetLength(Result, 1);
  Result[0].Band := ABand;
  Result[0].Y := BAND_Y;
  Result[0].Height := ABand.Height;
end;

function ScreenRectOf(AObj: TReportObject; const ALayouts: TDesignerBandLayouts;
  ALookup: TBandLookup; AZoom: Integer): TRect;
begin
  Result := DesignerObjScreenRect(AObj, ALayouts, PAGE_LEFT, PAGE_TOP, MARGIN_L,
    AZoom, nil, ALookup.Owner, ALookup.Index);
end;

{ Scans a 32-bit bitmap and returns the bounding box of every non-white pixel.
  Returns an empty rectangle when the bitmap is entirely white. }
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

function BuildContentModel: TReportModel;
var
  Band: TReportBand;
  Txt : TReportTextObject;
begin
  Result := TReportModel.Create;

  Band := TReportBand.Create;
  Band.BandType := btPageHeader;
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

{ Renders the designer content layer into a fresh white bitmap scaled to AZoom
  and returns the ink bounding box. }
function RenderInkBounds(ADesigner: TVittixReportDesigner; AZoom: Integer): TRect;
var
  SW, SH: Integer;
  Bmp: TBitmap;
begin
  SW := MulDiv(ADesigner.Report.PageSettings.PageWidth, AZoom, 100);
  SH := MulDiv(ADesigner.Report.PageSettings.PageHeight, AZoom, 100);
  Assert.IsTrue((SW > 0) and (SH > 0), 'scaled page size must be positive');

  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf32bit;
    Bmp.SetSize(SW, SH);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.Brush.Style := bsSolid;
    Bmp.Canvas.FillRect(Rect(0, 0, SW, SH));

    Assert.IsTrue(ADesigner.RenderContentTo(Bmp.Canvas, Rect(0, 0, SW, SH)),
      'content layer must render at zoom ' + IntToStr(AZoom));

    Result := InkBounds(Bmp);
  finally
    Bmp.Free;
  end;
end;

{ ============================ transform tests ============================ }

procedure TDesignerZoomTransformTests.AdjacentObjects_StayAdjacent_AtAllZooms;
var
  Band: TReportBand;
  A, B: TReportTextObject;
  Lookup: TBandLookup;
  Layouts: TDesignerBandLayouts;
  RA, RB: TRect;
  Z: Integer;
begin
  Band := TReportBand.Create;
  try
    Band.BandType := btMasterData;
    Band.Height := 40;
    Layouts := SingleBandLayouts(Band);
    Lookup := TBandLookup.Create;
    try
      Lookup.Band := Band;
      A := TReportTextObject.Create;
      B := TReportTextObject.Create;
      try
        A.Bounds := Rect(12, 8, 200, 28);
        B.Bounds := Rect(200, 8, 340, 28);   // A.Right = B.Left (touching)
        for Z in ZOOMS do
        begin
          RA := ScreenRectOf(A, Layouts, Lookup, Z);
          RB := ScreenRectOf(B, Layouts, Lookup, Z);
          Assert.AreEqual(RA.Right, RB.Left,
            'abutting boundaries diverged at zoom ' + IntToStr(Z) + '%');
        end;
      finally
        A.Free;
        B.Free;
      end;
    finally
      Lookup.Free;
    end;
  finally
    Band.Free;
  end;
end;

procedure TDesignerZoomTransformTests.ObjectWidth_ScalesProportionally_AtAllZooms;
var
  Band: TReportBand;
  Obj : TReportTextObject;
  Lookup: TBandLookup;
  Layouts: TDesignerBandLayouts;
  R: TRect;
  W100, Wz: Integer;
  Z: Integer;
begin
  Band := TReportBand.Create;
  try
    Band.BandType := btMasterData;
    Band.Height := 40;
    Layouts := SingleBandLayouts(Band);
    Lookup := TBandLookup.Create;
    try
      Lookup.Band := Band;
      Obj := TReportTextObject.Create;
      try
        Obj.Bounds := Rect(12, 8, 200, 28);   // logical width 188
        R := ScreenRectOf(Obj, Layouts, Lookup, 100);
        W100 := R.Right - R.Left;

        for Z in ZOOMS do
        begin
          R := ScreenRectOf(Obj, Layouts, Lookup, Z);
          Wz := R.Right - R.Left;
          Assert.IsTrue(Abs(Wz - MulDiv(W100, Z, 100)) <= 2,
            Format('width at %d%% not proportional (got %d, expected ~%d)',
              [Z, Wz, MulDiv(W100, Z, 100)]));
        end;
      finally
        Obj.Free;
      end;
    finally
      Lookup.Free;
    end;
  finally
    Band.Free;
  end;
end;

procedure TDesignerZoomTransformTests.BandBodyOrigin_MatchesHeaderBottom_AtAllZooms;
var
  Band: TReportBand;
  Obj : TReportTextObject;
  Lookup: TBandLookup;
  Layouts: TDesignerBandLayouts;
  R: TRect;
  ExpectedTop: Integer;
  Z: Integer;
begin
  { A child at Bounds.Top = 0 sits exactly at the band body origin, which must
    equal the bottom of the (logical, scaled) band header.  This keeps header,
    band body and object origin under one transformation. }
  Band := TReportBand.Create;
  try
    Band.BandType := btMasterData;
    Band.Height := 40;
    Layouts := SingleBandLayouts(Band);
    Lookup := TBandLookup.Create;
    try
      Lookup.Band := Band;
      Obj := TReportTextObject.Create;
      try
        Obj.Bounds := Rect(12, 0, 200, 20);
        for Z in ZOOMS do
        begin
          R := ScreenRectOf(Obj, Layouts, Lookup, Z);
          ExpectedTop := PAGE_TOP + MulDiv(BAND_Y + BAND_HDR_H, Z, 100);
          Assert.AreEqual(ExpectedTop, R.Top,
            'band body origin != scaled header bottom at zoom ' + IntToStr(Z) + '%');
        end;
      finally
        Obj.Free;
      end;
    finally
      Lookup.Free;
    end;
  finally
    Band.Free;
  end;
end;

procedure TDesignerZoomTransformTests.ScreenToPage_RoundTrips_AtAllZooms;
const
  LOGICALS: array[0..4] of Integer = (0, 12, 200, 440, 553);
var
  Z, L: Integer;
  ScreenX: Integer;
  P: TPoint;
begin
  for Z in ZOOMS do
    for L in LOGICALS do
    begin
      ScreenX := PAGE_LEFT + MulDiv(MARGIN_L, Z, 100) + MulDiv(L, Z, 100);
      P := DesignerScreenToPage(Point(ScreenX, PAGE_TOP + 100),
        PAGE_LEFT, PAGE_TOP, MARGIN_L, Z);
      Assert.IsTrue(Abs(P.X - L) <= 1,
        Format('screen->logical round trip off at zoom %d%% (logical %d -> %d)',
          [Z, L, P.X]));
    end;
end;

{ ============================= content tests ============================= }

procedure TDesignerUniformContentTests.ContentLayer_IsLogicalSize_ZoomIndependent;
var
  D: TVittixReportDesigner;
  LogW, LogH: Integer;
begin
  D := TVittixReportDesigner.Create(nil);
  try
    D.LoadReport(BuildContentModel, True);
    LogW := D.Report.PageSettings.PageWidth;
    LogH := D.Report.PageSettings.PageHeight;

    Assert.IsTrue(D.UpdateContentMetafile, 'content layer must build');
    Assert.IsTrue(Abs(D.ContentMetafile.Width - LogW) <= 2,
      'content layer width must be the logical page width');
    Assert.IsTrue(Abs(D.ContentMetafile.Height - LogH) <= 2,
      'content layer height must be the logical page height');

    // Zoom must not change the logical content layer.
    D.Zoom := 400;
    Assert.IsTrue(D.UpdateContentMetafile, 'content layer must rebuild');
    Assert.IsTrue(Abs(D.ContentMetafile.Width - LogW) <= 2,
      'content layer width must be zoom-independent');
  finally
    D.Free;
  end;
end;

procedure TDesignerUniformContentTests.Content_TextInk_ScalesWithZoom;
var
  D: TVittixReportDesigner;
  Ink51, Ink100, Ink151: TRect;
  W51, W100, W151: Integer;
begin
  D := TVittixReportDesigner.Create(nil);
  try
    D.LoadReport(BuildContentModel, True);

    Ink51  := RenderInkBounds(D, 51);
    Ink100 := RenderInkBounds(D, 100);
    Ink151 := RenderInkBounds(D, 151);

    W51  := Ink51.Right  - Ink51.Left;
    W100 := Ink100.Right - Ink100.Left;
    W151 := Ink151.Right - Ink151.Left;

    Assert.IsTrue(W51 > 0,  'no text ink at 51%');
    Assert.IsTrue(W100 > 0, 'no text ink at 100%');
    Assert.IsTrue(W151 > 0, 'no text ink at 151%');

    // Content (font metrics) must scale with zoom: 51% and 151% ink widths
    // must track 0.51x and 1.51x of the 100% ink width.
    Assert.IsTrue(Abs(W51 * 100 - W100 * 51) <= W100 * 12,
      Format('text ink width not ~0.51x at 51%% (51%%=%d, 100%%=%d)', [W51, W100]));
    Assert.IsTrue(Abs(W151 * 100 - W100 * 151) <= W100 * 12,
      Format('text ink width not ~1.51x at 151%% (151%%=%d, 100%%=%d)', [W151, W100]));
  finally
    D.Free;
  end;
end;

end.
