unit Frm.Preview;

(*
  Frm.Preview - Print Preview Window
  =====================================
  Hosts TVittixReportPreview inside a modal dialog, using the light-chrome
  layout approved for the preview mockup:

    * Heading bar      "Print Preview: <report title> (Pages 1-n)"
    * Grouped toolbar  icon above caption, groups separated by rules:
                         Navigation  First / Prev / Next / Last / Go To...
                         Zoom        Zoom In / Zoom Out, - slider + , percent
                         Layout      Fit Width / Fit Page
                         Tools       Toggle Margins (margin-guide overlay)
                         Actions     Print (accented) / Save as PDF
    * Status bar       segmented: Status / Page x of y / Zoom: n% / Close Preview

  The first page is fitted to the window as soon as the window is actually
  shown, and keeps following the window size until the user picks a zoom (any
  slider move, zoom in/out or Fit Width click). Fit Page stays sticky.

  Rendering: passes the report through TReportRenderer, which runs the
  engine against a nil dataset (design-time preview - no live data).
  For live data, call LoadReport(Report, DataSet) before ShowModal.

  Icons are read from the shared designer PNG resource
  (resources\vittix_png_icons.res, {$R}-included by Frm.Main.pas), so this
  unit deliberately emits no duplicate resource. If an icon is unavailable
  the button degrades to a caption-only button.

  The four page-navigation glyphs are drawn at runtime because the shared
  icon set has no first/prev/next/last page artwork.
*)

interface

uses
  System.SysUtils, System.Classes, System.Types,
  Vittix.Designer.IconLoader,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.Buttons, Vcl.Dialogs, Vcl.ImgList, Vcl.Graphics,
  Data.DB,
  Vittix.Report.Engine,
  Vittix.Report.Model,
  Vittix.Report.Renderer,
  Vittix.Report.Preview;

type
  { Page-navigation glyphs drawn at runtime, because the shared designer icon
    set has no first/prev/next/last page artwork. }
  TVittixPreviewNavGlyph = (ngFirst, ngPrev, ngNext, ngLast, ngGoTo);

  TfrmPreview = class(TForm)
    pnlHeader      : TPanel;
    pnlHeaderLine  : TPanel;
    lblDocTitle    : TLabel;
    pnlToolbar     : TPanel;
    pnlToolbarLine : TPanel;
    btnFirst       : TSpeedButton;
    btnPrev        : TSpeedButton;
    btnNext        : TSpeedButton;
    btnLast        : TSpeedButton;
    btnGoToPage    : TSpeedButton;
    lblGrpNav      : TLabel;
    sepNav         : TPanel;
    btnZoomIn      : TSpeedButton;
    btnZoomOut     : TSpeedButton;
    btnZoomStepOut : TButton;
    trkZoom        : TTrackBar;
    btnZoomStepIn  : TButton;
    lblZoom        : TLabel;
    lblGrpZoom     : TLabel;
    sepZoom        : TPanel;
    btnFitWidth    : TSpeedButton;
    btnFitPage     : TSpeedButton;
    lblGrpLayout   : TLabel;
    sepLayout      : TPanel;
    pnlMarginsSwitch : TPaintBox;
    lblGrpTools    : TLabel;
    sepTools       : TPanel;
    pnlPrintBtn    : TPanel;
    btnPrint       : TSpeedButton;
    btnSavePDF     : TSpeedButton;
    lblGrpActions  : TLabel;
    pnlStatus      : TPanel;
    pnlStatusLine  : TPanel;
    lblStatusText  : TLabel;
    sepStatus1     : TPanel;
    lblPageInfo    : TLabel;
    sepStatus2     : TPanel;
    lblZoomInfo    : TLabel;
    sepStatus3     : TPanel;
    btnClosePreview: TButton;
    ilIcons        : TImageList;
    ilIconsLight   : TImageList;
    Preview        : TVittixReportPreview;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure btnFirstClick(Sender: TObject);
    procedure btnPrevClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnLastClick(Sender: TObject);
    procedure btnGoToPageClick(Sender: TObject);
    procedure btnZoomInClick(Sender: TObject);
    procedure btnZoomOutClick(Sender: TObject);
    procedure btnZoomStepOutClick(Sender: TObject);
    procedure btnZoomStepInClick(Sender: TObject);
    procedure btnFitWidthClick(Sender: TObject);
    procedure btnFitPageClick(Sender: TObject);
    procedure trkZoomChange(Sender: TObject);
    procedure btnPrintClick(Sender: TObject);
    procedure btnSavePDFClick(Sender: TObject);
    procedure btnClosePreviewClick(Sender: TObject);
    procedure PreviewPageChanged(Sender: TObject);
    procedure PreviewZoomChanged(Sender: TObject);
    procedure pnlMarginsSwitchClick(Sender: TObject);
    procedure pnlMarginsSwitchPaint(Sender: TObject);

  private
    FUpdatingZoom: Boolean;
    FAutoFit     : Boolean;
    FReport      : TReportModel;
    FDataSet     : TDataSet;
    FReportTitle : string;

    procedure ApplyChrome;
    procedure ApplyPendingFit;
    procedure SetupIcons;
    procedure UpdateNav;
    procedure UpdateZoomUI;
    procedure UpdateDocTitle;
    procedure SetStatusText(const AText: string);
    procedure PaintMarginsSwitch;

    function  CreateNavGlyph(AKind: TVittixPreviewNavGlyph): Vcl.Graphics.TBitmap;
    function  AddNavGlyph(AKind: TVittixPreviewNavGlyph): Integer;
    procedure RecolorMaskedIcon(ABitmap: Vcl.Graphics.TBitmap; AColor: TColor);

  public
    procedure LoadReport(AReport: TReportModel; ADataSet: TDataSet = nil);
  end;

