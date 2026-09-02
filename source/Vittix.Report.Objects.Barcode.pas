unit Vittix.Report.Objects.Barcode;

interface

uses
  System.UITypes, System.Classes,
  System.Math,
  System.SysUtils,
  System.Variants,
  System.Types,
  System.Generics.Collections,
  Data.DB,
  Vcl.Graphics,
  Vittix.Report.Objects,
  Vittix.Report.Context,
  Vittix.Report.Expressions,
  Vittix.Report.Utils;

type
  TReportBarcodeSymbology = (bsLegacy, bsCode39, bsCode128, bsEAN13);

  TReportBarcodeObject = class(TReportObject)
  private
    FValue: string;
    FDataField: string;
    FSymbology: TReportBarcodeSymbology;
    FShowText: Boolean;
    FBarColor: TColor;
    FBackgroundColor: TColor;
  public
    constructor Create; override;
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    class function DisplayName: string; override;
  published
    property Value: string read FValue write FValue;
    property DataField: string read FDataField write FDataField;
    property Symbology: TReportBarcodeSymbology read FSymbology write FSymbology default bsLegacy;
    property ShowText: Boolean read FShowText write FShowText default True;
    property BarColor: TColor read FBarColor write FBarColor default clBlack;
    property BackgroundColor: TColor read FBackgroundColor write FBackgroundColor default clWhite;
  end;

{
  Element-pattern helpers shared by the canvas draw path and the engine's
  export-command capture path.

  An "element pattern" is a string of digit characters '1'..'4' giving the
  width of each successive barcode element in modules, alternating bar and
  space, always starting with a bar.  Empty result = input invalid for the
  symbology (nothing is drawn).
}

{ Encodes AValue as a sequence of Code128 symbol values (start code, data,
  checksum; stop symbol excluded).  Characters outside ASCII 32..126 are
  dropped, mirroring the Code39 normalization convention. }
function Code128EncodeValues(const AValue: string): TArray<Byte>;

{ Returns the EAN-13 check digit (0..9) for a 12-digit string, or -1 if the
  input is not exactly 12 digits. }
function EAN13CheckDigit(const ATwelveDigits: string): Integer;

{ Encodes AValue for ASymbology as an element pattern (see above).  Supports
  bsCode128 and bsEAN13; returns '' for other/invalid inputs. }
function EncodeBarcodeElements(ASymbology: TReportBarcodeSymbology;
  const AValue: string): string;

{ Total module count of an element pattern. }
function BarcodeElementTotalUnits(const AElements: string): Integer;

implementation

{$IFDEF DEBUG}
procedure DebugLogDataFieldIssue(AObj: TReportObject; const ADataField, AReason: string;
  ADataSet: TDataSet);
begin
  if not Assigned(AObj) then
    Exit;
  Vittix.Report.Utils.DebugLogDataFieldIssue(AObj.ClassName, AObj.Name, ADataField, AReason, ADataSet);
end;
{$ENDIF}

function ShouldPrintBarcodeObject(AObj: TReportObject;
  const Context: TExpressionContext): Boolean;
var
  PWResult: Variant;
begin
  Result := False;
  if not Assigned(AObj) then
    Exit;

  if not AObj.Visible then
    Exit;

  if Trim(AObj.PrintWhen) = '' then
  begin
    Result := True;
    Exit;
  end;

  try
    PWResult := TReportExpression.Evaluate(AObj.PrintWhen, Context);
  except
    Exit(False);
  end;

  if VarIsNull(PWResult) or VarIsEmpty(PWResult) then
    Exit(False);

  Result := ConditionVariantToBool(PWResult);
end;

