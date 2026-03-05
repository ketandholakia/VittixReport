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
  Vittix.Report.Core.Model, Vittix.Report.Core.Bands, Vittix.Report.Core.Objects,
  Vittix.Report.DesignerControl, Vittix.Report.Toolbox,
  Vittix.Report.Engine.Engine, Vittix.Report.Engine.Renderer,
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

{$R *.dfm}

uses
  System.TypInfo, System.Math;

{ ============================================================================
  Constructor / Destructor
  ============================================================================ }

constructor TfrmMain.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption    := 'VittixReport Full-Featured Demo';
  Width      := 1280;
  Height     := 800;
  WindowState:= wsMaximized;
  Color      := clBtnFace;

  if csDesigning in ComponentState then
    Exit;

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
  function NeedComp(const AName: string): TComponent;
  begin
    Result := FindComponent(AName);
    if not Assigned(Result) then
      raise Exception.CreateFmt('Required component not found: %s', [AName]);
  end;

var
  ToolboxHost : TPanel;
  PreviewHost : TPanel;
  DesignerHost: TPanel;
begin
  FStatusBar := NeedComp('FStatusBar') as TStatusBar;
  FPnlLeft   := NeedComp('FPnlLeft') as TPanel;
  FSplLeft   := NeedComp('FSplLeft') as TSplitter;
  FPnlRight  := NeedComp('FPnlRight') as TPanel;
  FSplRight  := NeedComp('FSplRight') as TSplitter;
  FPnlCenter := NeedComp('FPnlCenter') as TPanel;
  FPnlGrid   := NeedComp('FPnlGrid') as TPanel;
  FSplH      := NeedComp('FSplH') as TSplitter;
  FPnlDesigner := NeedComp('FPnlDesigner') as TPanel;

  FPropGrid := NeedComp('FPropGrid') as TStringGrid;
  FGrid     := NeedComp('FGrid') as TDBGrid;
  FCDS      := NeedComp('FCDS') as TClientDataSet;
  FDS       := NeedComp('FDS') as TDataSource;
  FDlgOpen  := NeedComp('FDlgOpen') as TOpenDialog;
  FDlgSave  := NeedComp('FDlgSave') as TSaveDialog;

  ToolboxHost  := NeedComp('FToolboxHost') as TPanel;
  PreviewHost  := NeedComp('FPreviewHost') as TPanel;
  DesignerHost := NeedComp('FDesignerHost') as TPanel;

  FStatusBar.SimplePanel := False;
  while FStatusBar.Panels.Count < 3 do
    FStatusBar.Panels.Add;
  FStatusBar.Panels[0].Width := 300;  // selection info
  FStatusBar.Panels[1].Width := 150;  // zoom
  FStatusBar.Panels[2].Width := 200;  // file name
  FStatusBar.Panels[0].Text := 'Ready';
  FStatusBar.Panels[1].Text := 'Zoom: 100%';
  FStatusBar.Panels[2].Text := 'Unsaved report';

  { ---- Left panel dynamic control: Toolbox ---- }
  FToolbox := TVittixReportToolbox.Create(Self);
  FToolbox.Parent        := ToolboxHost;
  FToolbox.Align         := alClient;
  FToolbox.OnToolSelected:= ToolboxToolSelected;
  FToolbox.RefreshToolList;

  { ---- Right panel dynamic control: Preview ---- }
  FPreview := TVittixReportPreview.Create(Self);
  FPreview.Parent  := PreviewHost;
  FPreview.Align   := alClient;
  FPreview.Color   := $00C8C8C8;

  { ---- Center dynamic control: Designer ---- }
  FDesigner := TVittixReportDesigner.Create(Self);
  FDesigner.Parent              := DesignerHost;
  FDesigner.Align               := alClient;
  FDesigner.OnModified          := DesignerModified;
  FDesigner.OnSelectionChanged  := DesignerSelectionChanged;
  FDesigner.DataSet             := FCDS;

  { ---- Renderer ---- }
  FRenderer := TReportRenderer.Create;
end;

{ ============================================================================
  Menu
  ============================================================================ }

procedure TfrmMain.BuildMenu;
  function NeedComp(const AName: string): TComponent;
  begin
    Result := FindComponent(AName);
    if not Assigned(Result) then
      raise Exception.CreateFmt('Required menu component not found: %s', [AName]);
  end;
