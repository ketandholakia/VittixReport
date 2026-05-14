unit Frm.Main;

(*
  Frm.Main — Vittix Report Designer  —  Main Application Form
  ============================================================

  Layout
  ------
    +-------------------------------------------------------------+
    ¦  Menu Bar                                                   ¦
    ¦  ToolBar  (File | Edit | Insert | Align | View | Report)   ¦
    ¦  StatusBar                                                  ¦
    +------------------------------------------------------------¦
    ¦          ¦                                  ¦              ¦
    ¦ Toolbox  ¦   TVittixReportDesigner canvas   ¦  Properties  ¦
    ¦ (left    ¦        (centre, scrollable)      ¦  (right      ¦
    ¦  panel)  ¦                                  ¦   panel)     ¦
    ¦          ¦                                  ¦              ¦
    +------------------------------------------------------------+

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
  Datasnap.DBClient,
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
  System.ImageList;

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

    { ---- Property panel ---- }
    lblProperties: TLabel;
    PropEditor   : TValueListEditor;
    btnApplyProps: TButton;

    { ---- Designer canvas in a scroll box ---- }
    ScrollBox1   : TScrollBox;

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
    procedure mnuCreateSimpleSampleReportClick(Sender: TObject);
    procedure mnuCreateSampleGroupedReportClick(Sender: TObject);
    procedure mnuCreateCanGrowRemarksTestReportClick(Sender: TObject);
    procedure mnuCreateBarcodeTestReportClick(Sender: TObject);
    procedure mnuCreateImagePathTestReportClick(Sender: TObject);

    { Designer events }
    procedure DesignerSelectionChanged(Sender: TObject);
    procedure DesignerModified(Sender: TObject);

    { Toolbox }
    procedure ToolboxToolSelected(Sender: TObject);

    { Property editor }
    procedure btnApplyPropsClick(Sender: TObject);
    procedure PropEditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PropEditorDblClick(Sender: TObject);

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
    // Created dynamically in FormCreate (not streamed from DFM)
    FDesigner   : TVittixReportDesigner;
    FDataSource1: TDataSource;
    FPnlFields  : TPanel;
    FLblFields  : TLabel;
    FLstFields  : TListBox;
    FSampleDataSet: TClientDataSet;

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
    function  AddTextObject(ABand: TReportBand; const AText: string; X, Y, W, H: Integer): TReportTextObject;
    function  AddFieldObject(ABand: TReportBand; const AFieldName: string; X, Y, W, H: Integer): TReportFieldObject;
    function  PrepareForSampleTemplate(const APrompt: string): Integer;
    procedure FinalizeSampleTemplate(const AStatus: string);
    procedure BuildSimpleSampleReport;
    procedure BuildGroupedSampleReport;
    procedure BuildCanGrowRemarksTestReport;
    procedure BuildBarcodeTestReport;
    procedure BuildImagePathTestReport;
    procedure ConfirmSaveIfModified;
    procedure DynInsertMenuClick(Sender: TObject);
    procedure DynAddBandMenuClick(Sender: TObject);

    procedure RefreshFieldList;
    procedure FieldListDblClick(Sender: TObject);
    procedure DesignerDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure DesignerDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure DesignerDataSetChanged(Sender: TObject);
    procedure CreateSampleDataSet;
    procedure ReloadSampleDataSet;
    procedure UseSampleDataSet;

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
  MICreateImagePathTestReport: TMenuItem;
  MICreateBarcodeTestReport: TMenuItem;
  MICreateCanGrowRemarksTestReport: TMenuItem;
  MICreateSampleGroupedReport: TMenuItem;
  MICreateSimpleSampleReport: TMenuItem;
begin
  // Defensive registration for command-line open mode.
  // Some environments can start with an incomplete registry; ensure bands
  // always deserialize from ReportJSON.
  RegisterReportObject(TReportBand);

  // Designer control is created at runtime (not streamed from DFM).
  FDesigner := TVittixReportDesigner.Create(Self);
  FDesigner.Parent := ScrollBox1;
  FDesigner.Left := 16;
  FDesigner.Top := 16;
  FDesigner.Width := 1200;
  FDesigner.Height := 1600;
  FDataSource1 := TDataSource.Create(Self);

  // Ensure the Toolbox knows all registered types (including Barcode + Table
  // which self-register in their unit initialization sections)
  Toolbox.RefreshToolList;
  BuildInsertMenu;

  // ---- Build the Fields panel dynamically inside pnlToolbox ----
  FPnlFields          := TPanel.Create(Self);
  FPnlFields.Parent   := pnlToolbox;
  FPnlFields.Align    := alBottom;
  FPnlFields.Height   := 160;
  FPnlFields.BevelOuter := bvNone;
  FPnlFields.Caption  := '';

  FLblFields          := TLabel.Create(Self);
  FLblFields.Parent   := FPnlFields;
  FLblFields.Align    := alTop;
  FLblFields.Caption  := ' Dataset Fields';
  FLblFields.Font.Style := [fsBold];
  FLblFields.Height   := 18;

  FLstFields          := TListBox.Create(Self);
  FLstFields.Parent   := FPnlFields;
  FLstFields.Align    := alClient;
  FLstFields.OnDblClick := FieldListDblClick;
  FLstFields.DragMode := dmAutomatic;
  FLstFields.Hint     := 'Double-click or drag a field into a band to insert a bound label';
  FLstFields.ShowHint := True;

  // Splitter between toolbox list and fields panel
  Splitter           := TSplitter.Create(Self);
  Splitter.Parent    := pnlToolbox;
  Splitter.Align     := alBottom;
  Splitter.Height    := 5;

  // Wire designer events
  FDesigner.OnSelectionChanged := DesignerSelectionChanged;
  FDesigner.OnModified         := DesignerModified;
  FDesigner.OnDataSetChanged   := DesignerDataSetChanged;
  FDesigner.OnDragOver         := DesignerDragOver;
  FDesigner.OnDragDrop         := DesignerDragDrop;
  PropEditor.OnDblClick        := PropEditorDblClick;

  // Connect the shared DataSource so the designer sees whatever dataset
  // is assigned at runtime.
  FDesigner.DataSource := FDataSource1;
  CreateSampleDataSet;
  UseSampleDataSet;

  // File dialogs
  dlgOpen.Filter := 'Vittix Report Files (*.vrt)|*.vrt|All Files (*.*)|*.*';
  dlgOpen.DefaultExt := 'vrt';
  dlgSave.Filter := 'Vittix Report Files (*.vrt)|*.vrt|All Files (*.*)|*.*';
  dlgSave.DefaultExt := 'vrt';

  FCurrentFile := '';
  FModified    := False;

  // Command-line mode: VittixDesigner.exe "<input>" "<output>"
  // When launched by the component editor, load the input file and
  // remember the output path for Save & Close.
  FCmdLineInputFile  := '';
  FCmdLineOutputFile := '';
  if ParamCount >= 1 then
  begin
    FCmdLineInputFile  := ParamStr(1);
    if ParamCount >= 2 then
      FCmdLineOutputFile := ParamStr(2);

    if (FCmdLineInputFile <> '') and TFile.Exists(FCmdLineInputFile) then
    try
      var JSON := TFile.ReadAllText(FCmdLineInputFile, TEncoding.UTF8);
      if Trim(JSON) <> '' then
      begin
        var R: TReportModel := nil;
        try
          R := TReportSerializer.LoadFromJSON(JSON);
        except
          // Backward-compatible fallback if input was passed as a file format
          // expected by LoadFromFile.
          R := TReportSerializer.LoadFromFile(FCmdLineInputFile);
        end;
        if Assigned(R) then
        begin
          FDesigner.LoadReport(R, True);
          edtReportTitle.Text  := FDesigner.Report.Title;
          edtReportAuthor.Text := FDesigner.Report.Author;
        end;
      end;
    except
      // ignore — start with blank report
    end;
  end;

  RefreshFieldList;
  UpdateTitleBar;
  UpdateStatusBar;
  UpdateMenuState;

  MICreateImagePathTestReport := TMenuItem.Create(Self);
  MICreateImagePathTestReport.Caption := 'Create ImagePath Test Report';
  MICreateImagePathTestReport.OnClick := mnuCreateImagePathTestReportClick;
  mnuReport.Insert(0, MICreateImagePathTestReport);

  MICreateBarcodeTestReport := TMenuItem.Create(Self);
  MICreateBarcodeTestReport.Caption := 'Create Barcode Test Report';
  MICreateBarcodeTestReport.OnClick := mnuCreateBarcodeTestReportClick;
  mnuReport.Insert(0, MICreateBarcodeTestReport);

  MICreateCanGrowRemarksTestReport := TMenuItem.Create(Self);
  MICreateCanGrowRemarksTestReport.Caption := 'Create CanGrow Remarks Test Report';
  MICreateCanGrowRemarksTestReport.OnClick := mnuCreateCanGrowRemarksTestReportClick;
  mnuReport.Insert(0, MICreateCanGrowRemarksTestReport);

  MICreateSampleGroupedReport := TMenuItem.Create(Self);
  MICreateSampleGroupedReport.Caption := 'Create Grouped Sample Report';
  MICreateSampleGroupedReport.OnClick := mnuCreateSampleGroupedReportClick;
  mnuReport.Insert(0, MICreateSampleGroupedReport);

  MICreateSimpleSampleReport := TMenuItem.Create(Self);
  MICreateSimpleSampleReport.Caption := 'Create Simple Sample Report';
  MICreateSimpleSampleReport.OnClick := mnuCreateSimpleSampleReportClick;
  mnuReport.Insert(0, MICreateSimpleSampleReport);
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
      FDesigner.Report.Title  := edtReportTitle.Text;
      FDesigner.Report.Author := edtReportAuthor.Text;
      // Write JSON (not .vrt format) so the component editor can read it
      // back directly into TVittixReport.ReportJSON
      TFile.WriteAllText(FCmdLineOutputFile,
        TReportSerializer.SaveToJSON(FDesigner.Report),
        TEncoding.UTF8);
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
  FDesigner.NewReport;
  FCurrentFile := '';
  FModified    := False;
  edtReportTitle.Text  := FDesigner.Report.Title;
  edtReportAuthor.Text := FDesigner.Report.Author;
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
    FDesigner.LoadReport(R, True {take ownership});
    FCurrentFile := dlgOpen.FileName;
    FModified    := False;
    edtReportTitle.Text  := FDesigner.Report.Title;
    edtReportAuthor.Text := FDesigner.Report.Author;
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
    FDesigner.Report.Title  := edtReportTitle.Text;
    FDesigner.Report.Author := edtReportAuthor.Text;
    try
      TReportSerializer.SaveToFile(FDesigner.Report, FCurrentFile);
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
        Rend.Render(FDesigner.Report, nil {no live dataset in designer});
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
  FDesigner.Undo;
  UpdateMenuState;
  UpdatePropertyPanel;
end;

procedure TfrmMain.mnuRedoClick(Sender: TObject);
begin
  FDesigner.Redo;
  UpdateMenuState;
  UpdatePropertyPanel;
end;

procedure TfrmMain.mnuCutClick(Sender: TObject);
begin
  FDesigner.CopySelection;
  FDesigner.DeleteSelected;
end;

procedure TfrmMain.mnuCopyClick(Sender: TObject);
begin
  FDesigner.CopySelection;
end;

procedure TfrmMain.mnuPasteClick(Sender: TObject);
begin
  FDesigner.PasteSelection;
end;

procedure TfrmMain.mnuDeleteClick(Sender: TObject);
begin
  FDesigner.DeleteSelected;
end;

procedure TfrmMain.mnuSelectAllClick(Sender: TObject);
begin
  FDesigner.SelectAllObjects;
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
  FDesigner.Report.Objects.Add(Band);
  FDesigner.RebuildLayout;
  FModified := True;
  UpdateTitleBar;
  StatusBar1.Panels[1].Text := 'Band added: ' + BandTypeName(ABandType);
end;

function TfrmMain.AddTextObject(ABand: TReportBand; const AText: string; X, Y, W, H: Integer): TReportTextObject;
begin
  Result := TReportTextObject.Create;
  Result.Bounds := Rect(X, Y, X + W, Y + H);
  Result.Text := AText;
  ABand.Children.Add(Result);
end;

function TfrmMain.AddFieldObject(ABand: TReportBand; const AFieldName: string; X, Y, W, H: Integer): TReportFieldObject;
begin
  Result := TReportFieldObject.Create;
  Result.Bounds := Rect(X, Y, X + W, Y + H);
  Result.DataField := AFieldName;
  Result.Text := '[' + AFieldName + ']';
  ABand.Children.Add(Result);
end;

function TfrmMain.PrepareForSampleTemplate(const APrompt: string): Integer;
var
  I: Integer;
begin
  ConfirmSaveIfModified;
  if (FDesigner.Report.Objects.Count > 0) or FModified then
    if MessageDlg(APrompt, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Abort;

  UseSampleDataSet;
  FDesigner.NewReport;
  FCurrentFile := '';
  FModified := True;

  FDesigner.Report.FieldNames.Clear;
  for I := 0 to FSampleDataSet.FieldDefs.Count - 1 do
    FDesigner.Report.FieldNames.Add(FSampleDataSet.FieldDefs[I].Name);

  FDesigner.Report.DataSetNames.Clear;
  FDesigner.Report.DataSetNames.Add('MainData');

  Result := FDesigner.Report.PageSettings.PageWidth;
  if Result <= 0 then
    Result := 793;
end;

procedure TfrmMain.FinalizeSampleTemplate(const AStatus: string);
begin
  FDesigner.RebuildLayout;
  RefreshFieldList;
  UpdateTitleBar;
  UpdateMenuState;
  UpdateStatusBar;
  StatusBar1.Panels[1].Text := AStatus;
end;

procedure TfrmMain.BuildSimpleSampleReport;
var
  TitleBand, MasterBand: TReportBand;
  Obj: TReportTextObject;
  BandRight: Integer;
begin
  BandRight := PrepareForSampleTemplate('This will replace the current report with a simple sample layout. Continue?');
  TitleBand := TReportBand.Create;
  TitleBand.BandType := btReportTitle;
  TitleBand.Bounds := Rect(0, 0, BandRight, 46);
  TitleBand.Height := 46;
  Obj := AddTextObject(TitleBand, 'Simple Sample Report', 12, 10, 260, 20);
  Obj.Font.Style := [fsBold];
  FDesigner.Report.Objects.Add(TitleBand);

  MasterBand := TReportBand.Create;
  MasterBand.BandType := btMasterData;
  MasterBand.Bounds := Rect(0, 0, BandRight, 24);
  MasterBand.Height := 24;
  AddFieldObject(MasterBand, 'CustomerName', 12, 3, 150, 18);
  AddFieldObject(MasterBand, 'ItemName', 168, 3, 170, 18);
  AddFieldObject(MasterBand, 'Qty', 344, 3, 45, 18);
  AddFieldObject(MasterBand, 'Rate', 394, 3, 80, 18);
  AddFieldObject(MasterBand, 'Amount', 479, 3, 90, 18);
  FDesigner.Report.Objects.Add(MasterBand);
  FinalizeSampleTemplate('Simple sample report created');
end;

procedure TfrmMain.BuildGroupedSampleReport;
var
  TitleBand, GroupHeader, MasterBand: TReportBand;
  Obj: TReportTextObject;
  BandRight: Integer;
begin
  BandRight := PrepareForSampleTemplate('This will replace the current report with a grouped sample layout. Continue?');
  TitleBand := TReportBand.Create;
  TitleBand.BandType := btReportTitle;
  TitleBand.Bounds := Rect(0, 0, BandRight, 50);
  TitleBand.Height := 50;
  Obj := AddTextObject(TitleBand, 'Grouped Sample Report', 12, 10, 260, 24);
  Obj.Font.Style := [fsBold];
  FDesigner.Report.Objects.Add(TitleBand);

  GroupHeader := TReportBand.Create;
  GroupHeader.BandType := btGroupHeader;
  GroupHeader.Bounds := Rect(0, 0, BandRight, 28);
  GroupHeader.Height := 28;
  GroupHeader.GroupField := 'GroupName';
  Obj := AddFieldObject(GroupHeader, 'GroupName', 12, 4, 220, 18);
  Obj.Font.Style := [fsBold];
  FDesigner.Report.Objects.Add(GroupHeader);

  MasterBand := TReportBand.Create;
  MasterBand.BandType := btMasterData;
  MasterBand.Bounds := Rect(0, 0, BandRight, 24);
  MasterBand.Height := 24;
  AddFieldObject(MasterBand, 'CustomerName', 12, 3, 160, 18);
  AddFieldObject(MasterBand, 'ItemName', 180, 3, 160, 18);
  AddFieldObject(MasterBand, 'Qty', 350, 3, 50, 18);
  AddFieldObject(MasterBand, 'Amount', 410, 3, 90, 18);
  FDesigner.Report.Objects.Add(MasterBand);
  FinalizeSampleTemplate('Grouped sample report created');
end;

procedure TfrmMain.BuildCanGrowRemarksTestReport;
var
  TitleBand, MasterBand: TReportBand;
  Obj: TReportTextObject;
  FieldObj: TReportFieldObject;
  BandRight: Integer;
begin
  BandRight := PrepareForSampleTemplate('This will replace the current report with a CanGrow remarks test layout. Continue?');
  TitleBand := TReportBand.Create;
  TitleBand.BandType := btReportTitle;
  TitleBand.Bounds := Rect(0, 0, BandRight, 46);
  TitleBand.Height := 46;
  Obj := AddTextObject(TitleBand, 'CanGrow Remarks Test Report', 12, 10, 300, 20);
  Obj.Font.Style := [fsBold];
  FDesigner.Report.Objects.Add(TitleBand);

  MasterBand := TReportBand.Create;
  MasterBand.BandType := btMasterData;
  MasterBand.Bounds := Rect(0, 0, BandRight, 60);
  MasterBand.Height := 60;
  MasterBand.CanGrow := True;
  AddFieldObject(MasterBand, 'CustomerName', 12, 3, 170, 18);
  FieldObj := AddFieldObject(MasterBand, 'Remarks', 12, 24, BandRight - 32, 30);
  FieldObj.WordWrap := True;
  FieldObj.AutoSize := False;
  FDesigner.Report.Objects.Add(MasterBand);
  FinalizeSampleTemplate('CanGrow remarks test report created');
end;

procedure TfrmMain.BuildBarcodeTestReport;
var
  TitleBand, MasterBand: TReportBand;
  Obj: TReportTextObject;
  BarcodeObj: TReportBarcodeObject;
  BandRight: Integer;
begin
  BandRight := PrepareForSampleTemplate('This will replace the current report with a barcode test layout. Continue?');
  TitleBand := TReportBand.Create;
  TitleBand.BandType := btReportTitle;
  TitleBand.Bounds := Rect(0, 0, BandRight, 46);
  TitleBand.Height := 46;
  Obj := AddTextObject(TitleBand, 'Barcode Test Report', 12, 10, 240, 20);
  Obj.Font.Style := [fsBold];
  FDesigner.Report.Objects.Add(TitleBand);

  MasterBand := TReportBand.Create;
  MasterBand.BandType := btMasterData;
  MasterBand.Bounds := Rect(0, 0, BandRight, 64);
  MasterBand.Height := 64;
  AddFieldObject(MasterBand, 'CustomerName', 12, 3, 180, 18);
  BarcodeObj := TReportBarcodeObject.Create;
  BarcodeObj.Bounds := Rect(200, 3, 520, 56);
  BarcodeObj.DataField := 'BarcodeValue';
  MasterBand.Children.Add(BarcodeObj);
  FDesigner.Report.Objects.Add(MasterBand);
  FinalizeSampleTemplate('Barcode test report created');
end;

procedure TfrmMain.BuildImagePathTestReport;
var
  TitleBand, MasterBand: TReportBand;
  Obj: TReportTextObject;
  ImageObj: TReportImageObject;
  BandRight: Integer;
begin
  BandRight := PrepareForSampleTemplate('This will replace the current report with an image path test layout. Continue?');
  TitleBand := TReportBand.Create;
  TitleBand.BandType := btReportTitle;
  TitleBand.Bounds := Rect(0, 0, BandRight, 46);
  TitleBand.Height := 46;
  Obj := AddTextObject(TitleBand, 'ImagePath Test Report', 12, 10, 260, 20);
  Obj.Font.Style := [fsBold];
  FDesigner.Report.Objects.Add(TitleBand);

  MasterBand := TReportBand.Create;
  MasterBand.BandType := btMasterData;
  MasterBand.Bounds := Rect(0, 0, BandRight, 64);
  MasterBand.Height := 64;
  AddFieldObject(MasterBand, 'CustomerName', 12, 3, 180, 18);
  ImageObj := TReportImageObject.Create;
  ImageObj.Bounds := Rect(200, 3, 300, 58);
  ImageObj.DataField := 'ImagePath';
  MasterBand.Children.Add(ImageObj);
  FDesigner.Report.Objects.Add(MasterBand);
  FinalizeSampleTemplate('Image path test report created');
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

procedure TfrmMain.mnuAlignLeftClick(Sender: TObject);   begin FDesigner.AlignLeft;    end;
procedure TfrmMain.mnuAlignRightClick(Sender: TObject);  begin FDesigner.AlignRight;   end;
procedure TfrmMain.mnuAlignTopClick(Sender: TObject);    begin FDesigner.AlignTop;     end;
procedure TfrmMain.mnuAlignBottomClick(Sender: TObject); begin FDesigner.AlignBottom;  end;
procedure TfrmMain.mnuSameWidthClick(Sender: TObject);   begin FDesigner.SameWidth;    end;
procedure TfrmMain.mnuSameHeightClick(Sender: TObject);  begin FDesigner.SameHeight;   end;
procedure TfrmMain.mnuCenterHClick(Sender: TObject);     begin FDesigner.CenterH;      end;
procedure TfrmMain.mnuCenterVClick(Sender: TObject);     begin FDesigner.CenterV;      end;
procedure TfrmMain.mnuDistHClick(Sender: TObject);       begin FDesigner.DistributeH;  end;
procedure TfrmMain.mnuDistVClick(Sender: TObject);       begin FDesigner.DistributeV;  end;
procedure TfrmMain.mnuFrontClick(Sender: TObject);       begin FDesigner.BringToFront; end;
procedure TfrmMain.mnuBackClick(Sender: TObject);        begin FDesigner.SendToBack;   end;

{ =========================================================================== }
{  View / Zoom                                                                 }
{ =========================================================================== }

procedure TfrmMain.mnuZoomInClick(Sender: TObject);
begin
  FDesigner.ZoomIn;
  edtZoom.Text := IntToStr(FDesigner.Zoom);
end;

procedure TfrmMain.mnuZoomOutClick(Sender: TObject);
begin
  FDesigner.ZoomOut;
  edtZoom.Text := IntToStr(FDesigner.Zoom);
end;

procedure TfrmMain.mnuZoomResetClick(Sender: TObject);
begin
  FDesigner.ZoomReset;
  edtZoom.Text := '100';
end;

procedure TfrmMain.mnuShowGridClick(Sender: TObject);
begin
  FDesigner.ShowGrid    := not FDesigner.ShowGrid;
  mnuShowGrid.Checked  := FDesigner.ShowGrid;
end;

procedure TfrmMain.mnuSnapGridClick(Sender: TObject);
begin
  FDesigner.SnapToGrid  := not FDesigner.SnapToGrid;
  mnuSnapGrid.Checked  := FDesigner.SnapToGrid;
end;

procedure TfrmMain.mnuShowRulersClick(Sender: TObject);
begin
  FDesigner.ShowRulers   := not FDesigner.ShowRulers;
  mnuShowRulers.Checked := FDesigner.ShowRulers;
end;

procedure TfrmMain.mnuShowMarginsClick(Sender: TObject);
begin
  FDesigner.ShowMargins   := not FDesigner.ShowMargins;
  mnuShowMargins.Checked := FDesigner.ShowMargins;
end;

procedure TfrmMain.ApplyZoom;
var Z: Integer;
begin
  Z := ZoomFromEdit;
  if Z > 0 then
  begin
    FDesigner.Zoom := Z;
    edtZoom.Text  := IntToStr(FDesigner.Zoom);
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
    Frm.LoadReport(FDesigner.Report);
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
    Frm.LoadSettings(FDesigner.Report.PageSettings);
    if Frm.ShowModal = mrOk then
    begin
      Frm.SaveSettings(FDesigner.Report.PageSettings);
      FDesigner.RebuildLayout;
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
    Frm.LoadReport(FDesigner.Report);
    if Frm.ShowModal = mrOk then
    begin
      FDesigner.RebuildLayout;
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

procedure TfrmMain.mnuCreateSimpleSampleReportClick(Sender: TObject);
begin
  BuildSimpleSampleReport;
end;

procedure TfrmMain.mnuCreateSampleGroupedReportClick(Sender: TObject);
begin
  BuildGroupedSampleReport;
end;

procedure TfrmMain.mnuCreateCanGrowRemarksTestReportClick(Sender: TObject);
begin
  BuildCanGrowRemarksTestReport;
end;

procedure TfrmMain.mnuCreateBarcodeTestReportClick(Sender: TObject);
begin
  BuildBarcodeTestReport;
end;

procedure TfrmMain.mnuCreateImagePathTestReportClick(Sender: TObject);
begin
  BuildImagePathTestReport;
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
    FDesigner.BeginInsertObject(Cls);
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
  Obj := FDesigner.PrimarySelected;
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
  Obj := FDesigner.PrimarySelected;
  if not Assigned(Obj) then Exit;
  TReportPropertyBridge.SaveGridToObject(Obj, PropEditor);
  FDesigner.RebuildLayout;   // repaint with new property values
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

procedure TfrmMain.PropEditorDblClick(Sender: TObject);
var
  Obj: TReportObject;
  RowKey: string;
  Dlg: TFontDialog;
begin
  if (PropEditor.Row < 0) or (PropEditor.Row >= PropEditor.RowCount) then
    Exit;

  RowKey := PropEditor.Keys[PropEditor.Row];
  if not SameText(RowKey, 'Font') then
    Exit;

  Obj := FDesigner.PrimarySelected;
  if not (Obj is TReportTextObject) then
    Exit;

  Dlg := TFontDialog.Create(Self);
  try
    Dlg.Font.Assign(TReportTextObject(Obj).Font);
    if not Dlg.Execute then
      Exit;

    TReportTextObject(Obj).Font.Assign(Dlg.Font);
    FDesigner.RebuildLayout;
    FModified := True;
    UpdateTitleBar;
    UpdatePropertyPanel;
  finally
    Dlg.Free;
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
  SelCount := FDesigner.SelectedCount;

  if SelCount = 0 then
    StatusBar1.Panels[0].Text := 'No selection'
  else if SelCount = 1 then
  begin
    var Obj := FDesigner.PrimarySelected;
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
  HasSel := FDesigner.SelectedCount > 0;
  Multi  := FDesigner.SelectedCount >= 2;

  mnuUndo.Enabled    := FDesigner.CanUndo;
  mnuRedo.Enabled    := FDesigner.CanRedo;
  btnUndo.Enabled    := FDesigner.CanUndo;
  btnRedo.Enabled    := FDesigner.CanRedo;

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

  mnuDistH.Enabled := FDesigner.SelectedCount >= 3;
  mnuDistV.Enabled := FDesigner.SelectedCount >= 3;
  btnDistH.Enabled := FDesigner.SelectedCount >= 3;
  btnDistV.Enabled := FDesigner.SelectedCount >= 3;

  mnuFront.Enabled := HasSel;
  mnuBack.Enabled  := HasSel;
  btnFront.Enabled := HasSel;
  btnBack.Enabled  := HasSel;

  mnuShowGrid.Checked    := FDesigner.ShowGrid;
  mnuSnapGrid.Checked    := FDesigner.SnapToGrid;
  mnuShowRulers.Checked  := FDesigner.ShowRulers;
  mnuShowMargins.Checked := FDesigner.ShowMargins;

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
  FDesigner.BeginInsertObject(Cls);
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
  // FormCreate can trigger dataset notifications before this panel exists.
  if not Assigned(FLstFields) or not Assigned(FLblFields) then
    Exit;

  FLstFields.Items.BeginUpdate;
  try
    FLstFields.Items.Clear;
    Names := FDesigner.GetFieldNames;
    for N in Names do
      FLstFields.Items.Add(N);
  finally
    FLstFields.Items.EndUpdate;
  end;

  if FLstFields.Items.Count = 0 then
    FLblFields.Caption := ' Dataset Fields  (none)'
  else
    FLblFields.Caption := Format(' Dataset Fields  (%d)', [FLstFields.Items.Count]);
end;

procedure TfrmMain.FieldListDblClick(Sender: TObject);
var
  FieldName: string;
begin
  if FLstFields.ItemIndex < 0 then Exit;
  FieldName := FLstFields.Items[FLstFields.ItemIndex];
  if not FDesigner.InsertFieldObject(FieldName) then
    ShowMessage('Please click a band on the canvas first to set the active band, then double-click a field.');
end;

procedure TfrmMain.DesignerDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  Accept := (Source = FLstFields) and (FLstFields.ItemIndex >= 0);
end;

procedure TfrmMain.DesignerDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  FieldName: string;
begin
  if Source <> FLstFields then Exit;
  if FLstFields.ItemIndex < 0 then Exit;

  FieldName := FLstFields.Items[FLstFields.ItemIndex];
  if not FDesigner.InsertFieldObjectAt(FieldName, X, Y) then
    ShowMessage('Drop the field inside a band area.');
end;

procedure TfrmMain.DesignerDataSetChanged(Sender: TObject);
begin
  RefreshFieldList;
end;

procedure TfrmMain.CreateSampleDataSet;
begin
  if Assigned(FSampleDataSet) then
    Exit;

  FSampleDataSet := TClientDataSet.Create(Self);
  with FSampleDataSet.FieldDefs do
  begin
    Clear;
    Add('CustomerName', ftString, 80);
    Add('InvoiceNo', ftString, 30);
    Add('InvoiceDate', ftDate);
    Add('ItemName', ftString, 80);
    Add('Qty', ftInteger);
    Add('Rate', ftCurrency);
    Add('Amount', ftCurrency);
    Add('GroupName', ftString, 40);
    Add('ImagePath', ftString, 260);
    Add('BarcodeValue', ftString, 80);
    Add('Remarks', ftMemo);
  end;
  FSampleDataSet.CreateDataSet;
end;

procedure TfrmMain.ReloadSampleDataSet;
begin
  CreateSampleDataSet;
  FSampleDataSet.DisableControls;
  try
    FSampleDataSet.EmptyDataSet;
    FSampleDataSet.AppendRecord(['Acme Retail', 'INV-1001', EncodeDate(2026, 1, 3), 'A4 Paper Ream', 5, 120.50, 602.50, 'Office Supplies', 'D:\test\sample.bmp', '890123450001', 'Urgent delivery requested for the head office stock refill.']);
    FSampleDataSet.AppendRecord(['Acme Retail', 'INV-1002', EncodeDate(2026, 1, 5), 'Laser Toner Black', 2, 1850.00, 3700.00, 'Office Supplies', '', '890123450002', 'Handle with care during transport and avoid stacking near heat sources.']);
    FSampleDataSet.AppendRecord(['Northwind Foods', 'INV-1003', EncodeDate(2026, 1, 7), 'Cold Storage Box', 3, 760.75, 2282.25, 'Logistics', 'D:\test\sample.bmp', '890123450003', 'Keep dry']);
    FSampleDataSet.AppendRecord(['Northwind Foods', 'INV-1004', EncodeDate(2026, 1, 10), 'Barcode Labels', 12, 45.00, 540.00, 'Logistics', '', '890123450004', 'Batch A']);
  finally
    FSampleDataSet.EnableControls;
  end;
  FSampleDataSet.First;
end;

procedure TfrmMain.UseSampleDataSet;
begin
  ReloadSampleDataSet;
  FDataSource1.DataSet := FSampleDataSet;
  FDesigner.DataSet := FSampleDataSet;
  RefreshFieldList;
end;

procedure TfrmMain.BuildInsertMenu;
var
  C, ExistingClass: TReportObjectClass;
  MI : TMenuItem;
  I  : Integer;
  BT : TReportBandType;
  Exists: Boolean;
begin
  // Remove previously generated dynamic items.
  for I := mnuInsert.Count - 1 downto 0 do
    if SameText(mnuInsert.Items[I].Hint, 'dynobj') or
       SameText(mnuInsert.Items[I].Hint, 'dynband') then
      mnuInsert.Delete(I);

  // Add missing band menu entries so all runtime band types are reachable.
  for BT := Low(TReportBandType) to High(TReportBandType) do
  begin
    if BT in [btReportTitle, btPageHeader, btMasterData, btPageFooter, btReportSummary] then
      Continue; // already declared statically in DFM

    Exists := False;
    for I := 0 to mnuInsert.Count - 1 do
      if SameText(mnuInsert.Items[I].Caption, 'Band: ' + BandTypeName(BT)) then
      begin
        Exists := True;
        Break;
      end;

    if not Exists then
    begin
      MI := TMenuItem.Create(mnuInsert);
      MI.Caption := 'Band: ' + BandTypeName(BT);
      MI.Tag     := Ord(BT);
      MI.Hint    := 'dynband';
      MI.OnClick := DynAddBandMenuClick;
      mnuInsert.Insert(mnuInsert.IndexOf(mnuSep5), MI);
    end;
  end;

  // Dynamically add one menu item per registered object class
  for C in GetRegisteredReportObjects do
  begin
    // Bands are added through "Band: ..." entries; do not show as canvas object.
    if C.InheritsFrom(TReportBand) then
      Continue;

    // Skip duplicates if a class with same DisplayName is already present.
    Exists := False;
    for I := 0 to mnuInsert.Count - 1 do
      if SameText(mnuInsert.Items[I].Hint, 'dynobj') then
      begin
        ExistingClass := TReportObjectClass(mnuInsert.Items[I].Tag);
        if Assigned(ExistingClass) and SameText(ExistingClass.DisplayName, C.DisplayName) then
        begin
          Exists := True;
          Break;
        end;
      end;
    if Exists then
      Continue;

    MI := TMenuItem.Create(mnuInsert);
    MI.Caption := 'Insert ' + C.DisplayName;
    MI.Tag     := NativeInt(C);
    MI.Hint    := 'dynobj';
    MI.OnClick := DynInsertMenuClick;
    mnuInsert.Add(MI);
  end;
end;

procedure TfrmMain.DynAddBandMenuClick(Sender: TObject);
begin
  AddBand(TReportBandType(TMenuItem(Sender).Tag));
end;

end.

