unit Frm.Main;

(*
  Frm.Main — Vittix Report Designer  —  Main Application Form
  ============================================================

  Layout
  ------
    ┌─────────────────────────────────────────────────────────────┐
    │  Menu Bar                                                   │
    │  ToolBar  (File | Edit | Insert | Align | View | Report)   │
    │  StatusBar                                                  │
    ├──────────┬──────────────────────────────────┬──────────────┤
    │          │                                  │              │
    │ Toolbox  │   TVittixReportDesigner canvas   │  Properties  │
    │ (left    │        (centre, scrollable)      │  (right      │
    │  panel)  │                                  │   panel)     │
    │          │                                  │              │
    └──────────┴──────────────────────────────────┴──────────────┘

  Panels are resized via splitters.  The toolbox lists every registered
  TReportObject class.  The property panel shows the currently selected
  object's published properties via TReportPropertyBridge + TValueListEditor.
*)

interface

uses
  System.SysUtils, System.Classes, System.Types, System.IOUtils,
  Vcl.Forms, Vcl.Controls, Vcl.ComCtrls, Vcl.ToolWin,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Dialogs,
  Vcl.ValEdit, Vcl.ActnList, Vcl.ActnMan, Vcl.ActnCtrls,
  Vcl.ImgList, Vcl.Graphics, Vcl.Buttons,
  Data.DB, Data.Win.ADODB,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.PageSettings,
  Vittix.Report.Serializer,
  Vittix.Report.DesignerControl,
  Vittix.Report.Toolbox,
  Vittix.Report.PropertyBridge,
  Vittix.Report.Renderer,
  Vittix.Report.Export.PDF,
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Objects.Table, Vcl.Grids,  Vcl.CheckLst,
  System.ImageList,

  RzPanel, RzButton;

