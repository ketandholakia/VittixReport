unit MainForm;
(*
  VittixReport Full-Featured Demo
  ================================
  Demonstrates the complete VittixReport designer workflow:

  Layout
  ------
  [Toolbar]
  [Toolbox | Designer  | Preview ]
  [        | DataGrid  |         ]
  [StatusBar]

  Features shown
  --------------
  * Full menu (File / Edit / Insert / Band / Format / View / Report / Help)
  * Toolbar with all common actions + zoom combo
  * TVittixReportToolbox  click a tool, then click on the designer to place
  * TVittixReportDesigner with rulers, grid, snap, undo/redo
  * Live preview pane that rebuilds after every report change
  * In-memory TClientDataSet (Orders) with 20 sample rows
  * Sample report built programmatically on startup
  * Load / Save .vrt report files
  * Export to PDF
  * Band insertion via Band menu
  * All format alignment/distribution/z-order commands
  * Status bar showing selection count and current zoom
*)

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Types,
  Vcl.Controls, Vcl.Forms, Vcl.Menus, Vcl.ComCtrls, Vcl.ToolWin,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids, Vcl.DBGrids, Vcl.Dialogs, Vcl.Graphics,
  Data.DB, Datasnap.DBClient,
  Vittix.Report.Model, Vittix.Report.Bands, Vittix.Report.Objects,
  Vittix.Report.DesignerControl, Vittix.Report.Toolbox,
  Vittix.Report.Engine, Vittix.Report.Renderer,
  Vittix.Report.Preview, Vittix.Report.Serializer,
  Vittix.Report.Export.PDF;

type
  TfrmMain = class(TForm)
  private
    { -- Layout controls -- }
    FMainMenu   : TMainMenu;
    FToolBar    : TToolBar;
    FStatusBar  : TStatusBar;
    FPnlLeft    : TPanel;
    FPnlRight   : TPanel;
    FSplLeft    : TSplitter;
    FSplRight   : TSplitter;
    FPnlCenter  : TPanel;
    FPnlDesigner: TPanel;
    FSplH       : TSplitter;
    FPnlGrid    : TPanel;

    { -- Report controls -- }
    FToolbox  : TVittixReportToolbox;
    FDesigner : TVittixReportDesigner;
    FPreview  : TVittixReportPreview;
    FGrid     : TDBGrid;

    { -- Data -- }
    FCDS : TClientDataSet;
    FDS  : TDataSource;

    { -- Renderer -- }
    FRenderer : TReportRenderer;

    { -- Property panel -- }
    FPropGrid : TStringGrid;
    FPropObj  : TReportObject;   // object currently shown in the property grid

    { -- Toolbar buttons -- }
    FBtnNew, FBtnOpen, FBtnSave       : TToolButton;
    FBtnUndo, FBtnRedo                : TToolButton;
    FBtnDelete                        : TToolButton;
    FBtnSelectAll                     : TToolButton;
    FBtnBringFront, FBtnSendBack      : TToolButton;
    FBtnAlignLeft, FBtnAlignRight     : TToolButton;
    FBtnAlignTop, FBtnAlignBottom     : TToolButton;
    FBtnCenterH, FBtnCenterV          : TToolButton;
    FBtnZoomOut, FBtnZoomIn, FBtnZoom100: TToolButton;
    FBtnBuild                         : TToolButton;
    FZoomCombo                        : TComboBox;
    FBtnInsert                        : TToolButton;

    { -- Menu items needing runtime access -- }
    FMnuUndo, FMnuRedo         : TMenuItem;
    FMnuShowRulers             : TMenuItem;
    FMnuShowGrid               : TMenuItem;
    FMnuShowMargins            : TMenuItem;
    FMnuPreviewPane            : TMenuItem;
    FMnuDataPane               : TMenuItem;

    { -- Dialogs -- }
    FDlgOpen : TOpenDialog;
    FDlgSave : TSaveDialog;

    { -- State -- }
    FCurrentFile: string;
    FPreviewVisible: Boolean;
    FDataVisible   : Boolean;

    { -- Setup -- }
    procedure BuildLayout;
    procedure BuildMenu;
    procedure BuildToolbar;
    procedure BuildSampleData;
    procedure BuildSampleReport;
    procedure BuildPreview;

    { -- Data helpers -- }
    procedure RefreshPreview;
    procedure UpdateStatusBar;
    procedure UpdateUndoRedo;
    procedure SetCurrentFile(const FN: string);

    { -- Event handlers: File -- }
    procedure MnuNewClick(Sender: TObject);
    procedure MnuOpenClick(Sender: TObject);
    procedure MnuSaveClick(Sender: TObject);
    procedure MnuSaveAsClick(Sender: TObject);
    procedure MnuExportPDFClick(Sender: TObject);
    procedure MnuExitClick(Sender: TObject);

    { -- Event handlers: Edit -- }
    procedure MnuUndoClick(Sender: TObject);
    procedure MnuRedoClick(Sender: TObject);
    procedure MnuDeleteClick(Sender: TObject);
    procedure MnuSelectAllClick(Sender: TObject);
    procedure MnuCopyClick(Sender: TObject);
    procedure MnuPasteClick(Sender: TObject);

    { -- Event handlers: Band -- }
    procedure MnuAddBandClick(Sender: TObject);

    { -- Event handlers: Format -- }
    procedure MnuAlignLeftClick(Sender: TObject);
    procedure MnuAlignRightClick(Sender: TObject);
    procedure MnuAlignTopClick(Sender: TObject);
    procedure MnuAlignBottomClick(Sender: TObject);
    procedure MnuSameWidthClick(Sender: TObject);
    procedure MnuSameHeightClick(Sender: TObject);
    procedure MnuDistHClick(Sender: TObject);
    procedure MnuDistVClick(Sender: TObject);
    procedure MnuCenterHClick(Sender: TObject);
    procedure MnuCenterVClick(Sender: TObject);
    procedure MnuBringFrontClick(Sender: TObject);
    procedure MnuSendBackClick(Sender: TObject);

    { -- Event handlers: View -- }
    procedure MnuShowRulersClick(Sender: TObject);
    procedure MnuShowGridClick(Sender: TObject);
    procedure MnuShowMarginsClick(Sender: TObject);
    procedure MnuZoomInClick(Sender: TObject);
    procedure MnuZoomOutClick(Sender: TObject);
    procedure MnuZoomResetClick(Sender: TObject);
    procedure MnuPreviewPaneClick(Sender: TObject);
    procedure MnuDataPaneClick(Sender: TObject);

    { -- Event handlers: Report -- }
    procedure MnuBuildClick(Sender: TObject);

    { -- Event handlers: Help -- }
    procedure MnuAboutClick(Sender: TObject);

    { -- Designer events -- }
    procedure DesignerModified(Sender: TObject);
    procedure DesignerSelectionChanged(Sender: TObject);

    { -- Toolbox event -- }
    procedure ToolboxToolSelected(Sender: TObject);

    { -- Property grid -- }
    procedure PopulatePropertyGrid;
    procedure PropGridSetEditText(Sender: TObject; ACol, ARow: Integer;
      const Value: string);

    { -- Zoom combo -- }
    procedure ZoomComboChange(Sender: TObject);

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  frmMain: TfrmMain;

