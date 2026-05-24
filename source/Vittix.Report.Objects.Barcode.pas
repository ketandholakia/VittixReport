unit Vittix.Report.Objects.Barcode;

interface

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  System.Variants,
  System.Types,
  Data.DB,
  Vcl.Graphics,
  Vittix.Report.Objects,
  Vittix.Report.Context,
  Vittix.Report.Expressions,
  Vittix.Report.Utils;

type
  TReportBarcodeSymbology = (bsLegacy, bsCode39);

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
    if not Assigned(Context.DataSet) then
      DebugLogDataFieldIssue(Self, FDataField, 'dataset nil', Context.DataSet)
    else if not Context.DataSet.Active then
      DebugLogDataFieldIssue(Self, FDataField, 'dataset inactive', Context.DataSet);
{$ENDIF}
    Fld := nil;
    if TryGetField(Context.DataSet, FDataField, Fld) then
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
    if Assigned(Context.DataSet) and Context.DataSet.Active and (Fld = nil) then
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

  if FSymbology = bsCode39 then
    DrawCode39Barcode(C, S, R, BarTop, BarBottom, DrawW)
  else
    DrawLegacyBarcode(C, S, R, BarTop, BarBottom, DrawW);

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