implementation

{$R *.dfm}

uses
  System.UITypes,
  Winapi.Windows,
  Vittix.Report.Export.PDF;


type
  { 24-bit DIB pixel, the layout the masked bitmap helpers work in. }
  TBgrIcon = packed record
    B, G, R: Byte;
  end;
  PBgrIcon = ^TBgrIcon;

const
  { Chrome palette (TColor is $00BBGGRR). }
  CHROME_BG      : TColor = $00F5F5F5;   // heading band
  CHROME_TOOLBAR : TColor = $00FAFAFA;   // toolbar band
  CHROME_STATUS  : TColor = $00F0F0F0;   // status bar
  CHROME_LINE    : TColor = $00E3E3E3;   // horizontal rules
  CHROME_SEP     : TColor = $00DCDCDC;   // status bar segment separators
  CHROME_DESK    : TColor = $00CDCDCD;   // surface around the page
  TEXT_MAIN      : TColor = $001A1A1A;
  TEXT_GROUP     : TColor = $008A8A8A;
  ACCENT_BLUE    : TColor = $00D0720B;   // RGB(11, 114, 208) - switch "on"
  ACCENT_GREEN   : TColor = $003A8E3F;   // RGB(63, 142, 58)  - Print button
  SWITCH_OFF     : TColor = $00C4C4C4;

  GLYPH_INK      : TColor = $001A1A1A;   // near-black ink for drawn glyphs

{ =========================================================================== }
{  Form lifecycle                                                              }
{ =========================================================================== }

procedure TfrmPreview.FormCreate(Sender: TObject);
begin
  FUpdatingZoom := False;
  FReport       := nil;
  FDataSet      := nil;
  FReportTitle  := '';

  ApplyChrome;
  SetupIcons;

  Preview.Color         := CHROME_DESK;
  Preview.OnPageChanged := PreviewPageChanged;
  Preview.OnZoomChanged := PreviewZoomChanged;
  FAutoFit              := True;

  UpdateNav;
  UpdateZoomUI;
  SetStatusText('Ready.');
  PaintMarginsSwitch;