type
  TfrmMain = class(TForm)

    { ---- Menus ---- }
    mnuMain        : TMainMenu;
    mnuFile        : TMenuItem;
      mnuNew       : TMenuItem;
      mnuOpen      : TMenuItem;
      mnuSave      : TMenuItem;
      mnuSaveAs    : TMenuItem;
      mnuSep1      : TMenuItem;
      mnuExportPDF : TMenuItem;
      mnuSep2      : TMenuItem;
      mnuExit      : TMenuItem;
    mnuEdit        : TMenuItem;
      mnuUndo      : TMenuItem;
      mnuRedo      : TMenuItem;
      mnuSep3      : TMenuItem;
      mnuCut       : TMenuItem;
      mnuCopy      : TMenuItem;
      mnuPaste     : TMenuItem;
      mnuDelete    : TMenuItem;
      mnuSep4      : TMenuItem;
      mnuSelectAll : TMenuItem;
    mnuInsert      : TMenuItem;
      mnuAddBandTitle   : TMenuItem;
      mnuAddBandHeader  : TMenuItem;
      mnuAddBandData    : TMenuItem;
      mnuAddBandFooter  : TMenuItem;
      mnuAddBandSummary : TMenuItem;
      mnuSep5           : TMenuItem;
    mnuAlign       : TMenuItem;
      mnuAlignLeft  : TMenuItem;
      mnuAlignRight : TMenuItem;
      mnuAlignTop   : TMenuItem;
      mnuAlignBottom: TMenuItem;
      mnuSep6       : TMenuItem;
      mnuSameWidth  : TMenuItem;
      mnuSameHeight : TMenuItem;
      mnuSep7       : TMenuItem;
      mnuCenterH    : TMenuItem;
      mnuCenterV    : TMenuItem;
      mnuSep8       : TMenuItem;
      mnuDistH      : TMenuItem;
      mnuDistV      : TMenuItem;
      mnuSep9       : TMenuItem;
      mnuFront      : TMenuItem;
      mnuBack       : TMenuItem;
    mnuView        : TMenuItem;
      mnuZoomIn     : TMenuItem;
      mnuZoomOut    : TMenuItem;
      mnuZoomReset  : TMenuItem;
      mnuSep10      : TMenuItem;
      mnuShowGrid   : TMenuItem;
      mnuSnapGrid   : TMenuItem;
      mnuShowRulers : TMenuItem;
      mnuShowMargins: TMenuItem;
    mnuReport      : TMenuItem;
      mnuPreview    : TMenuItem;
      mnuPageSetup  : TMenuItem;
      mnuBandMgr    : TMenuItem;
      mnuSep11      : TMenuItem;
      mnuReportProps: TMenuItem;

    { ---- Dialogs ---- }
    dlgOpen   : TOpenDialog;
    dlgSave   : TSaveDialog;

    { ---- Main toolbar ---- }
    ToolBar1  : TToolBar;
    btnNew    : TToolButton;
    btnOpen   : TToolButton;
    btnSave   : TToolButton;
    tbSep1    : TToolButton;
    btnUndo   : TToolButton;
    btnRedo   : TToolButton;
    tbSep2    : TToolButton;
    btnDelete : TToolButton;
    btnCopy   : TToolButton;
    btnPaste  : TToolButton;
    tbSep3    : TToolButton;
    btnAlignLeft  : TToolButton;
    btnAlignRight : TToolButton;
    btnAlignTop   : TToolButton;
    btnAlignBottom: TToolButton;
    tbSep4        : TToolButton;
    btnSameW  : TToolButton;
    btnSameH  : TToolButton;
    tbSep5    : TToolButton;
    btnCenterH: TToolButton;
    btnCenterV: TToolButton;
    tbSep6    : TToolButton;
    btnDistH  : TToolButton;
    btnDistV  : TToolButton;
    tbSep7    : TToolButton;
    btnFront  : TToolButton;
    btnBack   : TToolButton;
    tbSep8    : TToolButton;
    btnZoomIn : TToolButton;
    btnZoomOut: TToolButton;
    tbSep9    : TToolButton;
    btnPreview: TToolButton;

    { ---- Status bar ---- }
    StatusBar1: TStatusBar;

    { ---- Layout ---- }
    pnlOuter     : TPanel;       // fills client area (below toolbar, above statusbar)
    splLeft      : TSplitter;    // between toolbox and canvas
    splRight     : TSplitter;    // between canvas and properties
    pnlToolbox   : TPanel;       // left  — object toolbox
    pnlProperties: TPanel;       // right — property inspector
    pnlCanvas    : TPanel;       // centre — holds scroll box + designer

    { ---- Toolbox ---- }
    lblToolbox   : TLabel;
    Toolbox      : TVittixReportToolbox;

    { ---- Fields panel (below toolbox) ---- }
    pnlFields    : TPanel;
    lblFields    : TLabel;
    lstFields    : TListBox;

    { ---- Property panel ---- }
    lblProperties: TLabel;
    PropEditor   : TValueListEditor;
    btnApplyProps: TButton;

    { ---- Designer canvas in a scroll box ---- }
    ScrollBox1   : TScrollBox;
    Designer     : TVittixReportDesigner;

    { ---- Data access ---- }
    { Drop any TDataSet-descendant (TADOQuery, TFDQuery, etc.) on the form  }
    { and set DataSource1.DataSet to it. The designer will auto-populate    }
    { the Field List panel and enable live preview.                         }
    DataSource1  : TDataSource;

    { ---- Report-info strip inside property panel ---- }
    pnlReportInfo: TPanel;
    lblReportTitle: TLabel;
    edtReportTitle: TEdit;
    lblReportAuthor: TLabel;
    edtReportAuthor: TEdit;
    pnlZoom      : TPanel;
    lblZoom      : TLabel;
    edtZoom      : TEdit;
    btnZoomApply : TButton;
    CheckListBox1: TCheckListBox;
    ImageList1: TImageList;
    RzToolbar1: TRzToolbar;
    btn1: TRzToolButton;

    { ---- Event handlers ---- }

    { File }
    procedure mnuNewClick(Sender: TObject);
    procedure mnuOpenClick(Sender: TObject);
    procedure mnuSaveClick(Sender: TObject);
    procedure mnuSaveAsClick(Sender: TObject);
    procedure mnuExportPDFClick(Sender: TObject);
    procedure mnuExitClick(Sender: TObject);

    { Edit }
    procedure mnuUndoClick(Sender: TObject);
    procedure mnuRedoClick(Sender: TObject);
    procedure mnuCutClick(Sender: TObject);
    procedure mnuCopyClick(Sender: TObject);
    procedure mnuPasteClick(Sender: TObject);
    procedure mnuDeleteClick(Sender: TObject);
    procedure mnuSelectAllClick(Sender: TObject);

    { Insert — add bands }
    procedure mnuAddBandTitleClick(Sender: TObject);
    procedure mnuAddBandHeaderClick(Sender: TObject);
    procedure mnuAddBandDataClick(Sender: TObject);
    procedure mnuAddBandFooterClick(Sender: TObject);
    procedure mnuAddBandSummaryClick(Sender: TObject);

    { Align }
    procedure mnuAlignLeftClick(Sender: TObject);
    procedure mnuAlignRightClick(Sender: TObject);
    procedure mnuAlignTopClick(Sender: TObject);
    procedure mnuAlignBottomClick(Sender: TObject);
    procedure mnuSameWidthClick(Sender: TObject);
    procedure mnuSameHeightClick(Sender: TObject);
    procedure mnuCenterHClick(Sender: TObject);
    procedure mnuCenterVClick(Sender: TObject);
    procedure mnuDistHClick(Sender: TObject);
    procedure mnuDistVClick(Sender: TObject);
    procedure mnuFrontClick(Sender: TObject);
    procedure mnuBackClick(Sender: TObject);

    { View }
    procedure mnuZoomInClick(Sender: TObject);
    procedure mnuZoomOutClick(Sender: TObject);
    procedure mnuZoomResetClick(Sender: TObject);
    procedure mnuShowGridClick(Sender: TObject);
    procedure mnuSnapGridClick(Sender: TObject);
    procedure mnuShowRulersClick(Sender: TObject);
    procedure mnuShowMarginsClick(Sender: TObject);

    { Report }
    procedure mnuPreviewClick(Sender: TObject);
    procedure mnuPageSetupClick(Sender: TObject);
    procedure mnuBandMgrClick(Sender: TObject);
    procedure mnuReportPropsClick(Sender: TObject);

    { Designer events }
    procedure DesignerSelectionChanged(Sender: TObject);
    procedure DesignerModified(Sender: TObject);

    { Toolbox }
    procedure ToolboxToolSelected(Sender: TObject);

    { Property editor }
    procedure btnApplyPropsClick(Sender: TObject);
    procedure PropEditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    { Zoom edit }
    procedure btnZoomApplyClick(Sender: TObject);
    procedure edtZoomKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    { Form lifecycle }
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);

  private
    FCurrentFile: string;
    FModified   : Boolean;

    // Command-line mode: set when launched by the component editor
    FCmdLineInputFile : string;   // file to load on startup
    FCmdLineOutputFile: string;   // file to write on save & close

    procedure BuildInsertMenu;

    procedure UpdateTitleBar;
    procedure UpdateStatusBar;
    procedure UpdateMenuState;
    procedure UpdatePropertyPanel;
    procedure ApplyPropertyPanel;
    procedure ApplyZoom;

    procedure AddBand(ABandType: TReportBandType);
    procedure ConfirmSaveIfModified;
    procedure DynInsertMenuClick(Sender: TObject);

    procedure RefreshFieldList;
    procedure FieldListDblClick(Sender: TObject);
    procedure DesignerDataSetChanged(Sender: TObject);

    function  ZoomFromEdit: Integer;

  public
    property CurrentFile: string  read FCurrentFile;
    property Modified   : Boolean read FModified;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  Winapi.Windows,
  Frm.BandManager,
  Frm.PageSettings,
  Frm.Preview;

