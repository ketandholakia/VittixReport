unit Test.Vittix.Report.Objects.Barcode;

{
  Phase 4H-1: Code128 and EAN-13 barcode symbology tests.

  Deterministic encoding tests use known standard vectors; object-level tests
  exercise the TReportBarcodeObject -> Draw -> symbology dispatch path by
  drawing into a bitmap and asserting rendered output.
}

interface

uses
  DUnitX.TestFramework,
  Vcl.Graphics,
  Vittix.Report.Objects.Barcode;

type
  [TestFixture]
  TBarcodeTests = class
  private
    function DrawBarcode(ASymbology: TReportBarcodeSymbology;
      const AValue: string): TBitmap;
  public
    // Existing behavior (characterization)
    [Test] procedure Test_Code39_Characterization_DrawsBars;
    [Test] procedure Test_Legacy_Characterization_DrawsBars;
    // Code128 encoding
    [Test] procedure Test_Code128B_ABC;
    [Test] procedure Test_Code128C_NumericPairs;
    [Test] procedure Test_Code128_Mixed_AlphaThenLongDigitRun;
    [Test] procedure Test_Code128_OddDigitRun_Trailing;
    [Test] procedure Test_Code128_ShortDigitRun_StaysInB;
    [Test] procedure Test_Code128_UnsupportedCharsDropped;
    [Test] procedure Test_Code128_Empty_IsValidSymbol;
    [Test] procedure Test_Code128_Elements_StartWithBarAndAlternate;
    // EAN-13 encoding
    [Test] procedure Test_EAN13_CheckDigit_Vector;
    [Test] procedure Test_EAN13_12Digit_KnownVector_Elements;
    [Test] procedure Test_EAN13_13Digit_Valid;
    [Test] procedure Test_EAN13_InvalidChecksum_NoOutput;
    [Test] procedure Test_EAN13_InvalidLength_NoOutput;
    [Test] procedure Test_EAN13_NonNumeric_NoOutput;
    // Object integration
    [Test] procedure Test_Object_Draws_Code128;
    [Test] procedure Test_Object_Draws_EAN13;
    [Test] procedure Test_Object_InvalidEAN13_DrawsNothing;
    [Test] procedure Test_Object_Default_IsLegacy;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  Vittix.Report.Context,
  Vittix.Report.Objects;

{ Draws a barcode object into a fresh white bitmap using its real Draw path.
  Caller owns the returned bitmap. }
function TBarcodeTests.DrawBarcode(ASymbology: TReportBarcodeSymbology;
  const AValue: string): TBitmap;
var
  Obj: TReportBarcodeObject;
  Ctx: TExpressionContext;
begin
  Result := TBitmap.Create;
  try
    Result.SetSize(220, 60);
    Result.Canvas.Brush.Color := clWhite;
    Result.Canvas.FillRect(Rect(0, 0, 220, 60));
    Obj := TReportBarcodeObject.Create;
    try
      Obj.Bounds := Rect(10, 10, 220, 60);
      Obj.Value := AValue;
      Obj.Symbology := ASymbology;
      Obj.ShowText := False;
      Ctx := Default(TExpressionContext);
      Obj.Draw(Result.Canvas, Ctx);
    finally
      Obj.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function CountDarkPixels(ABmp: TBitmap): Integer;
var
  X, Y: Integer;
begin
  // Count only actual bar-colored pixels (default BarColor = clBlack);
  // the object's silver border rectangle must not count as bars.
  Result := 0;
  for Y := 14 to 40 do
    for X := 10 to 219 do
      if ABmp.Canvas.Pixels[X, Y] = clBlack then
        Inc(Result);
end;

{ --- Existing behavior (characterization) --- }

procedure TBarcodeTests.Test_Code39_Characterization_DrawsBars;
var
  Bmp: TBitmap;
begin
  // Code39 must keep drawing bars for its supported character set.
  Bmp := DrawBarcode(bsCode39, 'ABC123');
  try
    Assert.IsTrue(CountDarkPixels(Bmp) > 100);
  finally
    Bmp.Free;
  end;
end;

procedure TBarcodeTests.Test_Legacy_Characterization_DrawsBars;
var
  Bmp: TBitmap;
begin
  // The default legacy symbology must keep its current (visual) behavior.
  Bmp := DrawBarcode(bsLegacy, 'ABC123');
  try
    Assert.IsTrue(CountDarkPixels(Bmp) > 100);
  finally
    Bmp.Free;
  end;
end;

{ --- Code128 encoding --- }

procedure TBarcodeTests.Test_Code128B_ABC;
var
  V: TArray<Byte>;
