unit Vittix.Report.Preview;

{
  Vittix.Report.Preview
  =====================
  TVittixReportPreview — a VCL control that displays rendered report pages.

  Lifetime safety (this revision)
  --------------------------------
  The previous design stored a raw pointer to TReportRenderer.  If the caller
  freed the renderer while the control was still alive, the Paint method
  would dereference a dangling pointer.

  Fix: the control now takes ownership of its own TObjectList<TBitmap> that is
  populated by copying bitmaps from the renderer inside LoadFromRenderer.
  After the call returns the renderer can be freed or reused without risk.

  The copy is performed with TCanvas.Draw at the same size, which is O(pixels)
  but avoids any dependency on the renderer's lifetime.  For very large reports
  (hundreds of pages) consider using LoadPageRange(Start, End) to copy lazily.
}

interface

uses
  System.Classes,
  System.Types,
  System.SysUtils,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Printers,
  Vittix.Report.PageSettings,
  Vittix.Report.Renderer;

type
  TVittixReportPreview = class(TCustomControl)
  private
    FPages:      TObjectList<TBitmap>;  // owned; independent of TReportRenderer
    FPageIndex:  Integer;
    FZoomPercent: Integer;
    FOnPageChanged: TNotifyEvent;
    FMargins: TReportMargins;
    FShowMarginOverlay: Boolean;

    procedure SetPageIndex(const Value: Integer);
    procedure SetZoomPercent(const Value: Integer);
    function  GetPageCount: Integer;

  protected
    procedure Paint; override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    /// <summary>
    ///   Copies pages from the renderer into this control's own bitmap list.
    ///   The renderer can be freed after this call without affecting the preview.
    /// </summary>
    procedure LoadFromRenderer(ARenderer: TReportRenderer);

    /// <summary>Discards all copied pages and repaints blank.</summary>
    procedure Clear;

    procedure NextPage;
    procedure PrevPage;
    procedure FirstPage;
    procedure LastPage;

    { Aliases used by the preview form }
    procedure GoNext;   inline;
    procedure GoPrev;   inline;
    procedure GoFirst;  inline;
    procedure GoLast;   inline;

    procedure ZoomIn;
    procedure ZoomOut;
    procedure FitWidth;
    procedure FitPage;
    procedure Print;
    procedure SetMargins(const Value: TReportMargins);

    property PageCount:   Integer read GetPageCount;
    property CurrentPage: Integer read FPageIndex;

  published
    property Align;
    property Color default clGray;
    property ZoomPercent: Integer
      read FZoomPercent write SetZoomPercent default 100;
    property PageIndex: Integer
      read FPageIndex write SetPageIndex;
    property Margins: TReportMargins
      read FMargins write SetMargins;
    property ShowMarginOverlay: Boolean
      read FShowMarginOverlay write FShowMarginOverlay default True;
    property OnPageChanged: TNotifyEvent
      read FOnPageChanged write FOnPageChanged;
  end;

procedure Register;

implementation

uses
  System.Math;

{ ================= Constructor / Destructor ================= }

constructor TVittixReportPreview.Create(AOwner: TComponent);
begin
  inherited;
  DoubleBuffered := True;
  Color          := clGray;
  FZoomPercent   := 100;
  FPages         := TObjectList<TBitmap>.Create(True); // owns bitmaps
  FMargins       := TReportMargins.Default;
  FShowMarginOverlay := True;
end;

destructor TVittixReportPreview.Destroy;
begin
  FPages.Free;
  inherited;
end;

{ ================= LoadFromRenderer ================= }

procedure TVittixReportPreview.LoadFromRenderer(ARenderer: TReportRenderer);
var
  i:    Integer;
  Src:  TBitmap;
  Copy: TBitmap;
begin
  FPages.Clear;
  FPageIndex := 0;

  if not Assigned(ARenderer) then
  begin
    Invalidate;
    Exit;
  end;

  for i := 0 to ARenderer.Pages.Count - 1 do
  begin
    Src  := ARenderer.Pages[i].Bitmap;
    Copy := TBitmap.Create;
    Copy.SetSize(Src.Width, Src.Height);
    Copy.Canvas.Draw(0, 0, Src);   // pixel-perfect copy
    FPages.Add(Copy);
  end;

  Invalidate;
end;

procedure TVittixReportPreview.SetMargins(const Value: TReportMargins);
begin
  FMargins := Value;
  Invalidate;
end;

{ ================= Clear ================= }

procedure TVittixReportPreview.Clear;
begin
  FPages.Clear;
  FPageIndex := 0;
  Invalidate;
end;

{ ================= PageCount ================= }

function TVittixReportPreview.GetPageCount: Integer;
begin
  Result := FPages.Count;
end;

{ ================= Navigation ================= }