begin
  FMainMenu := NeedComp('FMainMenu') as TMainMenu;
  FMnuUndo := NeedComp('FMnuUndo') as TMenuItem;
  FMnuRedo := NeedComp('FMnuRedo') as TMenuItem;
  FMnuShowRulers  := NeedComp('FMnuShowRulers') as TMenuItem;
  FMnuShowGrid    := NeedComp('FMnuShowGrid') as TMenuItem;
  FMnuShowMargins := NeedComp('FMnuShowMargins') as TMenuItem;
  FMnuPreviewPane := NeedComp('FMnuPreviewPane') as TMenuItem;
  FMnuDataPane    := NeedComp('FMnuDataPane') as TMenuItem;

  (NeedComp('MnuFileNew') as TMenuItem).ShortCut      := TextToShortCut('Ctrl+N');
  (NeedComp('MnuFileOpen') as TMenuItem).ShortCut     := TextToShortCut('Ctrl+O');
  (NeedComp('MnuFileSave') as TMenuItem).ShortCut     := TextToShortCut('Ctrl+S');
  (NeedComp('MnuFileSaveAs') as TMenuItem).ShortCut   := TextToShortCut('Ctrl+Shift+S');
  (NeedComp('MnuFileExit') as TMenuItem).ShortCut     := TextToShortCut('Alt+F4');
  FMnuUndo.ShortCut                                   := TextToShortCut('Ctrl+Z');
  FMnuRedo.ShortCut                                   := TextToShortCut('Ctrl+Y');
  (NeedComp('MnuEditCopy') as TMenuItem).ShortCut     := TextToShortCut('Ctrl+C');
  (NeedComp('MnuEditPaste') as TMenuItem).ShortCut    := TextToShortCut('Ctrl+V');
  (NeedComp('MnuEditDelete') as TMenuItem).ShortCut   := TextToShortCut('Del');
  (NeedComp('MnuEditSelectAll') as TMenuItem).ShortCut:= TextToShortCut('Ctrl+A');
  (NeedComp('MnuViewZoomIn') as TMenuItem).ShortCut   := TextToShortCut('Ctrl+=');
  (NeedComp('MnuViewZoomOut') as TMenuItem).ShortCut  := TextToShortCut('Ctrl+-');
  (NeedComp('MnuViewZoom100') as TMenuItem).ShortCut  := TextToShortCut('Ctrl+0');
  (NeedComp('MnuReportBuild') as TMenuItem).ShortCut  := TextToShortCut('F5');

  FMnuUndo.Enabled := False;
  FMnuRedo.Enabled := False;

  FMnuShowRulers.Checked  := True;
  FMnuShowGrid.Checked    := True;
  FMnuShowMargins.Checked := True;

  FMnuPreviewPane.Checked := True;
  FMnuDataPane.Checked    := True;

  Self.Menu := FMainMenu;
end;

{ ============================================================================
  Toolbar
  ============================================================================ }

procedure TfrmMain.BuildToolbar;
begin
  FToolBar      := FindComponent('FToolBar') as TToolBar;
  FBtnNew       := FindComponent('FBtnNew') as TToolButton;
  FBtnOpen      := FindComponent('FBtnOpen') as TToolButton;
  FBtnSave      := FindComponent('FBtnSave') as TToolButton;
  FBtnUndo      := FindComponent('FBtnUndo') as TToolButton;
  FBtnRedo      := FindComponent('FBtnRedo') as TToolButton;
  FBtnDelete    := FindComponent('FBtnDelete') as TToolButton;
  FBtnSelectAll := FindComponent('FBtnSelectAll') as TToolButton;
  FBtnInsert    := FindComponent('FBtnInsert') as TToolButton;
  FBtnBringFront:= FindComponent('FBtnBringFront') as TToolButton;
  FBtnSendBack  := FindComponent('FBtnSendBack') as TToolButton;
  FBtnAlignLeft := FindComponent('FBtnAlignLeft') as TToolButton;
  FBtnAlignRight:= FindComponent('FBtnAlignRight') as TToolButton;
  FBtnAlignTop  := FindComponent('FBtnAlignTop') as TToolButton;
  FBtnAlignBottom := FindComponent('FBtnAlignBottom') as TToolButton;
  FBtnCenterH   := FindComponent('FBtnCenterH') as TToolButton;
  FBtnCenterV   := FindComponent('FBtnCenterV') as TToolButton;
  FBtnZoomOut   := FindComponent('FBtnZoomOut') as TToolButton;
  FBtnZoom100   := FindComponent('FBtnZoom100') as TToolButton;
  FZoomCombo    := FindComponent('FZoomCombo') as TComboBox;
  FBtnZoomIn    := FindComponent('FBtnZoomIn') as TToolButton;
  FBtnBuild     := FindComponent('FBtnBuild') as TToolButton;

  FBtnUndo.Enabled := False;
  FBtnRedo.Enabled := False;

  if FZoomCombo.Items.Count = 0 then
    FZoomCombo.Items.AddStrings(['25%','50%','75%','100%','125%','150%','200%','300%','400%']);
  FZoomCombo.ItemIndex := 3; // 100%
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

  FDesigner.RebuildLayout;
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
  FDesigner.RebuildLayout;
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
    FDesigner.RebuildLayout;
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
