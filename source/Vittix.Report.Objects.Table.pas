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
  System.Math;

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
  if not Visible then
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

class function TReportTableObject.DisplayName: string;
begin
  Result := 'Table';
end;

initialization
  RegisterReportObject(TReportTableObject);

end.