implementation

uses
  System.StrUtils, System.TypInfo, System.Variants, System.Math;

{ ============================================================================
  Helper: create menu item
  ============================================================================ }

function MI(AOwner: TComponent; const ACaption: string;
  AOnClick: TNotifyEvent = nil; AShortCut: TShortCut = 0): TMenuItem;
begin
  Result := TMenuItem.Create(AOwner);
  Result.Caption  := ACaption;
  Result.OnClick  := AOnClick;
  Result.ShortCut := AShortCut;
end;

function Sep(AOwner: TComponent): TMenuItem;
begin
  Result := TMenuItem.Create(AOwner);
  Result.Caption := '-';
end;

{ ============================================================================
  Constructor / Destructor
  ============================================================================ }

constructor TfrmMain.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption    := 'VittixReport Full-Featured Demo';
  Width      := 1280;
  Height     := 800;
  WindowState:= wsMaximized;
  Color      := clBtnFace;

  FPreviewVisible := True;
  FDataVisible    := True;

  BuildLayout;
  BuildMenu;
  BuildToolbar;
  BuildSampleData;
  BuildSampleReport;
  RefreshPreview;
  UpdateStatusBar;
end;

destructor TfrmMain.Destroy;
begin
  FRenderer.Free;
  inherited;
end;

{ ============================================================================
  Layout
  ============================================================================ }

procedure TfrmMain.BuildLayout;
begin
  { ---- Status bar ---- }
  FStatusBar := TStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.SimplePanel := False;
  FStatusBar.Panels.Add.Width := 300;  // selection info
  FStatusBar.Panels.Add.Width := 150;  // zoom
  FStatusBar.Panels.Add.Width := 200;  // file name
  FStatusBar.Panels[0].Text := 'Ready';
  FStatusBar.Panels[1].Text := 'Zoom: 100%';
  FStatusBar.Panels[2].Text := 'Unsaved report';

  { ---- Left panel: Toolbox ---- }
  FPnlLeft := TPanel.Create(Self);
  FPnlLeft.Parent := Self;
  FPnlLeft.Align  := alLeft;
  FPnlLeft.Width  := 160;
  FPnlLeft.BevelOuter := bvNone;
  FPnlLeft.Caption := '';

  var LblTools := TLabel.Create(Self);
  LblTools.Parent    := FPnlLeft;
  LblTools.Align     := alTop;
  LblTools.Caption   := 'Object Toolbox';
  LblTools.Font.Style:= [fsBold];
  LblTools.Font.Size := 8;
  LblTools.Alignment := taCenter;
  LblTools.Height    := 22;

  FToolbox := TVittixReportToolbox.Create(Self);
  FToolbox.Parent        := FPnlLeft;
  FToolbox.Align         := alTop;
  FToolbox.Height        := 200;
  FToolbox.OnToolSelected:= ToolboxToolSelected;
  FToolbox.RefreshToolList;

  var SplProp := TSplitter.Create(Self);
  SplProp.Parent      := FPnlLeft;
  SplProp.Align       := alTop;
  SplProp.Height      := 5;
  SplProp.ResizeStyle := rsUpdate;

  var LblProps := TLabel.Create(Self);
  LblProps.Parent     := FPnlLeft;
  LblProps.Align      := alTop;
  LblProps.Caption    := 'Properties';
  LblProps.Font.Style := [fsBold];
  LblProps.Font.Size  := 8;
  LblProps.Alignment  := taCenter;
  LblProps.Height     := 22;

  FPropGrid := TStringGrid.Create(Self);
  FPropGrid.Parent           := FPnlLeft;
  FPropGrid.Align            := alClient;
  FPropGrid.ColCount         := 2;
  FPropGrid.RowCount         := 2;
  FPropGrid.FixedRows        := 1;
  FPropGrid.FixedCols        := 0;
  FPropGrid.DefaultRowHeight := 17;
  FPropGrid.Options          := FPropGrid.Options + [goEditing];
  FPropGrid.ScrollBars       := ssVertical;
  FPropGrid.ColWidths[0]     := 70;
  FPropGrid.ColWidths[1]     := 82;
  FPropGrid.Cells[0, 0]      := 'Property';
  FPropGrid.Cells[1, 0]      := 'Value';
  FPropGrid.OnSetEditText    := PropGridSetEditText;

  FSplLeft := TSplitter.Create(Self);
  FSplLeft.Parent := Self;
  FSplLeft.Align  := alLeft;
  FSplLeft.Width  := 5;

  { ---- Right panel: Preview ---- }
  FPnlRight := TPanel.Create(Self);
  FPnlRight.Parent := Self;
  FPnlRight.Align  := alRight;
  FPnlRight.Width  := 300;
  FPnlRight.BevelOuter := bvNone;
  FPnlRight.Caption := '';

  var LblPrev := TLabel.Create(Self);
  LblPrev.Parent    := FPnlRight;
  LblPrev.Align     := alTop;
  LblPrev.Caption   := 'Print Preview';
  LblPrev.Font.Style:= [fsBold];
  LblPrev.Font.Size := 8;
  LblPrev.Alignment := taCenter;
  LblPrev.Height    := 22;

  FPreview := TVittixReportPreview.Create(Self);
  FPreview.Parent  := FPnlRight;
  FPreview.Align   := alClient;
  FPreview.Color   := $00C8C8C8;

  FSplRight := TSplitter.Create(Self);
  FSplRight.Parent := Self;
  FSplRight.Align  := alRight;
  FSplRight.Width  := 5;

  { ---- Center ---- }
  FPnlCenter := TPanel.Create(Self);
  FPnlCenter.Parent     := Self;
  FPnlCenter.Align      := alClient;
  FPnlCenter.BevelOuter := bvNone;
  FPnlCenter.Caption    := '';

  { ---- Data grid at bottom of center ---- }
  FPnlGrid := TPanel.Create(Self);
  FPnlGrid.Parent     := FPnlCenter;
  FPnlGrid.Align      := alBottom;
  FPnlGrid.Height     := 200;
  FPnlGrid.BevelOuter := bvNone;
  FPnlGrid.Caption    := '';

  var LblGrid := TLabel.Create(Self);
  LblGrid.Parent    := FPnlGrid;
  LblGrid.Align     := alTop;
  LblGrid.Caption   := 'Data Source  (TClientDataSet  Orders)';
  LblGrid.Font.Style:= [fsBold];
  LblGrid.Font.Size := 8;
  LblGrid.Alignment := taCenter;
  LblGrid.Height    := 22;

  FCDS := TClientDataSet.Create(Self);
  FDS  := TDataSource.Create(Self);
  FDS.DataSet := FCDS;

  FGrid := TDBGrid.Create(Self);
  FGrid.Parent     := FPnlGrid;
  FGrid.Align      := alClient;
  FGrid.DataSource := FDS;
  FGrid.Options    := FGrid.Options + [dgRowLines, dgColLines, dgTitles];

  FSplH := TSplitter.Create(Self);
  FSplH.Parent := FPnlCenter;
  FSplH.Align  := alBottom;
  FSplH.Height := 5;

  { ---- Designer panel fills the rest ---- }
  FPnlDesigner := TPanel.Create(Self);
  FPnlDesigner.Parent     := FPnlCenter;
  FPnlDesigner.Align      := alClient;
  FPnlDesigner.BevelOuter := bvNone;
  FPnlDesigner.Caption    := '';

  var LblDes := TLabel.Create(Self);
  LblDes.Parent    := FPnlDesigner;
  LblDes.Align     := alTop;
  LblDes.Caption   := 'Report Designer  click a toolbox item then click here to insert | Drag to move | Handles to resize';
  LblDes.Font.Size := 8;
  LblDes.Alignment := taCenter;
  LblDes.Height    := 20;

  FDesigner := TVittixReportDesigner.Create(Self);
  FDesigner.Parent              := FPnlDesigner;
  FDesigner.Align               := alClient;
  FDesigner.OnModified          := DesignerModified;
  FDesigner.OnSelectionChanged  := DesignerSelectionChanged;
  FDesigner.DataSet             := FCDS;

  { ---- Renderer ---- }
  FRenderer := TReportRenderer.Create;

  { ---- Dialogs ---- }
  FDlgOpen := TOpenDialog.Create(Self);
  FDlgOpen.Title  := 'Open Report';
  FDlgOpen.Filter := 'VittixReport files (*.vrt)|*.vrt|All files|*.*';
  FDlgOpen.DefaultExt := 'vrt';

  FDlgSave := TSaveDialog.Create(Self);
  FDlgSave.Title  := 'Save Report';
  FDlgSave.Filter := 'VittixReport files (*.vrt)|*.vrt|All files|*.*';
  FDlgSave.DefaultExt := 'vrt';
