unit Vittix.Report.Objects.Table;

interface

uses
  System.Types,
  Vcl.Graphics,
  Vittix.Report.Objects,
  Vittix.Report.Context;

type
  TReportTableObject = class(TReportObject)
  private
    FRows: Integer;
    FCols: Integer;
    FHeaderRows: Integer;
    FGridColor: TColor;
    FHeaderColor: TColor;
  public
    constructor Create; override;
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    procedure CaptureExportCommands(const Context: TExpressionContext;
      const ASink: IReportExportCaptureSink); override;
    class function DisplayName: string; override;
  published
    property Rows: Integer read FRows write FRows default 4;
    property Cols: Integer read FCols write FCols default 4;
    property HeaderRows: Integer read FHeaderRows write FHeaderRows default 1;
    property GridColor: TColor read FGridColor write FGridColor default clGray;
    property HeaderColor: TColor read FHeaderColor write FHeaderColor default $00F0F0F0;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  System.Variants,
  Vittix.Report.Expressions,
  Vittix.Report.Utils,
  Vittix.Report.Export.Commands;

function ShouldPrintTableObject(AObj: TReportObject;
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

constructor TReportTableObject.Create;
begin
  inherited;
  Bounds := Rect(10, 10, 260, 110);
  FRows := 4;
  FCols := 4;
  FHeaderRows := 1;
  FGridColor := clGray;
  FHeaderColor := $00F0F0F0;
end;

procedure TReportTableObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  R: TRect;
  RowHeight, ColWidth: Integer;
  RowIndex, ColIndex, YPos, XPos: Integer;
begin
  if not ShouldPrintTableObject(Self, Context) then
    Exit;

  R := Bounds;
  if (FRows <= 0) or (FCols <= 0) then
    Exit;

  RowHeight := Max(1, (R.Bottom - R.Top) div FRows);
  ColWidth := Max(1, (R.Right - R.Left) div FCols);

  C.Brush.Style := bsSolid;
  C.Brush.Color := clWhite;
  C.Pen.Style := psSolid;
  C.Pen.Color := FGridColor;
  C.Rectangle(R);

  if FHeaderRows > 0 then
  begin
    C.Brush.Color := FHeaderColor;
    C.FillRect(Rect(R.Left + 1, R.Top + 1, R.Right - 1,
      Min(R.Bottom - 1, R.Top + (RowHeight * FHeaderRows))));
  end;

  C.Brush.Style := bsClear;
  C.Pen.Color := FGridColor;

  for RowIndex := 1 to FRows - 1 do
  begin
    YPos := R.Top + (RowHeight * RowIndex);
    C.MoveTo(R.Left, YPos);
    C.LineTo(R.Right, YPos);
  end;

  for ColIndex := 1 to FCols - 1 do
  begin
    XPos := R.Left + (ColWidth * ColIndex);
    C.MoveTo(XPos, R.Top);
    C.LineTo(XPos, R.Bottom);
  end;
end;

procedure TReportTableObject.CaptureExportCommands(const Context: TExpressionContext;
  const ASink: IReportExportCaptureSink);
var
  R: TRect;
  Origin: TPoint;
  RowHeight: Integer;
  ColWidth: Integer;
  RowIndex: Integer;
  ColIndex: Integer;
  YPos: Integer;
  XPos: Integer;
  FillCmd: TReportExportFillRectangleCommand;
  RectCmd: TReportExportRectangleCommand;
  LineCmd: TReportExportLineCommand;
begin
  if not Assigned(ASink) then
    Exit;

  Origin := ASink.GetCaptureOrigin;
  R := Bounds;
  OffsetRect(R, Origin.X, Origin.Y);
  if (Rows <= 0) or (Cols <= 0) then
    Exit;

  RowHeight := Max(1, R.Height div Rows);
  ColWidth := Max(1, R.Width div Cols);

  FillCmd := TReportExportFillRectangleCommand.Create;
  FillCmd.Bounds := R;
  FillCmd.FillColor := clWhite;
  ASink.AddCommand(FillCmd);

  if HeaderRows > 0 then
  begin
    FillCmd := TReportExportFillRectangleCommand.Create;
    FillCmd.Bounds := Rect(R.Left + 1, R.Top + 1, R.Right - 1,
      Min(R.Bottom - 1, R.Top + (RowHeight * HeaderRows)));
    FillCmd.FillColor := HeaderColor;
    ASink.AddCommand(FillCmd);
  end;

  RectCmd := TReportExportRectangleCommand.Create;
  RectCmd.Bounds := R;
  RectCmd.BorderColor := GridColor;
  RectCmd.BorderWidth := 1;
  ASink.AddCommand(RectCmd);

  for RowIndex := 1 to Rows - 1 do
  begin
    YPos := R.Top + (RowHeight * RowIndex);
    LineCmd := TReportExportLineCommand.Create;
    LineCmd.Color := GridColor;
    LineCmd.Width := 1;
    LineCmd.X1 := R.Left;
    LineCmd.Y1 := YPos;
    LineCmd.X2 := R.Right;
    LineCmd.Y2 := YPos;
    ASink.AddCommand(LineCmd);
  end;

  for ColIndex := 1 to Cols - 1 do
  begin
    XPos := R.Left + (ColWidth * ColIndex);
    LineCmd := TReportExportLineCommand.Create;
    LineCmd.Color := GridColor;
    LineCmd.Width := 1;
    LineCmd.X1 := XPos;
    LineCmd.Y1 := R.Top;
    LineCmd.X2 := XPos;
    LineCmd.Y2 := R.Bottom;
    ASink.AddCommand(LineCmd);
  end;
end;

class function TReportTableObject.DisplayName: string;
begin
  Result := 'Table';
end;

initialization
  RegisterReportObject(TReportTableObject);

end.