function Code39Pattern(Ch: Char): string;
begin
  case Ch of
    '0': Result := 'nnnwwnwnn';
    '1': Result := 'wnnwnnnnw';
    '2': Result := 'nnwwnnnnw';
    '3': Result := 'wnwwnnnnn';
    '4': Result := 'nnnwwnnnw';
    '5': Result := 'wnnwwnnnn';
    '6': Result := 'nnwwwnnnn';
    '7': Result := 'nnnwnnwnw';
    '8': Result := 'wnnwnnwnn';
    '9': Result := 'nnwwnnwnn';
    'A': Result := 'wnnnnwnnw';
    'B': Result := 'nnwnnwnnw';
    'C': Result := 'wnwnnwnnn';
    'D': Result := 'nnnnwwnnw';
    'E': Result := 'wnnnwwnnn';
    'F': Result := 'nnwnwwnnn';
    'G': Result := 'nnnnnwwnw';
    'H': Result := 'wnnnnwwnn';
    'I': Result := 'nnwnnwwnn';
    'J': Result := 'nnnnwwwnn';
    'K': Result := 'wnnnnnnww';
    'L': Result := 'nnwnnnnww';
    'M': Result := 'wnwnnnnwn';
    'N': Result := 'nnnnwnnww';
    'O': Result := 'wnnnwnnwn';
    'P': Result := 'nnwnwnnwn';
    'Q': Result := 'nnnnnnwww';
    'R': Result := 'wnnnnnwwn';
    'S': Result := 'nnwnnnwwn';
    'T': Result := 'nnnnwnwwn';
    'U': Result := 'wwnnnnnnw';
    'V': Result := 'nwwnnnnnw';
    'W': Result := 'wwwnnnnnn';
    'X': Result := 'nwnnwnnnw';
    'Y': Result := 'wwnnwnnnn';
    'Z': Result := 'nwwnwnnnn';
    '-': Result := 'nwnnnnwnw';
    '.': Result := 'wwnnnnwnn';
    ' ': Result := 'nwwnnnwnn';
    '$': Result := 'nwnwnwnnn';
    '/': Result := 'nwnwnnnwn';
    '+': Result := 'nwnnnwnwn';
    '%': Result := 'nnnwnwnwn';
    '*': Result := 'nwnnwnwnn';
  else
    Result := '';
  end;
end;

function NormalizeCode39Text(const S: string): string;
var
  I: Integer;
  Ch: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    Ch := UpCase(S[I]);
    if (Ch <> '*') and (Code39Pattern(Ch) <> '') then
      Result := Result + Ch;
  end;
  Result := '*' + Result + '*';
end;

procedure DrawLegacyBarcode(C: TCanvas; const S: string; const R: TRect; BarTop,
  BarBottom, DrawW: Integer);
var
  I, B, XPos: Integer;
  Ch: Char;
begin
  XPos := R.Left + 4;
  for I := 1 to Length(S) do
  begin
    Ch := S[I];
    for B := 0 to 6 do
    begin
      if XPos >= R.Left + 4 + DrawW then
        Break;

      if ((Ord(Ch) shr B) and 1) = 1 then
      begin
        C.MoveTo(XPos, BarTop);
        C.LineTo(XPos, BarBottom);
      end;
      Inc(XPos);
    end;
    Inc(XPos);
    if XPos >= R.Left + 4 + DrawW then
      Break;
  end;
end;

procedure DrawCode39Barcode(C: TCanvas; const S: string; const R: TRect; BarTop,
  BarBottom, DrawW: Integer);
var
  Encoded, Pattern: string;
  I, J, UnitW, ModuleUnits, TotalUnits, XPos, W: Integer;
begin
  Encoded := NormalizeCode39Text(S);
  TotalUnits := 0;
  for I := 1 to Length(Encoded) do
  begin
    Pattern := Code39Pattern(Encoded[I]);
    for J := 1 to Length(Pattern) do
      if Pattern[J] = 'w' then
        Inc(TotalUnits, 3)
      else
        Inc(TotalUnits);
    if I < Length(Encoded) then
      Inc(TotalUnits);
  end;

  UnitW := Max(1, DrawW div Max(1, TotalUnits));
  XPos := R.Left + 4;
  for I := 1 to Length(Encoded) do
  begin
    Pattern := Code39Pattern(Encoded[I]);
    for J := 1 to Length(Pattern) do
    begin
      if Pattern[J] = 'w' then
        ModuleUnits := 3
      else
        ModuleUnits := 1;
      W := UnitW * ModuleUnits;
      if Odd(J) then
      begin
        C.Brush.Color := C.Pen.Color;
        C.FillRect(Rect(XPos, BarTop, Min(XPos + W, R.Left + 4 + DrawW), BarBottom));
      end;
      Inc(XPos, W);
      if XPos >= R.Left + 4 + DrawW then
        Exit;
    end;
      Inc(XPos, UnitW);
  end;
end;

