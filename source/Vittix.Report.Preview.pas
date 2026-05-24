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
  Winapi.Messages,
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
    FPages:      TObjectList<Vcl.Graphics.TBitmap>;  // owned; independent of TReportRenderer
    FPageIndex:  Integer;
    FZoomPercent: Integer;
    FOnPageChanged: TNotifyEvent;
    FMargins: TReportMargins;
    FShowMarginOverlay: Boolean;
    FScrollX: Integer;
    FScrollY: Integer;

    procedure SetPageIndex(const Value: Integer);
    procedure SetZoomPercent(const Value: Integer);
    function  GetPageCount: Integer;
    procedure GetContentSize(out AWidth, AHeight: Integer);
    procedure SetScrollOffset(AX, AY: Integer);
    procedure UpdateScrollBars;
    procedure WMHScroll(var Message: TWMHScroll); message WM_HSCROLL;
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
    procedure WMSize(var Message: TWMSize); message WM_SIZE;

  protected
    procedure CreateParams(var Params: TCreateParams); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
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
  Winapi.Windows,
  System.Math;

{ ================= Constructor / Destructor ================= }

constructor TVittixReportPreview.Create(AOwner: TComponent);
begin
  inherited;
  DoubleBuffered := True;
  Color          := clGray;
  FZoomPercent   := 100;
  FPages         := TObjectList<Vcl.Graphics.TBitmap>.Create(True); // owns bitmaps
  FMargins       := TReportMargins.Default;
  FShowMarginOverlay := True;
end;

destructor TVittixReportPreview.Destroy;
begin
  FPages.Free;
  inherited;
end;

procedure TVittixReportPreview.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.Style := Params.Style or WS_HSCROLL or WS_VSCROLL;
end;

{ ================= LoadFromRenderer ================= }

procedure TVittixReportPreview.LoadFromRenderer(ARenderer: TReportRenderer);
var
  i:    Integer;
  Src:  Vcl.Graphics.TBitmap;
  Copy: Vcl.Graphics.TBitmap;
begin
  FPages.Clear;
  FPageIndex := 0;

  if not Assigned(ARenderer) then
  begin
    SetScrollOffset(0, 0);
    UpdateScrollBars;
    Invalidate;
    Exit;
  end;

  for i := 0 to ARenderer.Pages.Count - 1 do
  begin
    Src  := ARenderer.Pages[i].Bitmap;
    Copy := Vcl.Graphics.TBitmap.Create;
    Copy.SetSize(Src.Width, Src.Height);
    Copy.Canvas.Draw(0, 0, Src);   // pixel-perfect copy
    FPages.Add(Copy);
  end;

  SetScrollOffset(0, 0);
  UpdateScrollBars;
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
  SetScrollOffset(0, 0);
  UpdateScrollBars;
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
  SetScrollOffset(0, 0);
  UpdateScrollBars;
  Invalidate;
  if Assigned(FOnPageChanged) then FOnPageChanged(Self);
end;

procedure TVittixReportPreview.SetZoomPercent(const Value: Integer);
var
  NewZoom: Integer;
begin
  NewZoom := EnsureRange(Value, 10, 400);
  if FZoomPercent = NewZoom then
    Exit;
  FZoomPercent := NewZoom;
  UpdateScrollBars;
  Invalidate;
end;

procedure TVittixReportPreview.GetContentSize(out AWidth, AHeight: Integer);
var
  PageBmp: Vcl.Graphics.TBitmap;
  Scale: Double;
begin
  AWidth := ClientWidth;
  AHeight := ClientHeight;
  if (PageCount = 0) or (FPageIndex < 0) or (FPageIndex >= PageCount) then
    Exit;

  PageBmp := FPages[FPageIndex];
  Scale := FZoomPercent / 100;
  AWidth := Max(ClientWidth, Round(PageBmp.Width * Scale) + 20);
  AHeight := Max(ClientHeight, Round(PageBmp.Height * Scale) + 20);
end;

procedure TVittixReportPreview.SetScrollOffset(AX, AY: Integer);
var
  ContentW, ContentH: Integer;
begin
  GetContentSize(ContentW, ContentH);
  AX := EnsureRange(AX, 0, Max(0, ContentW - ClientWidth));
  AY := EnsureRange(AY, 0, Max(0, ContentH - ClientHeight));
  if (FScrollX = AX) and (FScrollY = AY) then
    Exit;

  FScrollX := AX;
  FScrollY := AY;
  UpdateScrollBars;
  Invalidate;
end;

procedure TVittixReportPreview.UpdateScrollBars;
var
  ContentW, ContentH: Integer;
  SI: TScrollInfo;
