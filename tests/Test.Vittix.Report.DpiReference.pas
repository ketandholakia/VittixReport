unit Test.Vittix.Report.DpiReference;

{
  DP-14 / H-4: 96-DPI measurement correctness - guard tests.

  The report geometry model is defined in 96-dpi pixels (see
  Vittix.Report.PageSettings), so text measurement must not follow the DPI of
  whichever process/canvas happens to render the report.  On a 125% display
  a DPI-aware process realizes 10pt text at -17px per em instead of the
  -13px the model assumes, so wrapping, CanGrow heights and the VectorPDF
  measurement all drift with the display scale (OQ-1 probe: the 05 memo
  wraps 2 -> 3 -> 4 lines at 100/125/150%).

  The console runner is DPI-unaware, so the scaled environment is simulated
  deterministically: an explicit 120 ppi on the canvas font is exactly the
  state a DPI-aware process reaches through its screen font defaults, and
  VCL realizes fonts against the target canvas DPI on Assign.

  RED first: the measure paths do not yet force the 96-dpi reference, so a
  120-ppi canvas yields different widths/heights (e.g. TextWidth 417 vs 330
  for the sample line) and the memo/text MeasuredBottom values diverge.
}

interface

uses
  System.Types,
  Vcl.Graphics,
  DUnitX.TestFramework,
  Vittix.Report.Context,
  Vittix.Report.Objects,
  Vittix.Report.Utils;

type
  [TestFixture]
  TDpiReferenceTests = class
  private
    FBitmap: TBitmap;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure NormalizeFont_ReRealizesAt96Dpi;

    [Test]
    procedure Memo_MeasuredBottom_IdenticalOn120And96PpiCanvas;

    [Test]
    procedure Text_MeasuredBottom_IdenticalOn120And96PpiCanvas;
  end;

implementation

procedure TDpiReferenceTests.Setup;
begin
  FBitmap := TBitmap.Create;
  FBitmap.SetSize(400, 400);
end;

procedure TDpiReferenceTests.TearDown;
begin
  FBitmap.Free;
end;

procedure TDpiReferenceTests.NormalizeFont_ReRealizesAt96Dpi;
var
  F: TFont;
begin
  F := TFont.Create;
  try
    F.Name := 'Arial';
    F.PixelsPerInch := 120;
    F.Size := 10;
    Assert.AreEqual(-17, F.Height,
      'precondition: 10pt realizes at -17px on a 120 ppi font');

    NormalizeFontToReferenceDPI(F);

    Assert.AreEqual(VITTIX_REFERENCE_DPI, F.PixelsPerInch,
      'ppi must be re-realized at the reference');
    Assert.AreEqual(10, F.Size, 'point size must be preserved');
    Assert.AreEqual(-13, F.Height,
      '10pt must realize at -13px at the 96-dpi reference');
  finally
    F.Free;
  end;
end;

procedure TDpiReferenceTests.Memo_MeasuredBottom_IdenticalOn120And96PpiCanvas;
var
  Memo: TReportMemoObject;
  Ctx: TExpressionContext;
  H96: Integer;
  H120: Integer;
begin
  Memo := TReportMemoObject.Create;
  try
    Memo.Bounds := Rect(10, 10, 330, 60);
    Memo.Font.Name := 'Arial';
    Memo.Font.Size := 10;
    Memo.MinHeight := 0;
    Memo.Text := 'The quick brown fox jumps over the lazy dog. ' +
      'The quick brown fox jumps over the lazy dog again and again.';

    Ctx := Default(TExpressionContext);

    H96 := Memo.MeasuredBottom(FBitmap.Canvas, Ctx);

    FBitmap.Canvas.Font.PixelsPerInch := 120;
    H120 := Memo.MeasuredBottom(FBitmap.Canvas, Ctx);

    Assert.AreEqual(H96, H120,
      'memo MeasuredBottom must not follow the canvas realization DPI');
  finally
    Memo.Free;
  end;
end;

procedure TDpiReferenceTests.Text_MeasuredBottom_IdenticalOn120And96PpiCanvas;
var
  Text: TReportTextObject;
  Ctx: TExpressionContext;
  H96: Integer;
  H120: Integer;
begin
  Text := TReportTextObject.Create;
  try
    Text.Bounds := Rect(10, 10, 330, 40);
    Text.AutoSize := True;
    Text.WordWrap := True;
    Text.Font.Name := 'Arial';
    Text.Font.Size := 10;
    Text.Text := 'The quick brown fox jumps over the lazy dog and keeps ' +
      'running through the wrapping test.';

    Ctx := Default(TExpressionContext);

    H96 := Text.MeasuredBottom(FBitmap.Canvas, Ctx);

    FBitmap.Canvas.Font.PixelsPerInch := 120;
    H120 := Text.MeasuredBottom(FBitmap.Canvas, Ctx);

    Assert.AreEqual(H96, H120,
      'text MeasuredBottom must not follow the canvas realization DPI');
  finally
    Text.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDpiReferenceTests);

end.