{ ================= Code 128 ================= }

function Code128Pattern(AValue: Integer): string;
{
  Standard Code 128 module widths per symbol value (0..106), six elements
  each; 106 is the 7-element stop symbol.  Sum of widths = 11 (13 for stop).
}
begin
  case AValue of
    0:    Result := '212222';
    1:    Result := '222122';
    2:    Result := '222221';
    3:    Result := '121223';
    4:    Result := '121322';
    5:    Result := '131222';
    6:    Result := '122213';
    7:    Result := '122312';
    8:    Result := '132212';
    9:    Result := '221213';
    10:   Result := '221312';
    11:   Result := '231212';
    12:   Result := '112232';
    13:   Result := '122132';
    14:   Result := '122231';
    15:   Result := '113222';
    16:   Result := '123122';
    17:   Result := '123221';
    18:   Result := '223211';
    19:   Result := '221132';
    20:   Result := '221231';
    21:   Result := '213212';
    22:   Result := '223112';
    23:   Result := '312131';
    24:   Result := '311222';
    25:   Result := '321122';
    26:   Result := '321221';
    27:   Result := '312212';
    28:   Result := '322112';
    29:   Result := '322211';
    30:   Result := '212123';
    31:   Result := '212321';
    32:   Result := '232121';
    33:   Result := '111323';
    34:   Result := '131123';
    35:   Result := '131321';
    36:   Result := '112313';
    37:   Result := '132113';
    38:   Result := '132311';
    39:   Result := '211313';
    40:   Result := '231113';
    41:   Result := '231311';
    42:   Result := '112133';
    43:   Result := '112331';
    44:   Result := '132131';
    45:   Result := '113123';
    46:   Result := '113321';
    47:   Result := '133121';
    48:   Result := '313121';
    49:   Result := '211331';
    50:   Result := '231131';
    51:   Result := '213113';
    52:   Result := '213311';
    53:   Result := '213131';
    54:   Result := '311123';
    55:   Result := '311321';
    56:   Result := '331121';
    57:   Result := '312113';
    58:   Result := '312311';
    59:   Result := '332111';
    60:   Result := '314111';
    61:   Result := '221411';
    62:   Result := '431111';
    63:   Result := '111224';
    64:   Result := '111422';
    65:   Result := '121124';
    66:   Result := '121421';
    67:   Result := '141122';
    68:   Result := '141221';
    69:   Result := '112214';
    70:   Result := '112412';
    71:   Result := '122114';
    72:   Result := '122411';
    73:   Result := '142112';
    74:   Result := '142211';
    75:   Result := '241211';
    76:   Result := '221114';
    77:   Result := '413111';
    78:   Result := '241112';
    79:   Result := '134111';
    80:   Result := '111242';
    81:   Result := '121142';
    82:   Result := '121242';
    83:   Result := '114212';
    84:   Result := '124112';
    85:   Result := '124211';
    86:   Result := '411212';
    87:   Result := '421112';
    88:   Result := '421211';
    89:   Result := '212141';
    90:   Result := '214121';
    91:   Result := '412121';
    92:   Result := '111143';
    93:   Result := '111341';
    94:   Result := '131141';
    95:   Result := '114113';
    96:   Result := '114311';
    97:   Result := '411113';
    98:   Result := '411311';
    99:   Result := '113141';   { Code C }
    100:  Result := '114131';   { Code B }
    101:  Result := '311141';
    102:  Result := '411131';
    103:  Result := '211412';   { Start A }
    104:  Result := '211214';   { Start B }
    105:  Result := '211232';   { Start C }
    106:  Result := '2331112';  { Stop }
  else
    Result := '';
  end;
end;

function Code128EncodeValues(const AValue: string): TArray<Byte>;
var
  CleanText: string;
  SymbolValues: TList<Byte>;
  CharIdx, TextLen, RunLen, Pairs, PairIdx, PairValue, Checksum: Integer;
  InCodeC: Boolean;