function BandTypeName(BT: TReportBandType): string; forward;

{ =========================================================================== }
{  Form lifecycle                                                              }
{ =========================================================================== }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  Splitter: TSplitter;
begin
  // Ensure the Toolbox knows all registered types (including Barcode + Table
  // which self-register in their unit initialization sections)
  Toolbox.RefreshToolList;

  // Wire designer events
  Designer.OnSelectionChanged := DesignerSelectionChanged;
  Designer.OnModified         := DesignerModified;
  Designer.OnDataSetChanged   := DesignerDataSetChanged;

  // Connect the shared DataSource so the designer sees whatever dataset
  // is assigned to DataSource1 at design-time or runtime.
  Designer.DataSource := DataSource1;

  // ---- Build the Fields panel dynamically inside pnlToolbox ----
  pnlFields          := TPanel.Create(Self);
  pnlFields.Parent   := pnlToolbox;
  pnlFields.Align    := alBottom;
  pnlFields.Height   := 160;
  pnlFields.BevelOuter := bvNone;
  pnlFields.Caption  := '';

  lblFields          := TLabel.Create(Self);
  lblFields.Parent   := pnlFields;
  lblFields.Align    := alTop;
  lblFields.Caption  := ' Dataset Fields';
  lblFields.Font.Style := [fsBold];
  lblFields.Height   := 18;

  lstFields          := TListBox.Create(Self);
  lstFields.Parent   := pnlFields;
  lstFields.Align    := alClient;
  lstFields.OnDblClick := FieldListDblClick;
  lstFields.Hint     := 'Double-click a field to insert a bound label into the active band';
  lstFields.ShowHint := True;

  // Splitter between toolbox list and fields panel
  Splitter           := TSplitter.Create(Self);
  Splitter.Parent    := pnlToolbox;
  Splitter.Align     := alBottom;
  Splitter.Height    := 5;

  // File dialogs
  dlgOpen.Filter := 'Vittix Report Files (*.vrt)|*.vrt|All Files (*.*)|*.*';
  dlgOpen.DefaultExt := 'vrt';
  dlgSave.Filter := 'Vittix Report Files (*.vrt)|*.vrt|All Files (*.*)|*.*';
  dlgSave.DefaultExt := 'vrt';

  FCurrentFile := '';
  FModified    := False;

  // Command-line mode: VittixDesigner.exe "input.vrt" "output.vrt"
  // When launched by the component editor, load the input file and
  // remember the output path for Save & Close.
  FCmdLineInputFile  := '';
  FCmdLineOutputFile := '';
  if ParamCount >= 1 then
  begin
    FCmdLineInputFile  := ParamStr(1);
    if ParamCount >= 2 then
      FCmdLineOutputFile := ParamStr(2);

    if TFile.Exists(FCmdLineInputFile) then
    try
      var R := TReportSerializer.LoadFromFile(FCmdLineInputFile);
      Designer.LoadReport(R, True);
      edtReportTitle.Text  := Designer.Report.Title;
      edtReportAuthor.Text := Designer.Report.Author;
    except
      // ignore — start with blank report
    end;
  end;

  RefreshFieldList;
  UpdateTitleBar;
  UpdateStatusBar;
  UpdateMenuState;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  // Designer frees its own TReportModel when it owns it
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := True;

  // Command-line mode: save the report to the output file before closing
  // so the component editor can read it back.
  if FCmdLineOutputFile <> '' then
  begin
    try
      Designer.Report.Title  := edtReportTitle.Text;
      Designer.Report.Author := edtReportAuthor.Text;
      TReportSerializer.SaveToFile(Designer.Report, FCmdLineOutputFile);
    except
      on E: Exception do
        ShowMessage('Could not save report: ' + E.Message);
    end;
    Exit; // skip the normal "save changes?" prompt
  end;

  if FModified then
    ConfirmSaveIfModified;