end;

{ ============================================================================
  Menu
  ============================================================================ }

procedure TfrmMain.BuildMenu;
var
  MFile, MEdit, MBand, MFmt, MView, MRpt, MHelp: TMenuItem;
  MAlign, MSame, MDist, MCenter: TMenuItem;
begin
  FMainMenu := TMainMenu.Create(Self);

  { ---- File ---- }
  MFile := MI(Self, '&File');
  MFile.Add(MI(Self, '&New',          MnuNewClick,      TextToShortCut('Ctrl+N')));
  MFile.Add(MI(Self, '&Open...',      MnuOpenClick,     TextToShortCut('Ctrl+O')));
  MFile.Add(Sep(Self));
  MFile.Add(MI(Self, '&Save',         MnuSaveClick,     TextToShortCut('Ctrl+S')));
  MFile.Add(MI(Self, 'Save &As...',   MnuSaveAsClick,   TextToShortCut('Ctrl+Shift+S')));
  MFile.Add(Sep(Self));
  MFile.Add(MI(Self, 'Export &PDF...', MnuExportPDFClick, 0));
  MFile.Add(Sep(Self));
  MFile.Add(MI(Self, 'E&xit',          MnuExitClick,    TextToShortCut('Alt+F4')));

  { ---- Edit ---- }
  MEdit := MI(Self, '&Edit');
  FMnuUndo := MI(Self, '&Undo', MnuUndoClick, TextToShortCut('Ctrl+Z'));
  FMnuRedo := MI(Self, '&Redo', MnuRedoClick, TextToShortCut('Ctrl+Y'));
  FMnuUndo.Enabled := False;
  FMnuRedo.Enabled := False;
  MEdit.Add(FMnuUndo);
  MEdit.Add(FMnuRedo);
  MEdit.Add(Sep(Self));
  MEdit.Add(MI(Self, '&Copy',      MnuCopyClick,      TextToShortCut('Ctrl+C')));
  MEdit.Add(MI(Self, '&Paste',     MnuPasteClick,     TextToShortCut('Ctrl+V')));
  MEdit.Add(Sep(Self));
  MEdit.Add(MI(Self, '&Delete',    MnuDeleteClick,    TextToShortCut('Del')));
  MEdit.Add(MI(Self, 'Select &All',MnuSelectAllClick, TextToShortCut('Ctrl+A')));

  { ---- Band ---- }
  MBand := MI(Self, '&Band');
  var MkBand := procedure(const Caption: string; BT: Integer)
  begin
    var Item := MI(Self, Caption, MnuAddBandClick);
    Item.Tag := BT;
    MBand.Add(Item);
  end;
  MkBand('Add Report &Title',      Ord(btReportTitle));
  MkBand('Add Page &Header',       Ord(btPageHeader));
  MkBand('Add &Column Header',     Ord(btColumnHeader));
  MkBand('Add &Master Data',       Ord(btMasterData));
  MkBand('Add &Detail',            Ord(btDetail));
  MkBand('Add Page &Footer',       Ord(btPageFooter));
  MkBand('Add Report &Summary',    Ord(btReportSummary));
  MkBand('Add Group H&eader',      Ord(btGroupHeader));
  MkBand('Add Group F&ooter',      Ord(btGroupFooter));
  MBand.Add(Sep(Self));
  MkBand('Add &Overlay',           Ord(btOverlay));

  { ---- Format ---- }
  MFmt := MI(Self, 'F&ormat');

  MAlign := MI(Self, '&Align');
  MAlign.Add(MI(Self, 'Align &Left',    MnuAlignLeftClick,   0));
  MAlign.Add(MI(Self, 'Align &Right',   MnuAlignRightClick,  0));
  MAlign.Add(MI(Self, 'Align &Top',     MnuAlignTopClick,    0));
  MAlign.Add(MI(Self, 'Align &Bottom',  MnuAlignBottomClick, 0));

  MCenter := MI(Self, '&Center');
  MCenter.Add(MI(Self, 'Center &Horizontally', MnuCenterHClick, 0));
  MCenter.Add(MI(Self, 'Center &Vertically',   MnuCenterVClick, 0));

  MDist := MI(Self, '&Distribute');
  MDist.Add(MI(Self, 'Distribute &Horizontally', MnuDistHClick, 0));
  MDist.Add(MI(Self, 'Distribute &Vertically',   MnuDistVClick, 0));

  MSame := MI(Self, 'Make &Same Size');
  MSame.Add(MI(Self, 'Same &Width',  MnuSameWidthClick,  0));
  MSame.Add(MI(Self, 'Same &Height', MnuSameHeightClick, 0));

  MFmt.Add(MAlign);
  MFmt.Add(MCenter);
  MFmt.Add(MDist);
  MFmt.Add(MSame);
  MFmt.Add(Sep(Self));
  MFmt.Add(MI(Self, 'Bring to &Front', MnuBringFrontClick, 0));
  MFmt.Add(MI(Self, 'Send to &Back',   MnuSendBackClick,   0));

  { ---- View ---- }
  MView := MI(Self, '&View');
  FMnuShowRulers  := MI(Self, 'Show &Rulers',  MnuShowRulersClick, 0);
  FMnuShowGrid    := MI(Self, 'Show &Grid',    MnuShowGridClick,   0);
  FMnuShowMargins := MI(Self, 'Show &Margins', MnuShowMarginsClick,0);
  FMnuShowRulers.Checked  := True;
  FMnuShowGrid.Checked    := True;
  FMnuShowMargins.Checked := True;
  MView.Add(FMnuShowRulers);
  MView.Add(FMnuShowGrid);
  MView.Add(FMnuShowMargins);
  MView.Add(Sep(Self));
  MView.Add(MI(Self, 'Zoom &In',  MnuZoomInClick,   TextToShortCut('Ctrl+=')));
  MView.Add(MI(Self, 'Zoom &Out', MnuZoomOutClick,  TextToShortCut('Ctrl+-')));
  MView.Add(MI(Self, '&100%',     MnuZoomResetClick,TextToShortCut('Ctrl+0')));
  MView.Add(Sep(Self));
  FMnuPreviewPane := MI(Self, 'Preview &Pane', MnuPreviewPaneClick, 0);
  FMnuDataPane    := MI(Self, '&Data Pane',    MnuDataPaneClick,    0);
  FMnuPreviewPane.Checked := True;
  FMnuDataPane.Checked    := True;
  MView.Add(FMnuPreviewPane);
  MView.Add(FMnuDataPane);

  { ---- Report ---- }
  MRpt := MI(Self, '&Report');
  MRpt.Add(MI(Self, '&Build Preview', MnuBuildClick, TextToShortCut('F5')));

  { ---- Help ---- }
  MHelp := MI(Self, '&Help');
  MHelp.Add(MI(Self, '&About...', MnuAboutClick, 0));

  FMainMenu.Items.Add(MFile);
  FMainMenu.Items.Add(MEdit);
  FMainMenu.Items.Add(MBand);
  FMainMenu.Items.Add(MFmt);
  FMainMenu.Items.Add(MView);
  FMainMenu.Items.Add(MRpt);
  FMainMenu.Items.Add(MHelp);

  Self.Menu := FMainMenu;