begin
  // Keep only Code Set B supported characters (ASCII 32..126); other
  // characters are dropped, mirroring the Code39 normalization convention.
  CleanText := '';
  for CharIdx := 1 to Length(AValue) do
    if (Ord(AValue[CharIdx]) >= 32) and (Ord(AValue[CharIdx]) <= 126) then
      CleanText := CleanText + AValue[CharIdx];
  TextLen := Length(CleanText);

  SymbolValues := TList<Byte>.Create;
  try
    if TextLen = 0 then
    begin
      // Valid (if useless) empty symbol: Start B only; the checksum appended
      // below equals the start value.
      SymbolValues.Add(104);
    end
    else
    begin
      // Count the leading digit run to decide the start code set: a run of
      // at least 4 digits begins in Code C (digit-pair compaction).
      RunLen := 0;
      while (1 + RunLen <= TextLen) and
            (CleanText[1 + RunLen] >= '0') and (CleanText[1 + RunLen] <= '9') do
        RunLen := RunLen + 1;
      if RunLen >= 4 then
      begin
        SymbolValues.Add(105); // Start C
        InCodeC := True;
      end
      else
      begin
        SymbolValues.Add(104); // Start B
        InCodeC := False;
      end;

      CharIdx := 1;
      while CharIdx <= TextLen do
      begin
        // Count the digit run at CharIdx.
        RunLen := 0;
        while (CharIdx + RunLen <= TextLen) and
              (CleanText[CharIdx + RunLen] >= '0') and
              (CleanText[CharIdx + RunLen] <= '9') do
          RunLen := RunLen + 1;

        if InCodeC then
        begin
          if RunLen < 2 then
          begin
            // Not enough digits for a pair: switch back to Code B.
            SymbolValues.Add(100); // Code B
            InCodeC := False;
          end
          else
          begin
            Pairs := RunLen div 2;
            for PairIdx := 1 to Pairs do
            begin
              PairValue := (Ord(CleanText[CharIdx]) - 48) * 10 +
                           (Ord(CleanText[CharIdx + 1]) - 48);
              SymbolValues.Add(PairValue);
              CharIdx := CharIdx + 2;
            end;
            if (Pairs = 0) or (RunLen mod 2 = 1) then
            begin
              // A single digit (or an odd leftover) goes back to Code B.
              SymbolValues.Add(100); // Code B
              InCodeC := False;
            end;
          end;
        end
        else
        begin
          if RunLen >= 4 then
          begin
            SymbolValues.Add(99); // Code C
            InCodeC := True;
          end
          else
          begin
            SymbolValues.Add(Ord(CleanText[CharIdx]) - 32);
            CharIdx := CharIdx + 1;
          end;
        end;
      end;
    end;

    // Checksum: sum(start + i * value_i) mod 103.
    Checksum := 0;
    for CharIdx := 0 to SymbolValues.Count - 1 do
      if CharIdx = 0 then
        Checksum := Checksum + SymbolValues[0]
      else
        Checksum := Checksum + CharIdx * SymbolValues[CharIdx];
    SymbolValues.Add(Checksum mod 103);

    Result := SymbolValues.ToArray;
  finally
    SymbolValues.Free;
  end;
end;

{ ================= EAN-13 ================= }

function EAN13GCode(ADigit: Integer): string;
begin
  // Left "odd parity" (G) digit patterns, 7 modules each.
  case ADigit of
    0: Result := '0001101';
    1: Result := '0011001';
    2: Result := '0010011';
    3: Result := '0111101';
    4: Result := '0100011';
    5: Result := '0110001';
    6: Result := '0101111';
    7: Result := '0111011';
    8: Result := '0110111';
    9: Result := '0001011';
  else
    Result := '';
  end;
end;

function EAN13LCode(ADigit: Integer): string;
begin
  // Left "even parity" (L) digit patterns, 7 modules each.
  case ADigit of
    0: Result := '0100111';
    1: Result := '0110011';
    2: Result := '0111011';
    3: Result := '0100001';
    4: Result := '0011101';
    5: Result := '0111001';
    6: Result := '0000101';
    7: Result := '0010001';
    8: Result := '0001001';
    9: Result := '0010111';
  else
    Result := '';
  end;
end;

function EAN13RCode(ADigit: Integer): string;
begin
  // Right digit patterns, 7 modules each.
  case ADigit of
    0: Result := '1110010';
    1: Result := '1100110';
    2: Result := '1101100';
    3: Result := '1000010';
    4: Result := '1011100';
    5: Result := '1001110';
    6: Result := '1010000';
    7: Result := '1000100';
    8: Result := '1001000';
    9: Result := '1110100';
  else
    Result := '';
  end;