end;

{ =========================================================================== }
{  File operations                                                             }
{ =========================================================================== }

procedure TfrmMain.mnuNewClick(Sender: TObject);
begin
  ConfirmSaveIfModified;
  Designer.NewReport;
  FCurrentFile := '';
  FModified    := False;
  edtReportTitle.Text  := Designer.Report.Title;
  edtReportAuthor.Text := Designer.Report.Author;
  UpdateTitleBar;
  UpdateMenuState;
end;

procedure TfrmMain.mnuOpenClick(Sender: TObject);
var
  R: TReportModel;
begin
  ConfirmSaveIfModified;
  if not dlgOpen.Execute then Exit;
  try
    R := TReportSerializer.LoadFromFile(dlgOpen.FileName);
    Designer.LoadReport(R, True {take ownership});
    FCurrentFile := dlgOpen.FileName;
    FModified    := False;
    edtReportTitle.Text  := Designer.Report.Title;
    edtReportAuthor.Text := Designer.Report.Author;
    UpdateTitleBar;
    UpdateMenuState;
    StatusBar1.Panels[1].Text := 'Loaded: ' + ExtractFileName(FCurrentFile);
  except
    on E: Exception do
      ShowMessage('Error loading report: ' + E.Message);
  end;
end;

procedure TfrmMain.mnuSaveClick(Sender: TObject);
begin
  if FCurrentFile = '' then
    mnuSaveAsClick(Sender)
  else
  begin
    // Commit report-info edits
    Designer.Report.Title  := edtReportTitle.Text;
    Designer.Report.Author := edtReportAuthor.Text;
    try
      TReportSerializer.SaveToFile(Designer.Report, FCurrentFile);
      FModified := False;
      UpdateTitleBar;
      StatusBar1.Panels[1].Text := 'Saved: ' + ExtractFileName(FCurrentFile);
    except
      on E: Exception do
        ShowMessage('Error saving report: ' + E.Message);
    end;
  end;
end;