begin
  // Start B, A=33, B=34, C=35; checksum = (104+33+2*34+3*35) mod 103 = 1.
  V := Code128EncodeValues('ABC');
  Assert.IsTrue(Length(V) = 5, Format('len=%d', [Length(V)]));
  Assert.IsTrue(V[0] = 104, Format('V0=%d', [V[0]]));
  Assert.IsTrue(V[1] = 33,  Format('V1=%d', [V[1]]));
  Assert.IsTrue(V[2] = 34,  Format('V2=%d', [V[2]]));
  Assert.IsTrue(V[3] = 35,  Format('V3=%d', [V[3]]));
  Assert.IsTrue(V[4] = 1,   Format('V4=%d', [V[4]])); // checksum
end;

procedure TBarcodeTests.Test_Code128C_NumericPairs;
var
  V: TArray<Byte>;
begin
  // 6 digits -> Start C, pairs 12/34/56 (all pairs consumed);
  // checksum = (105 + 12 + 2*34 + 3*56) mod 103 = 44.
  V := Code128EncodeValues('123456');
  Assert.AreEqual(5, Length(V));
  Assert.AreEqual(Integer(105), Integer(V[0]));
  Assert.AreEqual(Integer(12),  Integer(V[1]));
  Assert.AreEqual(Integer(34),  Integer(V[2]));
  Assert.AreEqual(Integer(56),  Integer(V[3]));
  Assert.AreEqual(Integer(44),  Integer(V[4]));
end;

procedure TBarcodeTests.Test_Code128_Mixed_AlphaThenLongDigitRun;
var
  V: TArray<Byte>;
begin
  // B('AB') C(12 34 56 78) B('CD'):
  // checksum = (104 + 33 + 2*34 + 3*99 + 4*12 + 5*34 + 6*56 + 7*78
  //             + 8*100 + 9*35 + 10*36) mod 103 = 90.
  V := Code128EncodeValues('AB12345678CD');
  Assert.AreEqual(12, Length(V));
  Assert.AreEqual(Integer(104), Integer(V[0]));
  Assert.AreEqual(Integer(99),  Integer(V[3]));
  Assert.AreEqual(Integer(12),  Integer(V[4]));
  Assert.AreEqual(Integer(78),  Integer(V[7]));
  Assert.AreEqual(Integer(100), Integer(V[8]));
  Assert.AreEqual(Integer(90),  Integer(V[11]));
end;

procedure TBarcodeTests.Test_Code128_OddDigitRun_Trailing;
var
  V: TArray<Byte>;
begin
  // '12345' -> Start C, 12, 34, Code B, '5'(21);
  // checksum = (105 + 12 + 2*34 + 3*100 + 4*21) mod 103 = 54.
  V := Code128EncodeValues('12345');
  Assert.AreEqual(6, Length(V));
  Assert.AreEqual(Integer(105), Integer(V[0]));
  Assert.AreEqual(Integer(12),  Integer(V[1]));
  Assert.AreEqual(Integer(34),  Integer(V[2]));
  Assert.AreEqual(Integer(100), Integer(V[3]));
  Assert.AreEqual(Integer(21),  Integer(V[4]));
  Assert.AreEqual(Integer(54),  Integer(V[5]));
end;

procedure TBarcodeTests.Test_Code128_ShortDigitRun_StaysInB;
var
  V: TArray<Byte>;
begin
  // Two digits: no Code C switch.
  // checksum = (104 + 17 + 2*18) mod 103 = 54.
  V := Code128EncodeValues('12');
  Assert.AreEqual(4, Length(V));
  Assert.AreEqual(Integer(104), Integer(V[0]));
  Assert.AreEqual(Integer(17),  Integer(V[1]));
  Assert.AreEqual(Integer(18),  Integer(V[2]));
  Assert.AreEqual(Integer(54),  Integer(V[3]));
end;

procedure TBarcodeTests.Test_Code128_UnsupportedCharsDropped;
var
  V: TArray<Byte>;
begin
  // 'é' (outside ASCII 32..126) is dropped; 'a'=65, 'b'=66;
  // checksum = (104 + 65 + 2*66) mod 103 = 95.
  V := Code128EncodeValues('aéb');
  Assert.AreEqual(4, Length(V));
  Assert.AreEqual(Integer(65), Integer(V[1]));
  Assert.AreEqual(Integer(66), Integer(V[2]));
  Assert.AreEqual(Integer(95), Integer(V[3]));
end;

procedure TBarcodeTests.Test_Code128_Empty_IsValidSymbol;
var
  V: TArray<Byte>;
begin
  // Empty input yields a valid Start B symbol; checksum = 104 mod 103 = 1.
  V := Code128EncodeValues('');
  Assert.IsTrue(Length(V) = 2, Format('len=%d', [Length(V)]));
  Assert.IsTrue(V[0] = 104, Format('V0=%d', [V[0]]));
  Assert.IsTrue(V[1] = 1,   Format('V1=%d', [V[1]]));
end;

procedure TBarcodeTests.Test_Code128_Elements_StartWithBarAndAlternate;
var
  Elements: string;
  I, Total: Integer;