end;

function EAN13ParityPattern(AFirstDigit: Integer): string;
begin
  // Parity of the six left digits, selected by the first (implicit) digit.
  case AFirstDigit of
    0: Result := 'AAAAAA';
    1: Result := 'AABABB';
    2: Result := 'AABBAB';
    3: Result := 'AABBBA';
    4: Result := 'ABAABB';
    5: Result := 'ABBAAB';
    6: Result := 'ABBBAA';
    7: Result := 'ABABAB';
    8: Result := 'ABABBA';
    9: Result := 'ABBABA';
  else
    Result := '';
  end;
end;

function EAN13CheckDigit(const ATwelveDigits: string): Integer;
var
  I, Sum: Integer;
begin
  Result := -1;
  if Length(ATwelveDigits) <> 12 then
    Exit;
  Sum := 0;
  for I := 1 to 12 do
  begin
    if (ATwelveDigits[I] < '0') or (ATwelveDigits[I] > '9') then
      Exit;
    if Odd(I) then
      Inc(Sum, Ord(ATwelveDigits[I]) - 48)
    else
      Inc(Sum, 3 * (Ord(ATwelveDigits[I]) - 48));
  end;
  Result := (10 - (Sum mod 10)) mod 10;
end;

function BitsToElementPattern(const ABits: string): string;
var
  I, Run: Integer;
begin
  // Run-length encode a bit pattern ('0'/'1') into element widths 1..4,
  // starting with a bar (the input must start with '1').
  Result := '';
  Run := 0;
  for I := 1 to Length(ABits) do
  begin
    Inc(Run);
    if (I = Length(ABits)) or (ABits[I] <> ABits[I + 1]) then
    begin
      if Run > 4 then
        Exit(''); // EAN-13 never produces runs wider than 4 modules
      Result := Result + Chr(48 + Run);
      Run := 0;
    end;
  end;
end;

function EAN13EncodeElements(const AValue: string): string;
var
  Digits, Bits, Left: string;
  I, Check: Integer;
  Parity: string;
begin
  Result := '';
  Digits := '';
  for I := 1 to Length(AValue) do
    if (AValue[I] >= '0') and (AValue[I] <= '9') then
      Digits := Digits + AValue[I]
    else
      Exit; // non-digit input is invalid for EAN-13

  if Length(Digits) = 12 then
  begin
    Check := EAN13CheckDigit(Digits);
    Digits := Digits + Chr(48 + Check);
  end
  else if Length(Digits) = 13 then
  begin
    if EAN13CheckDigit(Copy(Digits, 1, 12)) <> Ord(Digits[13]) - 48 then
      Exit; // supplied checksum is wrong
  end
  else
    Exit; // wrong length

  Parity := EAN13ParityPattern(Ord(Digits[1]) - 48);
  if Parity = '' then
    Exit;

  Bits := '101'; // start guard
  for I := 2 to 7 do
    if Parity[I - 1] = 'A' then
      Bits := Bits + EAN13GCode(Ord(Digits[I]) - 48)
    else
      Bits := Bits + EAN13LCode(Ord(Digits[I]) - 48);
  Bits := Bits + '01010'; // center guard
  for I := 8 to 13 do
    Bits := Bits + EAN13RCode(Ord(Digits[I]) - 48);
  Bits := Bits + '101';   // end guard

  Result := BitsToElementPattern(Bits);
end;

{ ================= Shared element drawing ================= }

