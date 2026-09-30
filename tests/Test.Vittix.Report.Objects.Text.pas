unit Test.Vittix.Report.Objects.Text;

{
  Test.Vittix.Report.Objects.Text
  ===============================
  DP-17 / M-7: TReportTextObject's wrapped path draws with DrawText WITHOUT
  DT_NOPREFIX, so GDI ampersand-prefix processing swallowed '&' from data
  ("AT&T" rendered as "ATT" with the next character underlined). The
  single-line path uses TextOut and always drew literals - the two paths
  disagreed. DT_NOPREFIX makes DrawText literal too.
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
  TTestTextObjectAmpersand = class
  private
    procedure RenderText(const AText: string; out ABmp: TBitmap);
    class function RightmostDarkX(ABmp: TBitmap): Integer;
  public
    [Test]
    procedure Test_WrappedText_Ampersand_IsLiteral;
  end;

implementation

{ TTestTextObjectAmpersand }

procedure TTestTextObjectAmpersand.RenderText(const AText: string;
  out ABmp: TBitmap);
var
  Obj: TReportTextObject;
  Ctx: TExpressionContext;
begin
  ABmp := TBitmap.Create;
  try
    ABmp.PixelFormat := pf32bit;
    ABmp.SetSize(200, 60);
    ABmp.Canvas.Brush.Color := clWhite;
    ABmp.Canvas.FillRect(Rect(0, 0, ABmp.Width, ABmp.Height));

    Obj := TReportTextObject.Create;
    try
      Obj.Text := AText;
      Obj.WordWrap := True;   // wrapped path = DrawText (the DT_NOPREFIX site)
      Obj.Transparent := True;
      Obj.BorderVisible := False;
      Obj.Font.Name := 'Arial';
      Obj.Font.Size := 14;
      Obj.Bounds := Rect(10, 10, 190, 50);

      Ctx := Default(TExpressionContext);
      Obj.Draw(ABmp.Canvas, Ctx);
    finally
      Obj.Free;
    end;
  except
    ABmp.Free;
    raise;
  end;
end;

class function TTestTextObjectAmpersand.RightmostDarkX(ABmp: TBitmap): Integer;
var
  X, Y: Integer;
  Row: PByteArray;
  B, G, R: Byte;
begin
  // Rightmost text extent. GDI prefix processing does not change the text
  // WIDTH (the swallowed '&' leaves only an underline), so the extent is
  // the discriminator: 'A&TX' must be wider than 'ATX' when '&' is literal.
  Result := -1;
  for Y := 0 to ABmp.Height - 1 do
  begin
    Row := ABmp.ScanLine[Y];
    for X := ABmp.Width - 1 downto 0 do
    begin
      B := Row[X * 4];
      G := Row[X * 4 + 1];
      R := Row[X * 4 + 2];
      if (R <= 100) and (G <= 100) and (B <= 100) then
        if X > Result then
        begin
          Result := X;
          Break;
        end;
    end;
  end;
end;

procedure TTestTextObjectAmpersand.Test_WrappedText_Ampersand_IsLiteral;
var
  BmpAmp, BmpPlain: TBitmap;
  ExtentAmp, ExtentPlain: Integer;
begin
  // Pre-fix: DrawText's prefix processing swallowed the '&' in the wrapped
  // path, so 'A&TX' drew 'ATX' (plus an underline) with the same text
  // extent as plain 'ATX'. With DT_NOPREFIX the ampersand is a literal
  // glyph and 'A&TX' is measurably wider.
  RenderText('A&TX', BmpAmp);
  try
    RenderText('ATX', BmpPlain);
    try
      ExtentAmp := RightmostDarkX(BmpAmp);
      ExtentPlain := RightmostDarkX(BmpPlain);
      Assert.IsTrue(ExtentAmp > ExtentPlain,
        Format('the ampersand in wrapped text must render literally: ' +
          'extent of ''A&TX'' (%d) must exceed extent of ''ATX'' (%d); ' +
          'equal extents mean DrawText prefix processing is still eating it',
          [ExtentAmp, ExtentPlain]));
    finally
      BmpPlain.Free;
    end;
  finally
    BmpAmp.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestTextObjectAmpersand);

end.