procedure TfrmMain.mnuSaveAsClick(Sender: TObject);
begin
  if FCurrentFile <> '' then
    dlgSave.FileName := FCurrentFile;
  if not dlgSave.Execute then Exit;
  FCurrentFile := dlgSave.FileName;
  mnuSaveClick(Sender);
end;

procedure TfrmMain.mnuExportPDFClick(Sender: TObject);
var
  dlgPDF: TSaveDialog;
  Rend  : TReportRenderer;
begin
  dlgPDF := TSaveDialog.Create(nil);
  try
    dlgPDF.Filter     := 'PDF Files (*.pdf)|*.pdf|All Files (*.*)|*.*';
    dlgPDF.DefaultExt := 'pdf';
    dlgPDF.Title      := 'Export Report to PDF';
    if FCurrentFile <> '' then
      dlgPDF.FileName := ChangeFileExt(FCurrentFile, '.pdf');
    if not dlgPDF.Execute then Exit;

    Screen.Cursor := crHourGlass;
    try
      Rend := TReportRenderer.Create;
      try
        Rend.Render(Designer.Report, nil {no live dataset in designer});
        if Rend.Pages.Count = 0 then
        begin
          ShowMessage('No pages were generated. Add a MasterData band with objects and ensure a DataSet is assigned.');
          Exit;
        end;
        // Build a TObjectList<TMetafile> for the exporter
        // (The renderer has TRenderPage wrappers; we need the metafile pages
        //  from the engine — use TReportEngine directly here)
        ShowMessage('PDF export requires a live DataSet connected to the engine. ' +
                    'Connect a DataSet and call the engine from your application code. ' +
                    'The report has been designed and saved; wire it to a TReportEngine for PDF output.');
      finally
        Rend.Free;
      end;
    finally
      Screen.Cursor := crDefault;
    end;
  finally
    dlgPDF.Free;
  end;
end;

procedure TfrmMain.mnuExitClick(Sender: TObject);
begin
  Close;
end;

{ =========================================================================== }
{  Edit operations                                                             }
{ =========================================================================== }

procedure TfrmMain.mnuUndoClick(Sender: TObject);
begin
  Designer.Undo;
  UpdateMenuState;
  UpdatePropertyPanel;
end;

procedure TfrmMain.mnuRedoClick(Sender: TObject);
begin
  Designer.Redo;
  UpdateMenuState;
  UpdatePropertyPanel;
end;

procedure TfrmMain.mnuCutClick(Sender: TObject);
begin
  Designer.CopySelection;
  Designer.DeleteSelected;
end;

procedure TfrmMain.mnuCopyClick(Sender: TObject);
begin
  Designer.CopySelection;
end;

procedure TfrmMain.mnuPasteClick(Sender: TObject);
begin
  Designer.PasteSelection;
end;

procedure TfrmMain.mnuDeleteClick(Sender: TObject);
begin
  Designer.DeleteSelected;
end;

procedure TfrmMain.mnuSelectAllClick(Sender: TObject);
begin
  Designer.SelectAllObjects;
end;

{ =========================================================================== }
{  Insert Band                                                                 }
{ =========================================================================== }

procedure TfrmMain.AddBand(ABandType: TReportBandType);
var
  Band: TReportBand;
begin
  Band := TReportBand.Create;
  Band.BandType := ABandType;
  Band.Height   := 40;
  Designer.Report.Objects.Add(Band);
  Designer.RebuildLayout;
  FModified := True;
  UpdateTitleBar;
  StatusBar1.Panels[1].Text := 'Band added: ' + BandTypeName(ABandType);
end;

function BandTypeName(BT: TReportBandType): string;
begin
  case BT of
    btReportTitle:   Result := 'Report Title';
    btPageHeader:    Result := 'Page Header';
    btMasterData:    Result := 'Master Data';
    btPageFooter:    Result := 'Page Footer';
    btReportSummary: Result := 'Summary';
    btGroupHeader:   Result := 'Group Header';
    btGroupFooter:   Result := 'Group Footer';
    btColumnHeader:  Result := 'Column Header';
    btDetail:        Result := 'Detail';
    btOverlay:       Result := 'Overlay';
  else
    Result := 'Band';
  end;
end;

procedure TfrmMain.mnuAddBandTitleClick(Sender: TObject);
begin AddBand(btReportTitle);   end;

procedure TfrmMain.mnuAddBandHeaderClick(Sender: TObject);
begin AddBand(btPageHeader);    end;

procedure TfrmMain.mnuAddBandDataClick(Sender: TObject);
begin AddBand(btMasterData);    end;

