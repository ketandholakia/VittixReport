unit Frm.Preview;

(*
  Frm.Preview - Print Preview Window
  =====================================
  Hosts TVittixReportPreview inside a modal dialog with:
    * First / Prev / Next / Last page navigation toolbar
    * Zoom In / Zoom Out / Fit Width / Fit Page buttons
    * Zoom slider (TTrackBar, 10-400%) and zoom percent label
    * Page counter label
    * "Print" button (wired to Preview.Print)

  Rendering: passes the report through TReportRenderer, which runs the
  engine against a nil dataset (design-time preview - no live data).
  For live data, call LoadReport(Report, DataSet) before ShowModal.
*)

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.Buttons, Vcl.Dialogs,
  Data.DB,
  Vittix.Report.Engine,
  Vittix.Report.Model,
  Vittix.Report.Renderer,
  Vittix.Report.Preview, Vcl.ToolWin;

type
  TfrmPreview = class(TForm)
    pnlTop      : TPanel;
    lblPrevTitle: TLabel;
    ToolBar1    : TToolBar;
    btnFirst    : TToolButton;
    btnPrev     : TToolButton;
    btnNext     : TToolButton;
    btnLast     : TToolButton;
    btnGoToPage : TToolButton;
    tbSep1      : TToolButton;
    btnZoomIn   : TToolButton;
    btnZoomOut  : TToolButton;
    btnFitWidth : TToolButton;
    btnFitPage  : TToolButton;
    tbSepZoom   : TToolButton;
    trkZoom     : TTrackBar;
    lblZoom     : TLabel;
    tbSep2      : TToolButton;
    lblPageInfo : TLabel;
    tbSep3      : TToolButton;
    btnPrint    : TToolButton;
    btnClose    : TButton;
    Preview     : TVittixReportPreview;
    StatusBar1  : TStatusBar;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnFirstClick(Sender: TObject);
    procedure btnPrevClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnLastClick(Sender: TObject);
    procedure btnGoToPageClick(Sender: TObject);
    procedure btnZoomInClick(Sender: TObject);
    procedure btnZoomOutClick(Sender: TObject);
    procedure btnFitWidthClick(Sender: TObject);
    procedure btnFitPageClick(Sender: TObject);
    procedure trkZoomChange(Sender: TObject);
    procedure btnPrintClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure PreviewPageChanged(Sender: TObject);
    procedure PreviewZoomChanged(Sender: TObject);

  private
    FUpdatingZoom: Boolean;
    procedure UpdateNav;
    procedure UpdateZoomUI;

  public
    procedure LoadReport(AReport: TReportModel; ADataSet: TDataSet = nil);
  end;

implementation

{$R *.dfm}

uses
  Winapi.Windows;

procedure TfrmPreview.FormCreate(Sender: TObject);
begin
  Preview.OnPageChanged := PreviewPageChanged;
  Preview.OnZoomChanged := PreviewZoomChanged;
  FUpdatingZoom := False;
  UpdateNav;
  UpdateZoomUI;
end;

procedure TfrmPreview.FormDestroy(Sender: TObject);
begin
  // Release copied preview page bitmaps as early as possible.
  Preview.Clear;
end;

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
{$IFDEF DEBUG}
  StartMs: UInt64;
  ElapsedMs: UInt64;
{$ENDIF}
begin
  // Free previously copied pages before building a new preview set.
  // This keeps memory/GDI pressure lower if rendering fails or is retried.
  Preview.Clear;

  Screen.Cursor := crHourGlass;
{$IFDEF DEBUG}
  StartMs := GetTickCount64;
{$ENDIF}
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
              StatusBar1.SimpleText := 'Preview loading cancelled.';
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

  // Apply fit-page by default so the first page always fills the window.
  Preview.FitPage;

{$IFDEF DEBUG}
  ElapsedMs := GetTickCount64 - StartMs;
  UpdateNav;
  UpdateZoomUI;
  StatusBar1.SimpleText := Format('%d page(s) rendered in %d ms', [Preview.PageCount, ElapsedMs]);
  OutputDebugString(PChar(Format('VittixDesigner Preview: %d page(s) rendered in %d ms',
    [Preview.PageCount, ElapsedMs])));
{$ELSE}
  UpdateNav;
  UpdateZoomUI;
  StatusBar1.SimpleText := Format('%d page(s) rendered', [Preview.PageCount]);
{$ENDIF}
end;

procedure TfrmPreview.UpdateNav;
begin
  btnFirst.Enabled := Preview.CurrentPage > 0;
  btnPrev.Enabled  := Preview.CurrentPage > 0;
  btnNext.Enabled  := (Preview.PageCount > 0) and (Preview.CurrentPage < Preview.PageCount - 1);
  btnLast.Enabled  := (Preview.PageCount > 0) and (Preview.CurrentPage < Preview.PageCount - 1);

  if Preview.PageCount > 0 then
    lblPageInfo.Caption :=
      Format('Page %d / %d', [Preview.CurrentPage + 1, Preview.PageCount])
  else
    lblPageInfo.Caption := 'No pages';
end;

procedure TfrmPreview.UpdateZoomUI;
begin
  lblZoom.Caption := Format('%d %%', [Preview.ZoomPercent]);

  // Prevent the TrackBar's OnChange from firing back into SetZoomPercent
  // while we are programmatically setting its position.
  FUpdatingZoom := True;
  try
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

  Preview.PageIndex := PageNo - 1;
  UpdateNav;
end;

procedure TfrmPreview.btnZoomInClick(Sender: TObject);
begin
  Preview.ZoomIn;
  UpdateNav;
end;

procedure TfrmPreview.btnZoomOutClick(Sender: TObject);
begin
  Preview.ZoomOut;
  UpdateNav;
end;

procedure TfrmPreview.btnFitWidthClick(Sender: TObject);
begin
  Preview.FitWidth;
  UpdateNav;
end;

procedure TfrmPreview.btnFitPageClick(Sender: TObject);
begin
  Preview.FitPage;
  UpdateNav;
end;

procedure TfrmPreview.trkZoomChange(Sender: TObject);
begin
  if FUpdatingZoom then Exit;
  Preview.ZoomPercent := trkZoom.Position;
end;

procedure TfrmPreview.btnPrintClick(Sender: TObject);
begin
  try
    Preview.Print;
  except
    on E: Exception do
      ShowMessage('Print error: ' + E.Message);
  end;
end;

procedure TfrmPreview.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