end;

{ ============================================================================
  Toolbar
  ============================================================================ }

procedure TfrmMain.BuildToolbar;

  function Btn(const Cap: string; OnClick: TNotifyEvent): TToolButton;
  begin
    Result := TToolButton.Create(Self);
    Result.Parent  := FToolBar;
    Result.Caption := Cap;
    Result.OnClick := OnClick;
    Result.AutoSize:= True;
  end;

  function BtnSep: TToolButton;
  begin
    Result := TToolButton.Create(Self);
    Result.Parent := FToolBar;
    Result.Style  := tbsSeparator;
  end;

begin
  FToolBar := TToolBar.Create(Self);
  FToolBar.Parent    := Self;
  FToolBar.Align     := alTop;
  FToolBar.ShowCaptions := True;
  FToolBar.Height    := 32;
  FToolBar.Flat      := True;

  { File group }
  FBtnNew  := Btn('New',  MnuNewClick);
  FBtnOpen := Btn('Open', MnuOpenClick);
  FBtnSave := Btn('Save', MnuSaveClick);
  BtnSep;

  { Edit group }
  FBtnUndo := Btn('Undo', MnuUndoClick);
  FBtnRedo := Btn('Redo', MnuRedoClick);
  FBtnUndo.Enabled := False;
  FBtnRedo.Enabled := False;
  BtnSep;

  { Object group }
  FBtnDelete    := Btn('Delete',     MnuDeleteClick);
  FBtnSelectAll := Btn('Select All', MnuSelectAllClick);
  FBtnInsert    := Btn('Insert Tool',ToolboxToolSelected);
  BtnSep;

  { Z-order }
  FBtnBringFront := Btn('Front', MnuBringFrontClick);
  FBtnSendBack   := Btn('Back',  MnuSendBackClick);
  BtnSep;

  { Alignment }
  FBtnAlignLeft   := Btn('L',  MnuAlignLeftClick);
  FBtnAlignRight  := Btn('R',  MnuAlignRightClick);
  FBtnAlignTop    := Btn('T',  MnuAlignTopClick);
  FBtnAlignBottom := Btn('Bot',MnuAlignBottomClick);
  FBtnCenterH     := Btn('CX', MnuCenterHClick);
  FBtnCenterV     := Btn('CY', MnuCenterVClick);
  BtnSep;

  { Zoom }
  FBtnZoomOut  := Btn('-', MnuZoomOutClick);
  FBtnZoom100  := Btn('100%', MnuZoomResetClick);

  FZoomCombo := TComboBox.Create(Self);
  FZoomCombo.Parent   := FToolBar;
  FZoomCombo.Width    := 70;
  FZoomCombo.Style    := csDropDownList;
  FZoomCombo.OnChange := ZoomComboChange;
  FZoomCombo.Items.AddStrings(['25%','50%','75%','100%','125%','150%','200%','300%','400%']);
  FZoomCombo.ItemIndex := 3; // 100%

  FBtnZoomIn   := Btn('+', MnuZoomInClick);
  BtnSep;

  { Build }
  FBtnBuild := Btn('Build Preview (F5)', MnuBuildClick);