procedure TfrmMain.mnuAddBandFooterClick(Sender: TObject);
begin AddBand(btPageFooter);    end;

procedure TfrmMain.mnuAddBandSummaryClick(Sender: TObject);
begin AddBand(btReportSummary); end;

{ =========================================================================== }
{  Align / Z-order                                                             }
{ =========================================================================== }

procedure TfrmMain.mnuAlignLeftClick(Sender: TObject);   begin Designer.AlignLeft;    end;
procedure TfrmMain.mnuAlignRightClick(Sender: TObject);  begin Designer.AlignRight;   end;
procedure TfrmMain.mnuAlignTopClick(Sender: TObject);    begin Designer.AlignTop;     end;
procedure TfrmMain.mnuAlignBottomClick(Sender: TObject); begin Designer.AlignBottom;  end;
procedure TfrmMain.mnuSameWidthClick(Sender: TObject);   begin Designer.SameWidth;    end;
procedure TfrmMain.mnuSameHeightClick(Sender: TObject);  begin Designer.SameHeight;   end;
procedure TfrmMain.mnuCenterHClick(Sender: TObject);     begin Designer.CenterH;      end;
procedure TfrmMain.mnuCenterVClick(Sender: TObject);     begin Designer.CenterV;      end;
procedure TfrmMain.mnuDistHClick(Sender: TObject);       begin Designer.DistributeH;  end;
procedure TfrmMain.mnuDistVClick(Sender: TObject);       begin Designer.DistributeV;  end;
procedure TfrmMain.mnuFrontClick(Sender: TObject);       begin Designer.BringToFront; end;
procedure TfrmMain.mnuBackClick(Sender: TObject);        begin Designer.SendToBack;   end;

{ =========================================================================== }
{  View / Zoom                                                                 }
{ =========================================================================== }

procedure TfrmMain.mnuZoomInClick(Sender: TObject);
begin
  Designer.ZoomIn;
  edtZoom.Text := IntToStr(Designer.Zoom);
end;

procedure TfrmMain.mnuZoomOutClick(Sender: TObject);
begin
  Designer.ZoomOut;
  edtZoom.Text := IntToStr(Designer.Zoom);
end;

procedure TfrmMain.mnuZoomResetClick(Sender: TObject);
begin
  Designer.ZoomReset;
  edtZoom.Text := '100';
end;

procedure TfrmMain.mnuShowGridClick(Sender: TObject);
begin
  Designer.ShowGrid    := not Designer.ShowGrid;
  mnuShowGrid.Checked  := Designer.ShowGrid;
end;

procedure TfrmMain.mnuSnapGridClick(Sender: TObject);
begin
  Designer.SnapToGrid  := not Designer.SnapToGrid;
  mnuSnapGrid.Checked  := Designer.SnapToGrid;
end;

procedure TfrmMain.mnuShowRulersClick(Sender: TObject);
begin
  Designer.ShowRulers   := not Designer.ShowRulers;
  mnuShowRulers.Checked := Designer.ShowRulers;
end;

procedure TfrmMain.mnuShowMarginsClick(Sender: TObject);
begin
  Designer.ShowMargins   := not Designer.ShowMargins;
  mnuShowMargins.Checked := Designer.ShowMargins;
end;

procedure TfrmMain.ApplyZoom;
var Z: Integer;
begin
  Z := ZoomFromEdit;
  if Z > 0 then
  begin
    Designer.Zoom := Z;
    edtZoom.Text  := IntToStr(Designer.Zoom);
  end;
end;

function TfrmMain.ZoomFromEdit: Integer;
begin
  Result := StrToIntDef(Trim(edtZoom.Text), 0);
end;

procedure TfrmMain.btnZoomApplyClick(Sender: TObject);
begin ApplyZoom; end;

procedure TfrmMain.edtZoomKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    ApplyZoom;
    Key := 0;
  end;
end;

{ =========================================================================== }
{  Report menu                                                                 }
{ =========================================================================== }

procedure TfrmMain.mnuPreviewClick(Sender: TObject);
var
  Frm: TfrmPreview;
begin
  Frm := TfrmPreview.Create(Application);
  try
    Frm.LoadReport(Designer.Report);
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TfrmMain.mnuPageSetupClick(Sender: TObject);
var
  Frm: TfrmPageSettings;