end;

procedure TfrmPreview.FormDestroy(Sender: TObject);
begin
  // Release copied preview page bitmaps as early as possible.
  Preview.Clear;
end;

procedure TfrmPreview.FormShow(Sender: TObject);
begin
  // LoadReport runs before the window is shown, so the fit computed there used
  // the design-time size. Re-apply it now that the real (maximised) size is in.
  ApplyPendingFit;
end;

procedure TfrmPreview.FormResize(Sender: TObject);
begin
  // Keep the page fitted while the initial fit is still in force, so the zoom
  // follows the window rather than sticking at the pre-show value.
  ApplyPendingFit;
end;

procedure TfrmPreview.ApplyPendingFit;
begin
  if FAutoFit and (Preview.PageCount > 0) then
    Preview.FitPage;
end;

procedure TfrmPreview.ApplyChrome;
begin
  Color := CHROME_BG;

  pnlHeader.Color      := CHROME_BG;
  pnlHeaderLine.Color  := CHROME_LINE;
  pnlToolbar.Color     := CHROME_TOOLBAR;
  pnlToolbarLine.Color := CHROME_LINE;
  pnlStatus.Color      := CHROME_STATUS;
  pnlStatusLine.Color  := CHROME_LINE;

  sepNav.Color    := CHROME_LINE;
  sepZoom.Color   := CHROME_LINE;
  sepLayout.Color := CHROME_LINE;
  sepTools.Color  := CHROME_LINE;
  sepStatus1.Color := CHROME_SEP;
  sepStatus2.Color := CHROME_SEP;
  sepStatus3.Color := CHROME_SEP;

  lblDocTitle.Font.Color   := TEXT_MAIN;
  lblStatusText.Font.Color := TEXT_MAIN;
  lblPageInfo.Font.Color   := TEXT_MAIN;
  lblZoomInfo.Font.Color   := TEXT_MAIN;
  lblZoom.Font.Color       := TEXT_MAIN;

  lblGrpNav.Font.Color     := TEXT_GROUP;
  lblGrpZoom.Font.Color    := TEXT_GROUP;
  lblGrpLayout.Font.Color  := TEXT_GROUP;
  lblGrpTools.Font.Color   := TEXT_GROUP;
  lblGrpActions.Font.Color := TEXT_GROUP;

  pnlMarginsSwitch.Cursor := crHandPoint;

  pnlPrintBtn.Color := ACCENT_GREEN;
  btnPrint.Font.Color := clWhite;

  btnZoomStepOut.Font.Height := -16;
  btnZoomStepIn.Font.Height  := -16;
end;

{ =========================================================================== }
{  Icons                                                                       }
{ =========================================================================== }

{ Paints every non-mask pixel with AColor, keeping the mask intact, so a dark
  glyph can be re-keyed for a coloured button. }
procedure TfrmPreview.RecolorMaskedIcon(ABitmap: Vcl.Graphics.TBitmap;
  AColor: TColor);
var
  Px: PBgrIcon;
  X, Y: Integer;
  MaskR, MaskG, MaskB: Byte;
  R, G, B: Byte;
begin
  MaskR := GetRValue(IconMaskColor);
  MaskG := GetGValue(IconMaskColor);
  MaskB := GetBValue(IconMaskColor);
  R := GetRValue(AColor);
  G := GetGValue(AColor);
  B := GetBValue(AColor);
  for Y := 0 to ABitmap.Height - 1 do
  begin
    Px := PBgrIcon(ABitmap.ScanLine[Y]);
    for X := 0 to ABitmap.Width - 1 do
    begin
      if (Px.R <> MaskR) or (Px.G <> MaskG) or (Px.B <> MaskB) then
      begin
        Px.R := R;
        Px.G := G;
        Px.B := B;
      end;
      Inc(Px);
    end;
  end;
