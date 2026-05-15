unit Vittix.Report.Objects.Barcode;

interface

uses
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
  TReportBarcodeObject = class(TReportObject)
  private
    FValue: string;
    FDataField: string;
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
    property ShowText: Boolean read FShowText write FShowText default True;
    property BarColor: TColor read FBarColor write FBarColor default clBlack;
    property BackgroundColor: TColor read FBackgroundColor write FBackgroundColor default clWhite;
  end;

implementation

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

  try
    Result := Boolean(VarAsType(PWResult, varBoolean));
  except
    Result := VarToStr(PWResult) <> '';
  end;
end;

constructor TReportBarcodeObject.Create;
begin
  inherited;
  Bounds := Rect(10, 10, 220, 60);
  FValue := '1234567890';
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
  i, b, XPos, BarTop, BarBottom, DrawW: Integer;
  Ch: Char;
begin
  if not ShouldPrintBarcodeObject(Self, Context) then
    Exit;

  R := Bounds;
  S := FValue;
  if Trim(FDataField) <> '' then
  begin
    Fld := nil;
    if TryGetField(Context.DataSet, FDataField, Fld) then
    begin
      try
        S := Fld.AsString; // preserve empty-string field values
      except
        // Keep fallback static value if provider raises.
      end;
    end;
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

  XPos := R.Left + 4;
  DrawW := Max(1, R.Right - R.Left - 8);

  C.Pen.Color := FBarColor;
  C.Pen.Width := 1;

  for i := 1 to Length(S) do
  begin
    Ch := S[i];
    for b := 0 to 6 do
    begin
      if XPos >= R.Left + 4 + DrawW then
        Break;

      if ((Ord(Ch) shr b) and 1) = 1 then
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