begin
  // Full element pattern for '123456' (Start C 12 34 56 checksum 44 stop):
  // 211232 + 112232 + 131123 + 331121 + 132131 + 2331112.
  Elements := EncodeBarcodeElements(bsCode128, '123456');
  Assert.AreEqual('2112321122321311233311211321312331112', Elements);
  // Structural invariants: starts with a bar, widths 1..4, even element count
  // (bar/space alternation ends with the stop's final bar -> odd count
  // including it; here just verify character domain).
  Assert.IsTrue(Length(Elements) > 0);
  Assert.IsTrue(Odd(Length(Elements))); // bars at odd positions
  Total := 0;
  for I := 1 to Length(Elements) do
  begin
    Assert.IsTrue((Elements[I] >= '1') and (Elements[I] <= '4'));
    Inc(Total, Ord(Elements[I]) - 48);
  end;
  Assert.AreEqual(Total, BarcodeElementTotalUnits(Elements));
end;

{ --- EAN-13 encoding --- }

procedure TBarcodeTests.Test_EAN13_CheckDigit_Vector;
begin
  // Known EAN-13 vector 4006381333931: check digit is 1.
  Assert.AreEqual(1, EAN13CheckDigit('400638133393'));
end;

procedure TBarcodeTests.Test_EAN13_12Digit_KnownVector_Elements;
begin
  // 400638133393 + computed check digit 1.  First digit 4 -> parity ABAABB.
  // Left:  0(G) 0(L) 6(G) 3(G) 8(L) 1(L);  Right: 3 3 3 9 3 1 (R codes).
  // The element pattern run-length-encodes the WHOLE symbol, so bars merge
  // across guard/digit boundaries (e.g. the start guard's closing bar merges
  // with the first data bar).  Expected widths below decode to:
  //   101 | 0001101 0100111 0101111 0111101 0001001 0110011 |
  //   01010 | 1000010 1000010 1000010 1110100 1000010 1100110 | 101
  Assert.AreEqual(
    '11132111123111414113121122211111141114111411311214112221111',
    EncodeBarcodeElements(bsEAN13, '400638133393'));
end;

procedure TBarcodeTests.Test_EAN13_13Digit_Valid;
begin
  // Supplying the full 13 digits (valid checksum) gives the same symbol.
  Assert.AreEqual(
    EncodeBarcodeElements(bsEAN13, '400638133393'),
    EncodeBarcodeElements(bsEAN13, '4006381333931'));
  Assert.AreNotEqual('', EncodeBarcodeElements(bsEAN13, '4006381333931'));
end;

procedure TBarcodeTests.Test_EAN13_InvalidChecksum_NoOutput;
begin
  Assert.AreEqual('', EncodeBarcodeElements(bsEAN13, '4006381333932'));
end;

procedure TBarcodeTests.Test_EAN13_InvalidLength_NoOutput;
begin
  Assert.AreEqual('', EncodeBarcodeElements(bsEAN13, '40063'));
  Assert.AreEqual('', EncodeBarcodeElements(bsEAN13, '40063813339311'));
end;

procedure TBarcodeTests.Test_EAN13_NonNumeric_NoOutput;
begin
  Assert.AreEqual('', EncodeBarcodeElements(bsEAN13, '40063813339A'));
end;

{ --- Object integration --- }

procedure TBarcodeTests.Test_Object_Draws_Code128;
var
  Bmp: TBitmap;
begin
  Bmp := DrawBarcode(bsCode128, '123456');
  try
    Assert.IsTrue(CountDarkPixels(Bmp) > 100,
      'Code128 symbology produced no bars through TReportBarcodeObject.Draw');
  finally
    Bmp.Free;
  end;
end;

procedure TBarcodeTests.Test_Object_Draws_EAN13;
var
  Bmp: TBitmap;
begin
  Bmp := DrawBarcode(bsEAN13, '4006381333931');
  try
    Assert.IsTrue(CountDarkPixels(Bmp) > 100,
      'EAN13 symbology produced no bars through TReportBarcodeObject.Draw');
  finally
    Bmp.Free;
  end;
end;

procedure TBarcodeTests.Test_Object_InvalidEAN13_DrawsNothing;
var
  Bmp: TBitmap;
begin
  // Invalid checksum -> no bars at all (deterministic no-output behavior).
  Bmp := DrawBarcode(bsEAN13, '4006381333932');
  try
    Assert.AreEqual(0, CountDarkPixels(Bmp));
  finally
    Bmp.Free;
  end;
end;

procedure TBarcodeTests.Test_Object_Default_IsLegacy;
var
  Obj: TReportBarcodeObject;
begin
  Obj := TReportBarcodeObject.Create;
  try
    Assert.IsTrue(Obj.Symbology = bsLegacy);
  finally
    Obj.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBarcodeTests);

end.