end;

function TfrmPreview.CreateNavGlyph(AKind: TVittixPreviewNavGlyph): Vcl.Graphics.TBitmap;
var
  Scratch: Vcl.Graphics.TBitmap;
  C: TCanvas;
  Src, Dst: PBgrIcon;
  X, Y, Lum: Integer;
  InkR, InkG, InkB: Byte;
  MaskR, MaskG, MaskB: Byte;
begin
  // Draw onto a scratch bitmap, then transfer into a 24bpp bitmap that uses the
  // mask colour for the paper. That is the same shape the PNG icons are loaded
  // in, and the only form TImageList.AddMasked keys on reliably.
  Scratch := Vcl.Graphics.TBitmap.Create;
  try
    Scratch.PixelFormat := pf24bit;
    Scratch.SetSize(24, 24);
    C := Scratch.Canvas;
    C.Brush.Color := clWhite;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(0, 0, 24, 24));
    C.Pen.Color  := clBlack;
    C.Pen.Width  := 2;
    C.Brush.Color := clBlack;

    // Outline chevrons: the mockup uses line art, not filled media arrows.
    C.Brush.Style := bsClear;
  case AKind of
    ngFirst:
      begin
        C.MoveTo(5, 6);
        C.LineTo(5, 18);
        C.Polyline([Point(16, 6), Point(8, 12), Point(16, 18)]);
      end;
    ngPrev:
      C.Polyline([Point(17, 6), Point(9, 12), Point(17, 18)]);
    ngNext:
      C.Polyline([Point(7, 6), Point(15, 12), Point(7, 18)]);
    ngLast:
      begin
        C.Polyline([Point(8, 6), Point(16, 12), Point(8, 18)]);
        C.MoveTo(19, 6);
        C.LineTo(19, 18);
      end;
    ngGoTo:
      begin
        C.Rectangle(5, 3, 16, 21);
        C.MoveTo(9, 13);
        C.LineTo(19, 13);
        C.Polyline([Point(15, 9), Point(19, 13), Point(15, 17)]);
      end;
    end;

    InkR  := GetRValue(GLYPH_INK);
    InkG  := GetGValue(GLYPH_INK);
    InkB  := GetBValue(GLYPH_INK);
    MaskR := GetRValue(IconMaskColor);
    MaskG := GetGValue(IconMaskColor);
    MaskB := GetBValue(IconMaskColor);

    Result := Vcl.Graphics.TBitmap.Create;
    Result.PixelFormat := pf24bit;
    Result.SetSize(24, 24);
    for Y := 0 to 23 do
    begin
      Src := PBgrIcon(Scratch.ScanLine[Y]);
      Dst := PBgrIcon(Result.ScanLine[Y]);
      for X := 0 to 23 do
      begin
        Lum := (Src.R + Src.G + Src.B) div 3;
        if Lum < 128 then
        begin
          Dst.R := InkR;
          Dst.G := InkG;
          Dst.B := InkB;
        end
        else
        begin
          Dst.R := MaskR;
          Dst.G := MaskG;
          Dst.B := MaskB;
        end;
        Inc(Src);
        Inc(Dst);
      end;
    end;
  finally
    Scratch.Free;
  end;
end;

function TfrmPreview.AddNavGlyph(AKind: TVittixPreviewNavGlyph): Integer;
var
  Bmp: Vcl.Graphics.TBitmap;