function BarcodeElementTotalUnits(const AElements: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(AElements) do
    Inc(Result, Ord(AElements[I]) - 48);
end;

function EncodeBarcodeElements(ASymbology: TReportBarcodeSymbology;
  const AValue: string): string;
var
  SymbolValues: TArray<Byte>;
  I: Integer;
begin
  case ASymbology of
    bsCode128:
      begin
        SymbolValues := Code128EncodeValues(AValue);
        Result := '';
        for I := 0 to High(SymbolValues) do
          Result := Result + Code128Pattern(SymbolValues[I]);
        Result := Result + Code128Pattern(106); // stop symbol
      end;
    bsEAN13:
      Result := EAN13EncodeElements(AValue);
  else
    Result := '';
  end;
end;

procedure DrawBarcodeElements(C: TCanvas; const AElements: string;
  const R: TRect; BarTop, BarBottom, DrawW: Integer);
var
  I, UnitW, TotalUnits, XPos, W: Integer;
begin
  TotalUnits := BarcodeElementTotalUnits(AElements);
  if TotalUnits <= 0 then
    Exit;

  UnitW := Max(1, DrawW div TotalUnits);
  XPos := R.Left + 4;
  for I := 1 to Length(AElements) do
  begin
    W := UnitW * (Ord(AElements[I]) - 48);
    if Odd(I) then
    begin
      C.Brush.Color := C.Pen.Color;
      C.FillRect(Rect(XPos, BarTop, Min(XPos + W, R.Left + 4 + DrawW), BarBottom));
    end;
    Inc(XPos, W);
    if XPos >= R.Left + 4 + DrawW then
      Exit;
  end;
end;

constructor TReportBarcodeObject.Create;
begin
  inherited;
  Bounds := Rect(10, 10, 220, 60);
  FValue := '1234567890';
  FSymbology := bsLegacy;
  FShowText := True;
  FBarColor := clBlack;
  FBackgroundColor := clWhite;
end;

procedure TReportBarcodeObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  R: TRect;
  TextRect: TRect;
  S: string;
  Fld: TField;
  BarTop, BarBottom, DrawW: Integer;
begin
  if not ShouldPrintBarcodeObject(Self, Context) then
    Exit;

  R := Bounds;
  S := FValue;
  if Trim(FDataField) <> '' then
  begin
{$IFDEF DEBUG}
    if not Assigned(Context.DataSet) and not Assigned(Context.UserDataSet) then
      DebugLogDataFieldIssue(Self, FDataField, 'dataset nil', Context.DataSet)
    else if not SourceActive(Context.DataSet, Context.UserDataSet) then
      DebugLogDataFieldIssue(Self, FDataField, 'dataset inactive', Context.DataSet);
{$ENDIF}
    Fld := nil;
    if Assigned(Context.UserDataSet) then
      S := SafeSourceFieldAsString(Context.DataSet, Context.UserDataSet, FDataField)
    else if TryGetField(Context.DataSet, FDataField, Fld) then
    begin
      try
        S := Fld.AsString; // preserve empty-string field values
      except
{$IFDEF DEBUG}
        DebugLogDataFieldIssue(Self, FDataField, 'field value conversion/read error', Context.DataSet);
{$ENDIF}
        // Keep fallback static value if provider raises.
      end;
    end;
{$IFDEF DEBUG}
    if SourceActive(Context.DataSet, Context.UserDataSet) and
       not Assigned(Context.UserDataSet) and (Fld = nil) then
      DebugLogDataFieldIssue(Self, FDataField, 'field missing', Context.DataSet);
{$ENDIF}
  end;

  C.Brush.Style := bsSolid;
  C.Brush.Color := FBackgroundColor;
  C.Pen.Style := psSolid;
  C.Pen.Color := clSilver;
  C.Rectangle(R);

  BarTop := R.Top + 4;
  if FShowText then
    BarBottom := R.Bottom - 16
  else
    BarBottom := R.Bottom - 4;

  if BarBottom <= BarTop then
    BarBottom := R.Bottom - 4;

  DrawW := Max(1, R.Right - R.Left - 8);

  C.Pen.Color := FBarColor;
  C.Pen.Width := 1;

  case FSymbology of
    bsCode39:
      DrawCode39Barcode(C, S, R, BarTop, BarBottom, DrawW);
    bsCode128, bsEAN13:
      DrawBarcodeElements(C, EncodeBarcodeElements(FSymbology, S),
        R, BarTop, BarBottom, DrawW);
  else
    DrawLegacyBarcode(C, S, R, BarTop, BarBottom, DrawW);
  end;

  if FShowText then
  begin
    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := clBlack;
    TextRect := Rect(R.Left + 2, R.Bottom - 14, R.Right - 2, R.Bottom - 2);
    C.TextRect(TextRect,
      S, [tfSingleLine, tfCenter, tfVerticalCenter, tfEndEllipsis]);
  end;
end;

class function TReportBarcodeObject.DisplayName: string;
begin
  Result := 'Barcode';
end;

initialization
  RegisterReportObject(TReportBarcodeObject);

end.