end;

{ ============================================================================
  Sample data
  ============================================================================ }

procedure TfrmMain.BuildSampleData;
const
  Customers: array[0..14] of string = (
    'Contoso Ltd.',  'Northwind Trading', 'Adventure Works',
    'Tailspin Toys', 'Fabrikam Inc.',     'Woodgrove Bank',
    'Lucerne Publishing','Fourth Coffee', 'Proseware',
    'Coho Winery',   'Wide World Importers','Blue Yonder Airlines',
    'Graphic Design Institute','Margie Travel','Trey Research');
  Cities: array[0..14] of string = (
    'London','Seattle','Berlin','Paris','Tokyo','Sydney',
    'New York','Chicago','Toronto','Amsterdam','Madrid','Rome',
    'Vienna','Amsterdam','Dublin');
var
  I: Integer;
begin
  FCDS.Close;
  FCDS.FieldDefs.Clear;
  FCDS.FieldDefs.Add('OrderNo',  ftInteger);
  FCDS.FieldDefs.Add('Customer', ftString, 50);
  FCDS.FieldDefs.Add('City',     ftString, 30);
  FCDS.FieldDefs.Add('Product',  ftString, 40);
  FCDS.FieldDefs.Add('Qty',      ftInteger);
  FCDS.FieldDefs.Add('Amount',   ftCurrency);
  FCDS.CreateDataSet;
  for I := 0 to 19 do
    FCDS.AppendRecord([
      1001 + I,
      Customers[I mod 15],
      Cities[I mod 15],
      'Product ' + IntToStr((I mod 5) + 1),
      (I mod 10) + 1,
      Round(10.0 + (I * 37.83))
    ]);
  FCDS.First;
end;

{ ============================================================================
  Sample report
  ============================================================================ }

procedure TfrmMain.BuildSampleReport;
var
  Band  : TReportBand;
  Lbl   : TReportLabelObject;
  Fld   : TReportFieldObject;
  Memo  : TReportMemoObject;
  Line  : TReportLineObject;
  Shape : TReportShapeObject;

  { Add a static label }
  procedure AddLabel(ABand: TReportBand; const AText: string;
    L, T, W, H: Integer; Bold: Boolean = False; FontSz: Integer = 9);
  begin
    Lbl := TReportLabelObject.Create;
    Lbl.Bounds       := Rect(L, T, L + W, T + H);
    Lbl.Text         := AText;
    Lbl.Font.Name    := 'Segoe UI';
    Lbl.Font.Size    := FontSz;
    if Bold then Lbl.Font.Style := Lbl.Font.Style + [fsBold]
    else         Lbl.Font.Style := [];
    Lbl.Transparent  := True;
    ABand.Children.Add(Lbl);
  end;

  { Add a data-bound field }
  procedure AddField(ABand: TReportBand; const AField: string;
    L, T, W, H: Integer; FontSz: Integer = 9);
  begin
    Fld := TReportFieldObject.Create;
    Fld.Bounds       := Rect(L, T, L + W, T + H);
    Fld.DataField    := AField;
    Fld.Text         := '';
    Fld.Font.Name    := 'Segoe UI';
    Fld.Font.Size    := FontSz;
    Fld.Font.Style   := [];
    Fld.Transparent  := True;
    Fld.BorderVisible := False;
    ABand.Children.Add(Fld);
  end;

  { Add a horizontal rule }
  procedure AddLine(ABand: TReportBand; L, T, W: Integer;
    AColor: TColor = clSilver);
  begin
    Line := TReportLineObject.Create;
    Line.Bounds     := Rect(L, T, L + W, T + 2);
    Line.LineColor  := AColor;
    Line.LineWidth  := 1;
    Line.LineStyle  := psSolid;
    ABand.Children.Add(Line);
  end;