begin
  Bmp := CreateNavGlyph(AKind);
  try
    Result := AddMaskedBitmap(ilIcons, Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure TfrmPreview.SetupIcons;
var
  Idx: Integer;
  Btn: TSpeedButton;
  Bmp: Vcl.Graphics.TBitmap;
begin
  // 24bpp + colour-keyed masks, deliberately not cd32Bit:
  //  * AddMasked only honours the colour key below 32bpp, and
  //  * TCustomImageList.DoDraw sends disabled images on a cd32Bit list through
  //    an ILS_SATURATE path that ignores the mask, which paints a black box
  //    behind every disabled button (the navigation buttons on a one page
  //    report are disabled, so this shows up immediately).
  ilIcons.Width        := 24;
  ilIcons.Height       := 24;
  ilIcons.ColorDepth   := cd24Bit;
  ilIcons.DrawingStyle := dsTransparent;
  ilIcons.Clear;

  ilIconsLight.Width        := 24;
  ilIconsLight.Height       := 24;
  ilIconsLight.ColorDepth   := cd24Bit;
  ilIconsLight.DrawingStyle := dsTransparent;
  ilIconsLight.Clear;

  // Point the toolbar buttons at the lists built below.
  for Btn in [btnFirst, btnPrev, btnNext, btnLast, btnGoToPage,
              btnZoomIn, btnZoomOut, btnFitWidth, btnFitPage, btnSavePDF] do
    Btn.Images := ilIcons;
  btnPrint.Images := ilIconsLight;

  // Navigation - drawn glyphs (no matching artwork in the shared set).
  Idx := AddNavGlyph(ngFirst);
  btnFirst.ImageIndex := Idx;
  Idx := AddNavGlyph(ngPrev);
  btnPrev.ImageIndex := Idx;
  Idx := AddNavGlyph(ngNext);
  btnNext.ImageIndex := Idx;
  Idx := AddNavGlyph(ngLast);
  btnLast.ImageIndex := Idx;
  Idx := AddNavGlyph(ngGoTo);
  btnGoToPage.ImageIndex := Idx;

  // Zoom / layout / actions - shared designer PNG icons. AddIcon loads them
  // through a colour-keyed mask, which is what keeps their background
  // transparent (see Vittix.Designer.IconLoader).
  Idx := AddIcon(ilIcons, 'zoom_in');
  btnZoomIn.ImageIndex := Idx;
  Idx := AddIcon(ilIcons, 'zoom_out');
  btnZoomOut.ImageIndex := Idx;
  Idx := AddIcon(ilIcons, 'zoom_fit_width');
  btnFitWidth.ImageIndex := Idx;
  Idx := AddIcon(ilIcons, 'zoom_fit_to_page');
  btnFitPage.ImageIndex := Idx;
  Idx := AddIcon(ilIcons, 'picture_as_pdf');
  btnSavePDF.ImageIndex := Idx;
  // Re-keyed white so the glyph reads on the accented green button.
  Bmp := LoadIconBitmap('print');
  if Bmp <> nil then
  try
    RecolorMaskedIcon(Bmp, clWhite);
    btnPrint.ImageIndex := AddMaskedBitmap(ilIconsLight, Bmp);
  finally
    Bmp.Free;
  end;
end;

{ =========================================================================== }
{  Load / navigation / zoom                                                    }
{ =========================================================================== }

procedure TfrmPreview.LoadReport(AReport: TReportModel; ADataSet: TDataSet);
var
  Rend: TReportRenderer;
  Engine: TReportEngine;
  const
    PreviewWarnThresholdMB = 300;
  var
    PageCount: Integer;
    PageW: Integer;
    PageH: Integer;
    EstimatedBytes: Int64;
    EstimatedMB: Int64;
  StartMs: UInt64;
  ElapsedMs: UInt64;
begin
  FReport := AReport;
  FDataSet := ADataSet;
  if Assigned(AReport) then
    FReportTitle := AReport.Title
  else
    FReportTitle := '';

  // Free previously copied pages before building a new preview set.
  // This keeps memory/GDI pressure lower if rendering fails or is retried.
  Preview.Clear;

  Screen.Cursor := crHourGlass;
  StartMs := GetTickCount64;
  try
    Rend := TReportRenderer.Create;
    try
      Engine := TReportEngine.Create(AReport, ADataSet);
      try
        Engine.Prepare;
        Rend.Render(Engine, AReport.PageSettings.PageWidth, AReport.PageSettings.PageHeight);
      finally
        Engine.Free;
      end;
      PageCount := Rend.Pages.Count;
      Preview.Margins := AReport.PageSettings.Margins;
      if PageCount > 0 then
      begin
        PageW := Rend.Pages[0].Bitmap.Width;
        PageH := Rend.Pages[0].Bitmap.Height;
        if (PageW > 0) and (PageH > 0) then
        begin
          EstimatedBytes := Int64(PageCount) * Int64(PageW) * Int64(PageH) * 4;
          EstimatedMB := EstimatedBytes div (1024 * 1024);
          if EstimatedMB > PreviewWarnThresholdMB then
          begin
            if MessageDlg(
              Format('Preview may use approximately %d MB for %d pages.' + sLineBreak +
                     'Continue loading preview?', [EstimatedMB, PageCount]),
              mtWarning, [mbYes, mbNo], 0) <> mrYes then
            begin
              Preview.Clear;
              UpdateNav;
              SetStatusText('Preview loading cancelled.');
              Exit;
            end;
          end;
        end;
      end;

      Preview.LoadFromRenderer(Rend);
    finally
      Rend.Free;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  // Fit the page to the window. The window is not shown yet, so FAutoFit keeps
  // this re-applied in FormShow / on resize until the user picks a zoom.
  FAutoFit := True;
  Preview.FitPage;

  // The status bar mirrors the mockup, which reports the render time, so this
  // is measured in release builds too (a single GetTickCount64 pair).
  ElapsedMs := GetTickCount64 - StartMs;
  UpdateNav;
  UpdateZoomUI;
  SetStatusText(Format('Ready. (Rendering time: %d ms)', [ElapsedMs]));
  OutputDebugString(PChar(Format('VittixDesigner Preview: %d page(s) rendered in %d ms',
    [Preview.PageCount, ElapsedMs])));
end;

procedure TfrmPreview.UpdateNav;
begin
  btnFirst.Enabled := Preview.CurrentPage > 0;
  btnPrev.Enabled  := Preview.CurrentPage > 0;
  btnNext.Enabled  := (Preview.PageCount > 0) and (Preview.CurrentPage < Preview.PageCount - 1);
  btnLast.Enabled  := (Preview.PageCount > 0) and (Preview.CurrentPage < Preview.PageCount - 1);

  if Preview.PageCount > 0 then
    lblPageInfo.Caption := Format('Page %d of %d', [Preview.CurrentPage + 1, Preview.PageCount])
  else
    lblPageInfo.Caption := 'No pages';

  UpdateDocTitle;
end;

procedure TfrmPreview.UpdateDocTitle;
var
  Title: string;
begin
  Title := Trim(FReportTitle);
  if Title = '' then
    Title := 'Report';

  if Preview.PageCount > 0 then
    lblDocTitle.Caption := Format('Print Preview: %s (Pages 1-%d)', [Title, Preview.PageCount])
  else
    lblDocTitle.Caption := Format('Print Preview: %s (No pages)', [Title]);
end;

procedure TfrmPreview.SetStatusText(const AText: string);
begin
  lblStatusText.Caption := 'Status: ' + AText;
end;

procedure TfrmPreview.UpdateZoomUI;
begin
  lblZoom.Caption     := Format('%d %%', [Preview.ZoomPercent]);
  lblZoomInfo.Caption := Format('Zoom: %d%%', [Preview.ZoomPercent]);

  // Prevent the TrackBar's OnChange from firing back into SetZoomPercent
  // while we are programmatically setting its position.
  FUpdatingZoom := True;
  try
    if Preview.ZoomPercent < trkZoom.Min then
      trkZoom.Position := trkZoom.Min
    else if Preview.ZoomPercent > trkZoom.Max then
      trkZoom.Position := trkZoom.Max
    else
      trkZoom.Position := Preview.ZoomPercent;
  finally
    FUpdatingZoom := False;
  end;
end;

procedure TfrmPreview.PreviewPageChanged(Sender: TObject);
begin
  UpdateNav;
end;

procedure TfrmPreview.PreviewZoomChanged(Sender: TObject);
begin
  UpdateZoomUI;
end;

{ =========================================================================== }
{  Commands                                                                    }
{ =========================================================================== }

procedure TfrmPreview.btnFirstClick(Sender: TObject);
begin
  Preview.GoFirst;
end;

procedure TfrmPreview.btnPrevClick(Sender: TObject);
begin
  Preview.GoPrev;
end;

procedure TfrmPreview.btnNextClick(Sender: TObject);
begin
  Preview.GoNext;
end;

procedure TfrmPreview.btnLastClick(Sender: TObject);
begin
  Preview.GoLast;
end;

procedure TfrmPreview.btnGoToPageClick(Sender: TObject);
var
  S: string;
  PageNo: Integer;
begin
  if Preview.PageCount = 0 then
    Exit;

  S := IntToStr(Preview.CurrentPage + 1);
  if not InputQuery('Go To Page', 'Page number:', S) then
    Exit;
  if not TryStrToInt(Trim(S), PageNo) then
    Exit;
  if (PageNo < 1) or (PageNo > Preview.PageCount) then
  begin
    SetStatusText(Format('Page %d is out of range (1-%d).', [PageNo, Preview.PageCount]));
    Exit;
  end;

  Preview.PageIndex := PageNo - 1;
  UpdateNav;
end;

procedure TfrmPreview.btnZoomInClick(Sender: TObject);
begin
  FAutoFit := False;
  Preview.ZoomIn;
  UpdateZoomUI;
  UpdateNav;
end;

procedure TfrmPreview.btnZoomOutClick(Sender: TObject);
begin
  FAutoFit := False;
  Preview.ZoomOut;
  UpdateZoomUI;
  UpdateNav;
end;

procedure TfrmPreview.btnZoomStepOutClick(Sender: TObject);
begin
  FAutoFit := False;
  if Preview.ZoomPercent > trkZoom.Min then
    Preview.ZoomPercent := Preview.ZoomPercent - 5;
  UpdateZoomUI;
end;

procedure TfrmPreview.btnZoomStepInClick(Sender: TObject);
begin
  FAutoFit := False;
  if Preview.ZoomPercent < trkZoom.Max then
    Preview.ZoomPercent := Preview.ZoomPercent + 5;
  UpdateZoomUI;
end;

procedure TfrmPreview.btnFitWidthClick(Sender: TObject);
begin
  // One-shot: a manual fit choice cancels the automatic fit-page.
  FAutoFit := False;
  Preview.FitWidth;
  UpdateZoomUI;
  UpdateNav;
end;

procedure TfrmPreview.btnFitPageClick(Sender: TObject);
begin
  // Sticky: keeps the whole page in view while the window is resized.
  FAutoFit := True;
  Preview.FitPage;
  UpdateZoomUI;
  UpdateNav;
end;

procedure TfrmPreview.trkZoomChange(Sender: TObject);
begin
  if FUpdatingZoom then
    Exit;
  FAutoFit := False;
  Preview.ZoomPercent := trkZoom.Position;
end;

procedure TfrmPreview.btnPrintClick(Sender: TObject);
begin
  try
    Preview.Print;
  except
    on E: Exception do
      MessageDlg('Print error: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPreview.btnSavePDFClick(Sender: TObject);
var
  Dlg: TSaveDialog;
  Eng: TReportEngine;
begin
  if not Assigned(FReport) then
  begin
    SetStatusText('Nothing to export.');
    Exit;
  end;

  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Filter     := 'PDF Files (*.pdf)|*.pdf|All Files (*.*)|*.*';
    Dlg.DefaultExt := 'pdf';
    Dlg.Title      := 'Export Report to PDF';
    if Trim(FReportTitle) <> '' then
      Dlg.FileName := Trim(FReportTitle) + '.pdf';
    if not Dlg.Execute then
      Exit;

    try
      Screen.Cursor := crHourGlass;
      try
        Eng := TReportEngine.Create(FReport, FDataSet);
        try
          Eng.Prepare;
          if Eng.Pages.Count = 0 then
          begin
            MessageDlg('No pages were generated. Add a MasterData band with objects ' +
              'and ensure a DataSet is assigned.', mtWarning, [mbOK], 0);
            Exit;
          end;
          TReportPDFExporter.ExportToFile(Eng.Pages, Dlg.FileName);
          SetStatusText('Exported to ' + Dlg.FileName);
        finally
          Eng.Free;
        end;
      finally
        Screen.Cursor := crDefault;
      end;
    except
      on E: Exception do
        MessageDlg('PDF export error: ' + E.Message, mtError, [mbOK], 0);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmPreview.btnClosePreviewClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmPreview.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_ESCAPE:
      begin
        Key := 0;
        Close;
      end;
    VK_HOME:
      begin
        Key := 0;
        Preview.GoFirst;
      end;
    VK_END:
      begin
        Key := 0;
        Preview.GoLast;
      end;
    VK_PRIOR:
      begin
        Key := 0;
        Preview.GoPrev;
      end;
    VK_NEXT:
      begin
        Key := 0;
        Preview.GoNext;
      end;
    VK_ADD, VK_OEM_PLUS:
      if ssCtrl in Shift then
      begin
        Key := 0;
        Preview.ZoomIn;
        UpdateZoomUI;
      end;
    VK_SUBTRACT, VK_OEM_MINUS:
      if ssCtrl in Shift then
      begin
        Key := 0;
        Preview.ZoomOut;
        UpdateZoomUI;
      end;
  end;
end;

{ =========================================================================== }
{  Margin-guide switch (drawn, since VCL has no toggle-switch control)         }
{ =========================================================================== }

procedure TfrmPreview.pnlMarginsSwitchClick(Sender: TObject);
begin
  Preview.ShowMarginOverlay := not Preview.ShowMarginOverlay;
  PaintMarginsSwitch;
end;

procedure TfrmPreview.PaintMarginsSwitch;
var
  C   : TCanvas;
  R   : TRect;
  Fill: TColor;
  KnobSize, KnobL, KnobT: Integer;
begin
  C := pnlMarginsSwitch.Canvas;
  R := pnlMarginsSwitch.ClientRect;
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then
    Exit;

  // TPaintBox does not paint a background of its own.
  C.Brush.Style := bsSolid;
  C.Brush.Color := CHROME_TOOLBAR;
  C.FillRect(R);

  if Preview.ShowMarginOverlay then
    Fill := ACCENT_BLUE
  else
    Fill := SWITCH_OFF;

  // Pill
  C.Brush.Style := bsSolid;
  C.Brush.Color := Fill;
  C.Pen.Color   := Fill;
  C.RoundRect(R.Left, R.Top, R.Right, R.Bottom,
    R.Bottom - R.Top, R.Bottom - R.Top);

  // Knob
  KnobSize := (R.Bottom - R.Top) - 6;
  KnobT    := R.Top + 3;
  if Preview.ShowMarginOverlay then
    KnobL := R.Right - 3 - KnobSize
  else
    KnobL := R.Left + 3;

  C.Brush.Color := clWhite;
  C.Pen.Color   := clWhite;
  C.Ellipse(KnobL, KnobT, KnobL + KnobSize, KnobT + KnobSize);
end;

procedure TfrmPreview.pnlMarginsSwitchPaint(Sender: TObject);
begin
  PaintMarginsSwitch;
end;

end.