begin
  if not HandleAllocated then
    Exit;

  GetContentSize(ContentW, ContentH);
  FScrollX := EnsureRange(FScrollX, 0, Max(0, ContentW - ClientWidth));
  FScrollY := EnsureRange(FScrollY, 0, Max(0, ContentH - ClientHeight));

  ZeroMemory(@SI, SizeOf(SI));
  SI.cbSize := SizeOf(SI);
  SI.fMask := SIF_RANGE or SIF_PAGE or SIF_POS;
  SI.nMin := 0;

  SI.nMax := Max(0, ContentW - 1);
  SI.nPage := Max(1, ClientWidth);
  SI.nPos := FScrollX;
  SetScrollInfo(Handle, SB_HORZ, SI, True);
  ShowScrollBar(Handle, SB_HORZ, ContentW > ClientWidth);

  SI.nMax := Max(0, ContentH - 1);
  SI.nPage := Max(1, ClientHeight);
  SI.nPos := FScrollY;
  SetScrollInfo(Handle, SB_VERT, SI, True);
  ShowScrollBar(Handle, SB_VERT, ContentH > ClientHeight);
end;

procedure TVittixReportPreview.WMHScroll(var Message: TWMHScroll);
var
  SI: TScrollInfo;
  NewPos: Integer;
begin
  NewPos := FScrollX;
  case Message.ScrollCode of
    SB_LINELEFT: Dec(NewPos, 20);
    SB_LINERIGHT: Inc(NewPos, 20);
    SB_PAGELEFT: Dec(NewPos, ClientWidth);
    SB_PAGERIGHT: Inc(NewPos, ClientWidth);
    SB_THUMBPOSITION, SB_THUMBTRACK:
      begin
        ZeroMemory(@SI, SizeOf(SI));
        SI.cbSize := SizeOf(SI);
        SI.fMask := SIF_TRACKPOS;
        if GetScrollInfo(Handle, SB_HORZ, SI) then
          NewPos := SI.nTrackPos;
      end;
    SB_LEFT: NewPos := 0;
    SB_RIGHT: NewPos := MaxInt;
  end;
  SetScrollOffset(NewPos, FScrollY);
end;

procedure TVittixReportPreview.WMVScroll(var Message: TWMVScroll);
var
  SI: TScrollInfo;
  NewPos: Integer;
begin
  NewPos := FScrollY;
  case Message.ScrollCode of
    SB_LINEUP: Dec(NewPos, 20);
    SB_LINEDOWN: Inc(NewPos, 20);
    SB_PAGEUP: Dec(NewPos, ClientHeight);
    SB_PAGEDOWN: Inc(NewPos, ClientHeight);
    SB_THUMBPOSITION, SB_THUMBTRACK:
      begin
        ZeroMemory(@SI, SizeOf(SI));
        SI.cbSize := SizeOf(SI);
        SI.fMask := SIF_TRACKPOS;
        if GetScrollInfo(Handle, SB_VERT, SI) then
          NewPos := SI.nTrackPos;
      end;
    SB_TOP: NewPos := 0;
    SB_BOTTOM: NewPos := MaxInt;
  end;
  SetScrollOffset(FScrollX, NewPos);
end;

procedure TVittixReportPreview.WMSize(var Message: TWMSize);
begin
  inherited;
  UpdateScrollBars;
end;

function TVittixReportPreview.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  if ssCtrl in Shift then
    Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos)
  else
  begin
    SetScrollOffset(FScrollX, FScrollY - WheelDelta div 3);
    Result := True;
  end;
end;

{ ================= Paint ================= }

procedure TVittixReportPreview.Paint;
var
  PageBmp: Vcl.Graphics.TBitmap;
  Scale:   Double;
  W, H:   Integer;
  R:      TRect;
  ContentR: TRect;
  ContentW, ContentH: Integer;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  if PageCount = 0 then Exit;
  if (FPageIndex < 0) or (FPageIndex >= PageCount) then Exit;

  PageBmp := FPages[FPageIndex];

  Scale := FZoomPercent / 100;
  W     := Round(PageBmp.Width  * Scale);
  H     := Round(PageBmp.Height * Scale);
  GetContentSize(ContentW, ContentH);

  R := Rect(
    ((ContentW - W) div 2) - FScrollX,
    10 - FScrollY,
    ((ContentW - W) div 2) - FScrollX + W,
    10 - FScrollY + H
  );

  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clWhite;
  Canvas.Rectangle(R);
  Canvas.StretchDraw(R, PageBmp);

  if FShowMarginOverlay then
  begin
    ContentR := Rect(
      R.Left + Round(FMargins.Left * Scale),
      R.Top + Round(FMargins.Top * Scale),
      R.Right - Round(FMargins.Right * Scale),
      R.Bottom - Round(FMargins.Bottom * Scale));
    if (ContentR.Right > ContentR.Left) and (ContentR.Bottom > ContentR.Top) then
    begin
      Canvas.Brush.Style := bsClear;
      Canvas.Pen.Color := $00D0A060;
      Canvas.Pen.Style := psSolid;
      Canvas.Rectangle(ContentR);
    end;
  end;

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
  PageBmp: Vcl.Graphics.TBitmap;
begin
  if (PageCount = 0) or (ClientWidth <= 0) then Exit;
  PageBmp := FPages[FPageIndex];
  if PageBmp.Width <= 0 then Exit;
  SetZoomPercent(((ClientWidth - 20) * 100) div PageBmp.Width);
end;

procedure TVittixReportPreview.FitPage;
var
  PageBmp: Vcl.Graphics.TBitmap;
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
  Bmp:  Vcl.Graphics.TBitmap;
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