procedure TVittixReportPreview.FirstPage;
begin
  SetPageIndex(0);
end;

procedure TVittixReportPreview.LastPage;
begin
  SetPageIndex(PageCount - 1);
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
  FPageIndex := EnsureRange(Value, 0, PageCount - 1);
  Invalidate;
  if Assigned(FOnPageChanged) then FOnPageChanged(Self);
end;

procedure TVittixReportPreview.SetZoomPercent(const Value: Integer);
begin
  if Value < 10  then Exit;
  if Value > 400 then Exit;
  FZoomPercent := Value;
  Invalidate;
end;

{ ================= Paint ================= }

procedure TVittixReportPreview.Paint;
var
  PageBmp: TBitmap;
  Scale:   Double;
  W, H:   Integer;
  R:      TRect;
  ContentR: TRect;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  if PageCount = 0 then Exit;
  if (FPageIndex < 0) or (FPageIndex >= PageCount) then Exit;

  PageBmp := FPages[FPageIndex];

  Scale := FZoomPercent / 100;
  W     := Round(PageBmp.Width  * Scale);
  H     := Round(PageBmp.Height * Scale);

  R := Rect(
    (ClientWidth - W) div 2,
    10,
    (ClientWidth - W) div 2 + W,
    10 + H
  );

  if FShowMarginOverlay then
  begin
    ContentR := Rect(
      R.Left + Round(FMargins.Left * Scale),
      R.Top + Round(FMargins.Top * Scale),
      R.Right - Round(FMargins.Right * Scale),
      R.Bottom - Round(FMargins.Bottom * Scale));
    if (ContentR.Right > ContentR.Left) and (ContentR.Bottom > ContentR.Top) then
    begin
      Canvas.Brush.Color := $00FAFAF0;
      Canvas.FillRect(ContentR);
      Canvas.Brush.Style := bsClear;
      Canvas.Pen.Color := $00D0A060;
      Canvas.Pen.Style := psSolid;
      Canvas.Rectangle(ContentR);
    end;
  end;

  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clWhite;
  Canvas.Rectangle(R);
  Canvas.StretchDraw(R, PageBmp);

  Canvas.Pen.Color   := clSilver;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(R);
end;

{ ================= Navigation aliases ================= }

procedure TVittixReportPreview.GoFirst;  begin FirstPage; end;
procedure TVittixReportPreview.GoLast;   begin LastPage;  end;
procedure TVittixReportPreview.GoNext;   begin NextPage;  end;
procedure TVittixReportPreview.GoPrev;   begin PrevPage;  end;

{ ================= Zoom helpers ================= }

procedure TVittixReportPreview.ZoomIn;
begin
  SetZoomPercent(FZoomPercent + 10);
end;

procedure TVittixReportPreview.ZoomOut;
begin
  SetZoomPercent(FZoomPercent - 10);
end;

procedure TVittixReportPreview.FitWidth;
var
  PageBmp: TBitmap;
begin
  if (PageCount = 0) or (ClientWidth <= 0) then Exit;
  PageBmp := FPages[FPageIndex];
  if PageBmp.Width <= 0 then Exit;
  SetZoomPercent(((ClientWidth - 20) * 100) div PageBmp.Width);
end;

procedure TVittixReportPreview.FitPage;
var
  PageBmp: TBitmap;
  ScaleW, ScaleH: Integer;
begin
  if (PageCount = 0) or (ClientWidth <= 0) or (ClientHeight <= 0) then Exit;

  PageBmp := FPages[FPageIndex];
  if (PageBmp.Width <= 0) or (PageBmp.Height <= 0) then Exit;

  ScaleW := ((ClientWidth - 20) * 100) div PageBmp.Width;
  ScaleH := ((ClientHeight - 20) * 100) div PageBmp.Height;

  if ScaleW < ScaleH then
    SetZoomPercent(ScaleW)
  else
    SetZoomPercent(ScaleH);
end;

{ ================= Print ================= }

procedure TVittixReportPreview.Print;
var
  i:    Integer;
  Bmp:  TBitmap;
  R:    TRect;
begin
  if PageCount = 0 then Exit;
  Printer.BeginDoc;
  try
    for i := 0 to FPages.Count - 1 do
    begin
      Bmp := FPages[i];
      R   := Rect(0, 0, Printer.PageWidth, Printer.PageHeight);
      Printer.Canvas.StretchDraw(R, Bmp);
      if i < FPages.Count - 1 then
        Printer.NewPage;
    end;
    Printer.EndDoc;
  except
    Printer.Abort;
    raise;
  end;
end;

{ ================= Register ================= }

procedure Register;
begin
  RegisterComponents('Vittix Reporting', [TVittixReportPreview]);
end;

end.
