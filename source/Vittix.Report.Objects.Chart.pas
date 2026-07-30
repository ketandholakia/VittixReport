unit Vittix.Report.Objects.Chart;

interface

uses
  System.Classes, System.SysUtils, System.Types, System.Math, Vcl.Graphics,
  Data.DB, System.Generics.Collections,
  Vittix.Report.Context,
  Vittix.Report.Objects,
  Vittix.Report.Expressions;

type
  TChartType = (ctPie, ctBar, ctLine);

  TChartDataPoint = record
    LabelText: string;
    Value: Double;
    Color: TColor;
  end;

  TReportChartObject = class(TReportObject)
  private
    FChartType: TChartType;
    FDataSetName: string;
    FDataFieldLabel: string;
    FDataFieldValue: string;
    FTitle: string;
    FShowLegend: Boolean;
    FDataPoints: TList<TChartDataPoint>;
    FDataPrepared: Boolean;
    FDefaultColors: TArray<TColor>;

    procedure InitializeColors;
    procedure PrepareData(const Context: TExpressionContext);
    function ResolveDataSet(const Context: TExpressionContext): TDataSet;
    
    procedure DrawPie(C: TCanvas; const R: TRect);
    procedure DrawBar(C: TCanvas; const R: TRect);
    procedure DrawLine(C: TCanvas; const R: TRect);
    procedure DrawLegend(C: TCanvas; const R: TRect; out ChartRect: TRect);
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    class function DisplayName: string; override;

  published
    property ChartType: TChartType read FChartType write FChartType default ctPie;
    property DataSetName: string read FDataSetName write FDataSetName;
    property DataFieldLabel: string read FDataFieldLabel write FDataFieldLabel;
    property DataFieldValue: string read FDataFieldValue write FDataFieldValue;
    property Title: string read FTitle write FTitle;
    property ShowLegend: Boolean read FShowLegend write FShowLegend default True;
  end;

implementation

{ TReportChartObject }

constructor TReportChartObject.Create;
begin
  inherited;
  FChartType := ctPie;
  FShowLegend := True;
  FDataPoints := TList<TChartDataPoint>.Create;
  InitializeColors;
end;

destructor TReportChartObject.Destroy;
begin
  FDataPoints.Free;
  inherited;
end;

procedure TReportChartObject.InitializeColors;
begin

  
  SetLength(FDefaultColors, 12);
  FDefaultColors[0] := clRed; FDefaultColors[1] := clBlue; FDefaultColors[2] := clGreen;
  FDefaultColors[3] := clYellow; FDefaultColors[4] := clFuchsia; FDefaultColors[5] := clAqua;
  FDefaultColors[6] := clMaroon; FDefaultColors[7] := clNavy; FDefaultColors[8] := clOlive;
  FDefaultColors[9] := clPurple; FDefaultColors[10] := clTeal; FDefaultColors[11] := clGray;


end;

function TReportChartObject.ResolveDataSet(const Context: TExpressionContext): TDataSet;
begin
  Result := nil;
  if FDataSetName <> '' then
  begin
    if Assigned(Context.Hooks) then
      Result := Context.Hooks.GetNamedDataSet(FDataSetName);
  end;
  if not Assigned(Result) then
    Result := Context.DataSet;
end;

procedure TReportChartObject.PrepareData(const Context: TExpressionContext);
var
  DS: TDataSet;
  DP: TChartDataPoint;
  LblField, ValField: TField;
  ColorIdx: Integer;
  Bmk: TBookmark;
begin
  if FDataPrepared then Exit;
  
  FDataPoints.Clear;
  DS := ResolveDataSet(Context);
  if Assigned(DS) and DS.Active and (FDataFieldLabel <> '') and (FDataFieldValue <> '') then
  begin
    LblField := DS.FindField(FDataFieldLabel);
    ValField := DS.FindField(FDataFieldValue);
    
    if Assigned(LblField) and Assigned(ValField) then
    begin
      Bmk := DS.Bookmark;
      DS.DisableControls;
      try
        ColorIdx := 0;
        DS.First;
        while not DS.Eof do
        begin
          DP.LabelText := LblField.AsString;
          DP.Value := ValField.AsFloat;
          DP.Color := FDefaultColors[ColorIdx mod Length(FDefaultColors)];
          Inc(ColorIdx);
          
          FDataPoints.Add(DP);
          DS.Next;
        end;
      finally
        if DS.BookmarkValid(Bmk) then
          DS.GotoBookmark(Bmk);
        DS.EnableControls;
      end;
    end;
  end;
  
  FDataPrepared := True;