begin
  Frm := TfrmPageSettings.Create(Application);
  try
    Frm.LoadSettings(Designer.Report.PageSettings);
    if Frm.ShowModal = mrOk then
    begin
      Frm.SaveSettings(Designer.Report.PageSettings);
      Designer.RebuildLayout;
      FModified := True;
      UpdateTitleBar;
    end;
  finally
    Frm.Free;
  end;
end;

procedure TfrmMain.mnuBandMgrClick(Sender: TObject);
var
  Frm: TfrmBandManager;
begin
  Frm := TfrmBandManager.Create(Application);
  try
    Frm.LoadReport(Designer.Report);
    if Frm.ShowModal = mrOk then
    begin
      Designer.RebuildLayout;
      FModified := True;
      UpdateTitleBar;
    end;
  finally
    Frm.Free;
  end;
end;

procedure TfrmMain.mnuReportPropsClick(Sender: TObject);
begin
  // Focus the report-info strip in the right panel
  edtReportTitle.SetFocus;
end;

{ =========================================================================== }
{  Designer events                                                             }
{ =========================================================================== }

procedure TfrmMain.DesignerSelectionChanged(Sender: TObject);
begin
  UpdatePropertyPanel;
  UpdateMenuState;
end;

procedure TfrmMain.DesignerModified(Sender: TObject);
begin
  FModified := True;
  UpdateTitleBar;
  UpdateMenuState;
  UpdateStatusBar;
end;

{ =========================================================================== }
{  Toolbox                                                                     }
{ =========================================================================== }

procedure TfrmMain.ToolboxToolSelected(Sender: TObject);
var
  Cls: TReportObjectClass;
begin
  Cls := Toolbox.SelectedObjectClass;
  if Assigned(Cls) then
  begin
    Designer.BeginInsertObject(Cls);
    StatusBar1.Panels[1].Text :=
      'Insert mode: click inside a band to place a ' + Cls.DisplayName;
  end;
end;

{ =========================================================================== }
{  Property panel                                                              }
{ =========================================================================== }

procedure TfrmMain.UpdatePropertyPanel;
var
  Obj: TReportObject;
begin
  Obj := Designer.PrimarySelected;
  TReportPropertyBridge.LoadObjectToGrid(Obj, PropEditor);
  if Assigned(Obj) then
    lblProperties.Caption := 'Properties  —  ' + Obj.ClassName
  else
    lblProperties.Caption := 'Properties';
end;

procedure TfrmMain.ApplyPropertyPanel;
var
  Obj: TReportObject;
begin
  Obj := Designer.PrimarySelected;
  if not Assigned(Obj) then Exit;
  TReportPropertyBridge.SaveGridToObject(Obj, PropEditor);
  Designer.RebuildLayout;   // repaint with new property values
  FModified := True;
  UpdateTitleBar;
end;

procedure TfrmMain.btnApplyPropsClick(Sender: TObject);
begin
  ApplyPropertyPanel;
end;

procedure TfrmMain.PropEditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    ApplyPropertyPanel;
    Key := 0;
  end;
end;

{ =========================================================================== }
{  UI state helpers                                                            }
{ =========================================================================== }

procedure TfrmMain.UpdateTitleBar;
var
  Title: string;
begin
  Title := 'Vittix Report Designer';
  if FCurrentFile <> '' then
    Title := Title + '  —  ' + ExtractFileName(FCurrentFile);
  if FModified then
    Title := Title + ' *';
  Caption := Title;
end;

procedure TfrmMain.UpdateStatusBar;
var
  SelCount: Integer;
begin
  SelCount := Designer.SelectedCount;

  if SelCount = 0 then
    StatusBar1.Panels[0].Text := 'No selection'
  else if SelCount = 1 then
  begin
    var Obj := Designer.PrimarySelected;
    if Assigned(Obj) then
      StatusBar1.Panels[0].Text :=
        Obj.ClassName + '  at (' +
        IntToStr(Obj.Bounds.Left) + ', ' + IntToStr(Obj.Bounds.Top) + ')  ' +
        IntToStr(Obj.Bounds.Width) + ' × ' + IntToStr(Obj.Bounds.Height)
    else
      StatusBar1.Panels[0].Text := '1 object selected';
  end
  else
    StatusBar1.Panels[0].Text := IntToStr(SelCount) + ' objects selected';
end;

procedure TfrmMain.UpdateMenuState;
var
  HasSel: Boolean;
  Multi : Boolean;
