unit Frm.Preview;

(*
  Frm.Preview — Print Preview Window
  =====================================
  Hosts TVittixReportPreview inside a modal dialog with:
    • First / Prev / Next / Last page navigation toolbar
    • Zoom in / out / fit controls
    • Page counter label
    • "Print" button (wired to Preview.Print)
    • "Export PDF" note

  Rendering: passes the report through TReportRenderer, which runs the
  engine against a nil dataset (design-time preview — no live data).
  For live data, call LoadReport(Report, DataSet) before ShowModal.
*)

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.Buttons, Vcl.Dialogs,
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.Renderer,
  Vittix.Report.Preview;

type
  TfrmPreview = class(TForm)
    pnlTop      : TPanel;
    lblPrevTitle: TLabel;
    ToolBar1    : TToolBar;
    btnFirst    : TToolButton;
    btnPrev     : TToolButton;
    btnNext     : TToolButton;
    btnLast     : TToolButton;
    tbSep1      : TToolButton;
    btnZoomIn   : TToolButton;
    btnZoomOut  : TToolButton;
    btnFitWidth : TToolButton;
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
    procedure btnZoomInClick(Sender: TObject);
    procedure btnZoomOutClick(Sender: TObject);
    procedure btnFitWidthClick(Sender: TObject);
    procedure btnPrintClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure PreviewPageChanged(Sender: TObject);

  private
    procedure UpdateNav;

  public
    procedure LoadReport(AReport: TReportModel; ADataSet: TDataSet = nil);
  end;

implementation

{$R *.dfm}

procedure TfrmPreview.FormCreate(Sender: TObject);
begin
  Preview.OnPageChanged := PreviewPageChanged;
  UpdateNav;
end;

procedure TfrmPreview.FormDestroy(Sender: TObject);
begin
  // TVittixReportPreview owns its pages
end;

procedure TfrmPreview.LoadReport(AReport: TReportModel; ADataSet: TDataSet);
var
  Rend: TReportRenderer;
begin
  Screen.Cursor := crHourGlass;
  try
    Rend := TReportRenderer.Create;
    try
      Rend.Render(AReport, ADataSet);
      Preview.LoadFromRenderer(Rend);
    finally
      Rend.Free;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  UpdateNav;
  StatusBar1.SimpleText :=
    Format('%d page(s) rendered', [Preview.PageCount]);
end;

procedure TfrmPreview.UpdateNav;
begin
  btnFirst.Enabled := Preview.CurrentPage > 1;
  btnPrev.Enabled  := Preview.CurrentPage > 1;
  btnNext.Enabled  := Preview.CurrentPage < Preview.PageCount;
  btnLast.Enabled  := Preview.CurrentPage < Preview.PageCount;

  if Preview.PageCount > 0 then
    lblPageInfo.Caption :=
      Format('Page %d / %d', [Preview.CurrentPage, Preview.PageCount])
  else
    lblPageInfo.Caption := 'No pages';
end;

procedure TfrmPreview.PreviewPageChanged(Sender: TObject);
begin
  UpdateNav;
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