end;

procedure TReportChartObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  R, ChartRect: TRect;
  OldPen: TPen;
  OldBrush: TBrush;
  DP: TChartDataPoint;
  TitleH, TitleW: Integer;
begin
  R := Bounds;
  if R.IsEmpty then Exit;

  // Design time preview
  if not Assigned(ResolveDataSet(Context)) then
  begin
    if FDataPoints.Count = 0 then
    begin
      FDataPoints.Clear;
      DP.LabelText := 'A'; DP.Value := 30; DP.Color := clRed; FDataPoints.Add(DP);
      DP.LabelText := 'B'; DP.Value := 50; DP.Color := clBlue; FDataPoints.Add(DP);
      DP.LabelText := 'C'; DP.Value := 20; DP.Color := clGreen; FDataPoints.Add(DP);
    end;
  end
  else
    PrepareData(Context);

  OldPen := TPen.Create;
  OldBrush := TBrush.Create;
  try
    OldPen.Assign(C.Pen);
    OldBrush.Assign(C.Brush);

    C.Pen.Color := clBlack;
    C.Pen.Width := 1;
    C.Pen.Style := psSolid;
    C.Brush.Color := clWhite;
    C.Brush.Style := bsSolid;
    C.FillRect(R);

    // Title
    ChartRect := R;
    if FTitle <> '' then
    begin
      C.Font.Name := 'Arial';
      C.Font.Size := 10;
      C.Font.Style := [fsBold];
      C.Font.Color := clBlack;
      TitleH := C.TextHeight(FTitle);
      TitleW := C.TextWidth(FTitle);
      C.TextOut(ChartRect.Left + (ChartRect.Width - TitleW) div 2, ChartRect.Top + 2, FTitle);
      ChartRect.Top := ChartRect.Top + TitleH + 4;
    end;

    // Legend
    if FShowLegend and (FDataPoints.Count > 0) then
      DrawLegend(C, R, ChartRect);

    if (ChartRect.Width > 10) and (ChartRect.Height > 10) and (FDataPoints.Count > 0) then
    begin
      case FChartType of
        ctPie: DrawPie(C, ChartRect);
        ctBar: DrawBar(C, ChartRect);
        ctLine: DrawLine(C, ChartRect);
      end;
    end;

    C.Pen.Assign(OldPen);
    C.Brush.Assign(OldBrush);
  finally
    OldPen.Free;
    OldBrush.Free;
  end;
end;

procedure TReportChartObject.DrawLegend(C: TCanvas; const R: TRect; out ChartRect: TRect);
var
  i: Integer;
  MaxLabelW, LegendW, LegendH: Integer;
  DP: TChartDataPoint;
  TopY, LeftX: Integer;
begin
  ChartRect := R;
  C.Font.Name := 'Arial';
  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := clBlack;
  
  MaxLabelW := 0;
  for i := 0 to FDataPoints.Count - 1 do
    MaxLabelW := Max(MaxLabelW, C.TextWidth(FDataPoints[i].LabelText));
    
  LegendW := 10 + 4 + MaxLabelW + 4;
  LegendH := FDataPoints.Count * 14 + 4;
  
  // Right aligned legend
  ChartRect.Right := ChartRect.Right - LegendW - 4;
  
  LeftX := ChartRect.Right + 4;
  TopY := ChartRect.Top + (ChartRect.Height - LegendH) div 2;
  
  C.Brush.Color := clWhite;
  C.Pen.Color := clSilver;
  C.Rectangle(LeftX, TopY, LeftX + LegendW, TopY + LegendH);
  
  for i := 0 to FDataPoints.Count - 1 do
  begin
    DP := FDataPoints[i];
    C.Brush.Color := DP.Color;
    C.Pen.Color := clBlack;
    C.Rectangle(LeftX + 2, TopY + 2 + i * 14, LeftX + 10, TopY + 10 + i * 14);
    C.Brush.Style := bsClear;
    C.TextOut(LeftX + 14, TopY + i * 14, DP.LabelText);
    C.Brush.Style := bsSolid;
  end;
end;

procedure TReportChartObject.DrawPie(C: TCanvas; const R: TRect);
var
  Total: Double;
  i: Integer;
  DP: TChartDataPoint;
  StartAngle, EndAngle: Double;
  CX, CY, Radius: Integer;
  X1, Y1, X2, Y2: Integer;