begin
  FDesigner.Report.Clear;
  FDesigner.Report.Title := 'Orders Report';

  { ---- Report Title band ---- }
  Band := TReportBand.Create;
  Band.BandType := btReportTitle;
  Band.Height   := 54;
  Band.Bounds   := Rect(40, 0, 720, 54);
  FDesigner.Report.Objects.Add(Band);
  // Decorative background shape
  Shape            := TReportShapeObject.Create;
  Shape.Bounds     := Rect(0, 0, 680, 54);
  Shape.ShapeType  := stRoundRect;
  Shape.BrushColor := $00E8F4FF;   // light blue fill
  Shape.PenColor   := $00A0C0D8;
  Shape.PenWidth   := 1;
  Shape.CornerRadius := 8;
  Band.Children.Add(Shape);
  AddLabel(Band, 'Orders Report', 12, 6, 400, 26, True, 18);
  AddLabel(Band, 'Generated: [DateTime]', 12, 34, 340, 14);

  { ---- Page Header ---- }
  Band := TReportBand.Create;
  Band.BandType := btPageHeader;
  Band.Height   := 28;
  Band.Bounds   := Rect(40, 0, 720, 28);
  FDesigner.Report.Objects.Add(Band);
  AddLabel(Band, 'Order #',  0,   4, 70,  18, True);
  AddLabel(Band, 'Customer', 80,  4, 200, 18, True);
  AddLabel(Band, 'City',     290, 4, 130, 18, True);
  AddLabel(Band, 'Product',  430, 4, 130, 18, True);
  AddLabel(Band, 'Qty',      570, 4, 40,  18, True);
  AddLabel(Band, 'Amount',   620, 4, 90,  18, True);
  AddLine(Band, 0, 26, 680);   // separator under header

  { ---- Column Header ---- }
  Band := TReportBand.Create;
  Band.BandType            := btColumnHeader;
  Band.Height              := 20;
  Band.BackColor           := $00F0F4F8;
  Band.BackColorTransparent:= False;
  Band.Bounds              := Rect(40, 0, 720, 20);
  FDesigner.Report.Objects.Add(Band);
  AddLabel(Band, '#',        0,   2, 70,  16, True);
  AddLabel(Band, 'Customer', 80,  2, 200, 16, True);
  AddLabel(Band, 'City',     290, 2, 130, 16, True);
  AddLabel(Band, 'Product',  430, 2, 130, 16, True);
  AddLabel(Band, 'Qty',      570, 2, 40,  16, True);
  AddLabel(Band, 'Amount',   620, 2, 90,  16, True);

  { ---- Master Data ---- }
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height   := 22;
  Band.Bounds   := Rect(40, 0, 720, 22);
  FDesigner.Report.Objects.Add(Band);
  AddField(Band, 'OrderNo',  0,   2, 70,  18);
  AddField(Band, 'Customer', 80,  2, 200, 18);
  AddField(Band, 'City',     290, 2, 130, 18);
  AddField(Band, 'Product',  430, 2, 130, 18);
  AddField(Band, 'Qty',      570, 2, 40,  18);
  AddField(Band, 'Amount',   620, 2, 90,  18);

  { ---- Page Footer ---- }
  Band := TReportBand.Create;
  Band.BandType := btPageFooter;
  Band.Height   := 24;
  Band.Bounds   := Rect(40, 0, 720, 24);
  FDesigner.Report.Objects.Add(Band);
  AddLine(Band, 0, 0, 680);
  AddLabel(Band, 'Page [PageNumber]',  0,   5, 160, 16);
  AddLabel(Band, 'VittixReport Demo',  490, 5, 190, 16);

  { ---- Report Summary (CanGrow + Memo) ---- }
  Band := TReportBand.Create;
  Band.BandType := btReportSummary;
  Band.Height   := 64;
  Band.CanGrow  := True;
  Band.Bounds   := Rect(40, 0, 720, 64);
  FDesigner.Report.Objects.Add(Band);
  AddLine(Band, 0, 0, 680, clNavy);
  AddLabel(Band, 'Total Orders: [COUNT(OrderNo)]', 0, 6, 340, 18, True);
  // Memo — auto-grows to fit its text
  Memo               := TReportMemoObject.Create;
  Memo.Bounds        := Rect(0, 30, 680, 58);
  Memo.Text          := 'This report was generated by VittixReport. '
                      + 'All data shown is sample data for demonstration purposes. '
                      + 'Double-click any band or object in the designer to edit its properties.';
  Memo.Font.Name     := 'Segoe UI';
  Memo.Font.Size     := 8;
  Memo.Font.Style    := [fsItalic];
  Memo.AutoHeight    := True;
  Memo.WordWrap      := True;
  Memo.Transparent   := True;
  Memo.BorderVisible := False;
  Band.Children.Add(Memo);

  FDesigner.Invalidate;
  SetCurrentFile('');
end;

{ ============================================================================
  Preview / status helpers
  ============================================================================ }

procedure TfrmMain.RefreshPreview;
begin
  try
    FRenderer.Render(FDesigner.Report, FCDS);
    FPreview.LoadFromRenderer(FRenderer);
    UpdateStatusBar;
  except
    on E: Exception do
      FStatusBar.Panels[0].Text := 'Preview error: ' + E.Message;
  end;
end;

procedure TfrmMain.UpdateStatusBar;
var SelCount: Integer;
begin
  SelCount := FDesigner.SelectedCount;
  if SelCount = 0 then
    FStatusBar.Panels[0].Text := 'No selection'
  else if SelCount = 1 then
  begin
    var Obj := FDesigner.PrimarySelected;
    if Assigned(Obj) then
      FStatusBar.Panels[0].Text := Format('Selected: %s  [%d,%d  %dx%d]',
        [Obj.ClassName, Obj.Bounds.Left, Obj.Bounds.Top,
         Obj.Bounds.Width, Obj.Bounds.Height])
    else
      FStatusBar.Panels[0].Text := '1 object selected';
  end
  else
    FStatusBar.Panels[0].Text := Format('%d objects selected', [SelCount]);

  FStatusBar.Panels[1].Text := Format('Zoom: %d%%', [FDesigner.Zoom]);
  if FCurrentFile = '' then
    FStatusBar.Panels[2].Text := 'Unsaved report'
  else
    FStatusBar.Panels[2].Text := ExtractFileName(FCurrentFile);
end;

procedure TfrmMain.UpdateUndoRedo;
begin
  FMnuUndo.Enabled := FDesigner.CanUndo;
  FMnuRedo.Enabled := FDesigner.CanRedo;
  FBtnUndo.Enabled := FDesigner.CanUndo;
  FBtnRedo.Enabled := FDesigner.CanRedo;
end;

procedure TfrmMain.SetCurrentFile(const FN: string);
begin
  FCurrentFile := FN;
  if FN = '' then
    Caption := 'VittixReport Full-Featured Demo  <Unsaved>'
  else
    Caption := 'VittixReport Full-Featured Demo  ' + ExtractFileName(FN);
  UpdateStatusBar;
end;

procedure TfrmMain.BuildPreview;
begin
  RefreshPreview;
end;

{ ============================================================================
  File menu
  ============================================================================ }

