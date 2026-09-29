unit Test.Vittix.Report.Objects.Memo;

{
  Test.Vittix.Report.Objects.Memo
  ===============================
  Pixel-level golden tests for TReportMemoObject segment styling (DP-10/H-3).

  AddLineSegment stored only Text/Style/Width - the zero-initialized segment
  record then drew every run with Color=0 (clBlack) and the base font,
  discarding HTML <font color|face|size> runs AND the memo's own font color
  in preview and export. These tests render a memo onto a bitmap and assert
  the actual pixel colors, so they cover the full pipeline
  (ParseMemoRuns -> BuildMemoLines -> AddLineSegment -> Draw).
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  Vittix.Report.Context,
  Vittix.Report.Objects;

type
  [TestFixture]
  TTestMemoSegmentStyling = class
  private
    { Renders AText as an AllowHTML memo onto a white 32-bit bitmap and
      returns it; the CALLER frees the bitmap. }
    procedure RenderMemoText(const AText: string; ABaseColor: TColor;
      out ABmp: TBitmap);
    class function ScanForRed(ABmp: TBitmap): Boolean;
    class function ScanForBlue(ABmp: TBitmap): Boolean;
    class function ScanForDark(ABmp: TBitmap): Boolean;
  public
    [Test]
    procedure Test_HTMLColoredRun_DrawsInSpecifiedColor;
    [Test]
    procedure Test_PlainRun_UsesBaseColor_AfterColoredRun;
  end;

implementation

{ TTestMemoSegmentStyling }

procedure TTestMemoSegmentStyling.RenderMemoText(const AText: string;
  ABaseColor: TColor; out ABmp: TBitmap);
var
  Memo: TReportMemoObject;
  Ctx: TExpressionContext;
begin
  ABmp := TBitmap.Create;
  try
    ABmp.PixelFormat := pf32bit;
    ABmp.SetSize(320, 100);
    ABmp.Canvas.Brush.Color := clWhite;
    ABmp.Canvas.FillRect(Rect(0, 0, ABmp.Width, ABmp.Height));

    Memo := TReportMemoObject.Create;
    try
      Memo.Text := AText;
      Memo.AllowHTML := True;
      Memo.WordWrap := False;
      Memo.Transparent := True;
      Memo.BorderVisible := False;
      Memo.Font.Name := 'Arial';
      Memo.Font.Size := 16;
      Memo.Font.Color := ABaseColor;
      Memo.Bounds := Rect(10, 10, 310, 90);

      Ctx := Default(TExpressionContext);
      Memo.Draw(ABmp.Canvas, Ctx);
    finally
      Memo.Free;
    end;
  except
    ABmp.Free;
    raise;
  end;
end;

class function TTestMemoSegmentStyling.ScanForRed(ABmp: TBitmap): Boolean;
var
  X, Y: Integer;
  Row: PByteArray;
  R, G, B: Byte;
begin
  // pf32bit scanlines are B,G,R,pad little-endian on Windows.
  Result := False;
  for Y := 0 to ABmp.Height - 1 do
  begin
    Row := ABmp.ScanLine[Y];
    for X := 0 to ABmp.Width - 1 do
    begin
      B := Row[X * 4];
      G := Row[X * 4 + 1];
      R := Row[X * 4 + 2];
      if (R >= 200) and (G <= 120) and (B <= 120) then
        Exit(True);
    end;
  end;
end;

class function TTestMemoSegmentStyling.ScanForBlue(ABmp: TBitmap): Boolean;
var
  X, Y: Integer;
  Row: PByteArray;
  R, G, B: Byte;
begin
  Result := False;
  for Y := 0 to ABmp.Height - 1 do
  begin
    Row := ABmp.ScanLine[Y];
    for X := 0 to ABmp.Width - 1 do
    begin
      B := Row[X * 4];
      G := Row[X * 4 + 1];
      R := Row[X * 4 + 2];
      if (B >= 150) and (R <= 100) and (G <= 100) then
        Exit(True);
    end;
  end;
end;

class function TTestMemoSegmentStyling.ScanForDark(ABmp: TBitmap): Boolean;
var
  X, Y: Integer;
  Row: PByteArray;
  R, G, B: Byte;
begin
  Result := False;
  for Y := 0 to ABmp.Height - 1 do
  begin
    Row := ABmp.ScanLine[Y];
    for X := 0 to ABmp.Width - 1 do
    begin
      B := Row[X * 4];
      G := Row[X * 4 + 1];
      R := Row[X * 4 + 2];
      if (R <= 80) and (G <= 80) and (B <= 80) then
        Exit(True);
    end;
  end;
end;

procedure TTestMemoSegmentStyling.Test_HTMLColoredRun_DrawsInSpecifiedColor;
var
  Bmp: TBitmap;
begin
  RenderMemoText('<font color="#FF0000">RR</font>GG', clBlack, Bmp);
  try
    Assert.IsTrue(ScanForRed(Bmp),
      'HTML <font color="#FF0000"> run must draw red (pre-fix it drew black: ' +
      'the segment record never stored the run color)');
    Assert.IsTrue(ScanForDark(Bmp),
      'the plain run after the colored one must still draw');
  finally
    Bmp.Free;
  end;
end;

procedure TTestMemoSegmentStyling.Test_PlainRun_UsesBaseColor_AfterColoredRun;
var
  Bmp: TBitmap;
begin
  // The memo's own font color (blue here) flows into ParseMemoRuns as the
  // base color of plain runs. Pre-fix the plain segment's zero-initialized
  // Color (= clBlack) won the '<> clNone' check in Draw, so even the memo's
  // base color was lost as soon as one colored run existed.
  RenderMemoText('<font color="#FF0000">R</font>G', clBlue, Bmp);
  try
    Assert.IsTrue(ScanForRed(Bmp), 'colored run must draw red');
    Assert.IsTrue(ScanForBlue(Bmp),
      'plain run must use the memo base font color (blue), not zero-init black');
  finally
    Bmp.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestMemoSegmentStyling);

end.