begin
  Total := 0;
  for i := 0 to FDataPoints.Count - 1 do
    if FDataPoints[i].Value > 0 then
      Total := Total + FDataPoints[i].Value;

  if Total <= 0 then Exit;

  CX := R.Left + R.Width div 2;
  CY := R.Top + R.Height div 2;
  Radius := Min(R.Width, R.Height) div 2 - 4;

  StartAngle := 0;
  for i := 0 to FDataPoints.Count - 1 do
  begin
    DP := FDataPoints[i];
    if DP.Value <= 0 then Continue;

    EndAngle := StartAngle + (DP.Value / Total) * 360;
    
    // GDI Pie uses bounding box and two radial points.
    // Angles in GDI start at 3 o'clock and go counter-clockwise (with negative Y up).
    X1 := CX + Round(Radius * Cos(StartAngle * Pi / 180));
    Y1 := CY - Round(Radius * Sin(StartAngle * Pi / 180));
    
    X2 := CX + Round(Radius * Cos(EndAngle * Pi / 180));
    Y2 := CY - Round(Radius * Sin(EndAngle * Pi / 180));
    
    C.Brush.Color := DP.Color;
    C.Pie(CX - Radius, CY - Radius, CX + Radius, CY + Radius, X2, Y2, X1, Y1);
    
    StartAngle := EndAngle;
  end;
end;

procedure TReportChartObject.DrawBar(C: TCanvas; const R: TRect);
var
  MaxVal: Double;
  i: Integer;
  DP: TChartDataPoint;
  BarW: Integer;
  BarSpace: Integer;
  H: Integer;
begin
  MaxVal := 0;
  for i := 0 to FDataPoints.Count - 1 do
    MaxVal := Max(MaxVal, FDataPoints[i].Value);

  if MaxVal <= 0 then Exit;

  BarSpace := R.Width div (FDataPoints.Count * 2 + 1);
  BarW := BarSpace;

  for i := 0 to FDataPoints.Count - 1 do
  begin
    DP := FDataPoints[i];
    H := Round((DP.Value / MaxVal) * (R.Height - 10));
    
    C.Brush.Color := DP.Color;
    C.Rectangle(
      R.Left + BarSpace + i * (BarW + BarSpace),
      R.Bottom - H - 5,
      R.Left + BarSpace + i * (BarW + BarSpace) + BarW,
      R.Bottom - 5
    );
  end;
  
  // Axes
  C.Pen.Color := clBlack;
  C.MoveTo(R.Left, R.Top);
  C.LineTo(R.Left, R.Bottom - 5);
  C.LineTo(R.Right, R.Bottom - 5);
end;

procedure TReportChartObject.DrawLine(C: TCanvas; const R: TRect);
var
  MaxVal: Double;
  i: Integer;
  DP: TChartDataPoint;
  StepX: Integer;
  H, LastX, LastY: Integer;
  PX, PY: Integer;
begin
  MaxVal := 0;
  for i := 0 to FDataPoints.Count - 1 do
    MaxVal := Max(MaxVal, FDataPoints[i].Value);

  if MaxVal <= 0 then Exit;

  StepX := R.Width div Max(1, FDataPoints.Count - 1);
  if FDataPoints.Count = 1 then StepX := R.Width div 2;

  C.Pen.Color := clNavy;
  C.Pen.Width := 2;
  LastX := 0; LastY := 0;

  for i := 0 to FDataPoints.Count - 1 do
  begin
    DP := FDataPoints[i];
    H := Round((DP.Value / MaxVal) * (R.Height - 10));
    
    PX := R.Left + i * StepX;
    if FDataPoints.Count = 1 then PX := R.Left + StepX;
    PY := R.Bottom - H - 5;
    
    if i = 0 then
      C.MoveTo(PX, PY)
    else
    begin
      C.MoveTo(LastX, LastY);
      C.LineTo(PX, PY);
    end;
    
    LastX := PX;
    LastY := PY;
    
    // Draw dot
    C.Brush.Color := clRed;
    C.Ellipse(PX - 3, PY - 3, PX + 3, PY + 3);
  end;
  
  // Axes
  C.Pen.Width := 1;
  C.Pen.Color := clBlack;
  C.MoveTo(R.Left, R.Top);
  C.LineTo(R.Left, R.Bottom - 5);
  C.LineTo(R.Right, R.Bottom - 5);
end;

class function TReportChartObject.DisplayName: string;
begin
  Result := 'Chart';
end;

initialization
  RegisterReportObject(TReportChartObject);

end.