procedure TfrmMain.MnuNewClick(Sender: TObject);
begin
  if MessageDlg('Create a new empty report? Unsaved changes will be lost.',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FDesigner.NewReport;
    SetCurrentFile('');
    FStatusBar.Panels[0].Text := 'New report created';
    UpdateUndoRedo;
    RefreshPreview;
  end;
end;

procedure TfrmMain.MnuOpenClick(Sender: TObject);
begin
  if FDlgOpen.Execute then
  begin
    var R := TReportSerializer.LoadFromFile(FDlgOpen.FileName);
    FDesigner.LoadReport(R, True);
    SetCurrentFile(FDlgOpen.FileName);
    FStatusBar.Panels[0].Text := 'Loaded: ' + ExtractFileName(FDlgOpen.FileName);
    UpdateUndoRedo;
    RefreshPreview;
  end;
end;

procedure TfrmMain.MnuSaveClick(Sender: TObject);
begin
  if FCurrentFile = '' then
    MnuSaveAsClick(Sender)
  else
  begin
    TReportSerializer.SaveToFile(FDesigner.Report, FCurrentFile);
    FStatusBar.Panels[0].Text := 'Saved: ' + ExtractFileName(FCurrentFile);
  end;
end;

procedure TfrmMain.MnuSaveAsClick(Sender: TObject);
begin
  if FCurrentFile <> '' then
    FDlgSave.FileName := FCurrentFile;
  if FDlgSave.Execute then
  begin
    TReportSerializer.SaveToFile(FDesigner.Report, FDlgSave.FileName);
    SetCurrentFile(FDlgSave.FileName);
    FStatusBar.Panels[0].Text := 'Saved as: ' + ExtractFileName(FDlgSave.FileName);
  end;
end;

procedure TfrmMain.MnuExportPDFClick(Sender: TObject);
var
  DlgPDF : TSaveDialog;
  Engine : TReportEngine;
begin
  DlgPDF := TSaveDialog.Create(Self);
  try
    DlgPDF.Title      := 'Export to PDF';
    DlgPDF.Filter     := 'PDF files (*.pdf)|*.pdf|All files|*.*';
    DlgPDF.DefaultExt := 'pdf';
    if DlgPDF.Execute then
    begin
      Engine := TReportEngine.Create(FDesigner.Report, FCDS);
      try
        Engine.Prepare;
        TReportPDFExporter.ExportToFile(Engine.Pages, DlgPDF.FileName);
      finally
        Engine.Free;
      end;
      FStatusBar.Panels[0].Text := 'PDF exported: ' + ExtractFileName(DlgPDF.FileName);
    end;
  finally
    DlgPDF.Free;
  end;
end;

procedure TfrmMain.MnuExitClick(Sender: TObject);
begin
  Close;
end;

{ ============================================================================
  Edit menu
  ============================================================================ }

procedure TfrmMain.MnuUndoClick(Sender: TObject);
begin
  FDesigner.Undo;
  UpdateUndoRedo;
  RefreshPreview;
end;

procedure TfrmMain.MnuRedoClick(Sender: TObject);
begin
  FDesigner.Redo;
  UpdateUndoRedo;
  RefreshPreview;
end;

procedure TfrmMain.MnuDeleteClick(Sender: TObject);
begin
  FDesigner.DeleteSelected;
  RefreshPreview;
end;

procedure TfrmMain.MnuSelectAllClick(Sender: TObject);
begin
  FDesigner.SelectAllObjects;
end;

procedure TfrmMain.MnuCopyClick(Sender: TObject);
begin
  FDesigner.CopySelection;
  FStatusBar.Panels[0].Text := 'Copied to clipboard';
end;

procedure TfrmMain.MnuPasteClick(Sender: TObject);
begin
  FDesigner.PasteSelection;
  RefreshPreview;
end;

{ ============================================================================
  Band menu
  ============================================================================ }

procedure TfrmMain.MnuAddBandClick(Sender: TObject);
var
  Band: TReportBand;
  BT  : TReportBandType;
begin
  BT   := TReportBandType((Sender as TMenuItem).Tag);
  Band := TReportBand.Create;
  Band.BandType := BT;
  Band.Height   := 30;
  Band.Bounds   := Rect(40, 0, 720, 30);
  FDesigner.Report.Objects.Add(Band);
  FDesigner.Invalidate;
  RefreshPreview;
  FStatusBar.Panels[0].Text := 'Band added';
end;

{ ============================================================================
  Format menu
  ============================================================================ }

procedure TfrmMain.MnuAlignLeftClick(Sender: TObject);   begin FDesigner.AlignLeft;    RefreshPreview; end;
procedure TfrmMain.MnuAlignRightClick(Sender: TObject);  begin FDesigner.AlignRight;   RefreshPreview; end;
procedure TfrmMain.MnuAlignTopClick(Sender: TObject);    begin FDesigner.AlignTop;     RefreshPreview; end;
procedure TfrmMain.MnuAlignBottomClick(Sender: TObject); begin FDesigner.AlignBottom;  RefreshPreview; end;
procedure TfrmMain.MnuSameWidthClick(Sender: TObject);   begin FDesigner.SameWidth;    RefreshPreview; end;
procedure TfrmMain.MnuSameHeightClick(Sender: TObject);  begin FDesigner.SameHeight;   RefreshPreview; end;
procedure TfrmMain.MnuDistHClick(Sender: TObject);       begin FDesigner.DistributeH;  RefreshPreview; end;
procedure TfrmMain.MnuDistVClick(Sender: TObject);       begin FDesigner.DistributeV;  RefreshPreview; end;
procedure TfrmMain.MnuCenterHClick(Sender: TObject);     begin FDesigner.CenterH;      RefreshPreview; end;
procedure TfrmMain.MnuCenterVClick(Sender: TObject);     begin FDesigner.CenterV;      RefreshPreview; end;
procedure TfrmMain.MnuBringFrontClick(Sender: TObject);  begin FDesigner.BringToFront; RefreshPreview; end;
procedure TfrmMain.MnuSendBackClick(Sender: TObject);    begin FDesigner.SendToBack;   RefreshPreview; end;

{ ============================================================================
  View menu
  ============================================================================ }

procedure TfrmMain.MnuShowRulersClick(Sender: TObject);
begin
  FMnuShowRulers.Checked := not FMnuShowRulers.Checked;
  FDesigner.ShowRulers := FMnuShowRulers.Checked;
end;

procedure TfrmMain.MnuShowGridClick(Sender: TObject);
begin
  FMnuShowGrid.Checked := not FMnuShowGrid.Checked;
  FDesigner.ShowGrid := FMnuShowGrid.Checked;
end;

procedure TfrmMain.MnuShowMarginsClick(Sender: TObject);
begin
  FMnuShowMargins.Checked := not FMnuShowMargins.Checked;
  FDesigner.ShowMargins := FMnuShowMargins.Checked;
end;

procedure TfrmMain.MnuZoomInClick(Sender: TObject);
begin
  FDesigner.ZoomIn;
  FZoomCombo.Text := IntToStr(FDesigner.Zoom) + '%';
  UpdateStatusBar;
end;

procedure TfrmMain.MnuZoomOutClick(Sender: TObject);
begin
  FDesigner.ZoomOut;
  FZoomCombo.Text := IntToStr(FDesigner.Zoom) + '%';
  UpdateStatusBar;
end;

procedure TfrmMain.MnuZoomResetClick(Sender: TObject);
begin
  FDesigner.ZoomReset;
  FZoomCombo.ItemIndex := 3; // 100%
  UpdateStatusBar;
end;

procedure TfrmMain.MnuPreviewPaneClick(Sender: TObject);
begin
  FPreviewVisible := not FPreviewVisible;
  FMnuPreviewPane.Checked := FPreviewVisible;
  FPnlRight.Visible  := FPreviewVisible;
  FSplRight.Visible  := FPreviewVisible;
end;

procedure TfrmMain.MnuDataPaneClick(Sender: TObject);
begin
  FDataVisible := not FDataVisible;
  FMnuDataPane.Checked := FDataVisible;
  FPnlGrid.Visible := FDataVisible;
  FSplH.Visible    := FDataVisible;
end;

{ ============================================================================
  Report menu
  ============================================================================ }

procedure TfrmMain.MnuBuildClick(Sender: TObject);
begin
  RefreshPreview;
  FStatusBar.Panels[0].Text := Format('Preview built  %d page(s)',
    [FPreview.PageCount]);
end;

{ ============================================================================
  Help
  ============================================================================ }

procedure TfrmMain.MnuAboutClick(Sender: TObject);
begin
  MessageDlg(
    'VittixReport Full-Featured Demo'#13#10 +
    'Demonstrates TVittixReportDesigner component.'#13#10#13#10 +
    'Keyboard shortcuts:'#13#10 +
    '  Del         delete selection'#13#10 +
    '  Ctrl+A      select all'#13#10 +
    '  Ctrl+C/V    copy / paste'#13#10 +
    '  Ctrl+Z/Y    undo / redo'#13#10 +
    '  Arrow keys  nudge 1 px (Shift = grid step)'#13#10 +
    '  Ctrl+Wheel  zoom in/out'#13#10 +
    '  Esc         cancel insert mode',
    mtInformation, [mbOK], 0);
end;

{ ============================================================================
  Designer events
  ============================================================================ }

procedure TfrmMain.DesignerModified(Sender: TObject);
begin
  UpdateUndoRedo;
  UpdateStatusBar;
  PopulatePropertyGrid;
  RefreshPreview;
end;

procedure TfrmMain.DesignerSelectionChanged(Sender: TObject);
begin
  UpdateStatusBar;
  PopulatePropertyGrid;
end;

{ ============================================================================
  Property grid
  ============================================================================ }

procedure TfrmMain.PopulatePropertyGrid;
const
  SimpleKinds = [tkInteger, tkChar, tkEnumeration, tkFloat,
                 tkString, tkLString, tkWString, tkUString, tkInt64];
var
  Obj      : TReportObject;
  PropList : PPropList;
  Count, I, Row: Integer;
  PropInfo : PPropInfo;
  SVal     : string;
begin
  FPropGrid.RowCount      := 2;
  FPropGrid.Cells[0, 1]   := '';
  FPropGrid.Cells[1, 1]   := '';
  FPropObj := nil;
  if FDesigner.SelectedCount <> 1 then Exit;
  Obj := FDesigner.PrimarySelected;
  if not Assigned(Obj) then Exit;
  FPropObj := Obj;

  Count := GetPropList(Obj.ClassInfo, tkAny, nil);
  if Count <= 0 then Exit;

  GetMem(PropList, Count * SizeOf(PPropInfo));
  try
    GetPropList(Obj.ClassInfo, tkAny, PropList);
    Row := 1;
    FPropGrid.RowCount := Count + 1;
    for I := 0 to Count - 1 do
    begin
      PropInfo := PropList^[I];
      if not (PropInfo^.PropType^^.Kind in SimpleKinds) then Continue;
      FPropGrid.Cells[0, Row] := string(PropInfo^.Name);
      case PropInfo^.PropType^^.Kind of
        tkEnumeration:
          SVal := GetEnumName(PropInfo^.PropType^, GetOrdProp(Obj, PropInfo));
        tkFloat:
          SVal := FloatToStr(GetFloatProp(Obj, PropInfo));
        tkInteger:
          SVal := IntToStr(GetOrdProp(Obj, PropInfo));
        tkInt64:
          SVal := IntToStr(GetInt64Prop(Obj, PropInfo));
      else
        SVal := GetStrProp(Obj, PropInfo);
      end;
      FPropGrid.Cells[1, Row] := SVal;
      Inc(Row);
    end;
    FPropGrid.RowCount := Max(2, Row);
  finally
    FreeMem(PropList);
  end;
end;

procedure TfrmMain.PropGridSetEditText(Sender: TObject; ACol, ARow: Integer;
  const Value: string);
var
  PropName : string;
  PropInfo : PPropInfo;
begin
  if (ACol <> 1) or (ARow < 1) or not Assigned(FPropObj) then Exit;
  PropName := FPropGrid.Cells[0, ARow];
  if PropName = '' then Exit;
  PropInfo := GetPropInfo(FPropObj, PropName);
  if not Assigned(PropInfo) then Exit;
  try
    case PropInfo^.PropType^^.Kind of
      tkInteger:
        SetOrdProp(FPropObj, PropInfo, StrToIntDef(Value, GetOrdProp(FPropObj, PropInfo)));
      tkInt64:
        SetInt64Prop(FPropObj, PropInfo, StrToInt64Def(Value, GetInt64Prop(FPropObj, PropInfo)));
      tkFloat:
        SetFloatProp(FPropObj, PropInfo, StrToFloatDef(Value, GetFloatProp(FPropObj, PropInfo)));
      tkEnumeration:
        begin
          var OrdVal := GetEnumValue(PropInfo^.PropType^, Value);
          if OrdVal >= 0 then
            SetOrdProp(FPropObj, PropInfo, OrdVal);
        end;
      tkString, tkLString, tkWString, tkUString:
        SetStrProp(FPropObj, PropInfo, Value);
    end;
    FDesigner.Invalidate;
    RefreshPreview;
  except
    // ignore invalid values
  end;
end;

{ ============================================================================
  Toolbox
  ============================================================================ }

procedure TfrmMain.ToolboxToolSelected(Sender: TObject);
begin
  if Assigned(FToolbox.SelectedObjectClass) then
  begin
    FDesigner.BeginInsertObject(FToolbox.SelectedObjectClass);
    FStatusBar.Panels[0].Text :=
      'Insert mode: click on a band in the designer to place '
      + FToolbox.SelectedObjectClass.DisplayName;
  end;
end;

{ ============================================================================
  Zoom combo
  ============================================================================ }

procedure TfrmMain.ZoomComboChange(Sender: TObject);
const
  Zooms: array[0..8] of Integer = (25,50,75,100,125,150,200,300,400);
begin
  if FZoomCombo.ItemIndex >= 0 then
  begin
    FDesigner.Zoom := Zooms[FZoomCombo.ItemIndex];
    UpdateStatusBar;
  end;
end;

end.