begin
  HasSel := Designer.SelectedCount > 0;
  Multi  := Designer.SelectedCount >= 2;

  mnuUndo.Enabled    := Designer.CanUndo;
  mnuRedo.Enabled    := Designer.CanRedo;
  btnUndo.Enabled    := Designer.CanUndo;
  btnRedo.Enabled    := Designer.CanRedo;

  mnuCut.Enabled    := HasSel;
  mnuCopy.Enabled   := HasSel;
  mnuDelete.Enabled := HasSel;
  btnDelete.Enabled := HasSel;
  btnCopy.Enabled   := HasSel;

  mnuAlignLeft.Enabled   := Multi;
  mnuAlignRight.Enabled  := Multi;
  mnuAlignTop.Enabled    := Multi;
  mnuAlignBottom.Enabled := Multi;
  mnuSameWidth.Enabled   := Multi;
  mnuSameHeight.Enabled  := Multi;
  btnAlignLeft.Enabled   := Multi;
  btnAlignRight.Enabled  := Multi;
  btnAlignTop.Enabled    := Multi;
  btnAlignBottom.Enabled := Multi;
  btnSameW.Enabled       := Multi;
  btnSameH.Enabled       := Multi;

  mnuCenterH.Enabled := HasSel;
  mnuCenterV.Enabled := HasSel;
  btnCenterH.Enabled := HasSel;
  btnCenterV.Enabled := HasSel;

  mnuDistH.Enabled := Designer.SelectedCount >= 3;
  mnuDistV.Enabled := Designer.SelectedCount >= 3;
  btnDistH.Enabled := Designer.SelectedCount >= 3;
  btnDistV.Enabled := Designer.SelectedCount >= 3;

  mnuFront.Enabled := HasSel;
  mnuBack.Enabled  := HasSel;
  btnFront.Enabled := HasSel;
  btnBack.Enabled  := HasSel;

  mnuShowGrid.Checked    := Designer.ShowGrid;
  mnuSnapGrid.Checked    := Designer.SnapToGrid;
  mnuShowRulers.Checked  := Designer.ShowRulers;
  mnuShowMargins.Checked := Designer.ShowMargins;

  UpdateStatusBar;
end;

procedure TfrmMain.ConfirmSaveIfModified;
begin
  if not FModified then Exit;
  case MessageDlg('The report has unsaved changes. Save now?',
                  mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes:    mnuSaveClick(nil);
    mrCancel: Abort;
  end;
end;

{ =========================================================================== }
{  BuildLayout  — called from DFM (all layout is done in DFM)                 }
{ =========================================================================== }

procedure TfrmMain.DynInsertMenuClick(Sender: TObject);
var
  Cls: TReportObjectClass;
begin
  Cls := TReportObjectClass(TMenuItem(Sender).Tag);
  Designer.BeginInsertObject(Cls);
  StatusBar1.Panels[1].Text :=
    'Insert mode — click inside a band to place a ' + Cls.DisplayName;
end;

{ =========================================================================== }
{  Dataset / Field list                                                        }
{ =========================================================================== }

procedure TfrmMain.RefreshFieldList;
var
  Names: TArray<string>;
  N    : string;
begin
  lstFields.Items.BeginUpdate;
  try
    lstFields.Items.Clear;
    Names := Designer.GetFieldNames;
    for N in Names do
      lstFields.Items.Add(N);
  finally
    lstFields.Items.EndUpdate;
  end;

  if lstFields.Items.Count = 0 then
    lblFields.Caption := ' Dataset Fields  (none)'
  else
    lblFields.Caption := Format(' Dataset Fields  (%d)', [lstFields.Items.Count]);
end;

procedure TfrmMain.FieldListDblClick(Sender: TObject);
var
  FieldName: string;
begin
  if lstFields.ItemIndex < 0 then Exit;
  FieldName := lstFields.Items[lstFields.ItemIndex];
  if not Designer.InsertFieldObject(FieldName) then
    ShowMessage('Please click a band on the canvas first to set the active band, then double-click a field.');
end;

procedure TfrmMain.DesignerDataSetChanged(Sender: TObject);
begin
  RefreshFieldList;
end;

procedure TfrmMain.BuildInsertMenu;
var
  C  : TReportObjectClass;
  MI : TMenuItem;
begin
  // Dynamically add one menu item per registered object class
  for C in GetRegisteredReportObjects do
  begin
    MI := TMenuItem.Create(mnuInsert);
    MI.Caption := 'Insert ' + C.DisplayName;
    MI.Tag     := NativeInt(C);
    MI.OnClick := DynInsertMenuClick;
    mnuInsert.Add(MI);
  end;
end;

end.