unit Vittix.Report.Preview;

interface

uses
  System.Classes,
  System.Types,
  System.SysUtils,
  Vcl.Controls,
  Vcl.Graphics,
  Vittix.Report.Renderer;

type
  TVittixReportPreview = class(TCustomControl)
  private
    FRenderer: TReportRenderer;
    FPageIndex: Integer;
    FZoomPercent: Integer;

    procedure SetPageIndex(const Value: Integer);
    procedure SetZoomPercent(const Value: Integer);

    function GetPageCount: Integer;

  protected
    procedure Paint; override;

  public
    constructor Create(AOwner: TComponent); override;

    procedure LoadFromRenderer(ARenderer: TReportRenderer);

    procedure NextPage;
    procedure PrevPage;
    procedure FirstPage;
    procedure LastPage;

    property PageCount: Integer read GetPageCount;

  published
    property Align;
    property Color default clGray;
    property ZoomPercent: Integer
      read FZoomPercent write SetZoomPercent default 100;
    property PageIndex: Integer
      read FPageIndex write SetPageIndex;
  end;

procedure Register;

implementation

uses
  Math;

{ ================= Constructor ================= }

constructor TVittixReportPreview.Create(AOwner: TComponent);
begin
  inherited;
  DoubleBuffered := True;
  Color := clGray;
  FZoomPercent := 100;
end;

{ ================= Renderer Load ================= }

procedure TVittixReportPreview.LoadFromRenderer(
  ARenderer: TReportRenderer);
begin
  FRenderer := ARenderer;
  FPageIndex := 0;
  Invalidate;
end;

{ ================= Page Count ================= }

function TVittixReportPreview.GetPageCount: Integer;
begin
  if Assigned(FRenderer) then
    Result := FRenderer.Pages.Count
  else
    Result := 0;
end;

{ ================= Navigation ================= }

procedure TVittixReportPreview.FirstPage;
begin
  SetPageIndex(0);
end;

procedure TVittixReportPreview.LastPage;
begin
  SetPageIndex(PageCount-1);
end;

procedure TVittixReportPreview.NextPage;
begin
  SetPageIndex(FPageIndex + 1);
end;

procedure TVittixReportPreview.PrevPage;
begin
  SetPageIndex(FPageIndex - 1);
end;

{ ================= Setters ================= }

procedure TVittixReportPreview.SetPageIndex(const Value: Integer);
begin
  if PageCount = 0 then Exit;
  FPageIndex := EnsureRange(Value, 0, PageCount-1);
  Invalidate;
end;

procedure TVittixReportPreview.SetZoomPercent(const Value: Integer);
begin
  if Value < 10 then Exit;
  if Value > 400 then Exit;
  FZoomPercent := Value;
  Invalidate;
end;

{ ================= Paint ================= }

procedure TVittixReportPreview.Paint;
var
  PageBmp: TBitmap;
  Scale: Double;
  W,H: Integer;
  R: TRect;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  if not Assigned(FRenderer) then Exit;
  if PageCount = 0 then Exit;

  PageBmp := FRenderer.Pages[FPageIndex].Bitmap;

  Scale := FZoomPercent / 100;

  W := Round(PageBmp.Width * Scale);
  H := Round(PageBmp.Height * Scale);

  R := Rect(
    (ClientWidth - W) div 2,
    10,
    (ClientWidth - W) div 2 + W,
    10 + H
  );

  Canvas.Brush.Color := clWhite;
  Canvas.Rectangle(R);
  Canvas.StretchDraw(R, PageBmp);

  Canvas.Pen.Color := clSilver;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(R);
end;

{ ================= Register ================= }

procedure Register;
begin
  RegisterComponents('Vittix Reporting', [TVittixReportPreview]);
end;

end.
