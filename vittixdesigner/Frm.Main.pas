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
  System.SysUtils, System.Classes, System.Types, System.IOUtils, System.Rtti, System.TypInfo, System.Math,
  System.Variants,
  System.Generics.Collections,
  Vcl.Forms, Vcl.Controls, Vcl.ComCtrls, Vcl.ToolWin,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Dialogs,
  Vcl.ValEdit, Vcl.ActnList, Vcl.ActnMan, Vcl.ActnCtrls,
  Vcl.ImgList, Vcl.Graphics, Vcl.Buttons,
  Vcl.Clipbrd,
  Data.DB, Data.Win.ADODB,
  FireDAC.Comp.Client, FireDAC.Stan.Intf, FireDAC.Stan.StorageJSON,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.PageSettings,
  Vittix.Report.Serializer,
  Vittix.Report.DesignerControl,
  Vittix.Report.Toolbox,
  Vittix.Report.PropertyBridge,
  Vittix.Report.Context,
  Vittix.Report.Expressions,
  Vittix.Report.Scripting,
  Vittix.Report.Undo,
  Vittix.Report.Engine,
  Vittix.Report.Renderer,
  Vittix.Report.Export.PDF,
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Objects.Table, Vcl.Grids,  Vcl.CheckLst,
  Vittix.Report.ScriptHost.Adapter,
  System.ImageList, Vcl.VirtualImageList, SVGIconVirtualImageList,
  Vcl.BaseImageCollection, SVGIconImageCollection,
  Frm.Main.Helpers,
  Frm.Main.Commands,
  Frm.Main.RuntimeDemo,
  Frm.Main.PropertyPanel,
  Frm.Main.Structure,
  Frm.Main.SampleHelpers,
  Frm.Main.PropertyHelpers,
  Frm.Main.PropertyPanelHelpers,
  Frm.Main.PropertyEditorHelpers,
  Frm.Main.ApplyHelpers,
  Frm.Main.FontEditHelpers,
  Frm.Main.TreeFieldHelpers,
  Frm.Main.InsertMenuHelpers,
  Frm.Main.MenuStateHelpers,
  Frm.Main.HelpTexts,
  Frm.Main.ReportActions,
  Frm.Main.ViewHelpers,
  Frm.Main.DesignerHelpers,
  Frm.Main.PropertyPanelActions,
  Frm.Main.PropertyPanelEvents,
  Frm.Main.PropertyPanelState,
  Frm.Main.SampleDataHelpers,
  Frm.Main.QuickActions,
  Frm.DesignerOptions,
  Frm.ScriptEditor,
  Frm.ExpressionHelper,
  Vittix.Designer.Commands,
  // Vittix.Designer.RuntimeDemo,
  Vittix.Designer.RegressionRunner;

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
      mnuDesignerOptions: TMenuItem;
    mnuReport      : TMenuItem;
      mnuPreview    : TMenuItem;
      mnuPageSetup  : TMenuItem;
      mnuBandMgr    : TMenuItem;
      mnuSep11      : TMenuItem;
      mnuReportProps: TMenuItem;
    mnuHelp        : TMenuItem;
      mnuKeyboardShortcuts: TMenuItem;

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
    cboZoomToolbar: TComboBox;
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
    lblSelectedProps: TLabel;
    PropEditor   : TValueListEditor;
    btnApplyProps: TButton;
    pnlQuickActions: TPanel;
    btnFontQuick: TButton;
    btnFrontQuick: TButton;
    btnBackQuick: TButton;
    btnPreviewQuick: TButton;

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
    SVGIconImageCollection1: TSVGIconImageCollection;
    SVGIconVirtualImageList1: TSVGIconVirtualImageList;

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
    procedure mnuDesignerOptionsClick(Sender: TObject);

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
    procedure mnuOpenSimpleTestReportClick(Sender: TObject);
    procedure mnuOpenGroupedTestReportClick(Sender: TObject);
    procedure mnuOpenCanGrowTestReportClick(Sender: TObject);
    procedure mnuOpenBarcodeTestReportClick(Sender: TObject);
    procedure mnuOpenImagePathTestReportClick(Sender: TObject);
    procedure mnuOpenExpressionUsageDemoClick(Sender: TObject);
    procedure mnuOpenInvalidDataFieldDiagnosticsDemoClick(Sender: TObject);
    procedure mnuRunRegressionTestReportsClick(Sender: TObject);
    procedure mnuRunRuntimeEventCallbackDemoClick(Sender: TObject);
    procedure mnuKeyboardShortcutsClick(Sender: TObject);
    procedure mnuExpressionHelpClick(Sender: TObject);

    { Designer events }
    procedure DesignerSelectionChanged(Sender: TObject);
    procedure DesignerModified(Sender: TObject);
    procedure DesignerViewChanged(Sender: TObject);

    { Toolbox }
    procedure ToolboxToolSelected(Sender: TObject);

    { Property editor }
    procedure btnApplyPropsClick(Sender: TObject);
    procedure PropEditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PropEditorDblClick(Sender: TObject);
    procedure PropEditorEditButtonClick(Sender: TObject);
    procedure PropEditorSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure PropEditorSetEditText(Sender: TObject; ACol, ARow: Integer;
      const Value: string);
    procedure btnFontQuickClick(Sender: TObject);

    { Zoom edit }
    procedure btnZoomApplyClick(Sender: TObject);
    procedure CheckListBox1ClickCheck(Sender: TObject);
    procedure edtZoomKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    { Form lifecycle }
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);

  private
    FCurrentFile: string;
    FModified   : Boolean;
    FReportMetadataDirty: Boolean;
    FPropertyPanelDirty: Boolean;
    FLoadingPropertyPanel: Boolean;
    FUpdatingZoomControls: Boolean;
    FRuntimeEventDemoOutput: string;
    // Created dynamically in FormCreate (not streamed from DFM)
    FDesigner   : TVittixReportDesigner;
    FDataSource1: TDataSource;
    FPnlFields  : TPanel;
    FLblFields  : TLabel;
    FLstFields  : TListBox;
    FPnlVariables: TPanel;
    FLblVariables: TLabel;
    FTreeVariables: TTreeView;
    FPnlStructure: TPanel;
    FLblStructure: TLabel;
    FTreeStructure: TTreeView;
    FStructureTreePopup: TPopupMenu;
    FStructureTreeDeleteItem: TMenuItem;
    FStructureTreeExpandAllItem: TMenuItem;
    FStructureTreeCollapseAllItem: TMenuItem;
    FUpdatingStructureSelection: Boolean;
    FStructureTreeAddBandItem: TMenuItem;
    FStructureTreeAddObjectItem: TMenuItem;
    FStructureTreeAddSep: TMenuItem;
    FReportSampleReportsMenu: TMenuItem;
    FReportDemoReportsMenu: TMenuItem;
    FReportRegressionTestsMenu: TMenuItem;
    FReportMenuSeparator: TMenuItem;
    FSampleDataSet: TFDMemTable;
    // Session-only in-memory expression recents are now handled by Frm.ExpressionHelper.

    // Command-line mode: set when launched by the component editor
    FCmdLineInputFile : string;   // file to load on startup
    FCmdLineOutputFile: string;   // file to write on save & close

    procedure BuildInsertMenu;

    procedure UpdateTitleBar;
    procedure UpdateStatusBar;
    procedure UpdateMenuState;
    procedure ConfigureLayoutGuidance;
    procedure ConfigureViewToggleStrip;
    procedure InitializeToolbarZoomCombo;
    procedure UpdateZoomControls;
    function  FitPageWidthZoom: Integer;
    function  FitWholePageZoom: Integer;
    procedure ApplyToolbarZoomSelection;
    procedure ApplyZoom;
    procedure UpdatePropertyPanel;
    procedure UpdateAll;
    procedure ApplyPropertyPanel;
    procedure SetPropertyPanelDirty(AValue: Boolean);
    procedure UpdatePropertyPanelHeader(AObj: TReportObject);
    procedure UpdatePropertyPanelHintForRow(ARow: Integer);
    procedure ConfigurePropertyEditors;
    function  IsVisualGroupRow(const AKey: string): Boolean;
    function  IsFontDialogRowKey(const AKey: string): Boolean;
    function  IsColorPropertyKey(const AKey: string): Boolean;
    function  IsExpressionPropertyKey(const AKey: string): Boolean;
    function  IsBandEventScriptRowKey(const AKey: string): Boolean;
    function  EditExpressionPropertyRow(ARow: Integer): Boolean;
    function  EditBandEventScriptRow(ARow: Integer): Boolean;
    function  EditColorPropertyRow(ARow: Integer): Boolean;
    function  EditFontPropertyRow(ARow: Integer): Boolean;
    function  ConfirmMixedBandVerticalLayout: Boolean;
    function  CurrentPropertyTarget: TReportObject;
    function  SelectedObjectsSpanBands: Boolean;
    function  IsControlWithinParent(AControl, AParent: TWinControl): Boolean;
    function  SamePropertyValue(const AOld, ANew: TValue): Boolean;
    function  BuildChangedPropertyBatch(
      AObj: TReportObject;
      const AOldByProp: TDictionary<string, TValue>;
      const APropNames: TArray<string>;
      out ChangedNames: TArray<string>;
      out OldValues: TArray<TValue>;
      out NewValues: TArray<TValue>): Boolean;
    procedure CommitReportMetadataValues(const ANewTitle, ANewAuthor,
      ANewDescription: string; AUndoable: Boolean = True);
    procedure CommitReportMetadataChanges(AUndoable: Boolean = True);
    procedure ReportMetadataEditChange(Sender: TObject);

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
    function  GetRegressionReportPath(const AFileName: string): string;
    procedure OpenRegressionReport(const AFileName: string);
    procedure LoadDesignerReportFromFile(const AFileName: string;
      AUseSampleDataSet: Boolean = False);
    procedure RunRegressionTestReports;
    procedure RunRuntimeEventCallbackDemo;
    procedure ConfirmSaveIfModified;
    procedure DynInsertMenuClick(Sender: TObject);
    procedure DynAddBandMenuClick(Sender: TObject);

    procedure RefreshFieldList;
    procedure RefreshReportStructure;
    function  HasDesignerReport: Boolean;
    procedure RefreshAfterUndoRedo;
    procedure RefreshAfterReportStateChange;
    procedure SyncReportStructureSelection;
    function  TryGetPreviewDataSet(out ADataSet: TDataSet): Boolean;
    procedure GetReportPropertiesDialogValues(out ATitle, AAuthor: string);
    function  PageSettingsChanged(const AOldSettings, ANewSettings: TReportPageSettings): Boolean;
    procedure ApplyBandManagerSnapshot(const ABeforeJSON, AAfterJSON: string);
    procedure ShowReportPropertiesDialog;
    function  IsTextEditingControlFocused: Boolean;
    procedure SendMessageToFocusedControl(AMsg: Cardinal);
    procedure SendDeleteToFocusedControl;
    procedure StructureTreeChange(Sender: TObject; Node: TTreeNode);
    procedure StructureTreeDblClick(Sender: TObject);
    procedure StructureTreeMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure StructureTreePopupPopup(Sender: TObject);
    procedure StructureTreeDeleteClick(Sender: TObject);
    procedure StructureTreeExpandAllClick(Sender: TObject);
    procedure StructureTreeCollapseAllClick(Sender: TObject);
    function  FindStructureNodeByData(AData: Pointer): TTreeNode;
    function  StructureBandCaption(ABand: TReportBand): string;
    function  StructureObjectCaption(AObj: TReportObject): string;
    function  StructureObjectIconIndex(AObj: TReportObject): Integer;
    function  ShortNodePreview(const S: string; AMaxLen: Integer = 28): string;
    procedure FieldListDblClick(Sender: TObject);
    procedure DesignerDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure DesignerDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure DesignerDataSetChanged(Sender: TObject);
    procedure VariableListDblClick(Sender: TObject);
    procedure CreateSampleDataSet;
    procedure ReloadSampleDataSet;
    procedure UseSampleDataSet;
    procedure RuntimeEventDemoCopyClick(Sender: TObject);
    function  ZoomValueFromEdit: Integer;
    function  ZoomPercentFromText(const AText: string): Integer;
    procedure cboZoomToolbarChange(Sender: TObject);
    function  VariableTokenForNode(ANode: TTreeNode; out AToken: string;
      out ASupported: Boolean): Boolean;
    function  CanInsertVariableIntoCurrentProperty(out AKey: string): Boolean;
    procedure InsertVariableToken(const AToken: string);

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
  Winapi.Messages,
  Frm.BandManager,
  Frm.PageSettings,
  Frm.ReportProperties,
  Frm.Preview;

const
  TREE_ICON_REPORT    = 21;
  TREE_ICON_BAND      = 22;
  TREE_ICON_TEXT      = 23;
  TREE_ICON_FIELD     = 24;
  TREE_ICON_MEMO      = 25;
  TREE_ICON_IMAGE     = 26;
  TREE_ICON_BARCODE   = 27;
  TREE_ICON_SHAPE     = 28;
  TREE_ICON_LINE      = 29;
  TREE_ICON_SUBREPORT = 30;
  TREE_ICON_TABLE     = 31;

type
  TReportMetadataChangeCommand = class(TUndoableAction)
  private
    FForm: TfrmMain;
    FReport: TReportModel;
    FOldTitle: string;
    FOldAuthor: string;
    FOldDescription: string;
    FNewTitle: string;
    FNewAuthor: string;
    FNewDescription: string;
    procedure ApplyValues(const ATitle, AAuthor, ADescription: string);
  public
    constructor Create(AForm: TfrmMain; AReport: TReportModel;
      const AOldTitle, AOldAuthor, AOldDescription, ANewTitle, ANewAuthor,
      ANewDescription: string);
    procedure Execute; override;
    procedure Rollback; override;
  end;

constructor TReportMetadataChangeCommand.Create(AForm: TfrmMain;
  AReport: TReportModel; const AOldTitle, AOldAuthor, AOldDescription,
  ANewTitle, ANewAuthor, ANewDescription: string);
begin
  inherited Create;
  ActionName := 'Report Properties Change';
  FForm := AForm;
  FReport := AReport;
  FOldTitle := AOldTitle;
  FOldAuthor := AOldAuthor;
  FOldDescription := AOldDescription;
  FNewTitle := ANewTitle;
  FNewAuthor := ANewAuthor;
  FNewDescription := ANewDescription;
end;

procedure TReportMetadataChangeCommand.ApplyValues(const ATitle, AAuthor,
  ADescription: string);
begin
  if Assigned(FReport) then
  begin
    FReport.Title := ATitle;
    FReport.Author := AAuthor;
    FReport.Description := ADescription;
  end;

  if Assigned(FForm) then
  begin
    if Assigned(FForm.edtReportTitle) then
      FForm.edtReportTitle.Text := ATitle;
    if Assigned(FForm.edtReportAuthor) then
      FForm.edtReportAuthor.Text := AAuthor;
  end;
end;

procedure TReportMetadataChangeCommand.Execute;
begin
  ApplyValues(FNewTitle, FNewAuthor, FNewDescription);
end;

procedure TReportMetadataChangeCommand.Rollback;
begin
  ApplyValues(FOldTitle, FOldAuthor, FOldDescription);
end;

{ =========================================================================== }
{  Form lifecycle                                                              }
{ =========================================================================== }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  Splitter: TSplitter;
  MI: TMenuItem;
  Sep: TMenuItem;
  procedure TrySetOrdinalProp(AObj: TObject; const APropName: string; AValue: NativeInt);
  var
    PI: PPropInfo;
  begin
    if not Assigned(AObj) then
      Exit;
    PI := GetPropInfo(AObj, APropName);
    if Assigned(PI) then
      SetOrdProp(AObj, PI, AValue);
  end;
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
  Toolbox.ToolImages := SVGIconVirtualImageList1;
  Toolbox.RefreshToolList;

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

  FPnlVariables := TPanel.Create(Self);
  FPnlVariables.Parent := pnlToolbox;
  FPnlVariables.Align := alBottom;
  FPnlVariables.Height := 170;
  FPnlVariables.BevelOuter := bvNone;
  FPnlVariables.Caption := '';

  FLblVariables := TLabel.Create(Self);
  FLblVariables.Parent := FPnlVariables;
  FLblVariables.Align := alTop;
  FLblVariables.Caption := ' Variables';
  FLblVariables.Font.Style := [fsBold];
  FLblVariables.Height := 18;

  FTreeVariables := TTreeView.Create(Self);
  FTreeVariables.Parent := FPnlVariables;
  FTreeVariables.Align := alClient;
  FTreeVariables.ReadOnly := True;
  FTreeVariables.HideSelection := False;
  FTreeVariables.RowSelect := True;
  FTreeVariables.Indent := 18;
  FTreeVariables.OnDblClick := VariableListDblClick;
  FTreeVariables.Hint := 'Double-click a system variable to insert its token';
  FTreeVariables.ShowHint := True;
  var VarsRoot := FTreeVariables.Items.AddChild(nil, 'Variables');
  var SysRoot := FTreeVariables.Items.AddChild(VarsRoot, 'System variables');
  FTreeVariables.Items.AddChild(SysRoot, 'Date');
  FTreeVariables.Items.AddChild(SysRoot, 'Time');
  FTreeVariables.Items.AddChild(SysRoot, 'Page');
  FTreeVariables.Items.AddChild(SysRoot, 'Page#');
  FTreeVariables.Items.AddChild(SysRoot, 'TotalPages');
  FTreeVariables.Items.AddChild(SysRoot, 'TotalPages#');
  FTreeVariables.Items.AddChild(SysRoot, 'Line');
  FTreeVariables.Items.AddChild(SysRoot, 'Line#');
  FTreeVariables.Items.AddChild(SysRoot, 'CopyName# (not supported yet)');
  FTreeVariables.Items.AddChild(SysRoot, 'TableRow (not supported yet)');
  FTreeVariables.Items.AddChild(SysRoot, 'TableColumn (not supported yet)');
  VarsRoot.Expand(True);
  SysRoot.Expand(True);

  FPnlStructure := TPanel.Create(Self);
  FPnlStructure.Parent := pnlToolbox;
  FPnlStructure.Align := alBottom;
  FPnlStructure.Height := 200;
  FPnlStructure.BevelOuter := bvNone;
  FPnlStructure.Caption := '';

  FLblStructure := TLabel.Create(Self);
  FLblStructure.Parent := FPnlStructure;
  FLblStructure.Align := alTop;
  FLblStructure.Caption := ' Report Structure';
  FLblStructure.Font.Style := [fsBold];
  FLblStructure.Height := 18;

  FTreeStructure := TTreeView.Create(Self);
  FTreeStructure.Parent := FPnlStructure;
  FTreeStructure.Align := alClient;
  FTreeStructure.ReadOnly := True;
  FTreeStructure.HideSelection := False;
  FTreeStructure.RowSelect := True;
  FTreeStructure.Indent := 18;
  FTreeStructure.Images := SVGIconVirtualImageList1;
  FTreeStructure.Hint := 'Read-only outline of report bands and objects';
  FTreeStructure.ShowHint := True;
  FTreeStructure.OnChange := StructureTreeChange;
  FTreeStructure.OnDblClick := StructureTreeDblClick;
  FTreeStructure.OnMouseDown := StructureTreeMouseDown;

  FStructureTreePopup := TPopupMenu.Create(Self);
  FStructureTreePopup.OnPopup := StructureTreePopupPopup;

  FStructureTreeAddBandItem := TMenuItem.Create(FStructureTreePopup);
  FStructureTreeAddBandItem.Caption := 'Add Band';
  FStructureTreePopup.Items.Add(FStructureTreeAddBandItem);

  FStructureTreeAddObjectItem := TMenuItem.Create(FStructureTreePopup);
  FStructureTreeAddObjectItem.Caption := 'Add Object';
  FStructureTreePopup.Items.Add(FStructureTreeAddObjectItem);

  FStructureTreeAddSep := TMenuItem.Create(FStructureTreePopup);
  FStructureTreeAddSep.Caption := '-';
  FStructureTreePopup.Items.Add(FStructureTreeAddSep);

  FStructureTreeDeleteItem := TMenuItem.Create(FStructureTreePopup);
  FStructureTreeDeleteItem.Caption := 'Delete';
  FStructureTreeDeleteItem.OnClick := StructureTreeDeleteClick;
  FStructureTreePopup.Items.Add(FStructureTreeDeleteItem);

  Sep := TMenuItem.Create(FStructureTreePopup);
  Sep.Caption := '-';
  FStructureTreePopup.Items.Add(Sep);

  FStructureTreeExpandAllItem := TMenuItem.Create(FStructureTreePopup);
  FStructureTreeExpandAllItem.Caption := 'Expand All';
  FStructureTreeExpandAllItem.OnClick := StructureTreeExpandAllClick;
  FStructureTreePopup.Items.Add(FStructureTreeExpandAllItem);

  FStructureTreeCollapseAllItem := TMenuItem.Create(FStructureTreePopup);
  FStructureTreeCollapseAllItem.Caption := 'Collapse All';
  FStructureTreeCollapseAllItem.OnClick := StructureTreeCollapseAllClick;
  FStructureTreePopup.Items.Add(FStructureTreeCollapseAllItem);

  FTreeStructure.PopupMenu := FStructureTreePopup;

  // Now that the popup menus are created, populate them with bands and objects!
  BuildInsertMenu;

  // Ensure toolbar SVG icons render at full-strength normal color.
  // These properties are applied only when available in the installed
  // SVG icon component version.
  TrySetOrdinalProp(SVGIconImageCollection1, 'GrayScale', 0);
  TrySetOrdinalProp(SVGIconImageCollection1, 'Opacity', 255);
  TrySetOrdinalProp(SVGIconVirtualImageList1, 'GrayScale', 0);
  TrySetOrdinalProp(SVGIconVirtualImageList1, 'Opacity', 255);
  TrySetOrdinalProp(SVGIconVirtualImageList1, 'FixedColor', clWindowText);
  TrySetOrdinalProp(SVGIconVirtualImageList1, 'DisabledGrayScale', 1);
  TrySetOrdinalProp(SVGIconVirtualImageList1, 'DisabledOpacity', 125);

  // Splitters between toolbox/structure/fields panels
  Splitter           := TSplitter.Create(Self);
  Splitter.Parent    := pnlToolbox;
  Splitter.Align     := alBottom;
  Splitter.Height    := 5;

  Splitter           := TSplitter.Create(Self);
  Splitter.Parent    := pnlToolbox;
  Splitter.Align     := alBottom;
  Splitter.Height    := 5;

  Splitter           := TSplitter.Create(Self);
  Splitter.Parent    := pnlToolbox;
  Splitter.Align     := alBottom;
  Splitter.Height    := 5;

  // Wire designer events
  FDesigner.OnSelectionChanged := DesignerSelectionChanged;
  FDesigner.OnModified         := DesignerModified;
  FDesigner.OnViewChanged      := DesignerViewChanged;
  FDesigner.OnDataSetChanged   := DesignerDataSetChanged;
  FDesigner.OnDragOver         := DesignerDragOver;
  FDesigner.OnDragDrop         := DesignerDragDrop;
  edtReportTitle.OnChange      := ReportMetadataEditChange;
  edtReportAuthor.OnChange     := ReportMetadataEditChange;
  PropEditor.OnDblClick        := PropEditorDblClick;
  PropEditor.OnEditButtonClick := PropEditorEditButtonClick;
  PropEditor.OnSelectCell      := PropEditorSelectCell;
  PropEditor.OnSetEditText     := PropEditorSetEditText;
  cboZoomToolbar.OnChange      := cboZoomToolbarChange;

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
  ConfigureLayoutGuidance;
  ConfigureViewToggleStrip;

  FCurrentFile := '';
  FModified    := False;
  FReportMetadataDirty := False;
  FPropertyPanelDirty := False;
  FLoadingPropertyPanel := False;
  FUpdatingZoomControls := False;

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

  RefreshReportStructure;
  RefreshFieldList;
  InitializeToolbarZoomCombo;
  UpdateZoomControls;
  UpdateAll;

  FReportSampleReportsMenu := TMenuItem.Create(Self);
  FReportSampleReportsMenu.Caption := 'Sample Reports';

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Create Simple Sample Report';
  MI.OnClick := mnuCreateSimpleSampleReportClick;
  FReportSampleReportsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Create Grouped Sample Report';
  MI.OnClick := mnuCreateSampleGroupedReportClick;
  FReportSampleReportsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Create CanGrow Remarks Test Report';
  MI.OnClick := mnuCreateCanGrowRemarksTestReportClick;
  FReportSampleReportsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Create Barcode Test Report';
  MI.OnClick := mnuCreateBarcodeTestReportClick;
  FReportSampleReportsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Create ImagePath Test Report';
  MI.OnClick := mnuCreateImagePathTestReportClick;
  FReportSampleReportsMenu.Add(MI);

  FReportDemoReportsMenu := TMenuItem.Create(Self);
  FReportDemoReportsMenu.Caption := 'Demo Reports';

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Expression Usage Demo';
  MI.OnClick := mnuOpenExpressionUsageDemoClick;
  FReportDemoReportsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Invalid DataField Diagnostics Demo';
  MI.OnClick := mnuOpenInvalidDataFieldDiagnosticsDemoClick;
  FReportDemoReportsMenu.Add(MI);

  FReportRegressionTestsMenu := TMenuItem.Create(Self);
  FReportRegressionTestsMenu.Caption := 'Regression Tests';

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Open Simple Test Report';
  MI.OnClick := mnuOpenSimpleTestReportClick;
  FReportRegressionTestsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Open Grouped Test Report';
  MI.OnClick := mnuOpenGroupedTestReportClick;
  FReportRegressionTestsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Open CanGrow Test Report';
  MI.OnClick := mnuOpenCanGrowTestReportClick;
  FReportRegressionTestsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Open Barcode Test Report';
  MI.OnClick := mnuOpenBarcodeTestReportClick;
  FReportRegressionTestsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Open ImagePath Test Report';
  MI.OnClick := mnuOpenImagePathTestReportClick;
  FReportRegressionTestsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := '-';
  FReportRegressionTestsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Run Regression Test Reports';
  MI.OnClick := mnuRunRegressionTestReportsClick;
  FReportRegressionTestsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := '-';
  FReportRegressionTestsMenu.Add(MI);

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Run Runtime Event Callback Demo';
  MI.OnClick := mnuRunRuntimeEventCallbackDemoClick;
  FReportRegressionTestsMenu.Add(MI);

  FReportMenuSeparator := TMenuItem.Create(Self);
  FReportMenuSeparator.Caption := '-';

  mnuReport.Add(FReportMenuSeparator);
  mnuReport.Add(FReportSampleReportsMenu);
  mnuReport.Add(FReportDemoReportsMenu);
  mnuReport.Add(FReportRegressionTestsMenu);

  MI := TMenuItem.Create(Self);
  MI.Caption := 'Expression Help';
  MI.OnClick := mnuExpressionHelpClick;
  mnuHelp.Add(MI);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := True;

  // Command-line mode: save the report to the output file before closing
  // so the component editor can read it back.
  if FCmdLineOutputFile <> '' then
  begin
    try
      CommitReportMetadataChanges(False);
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

  if FModified or FReportMetadataDirty then
    ConfirmSaveIfModified;
end;

procedure TfrmMain.CommitReportMetadataValues(const ANewTitle, ANewAuthor,
  ANewDescription: string; AUndoable: Boolean = True);
var
  OldTitle: string;
  OldAuthor: string;
  OldDescription: string;
  Cmd: TReportMetadataChangeCommand;
begin
  if not HasDesignerReport then
    Exit;

  OldTitle := FDesigner.Report.Title;
  OldAuthor := FDesigner.Report.Author;
  OldDescription := FDesigner.Report.Description;

  if (OldTitle = ANewTitle) and (OldAuthor = ANewAuthor) and
     (OldDescription = ANewDescription) then
  begin
    FReportMetadataDirty := False;
    UpdateTitleBar;
    Exit;
  end;

  if AUndoable then
  begin
    Cmd := TReportMetadataChangeCommand.Create(Self, FDesigner.Report,
      OldTitle, OldAuthor, OldDescription,
      ANewTitle, ANewAuthor, ANewDescription);
    FDesigner.ExecuteUndoCommand(Cmd);
  end
  else
  begin
    FDesigner.Report.Title := ANewTitle;
    FDesigner.Report.Author := ANewAuthor;
    FDesigner.Report.Description := ANewDescription;
  end;

  FReportMetadataDirty := False;
  UpdateTitleBar;
  UpdateMenuState;
end;

procedure TfrmMain.CommitReportMetadataChanges(AUndoable: Boolean = True);
begin
  CommitReportMetadataValues(
    edtReportTitle.Text,
    edtReportAuthor.Text,
    FDesigner.Report.Description,
    AUndoable
  );
end;

procedure TfrmMain.ReportMetadataEditChange(Sender: TObject);
begin
  if not HasDesignerReport then
    Exit;
  FReportMetadataDirty :=
    (FDesigner.Report.Title <> edtReportTitle.Text) or
    (FDesigner.Report.Author <> edtReportAuthor.Text);
  UpdateTitleBar;
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
  FReportMetadataDirty := False;
  edtReportTitle.Text  := FDesigner.Report.Title;
  edtReportAuthor.Text := FDesigner.Report.Author;
  RefreshReportStructure;
  UpdateTitleBar;
  UpdateMenuState;
  SyncReportStructureSelection;
end;

procedure TfrmMain.LoadDesignerReportFromFile(const AFileName: string;
  AUseSampleDataSet: Boolean = False);
var
  R: TReportModel;
begin
  R := TReportSerializer.LoadFromFile(AFileName);
  if AUseSampleDataSet then
    UseSampleDataSet;
  FDesigner.LoadReport(R, True {take ownership});
  FDesigner.RebuildLayout;
  FCurrentFile := AFileName;
  FModified := False;
  FReportMetadataDirty := False;
  edtReportTitle.Text := FDesigner.Report.Title;
  edtReportAuthor.Text := FDesigner.Report.Author;
  RefreshFieldList;
  RefreshReportStructure;
  UpdateAll;
  StatusBar1.Panels[1].Text := 'Loaded: ' + ExtractFileName(FCurrentFile);
end;

procedure TfrmMain.mnuOpenClick(Sender: TObject);
begin
  ConfirmSaveIfModified;
  if not dlgOpen.Execute then Exit;
  try
    LoadDesignerReportFromFile(dlgOpen.FileName, False);
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
    // Commit pending report-info edits as a single undoable metadata change.
    CommitReportMetadataChanges(True);
    try
      TReportSerializer.SaveToFile(FDesigner.Report, FCurrentFile);
      FModified := False;
      FReportMetadataDirty := False;
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
  Eng   : TReportEngine;
  DS    : TDataSet;
begin
  CommitReportMetadataChanges(True);

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
      DS := nil;
      if Assigned(FDataSource1) then
        DS := FDataSource1.DataSet;
      if not Assigned(DS) then
      begin
        UseSampleDataSet;
        if Assigned(FDataSource1) then
          DS := FDataSource1.DataSet;
      end;
      if not Assigned(DS) then
      begin
        ShowMessage('PDF export requires a dataset for report preparation.');
        Exit;
      end;

      Eng := TReportEngine.Create(FDesigner.Report, DS);
      try
        Eng.Prepare;
        if Eng.Pages.Count = 0 then
        begin
          ShowMessage('No pages were generated. Add a MasterData band with objects and ensure a DataSet is assigned.');
          Exit;
        end;
        TReportPDFExporter.ExportToFile(Eng.Pages, dlgPDF.FileName);
      finally
        Eng.Free;
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
  RefreshAfterUndoRedo;
end;

procedure TfrmMain.mnuRedoClick(Sender: TObject);
begin
  FDesigner.Redo;
  RefreshAfterUndoRedo;
end;

procedure TfrmMain.mnuCutClick(Sender: TObject);
begin
  if IsTextEditingControlFocused then
  begin
    SendMessageToFocusedControl(WM_CUT);
    Exit;
  end;
  FDesigner.CopySelection;
  FDesigner.DeleteSelected;
end;

procedure TfrmMain.mnuCopyClick(Sender: TObject);
begin
  if IsTextEditingControlFocused then
  begin
    SendMessageToFocusedControl(WM_COPY);
    Exit;
  end;
  FDesigner.CopySelection;
end;

procedure TfrmMain.RuntimeEventDemoCopyClick(Sender: TObject);
begin
  Clipboard.AsText := FRuntimeEventDemoOutput;
end;

procedure TfrmMain.mnuPasteClick(Sender: TObject);
begin
  if IsTextEditingControlFocused then
  begin
    SendMessageToFocusedControl(WM_PASTE);
    Exit;
  end;
  FDesigner.PasteSelection;
end;

procedure TfrmMain.mnuDeleteClick(Sender: TObject);
begin
  if IsTextEditingControlFocused then
  begin
    SendDeleteToFocusedControl;
    Exit;
  end;
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
  Cmd: TInsertObjectCommand;
begin
  Band := TReportBand.Create;
  Band.BandType := ABandType;
  Band.Height   := 40;
  Cmd := TInsertObjectCommand.Create(FDesigner.Report.Objects, Band);
  Cmd.ActionName := 'Add Band';
  FDesigner.ExecuteUndoCommand(Cmd);
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
  RefreshAfterReportStateChange;
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

function TfrmMain.GetRegressionReportPath(const AFileName: string): string;
begin
  Result := Frm.Main.SampleHelpers.GetRegressionReportPath(AFileName);
end;

procedure TfrmMain.OpenRegressionReport(const AFileName: string);
begin
  Frm.Main.SampleHelpers.OpenRegressionReport(
    AFileName,
    procedure
    begin
      ConfirmSaveIfModified;
    end,
    procedure(AFileNameToLoad: string)
    begin
      LoadDesignerReportFromFile(AFileNameToLoad, True);
    end,
    procedure(AMessage: string)
    begin
      ShowMessage(AMessage);
    end,
    function(AReportName: string): string
    begin
      Result := GetRegressionReportPath(AReportName);
    end);
end;

procedure TfrmMain.RunRegressionTestReports;
begin
  UseSampleDataSet;
  RefreshAfterReportStateChange;
end;

procedure TfrmMain.RunRuntimeEventCallbackDemo;
const
  TracePreviewMax = 30;
var
  ReportModel: TReportModel;
  Engine: TReportEngine;
  Harness: TRuntimeEventDemoHarness;
  Lines: TStringList;
  BaselineTrace: TStringList;
  ObjectSkipTrace: TStringList;
  BandSkipTrace: TStringList;
  FN: string;
  I: Integer;
  BasePass: Boolean;
  ObjectSkipPass: Boolean;
  BandSkipPass: Boolean;
  CountingInflationPass: Boolean;
  BaseBeforeBand: Integer;
  BaseAfterBand: Integer;
  BaseBeforeObject: Integer;
  BaseAfterObject: Integer;
  BaseScriptBeforeObject: Integer;
  BaseScriptAfterObject: Integer;
  ScriptCancelPass: Boolean;
  TargetOrderPass: Boolean;
  TargetCancelOrderPass: Boolean;
  FieldBindPass: Boolean;
  FieldResolveMissPass: Boolean;
  FieldResolveMissWithUnsupportedPass: Boolean;
  BackgroundPass: Boolean;
  VisiblePass: Boolean;
  AnchorRightPass: Boolean;
  AnchorBottomPass: Boolean;
  EscapedQuotePass: Boolean;
  WhitespacePass: Boolean;
  TrailingSemicolonPass: Boolean;
  UnknownCommandPass: Boolean;
  FieldSyntaxPass: Boolean;
  FieldNamePass: Boolean;
  ColorValuePass: Boolean;
  VisibleValuePass: Boolean;
  TextLiteralPass: Boolean;
  CanPrintValuePass: Boolean;
  MultiInvalidPass: Boolean;
  MixedValidInvalidPass: Boolean;
  CancelShortCircuitPass: Boolean;
  QuotedSemicolonWithUnsupportedPass: Boolean;
  ObjectTypeMismatchPass: Boolean;
  LowercaseTextKeyPass: Boolean;
  MixedCaseCanPrintPass: Boolean;
  MixedCaseVisiblePass: Boolean;
  MixedCaseBackgroundPass: Boolean;
  FontColorPass: Boolean;
  FontSizePass: Boolean;
  FontNamePass: Boolean;
  FontBoldPass: Boolean;
  FontItalicPass: Boolean;
  HAlignPass: Boolean;
  VAlignPass: Boolean;
  PrintWhenPass: Boolean;
  DataFieldPass: Boolean;
  ExpressionPass: Boolean;
  BorderColorPass: Boolean;
  ImageDataFieldPass: Boolean;
  TransparentPass: Boolean;
  AutoSizePass: Boolean;
  WordWrapPass: Boolean;
  BorderVisiblePass: Boolean;
  BorderWidthPass: Boolean;
  PaddingLeftPass: Boolean;
  PaddingTopPass: Boolean;
  PaddingRightPass: Boolean;
  PaddingBottomPass: Boolean;
  FontColorOnTruePass: Boolean;
  BackgroundOnTruePass: Boolean;
  BorderColorOnTruePass: Boolean;
  BackgroundConditionPass: Boolean;
  BorderColorConditionPass: Boolean;
  FontColorConditionPass: Boolean;
  FieldDisplayFormatPass: Boolean;
  FieldEditMaskPass: Boolean;
  ImageStretchPass: Boolean;
  ImageCenterPass: Boolean;
  ImageProportionalPass: Boolean;
  OverallPass: Boolean;
  ScriptCancelTrace: TStringList;
  FieldBindTrace: TStringList;
  FieldResolveMissTrace: TStringList;
  FieldResolveMissWithUnsupportedTrace: TStringList;
  BackgroundTrace: TStringList;
  VisibleTrace: TStringList;
  AnchorRightTrace: TStringList;
  AnchorBottomTrace: TStringList;
  EscapedQuoteTrace: TStringList;
  WhitespaceTrace: TStringList;
  TrailingSemicolonTrace: TStringList;
  UnknownCommandTrace: TStringList;
  FieldSyntaxTrace: TStringList;
  FieldNameTrace: TStringList;
  ColorValueTrace: TStringList;
  VisibleValueTrace: TStringList;
  TextLiteralTrace: TStringList;
  CanPrintValueTrace: TStringList;
  MultiInvalidTrace: TStringList;
  MixedValidInvalidTrace: TStringList;
  CancelShortCircuitTrace: TStringList;
  QuotedSemicolonWithUnsupportedTrace: TStringList;
  ObjectTypeMismatchTrace: TStringList;
  LowercaseTextKeyTrace: TStringList;
  MixedCaseCanPrintTrace: TStringList;
  MixedCaseVisibleTrace: TStringList;
  MixedCaseBackgroundTrace: TStringList;
  FontColorTrace: TStringList;
  FontSizeTrace: TStringList;
  FontNameTrace: TStringList;
  FontBoldTrace: TStringList;
  FontItalicTrace: TStringList;
  HAlignTrace: TStringList;
  VAlignTrace: TStringList;
  PrintWhenTrace: TStringList;
  DataFieldTrace: TStringList;
  ExpressionTrace: TStringList;
  BorderColorTrace: TStringList;
  TransparentTrace: TStringList;
  AutoSizeTrace: TStringList;
  WordWrapTrace: TStringList;
  BorderVisibleTrace: TStringList;
  BorderWidthTrace: TStringList;
  PaddingLeftTrace: TStringList;
  PaddingTopTrace: TStringList;
  PaddingRightTrace: TStringList;
  PaddingBottomTrace: TStringList;
  FontColorOnTrueTrace: TStringList;
  BackgroundOnTrueTrace: TStringList;
  BorderColorOnTrueTrace: TStringList;
  BackgroundConditionTrace: TStringList;
  BorderColorConditionTrace: TStringList;
  FontColorConditionTrace: TStringList;
  FieldDisplayFormatTrace: TStringList;
  FieldEditMaskTrace: TStringList;
  ImageStretchTrace: TStringList;
  ImageCenterTrace: TStringList;
  ImageProportionalTrace: TStringList;
  ImageDataFieldTrace: TStringList;
  Obj: TReportObject;
  Band: TReportBand;
  ChildObj: TReportObject;
  DemoScriptTarget: TReportObject;
  DemoFieldTarget: TReportFieldObject;
  DemoImageTarget: TReportImageObject;
  DemoNonTextTarget: TReportObject;
  ResultDlg: TForm;
  ResultMemo: TMemo;
  BtnCopy: TButton;
  BtnClose: TButton;
  function TraceHasOrdered(const ATrace: TStrings; const AParts: array of string): Boolean;
  var
    StartAt, I, J: Integer;
  begin
    Result := False;
    if not Assigned(ATrace) then
      Exit;

    StartAt := 0;
    for I := 0 to High(AParts) do
    begin
      J := StartAt;
      while J < ATrace.Count do
      begin
        if Pos(AParts[I], ATrace[J]) > 0 then
          Break;
        Inc(J);
      end;
      if J >= ATrace.Count then
        Exit(False);
      StartAt := J + 1;
    end;
    Result := True;
  end;
  function TraceWindowHasNoTargetObjectHooks(const ATrace: TStrings): Boolean;
  var
    I, StartIdx, EndIdx: Integer;
    S: string;
  begin
    Result := False;
    if not Assigned(ATrace) then
      Exit;

    StartIdx := -1;
    EndIdx := -1;
    for I := 0 to ATrace.Count - 1 do
    begin
      if (StartIdx < 0) and (Pos('ScriptCanceledObject: TReportTextObject', ATrace[I]) > 0) then
        StartIdx := I;
      if (StartIdx >= 0) and (Pos('AfterBand: Report Title', ATrace[I]) > 0) then
      begin
        EndIdx := I;
        Break;
      end;
    end;

    if (StartIdx < 0) or (EndIdx < 0) or (EndIdx <= StartIdx) then
      Exit(False);

    for I := StartIdx + 1 to EndIdx - 1 do
    begin
      S := ATrace[I];
      if (Pos('BeforeObject: TReportTextObject', S) > 0) or
         (Pos('ScriptAfterObject: TReportTextObject "txtTitle"', S) > 0) or
         (Pos('AfterObject: TReportTextObject', S) > 0) then
        Exit(False);
    end;

    Result := True;
  end;
  procedure AppendUnsupportedSummary(const ATitle: string; const ATrace: TStrings; ALines: TStrings);
  var
    U: TStringList;
    L: string;
    I: Integer;
  begin
    if not Assigned(ATrace) or not Assigned(ALines) then
      Exit;

    U := TStringList.Create;
    try
      U.Sorted := True;
      U.Duplicates := dupIgnore;
      for L in ATrace do
        if Pos('ScriptUnsupported', L) > 0 then
          U.Add(L);

      ALines.Add(Format('  %s unsupported count: %d', [ATitle, U.Count]));
      for I := 0 to Min(4, U.Count - 1) do
        ALines.Add('    ' + U[I]);
      if U.Count > 5 then
        ALines.Add(Format('    ... (%d more unsupported lines)', [U.Count - 5]));
    finally
      U.Free;
    end;
  end;
  procedure AddUnsupportedReasonCounts(const ATrace: TStrings;
    ACounts: TDictionary<string, Integer>);
  var
    L: string;
    P1: Integer;
    P2: Integer;
    Reason: string;
    C: Integer;
  begin
    if not Assigned(ATrace) or not Assigned(ACounts) then
      Exit;

    for L in ATrace do
    begin
      P1 := Pos('ScriptUnsupported[', L);
      if P1 <= 0 then
        Continue;
      P1 := P1 + Length('ScriptUnsupported[');
      P2 := Pos(']:', L);
      if (P2 <= P1) then
        Continue;
      Reason := Trim(Copy(L, P1, P2 - P1));
      if Reason = '' then
        Reason := 'Unknown';
      if ACounts.TryGetValue(Reason, C) then
        ACounts.AddOrSetValue(Reason, C + 1)
      else
        ACounts.Add(Reason, 1);
    end;
  end;
  procedure AppendUnsupportedReasonSummary(ALines: TStrings;
    const ATraces: array of TStrings);
  var
    Counts: TDictionary<string, Integer>;
    Pair: TPair<string, Integer>;
    OutLines: TStringList;
    I: Integer;
  begin
    if not Assigned(ALines) then
      Exit;

    Counts := TDictionary<string, Integer>.Create;
    OutLines := TStringList.Create;
    try
      for I := Low(ATraces) to High(ATraces) do
        AddUnsupportedReasonCounts(ATraces[I], Counts);

      ALines.Add('');
      ALines.Add('Unsupported reason summary:');
      if Counts.Count = 0 then
      begin
        ALines.Add('  none');
        Exit;
      end;

      for Pair in Counts do
        OutLines.Add(Format('  %s: %d', [Pair.Key, Pair.Value]));
      OutLines.Sort;
      for I := 0 to OutLines.Count - 1 do
        ALines.Add(OutLines[I]);
    finally
      OutLines.Free;
      Counts.Free;
    end;
  end;
begin
  UseSampleDataSet;

  ReportModel := nil;
  Engine := nil;
  Harness := nil;
  Lines := TStringList.Create;
  BaselineTrace := TStringList.Create;
  ObjectSkipTrace := TStringList.Create;
  BandSkipTrace := TStringList.Create;
  ScriptCancelTrace := TStringList.Create;
  FieldBindTrace := TStringList.Create;
  FieldResolveMissTrace := TStringList.Create;
  FieldResolveMissWithUnsupportedTrace := TStringList.Create;
  BackgroundTrace := TStringList.Create;
  VisibleTrace := TStringList.Create;
  AnchorRightTrace := TStringList.Create;
  AnchorBottomTrace := TStringList.Create;
  EscapedQuoteTrace := TStringList.Create;
  WhitespaceTrace := TStringList.Create;
  TrailingSemicolonTrace := TStringList.Create;
  UnknownCommandTrace := TStringList.Create;
  FieldSyntaxTrace := TStringList.Create;
  FieldNameTrace := TStringList.Create;
  ColorValueTrace := TStringList.Create;
  VisibleValueTrace := TStringList.Create;
  TextLiteralTrace := TStringList.Create;
  CanPrintValueTrace := TStringList.Create;
  MultiInvalidTrace := TStringList.Create;
  MixedValidInvalidTrace := TStringList.Create;
  CancelShortCircuitTrace := TStringList.Create;
  QuotedSemicolonWithUnsupportedTrace := TStringList.Create;
  ObjectTypeMismatchTrace := TStringList.Create;
  LowercaseTextKeyTrace := TStringList.Create;
  MixedCaseCanPrintTrace := TStringList.Create;
  MixedCaseVisibleTrace := TStringList.Create;
  MixedCaseBackgroundTrace := TStringList.Create;
  FontColorTrace := TStringList.Create;
  FontSizeTrace := TStringList.Create;
  FontNameTrace := TStringList.Create;
  FontBoldTrace := TStringList.Create;
  FontItalicTrace := TStringList.Create;
  HAlignTrace := TStringList.Create;
  VAlignTrace := TStringList.Create;
  PrintWhenTrace := TStringList.Create;
  DataFieldTrace := TStringList.Create;
  ExpressionTrace := TStringList.Create;
  BorderColorTrace := TStringList.Create;
  TransparentTrace := TStringList.Create;
  AutoSizeTrace := TStringList.Create;
  WordWrapTrace := TStringList.Create;
  BorderVisibleTrace := TStringList.Create;
  BorderWidthTrace := TStringList.Create;
  PaddingLeftTrace := TStringList.Create;
  PaddingTopTrace := TStringList.Create;
  PaddingRightTrace := TStringList.Create;
  PaddingBottomTrace := TStringList.Create;
  FontColorOnTrueTrace := TStringList.Create;
  BackgroundOnTrueTrace := TStringList.Create;
  BorderColorOnTrueTrace := TStringList.Create;
  BackgroundConditionTrace := TStringList.Create;
  BorderColorConditionTrace := TStringList.Create;
  FontColorConditionTrace := TStringList.Create;
  FieldDisplayFormatTrace := TStringList.Create;
  FieldEditMaskTrace := TStringList.Create;
  ImageStretchTrace := TStringList.Create;
  ImageCenterTrace := TStringList.Create;
  ImageProportionalTrace := TStringList.Create;
  ImageDataFieldTrace := TStringList.Create;
  try
    FN := GetRegressionReportPath('01_simple_masterdata.vrt');
    if TFile.Exists(FN) then
      ReportModel := TReportSerializer.LoadFromFile(FN)
    else if Assigned(FDesigner) and Assigned(FDesigner.Report) then
      ReportModel := TReportSerializer.LoadFromJSON(
        TReportSerializer.SaveToJSON(FDesigner.Report))
    else
      raise Exception.Create('Could not load a report for runtime event demo.');

    Harness := TRuntimeEventDemoHarness.Create;
    DemoScriptTarget := nil;
    DemoFieldTarget := nil;
    DemoImageTarget := nil;
    DemoNonTextTarget := nil;
    for Obj in ReportModel.Objects do
    begin
      if Obj is TReportTextObject then
      begin
        if not Assigned(DemoScriptTarget) then
          DemoScriptTarget := Obj;
      end
      else if (Obj is TReportFieldObject) and not Assigned(DemoFieldTarget) then
        DemoFieldTarget := TReportFieldObject(Obj)
      else if (Obj is TReportImageObject) and not Assigned(DemoImageTarget) then
        DemoImageTarget := TReportImageObject(Obj)
      else if (not (Obj is TReportBand)) and not Assigned(DemoNonTextTarget) then
        DemoNonTextTarget := Obj;

      if Assigned(DemoScriptTarget) and Assigned(DemoFieldTarget) and Assigned(DemoImageTarget) and Assigned(DemoNonTextTarget) then
        Break;
    end;

    if not Assigned(DemoScriptTarget) then
    begin
      for Obj in ReportModel.Objects do
      begin
        if Obj is TReportBand then
        begin
          Band := TReportBand(Obj);
          for ChildObj in Band.Children do
          begin
            if (ChildObj is TReportTextObject) and not Assigned(DemoScriptTarget) then
              DemoScriptTarget := ChildObj
            else if (ChildObj is TReportFieldObject) and not Assigned(DemoFieldTarget) then
              DemoFieldTarget := TReportFieldObject(ChildObj)
            else if (ChildObj is TReportImageObject) and not Assigned(DemoImageTarget) then
              DemoImageTarget := TReportImageObject(ChildObj)
            else if (not (ChildObj is TReportTextObject)) and not Assigned(DemoNonTextTarget) then
              DemoNonTextTarget := ChildObj;
            if Assigned(DemoScriptTarget) and Assigned(DemoFieldTarget) and Assigned(DemoImageTarget) and Assigned(DemoNonTextTarget) then
              Break;
          end;
        end;
        if Assigned(DemoScriptTarget) and Assigned(DemoFieldTarget) and Assigned(DemoImageTarget) and Assigned(DemoNonTextTarget) then
          Break;
      end;
    end;

    if not Assigned(DemoNonTextTarget) then
    begin
      for Obj in ReportModel.Objects do
      begin
        if Obj is TReportBand then
        begin
          Band := TReportBand(Obj);
          DemoNonTextTarget := TReportLineObject.Create;
          DemoNonTextTarget.Name := 'rtDemoObjectTypeMismatch';
          DemoNonTextTarget.Bounds := Rect(12, 28, 180, 30);
          Band.Children.Add(DemoNonTextTarget);
          Break;
        end;
      end;
    end;

    if not Assigned(DemoImageTarget) then
    begin
      for Obj in ReportModel.Objects do
      begin
        if Obj is TReportBand then
        begin
          Band := TReportBand(Obj);
          DemoImageTarget := TReportImageObject.Create;
          DemoImageTarget.Name := 'rtDemoImageObject';
          DemoImageTarget.Bounds := Rect(200, 3, 300, 58);
          DemoImageTarget.DataField := 'ImagePath';
          Band.Children.Add(DemoImageTarget);
          Break;
        end;
      end;
    end;

    if Assigned(DemoScriptTarget) then
    begin
      if Trim(DemoScriptTarget.OnBeforePrint) = '' then
        DemoScriptTarget.OnBeforePrint := 'Text := ''Demo Title''';
      if Trim(DemoScriptTarget.OnAfterPrint) = '' then
        DemoScriptTarget.OnAfterPrint := 'DemoObjectAfter';
    end;

    if Assigned(DemoFieldTarget) then
    begin
      if Trim(DemoFieldTarget.OnBeforePrint) = '' then
        DemoFieldTarget.OnBeforePrint := 'DisplayFormat := #,##0.00; EditMask := ''!99;0;_''';
      if Trim(DemoFieldTarget.OnAfterPrint) = '' then
        DemoFieldTarget.OnAfterPrint := 'DemoFieldAfter';
    end;

    if Assigned(DemoImageTarget) then
    begin
      if Trim(DemoImageTarget.OnBeforePrint) = '' then
        DemoImageTarget.OnBeforePrint := 'Stretch := False; Center := True; Proportional := False';
      if Trim(DemoImageTarget.OnAfterPrint) = '' then
        DemoImageTarget.OnAfterPrint := 'DemoImageAfter';
    end;

    if not Assigned(DemoScriptTarget) then
      raise Exception.Create('Could not find text object for runtime event demo.');
    if not Assigned(DemoFieldTarget) then
      raise Exception.Create('Could not find field object for runtime event demo.');
    if not Assigned(DemoImageTarget) then
      raise Exception.Create('Could not find image object for runtime event demo.');

    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;

    BaseBeforeBand := Harness.BeforeBandCount;
    BaseAfterBand := Harness.AfterBandCount;
    BaseBeforeObject := Harness.BeforeObjectCount;
    BaseAfterObject := Harness.AfterObjectCount;
    BaseScriptBeforeObject := Harness.ScriptBeforeObjectCount;
    BaseScriptAfterObject := Harness.ScriptAfterObjectCount;
    BaselineTrace.Assign(Harness.Trace);

    BasePass :=
      (Harness.BeforeReportCount = 1) and
      (Harness.AfterReportCount = 1) and
      (Harness.BeforeBandCount > 0) and
      (Harness.AfterBandCount > 0) and
      (Harness.BeforeObjectCount > 0) and
      (Harness.AfterObjectCount > 0) and
      (Harness.BeforeBandCount >= Harness.AfterBandCount) and
      (Harness.BeforeObjectCount >= Harness.AfterObjectCount) and
      (Harness.ScriptBeforeObjectCount > 0) and
      (Harness.ScriptAfterObjectCount > 0);
    CountingInflationPass :=
      (Harness.BeforeReportCount = 1) and
      (Harness.AfterReportCount = 1);
    TargetOrderPass := TraceHasOrdered(BaselineTrace, [
      'ScriptBeforeObject: TReportTextObject "txtTitle"',
      'BeforeObject: TReportTextObject',
      'ScriptAfterObject: TReportTextObject "txtTitle"',
      'AfterObject: TReportTextObject'
    ]);

    Lines.Add('');
    Lines.Add('Baseline summary:');
    Lines.Add(Format('  BeforeReport=%d AfterReport=%d  BeforeBand=%d AfterBand=%d  BeforeObject=%d AfterObject=%d  ScriptBeforeObject=%d ScriptAfterObject=%d  ScriptSetText=%d ScriptUnsupported=%d  SkippedObject=%d SkippedBand=%d ScriptCanceled=%d',
      [Harness.BeforeReportCount, Harness.AfterReportCount,
       Harness.BeforeBandCount, Harness.AfterBandCount,
       Harness.BeforeObjectCount, Harness.AfterObjectCount,
       Harness.ScriptBeforeObjectCount, Harness.ScriptAfterObjectCount,
       Harness.ScriptTextSetCount, Harness.ScriptUnsupportedCount,
       Harness.SkippedObjectCount, Harness.SkippedBandCount,
       Harness.ScriptCanceledObjectCount]));
    if BasePass then
      Lines.Add('  Baseline: PASS')
    else
      Lines.Add('  Baseline: FAIL');
    if CountingInflationPass then
      Lines.Add('  Counting-pass inflation check: PASS')
    else
      Lines.Add('  Counting-pass inflation check: FAIL');
    if TargetOrderPass then
      Lines.Add('  Target object order check: PASS')
    else
      Lines.Add('  Target object order check: FAIL');

    Harness.ResetCounts;
    Harness.SkipObjectClassName := 'TReportTextObject';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    ObjectSkipPass := Harness.SkippedObjectCount > 0;
    ObjectSkipTrace.Assign(Harness.Trace);
    Lines.Add('');
    Lines.Add('Object-skip summary:');
    Lines.Add(Format('  BeforeReport=%d AfterReport=%d  BeforeBand=%d AfterBand=%d  BeforeObject=%d AfterObject=%d  ScriptBeforeObject=%d ScriptAfterObject=%d  ScriptSetText=%d ScriptUnsupported=%d  SkippedObject=%d SkippedBand=%d ScriptCanceled=%d',
      [Harness.BeforeReportCount, Harness.AfterReportCount,
       Harness.BeforeBandCount, Harness.AfterBandCount,
       Harness.BeforeObjectCount, Harness.AfterObjectCount,
       Harness.ScriptBeforeObjectCount, Harness.ScriptAfterObjectCount,
       Harness.ScriptTextSetCount, Harness.ScriptUnsupportedCount,
       Harness.SkippedObjectCount, Harness.SkippedBandCount,
       Harness.ScriptCanceledObjectCount]));
    if ObjectSkipPass then
      Lines.Add(Format('Object skip subtest (skip %s): PASS (SkippedObjectCount=%d)',
        ['TReportTextObject', Harness.SkippedObjectCount]))
    else
      Lines.Add(Format('Object skip subtest (skip %s): FAIL (SkippedObjectCount=%d)',
        ['TReportTextObject', Harness.SkippedObjectCount]));

    Harness.ResetCounts;
    Harness.SkipMasterDataBand := True;
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BandSkipPass := Harness.SkippedBandCount > 0;
    BandSkipTrace.Assign(Harness.Trace);
    Lines.Add('');
    Lines.Add('Band-skip summary:');
    Lines.Add(Format('  BeforeReport=%d AfterReport=%d  BeforeBand=%d AfterBand=%d  BeforeObject=%d AfterObject=%d  ScriptBeforeObject=%d ScriptAfterObject=%d  ScriptSetText=%d ScriptUnsupported=%d  SkippedObject=%d SkippedBand=%d ScriptCanceled=%d',
      [Harness.BeforeReportCount, Harness.AfterReportCount,
       Harness.BeforeBandCount, Harness.AfterBandCount,
       Harness.BeforeObjectCount, Harness.AfterObjectCount,
       Harness.ScriptBeforeObjectCount, Harness.ScriptAfterObjectCount,
       Harness.ScriptTextSetCount, Harness.ScriptUnsupportedCount,
       Harness.SkippedObjectCount, Harness.SkippedBandCount,
       Harness.ScriptCanceledObjectCount]));
    if BandSkipPass then
      Lines.Add(Format('Band skip subtest (skip Master Data): PASS (SkippedBandCount=%d)',
        [Harness.SkippedBandCount]))
    else
      Lines.Add(Format('Band skip subtest (skip Master Data): FAIL (SkippedBandCount=%d)',
        [Harness.SkippedBandCount]));
    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'CanPrint := False';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    ScriptCancelPass := Harness.ScriptCanceledObjectCount > 0;
    ScriptCancelTrace.Assign(Harness.Trace);
    Lines.Add('');
    Lines.Add('Script-host cancel summary:');
    Lines.Add(Format('  BeforeReport=%d AfterReport=%d  BeforeBand=%d AfterBand=%d  BeforeObject=%d AfterObject=%d  ScriptBeforeObject=%d ScriptAfterObject=%d  ScriptSetText=%d ScriptUnsupported=%d  SkippedObject=%d SkippedBand=%d ScriptCanceled=%d',
      [Harness.BeforeReportCount, Harness.AfterReportCount,
       Harness.BeforeBandCount, Harness.AfterBandCount,
       Harness.BeforeObjectCount, Harness.AfterObjectCount,
       Harness.ScriptBeforeObjectCount, Harness.ScriptAfterObjectCount,
       Harness.ScriptTextSetCount, Harness.ScriptUnsupportedCount,
       Harness.SkippedObjectCount, Harness.SkippedBandCount,
       Harness.ScriptCanceledObjectCount]));
    if ScriptCancelPass then
      Lines.Add('Script-host CanPrint=False subtest: PASS')
    else
      Lines.Add('Script-host CanPrint=False subtest: FAIL');
    TargetCancelOrderPass := TraceHasOrdered(ScriptCancelTrace, [
      'ScriptBeforeObject: TReportTextObject "txtTitle" text="CanPrint := False"',
      'ScriptCanceledObject: TReportTextObject'
    ]) and
      TraceWindowHasNoTargetObjectHooks(ScriptCancelTrace);
    if TargetCancelOrderPass then
      Lines.Add('  Target object cancel-order check: PASS')
    else
      Lines.Add('  Target object cancel-order check: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
    begin
      DemoScriptTarget.OnBeforePrint := 'Text := Field(''CustomerName'')';
      DemoScriptTarget.OnAfterPrint := 'DemoObjectAfter';
    end;
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FieldBindTrace.Assign(Harness.Trace);
    FieldBindPass :=
      (Pos('ScriptSetTextFromField: TReportTextObject "txtTitle" <- Field("CustomerName")',
        FieldBindTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    Lines.Add('');
    if FieldBindPass then
      Lines.Add('Field() text-binding subtest: PASS')
    else
      Lines.Add('Field() text-binding subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := Field(''NoSuchField'')';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FieldResolveMissTrace.Assign(Harness.Trace);
    FieldResolveMissPass :=
      (Pos('ScriptFieldResolveMiss: NoSuchField', FieldResolveMissTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0) and
      (Pos('ScriptUnsupported[', FieldResolveMissTrace.Text) = 0);
    if FieldResolveMissPass then
      Lines.Add('Field() missing-field resolve subtest: PASS')
    else
      Lines.Add('Field() missing-field resolve subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := Field(''NoSuchField''); Foo := 1';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FieldResolveMissWithUnsupportedTrace.Assign(Harness.Trace);
    FieldResolveMissWithUnsupportedPass :=
      (Pos('ScriptFieldResolveMiss: NoSuchField', FieldResolveMissWithUnsupportedTrace.Text) > 0) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', FieldResolveMissWithUnsupportedTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 1);
    if FieldResolveMissWithUnsupportedPass then
      Lines.Add('Field() resolve-miss + unsupported subtest: PASS')
    else
      Lines.Add('Field() resolve-miss + unsupported subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Background := clYellow';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BackgroundTrace.Assign(Harness.Trace);
    BackgroundPass :=
      (Pos('ScriptSetBackground: TReportTextObject "txtTitle" -> clYellow', BackgroundTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BackgroundPass then
      Lines.Add('Background command subtest: PASS')
    else
      Lines.Add('Background command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Visible := False';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    VisibleTrace.Assign(Harness.Trace);
    VisiblePass :=
      (Pos('ScriptSetVisible: TReportTextObject "txtTitle" -> False', VisibleTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if VisiblePass then
      Lines.Add('Visible command subtest: PASS')
    else
      Lines.Add('Visible command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'AnchorRight := True';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    AnchorRightTrace.Assign(Harness.Trace);
    AnchorRightPass :=
      (Pos('ScriptSetAnchorRight: TReportTextObject "txtTitle" -> True', AnchorRightTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if AnchorRightPass then
      Lines.Add('AnchorRight command subtest: PASS')
    else
      Lines.Add('AnchorRight command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'AnchorBottom := True';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    AnchorBottomTrace.Assign(Harness.Trace);
    AnchorBottomPass :=
      (Pos('ScriptSetAnchorBottom: TReportTextObject "txtTitle" -> True', AnchorBottomTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if AnchorBottomPass then
      Lines.Add('AnchorBottom command subtest: PASS')
    else
      Lines.Add('AnchorBottom command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := ''O''''Reilly''';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    EscapedQuoteTrace.Assign(Harness.Trace);
    EscapedQuotePass :=
      (Harness.ScriptTextSetCount > 0) and
      (Harness.ScriptUnsupportedCount = 0) and
      (Pos('ScriptSetText: TReportTextObject', EscapedQuoteTrace.Text) > 0) and
      (Pos('Reilly', EscapedQuoteTrace.Text) > 0);
    if EscapedQuotePass then
      Lines.Add('Escaped quote literal subtest: PASS')
    else
      Lines.Add('Escaped quote literal subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := '  Visible   :=   True ;   Text := ''WS''   ';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    WhitespaceTrace.Assign(Harness.Trace);
    WhitespacePass :=
      (Harness.ScriptTextSetCount > 0) and
      (Harness.ScriptUnsupportedCount = 0) and
      (Pos('ScriptSetVisible: TReportTextObject', WhitespaceTrace.Text) > 0) and
      (Pos('-> True', WhitespaceTrace.Text) > 0) and
      (Pos('ScriptSetText: TReportTextObject', WhitespaceTrace.Text) > 0) and
      (Pos('WS', WhitespaceTrace.Text) > 0);
    if WhitespacePass then
      Lines.Add('Whitespace normalization subtest: PASS')
    else
      Lines.Add('Whitespace normalization subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := ''Tail''; ; ;';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    TrailingSemicolonTrace.Assign(Harness.Trace);
    TrailingSemicolonPass :=
      (Harness.ScriptTextSetCount > 0) and
      (Harness.ScriptUnsupportedCount = 0) and
      (Pos('ScriptSetText: TReportTextObject', TrailingSemicolonTrace.Text) > 0) and
      (Pos('Tail', TrailingSemicolonTrace.Text) > 0);
    if TrailingSemicolonPass then
      Lines.Add('Trailing semicolon subtest: PASS')
    else
      Lines.Add('Trailing semicolon subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Foo := 1';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    UnknownCommandTrace.Assign(Harness.Trace);
    UnknownCommandPass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', UnknownCommandTrace.Text) > 0);
    if UnknownCommandPass then
      Lines.Add('Unknown command subtest: PASS')
    else
      Lines.Add('Unknown command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := Field(CustomerName)';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FieldSyntaxTrace.Assign(Harness.Trace);
    FieldSyntaxPass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[FieldSyntax]: Text := Field(CustomerName)', FieldSyntaxTrace.Text) > 0);
    if FieldSyntaxPass then
      Lines.Add('Field syntax subtest: PASS')
    else
      Lines.Add('Field syntax subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := Field(''   '')';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FieldNameTrace.Assign(Harness.Trace);
    FieldNamePass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[FieldName]: Text := Field(''   '')', FieldNameTrace.Text) > 0);
    if FieldNamePass then
      Lines.Add('Field name subtest: PASS')
    else
      Lines.Add('Field name subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Background := clNotAColor';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    ColorValueTrace.Assign(Harness.Trace);
    ColorValuePass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[ColorValue]: Background := clNotAColor', ColorValueTrace.Text) > 0);
    if ColorValuePass then
      Lines.Add('Color value subtest: PASS')
    else
      Lines.Add('Color value subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Visible := Maybe';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    VisibleValueTrace.Assign(Harness.Trace);
    VisibleValuePass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[VisibleValue]: Visible := Maybe', VisibleValueTrace.Text) > 0);
    if VisibleValuePass then
      Lines.Add('Visible value subtest: PASS')
    else
      Lines.Add('Visible value subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := Demo';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    TextLiteralTrace.Assign(Harness.Trace);
    TextLiteralPass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[TextLiteral]: Text := Demo', TextLiteralTrace.Text) > 0);
    if TextLiteralPass then
      Lines.Add('Text literal subtest: PASS')
    else
      Lines.Add('Text literal subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'CanPrint := Maybe';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    CanPrintValueTrace.Assign(Harness.Trace);
    CanPrintValuePass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[CanPrintValue]: CanPrint := Maybe', CanPrintValueTrace.Text) > 0);
    if CanPrintValuePass then
      Lines.Add('CanPrint value subtest: PASS')
    else
      Lines.Add('CanPrint value subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Foo := 1; Visible := Maybe; Text := Demo; Foo := 1';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    MultiInvalidTrace.Assign(Harness.Trace);
    MultiInvalidPass :=
      (Harness.ScriptUnsupportedCount >= 4) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', MultiInvalidTrace.Text) > 0) and
      (Pos('ScriptUnsupported[VisibleValue]: Visible := Maybe', MultiInvalidTrace.Text) > 0) and
      (Pos('ScriptUnsupported[TextLiteral]: Text := Demo', MultiInvalidTrace.Text) > 0);
    if MultiInvalidPass then
      Lines.Add('Multi-invalid aggregation subtest: PASS')
    else
      Lines.Add('Multi-invalid aggregation subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := ''OK''; Foo := 1; Visible := True; Text := Demo';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    MixedValidInvalidTrace.Assign(Harness.Trace);
    MixedValidInvalidPass :=
      (Harness.ScriptTextSetCount > 0) and
      (Harness.ScriptUnsupportedCount >= 2) and
      (Pos('ScriptSetText: TReportTextObject "txtTitle" -> "OK"', MixedValidInvalidTrace.Text) > 0) and
      (Pos('ScriptSetVisible: TReportTextObject "txtTitle" -> True', MixedValidInvalidTrace.Text) > 0) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', MixedValidInvalidTrace.Text) > 0) and
      (Pos('ScriptUnsupported[TextLiteral]: Text := Demo', MixedValidInvalidTrace.Text) > 0);
    if MixedValidInvalidPass then
      Lines.Add('Mixed valid+invalid sequence subtest: PASS')
    else
      Lines.Add('Mixed valid+invalid sequence subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'CanPrint := False; Foo := 1; Text := Demo';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    CancelShortCircuitTrace.Assign(Harness.Trace);
    CancelShortCircuitPass :=
      (Harness.ScriptCanceledObjectCount > 0) and
      (Harness.ScriptUnsupportedCount = 0) and
      (Pos('ScriptCanceledObject: TReportTextObject', CancelShortCircuitTrace.Text) > 0) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', CancelShortCircuitTrace.Text) = 0) and
      (Pos('ScriptUnsupported[TextLiteral]: Text := Demo', CancelShortCircuitTrace.Text) = 0) and
      TraceWindowHasNoTargetObjectHooks(CancelShortCircuitTrace);
    if CancelShortCircuitPass then
      Lines.Add('CanPrint short-circuit mixed sequence subtest: PASS')
    else
      Lines.Add('CanPrint short-circuit mixed sequence subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := ''A;B''; Foo := 1';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    QuotedSemicolonWithUnsupportedTrace.Assign(Harness.Trace);
    QuotedSemicolonWithUnsupportedPass :=
      (Harness.ScriptTextSetCount > 0) and
      (Harness.ScriptUnsupportedCount = 1) and
      (Pos('ScriptSetText: TReportTextObject "txtTitle" -> "A;B"', QuotedSemicolonWithUnsupportedTrace.Text) > 0) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', QuotedSemicolonWithUnsupportedTrace.Text) > 0);
    if QuotedSemicolonWithUnsupportedPass then
      Lines.Add('Quoted semicolon + unsupported subtest: PASS')
    else
      Lines.Add('Quoted semicolon + unsupported subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'text := ''lower''';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    LowercaseTextKeyTrace.Assign(Harness.Trace);
    LowercaseTextKeyPass :=
      (Pos('ScriptSetText: TReportTextObject "txtTitle" -> "lower"', LowercaseTextKeyTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if LowercaseTextKeyPass then
      Lines.Add('Lowercase key subtest (text): PASS')
    else
      Lines.Add('Lowercase key subtest (text): FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'cAnPrInT := False; Foo := 1';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    MixedCaseCanPrintTrace.Assign(Harness.Trace);
    MixedCaseCanPrintPass :=
      (Harness.ScriptCanceledObjectCount > 0) and
      (Harness.ScriptUnsupportedCount = 0) and
      (Pos('ScriptCanceledObject: TReportTextObject', MixedCaseCanPrintTrace.Text) > 0) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', MixedCaseCanPrintTrace.Text) = 0);
    if MixedCaseCanPrintPass then
      Lines.Add('Mixed-case key subtest (CanPrint): PASS')
    else
      Lines.Add('Mixed-case key subtest (CanPrint): FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'VISIBLE := True';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    MixedCaseVisibleTrace.Assign(Harness.Trace);
    MixedCaseVisiblePass :=
      (Pos('ScriptSetVisible: TReportTextObject "txtTitle" -> True', MixedCaseVisibleTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if MixedCaseVisiblePass then
      Lines.Add('Mixed-case key subtest (VISIBLE): PASS')
    else
      Lines.Add('Mixed-case key subtest (VISIBLE): FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BaCkGrOuNd := clYellow';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    MixedCaseBackgroundTrace.Assign(Harness.Trace);
    MixedCaseBackgroundPass :=
      (Pos('ScriptSetBackground: TReportTextObject "txtTitle" -> clYellow', MixedCaseBackgroundTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if MixedCaseBackgroundPass then
      Lines.Add('Mixed-case key subtest (BaCkGrOuNd): PASS')
    else
      Lines.Add('Mixed-case key subtest (BaCkGrOuNd): FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontColor := clNavy';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontColorTrace.Assign(Harness.Trace);
    FontColorPass :=
      (Pos('ScriptSetFontColor: TReportTextObject "txtTitle" -> clNavy', FontColorTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontColorPass then
      Lines.Add('FontColor command subtest: PASS')
    else
      Lines.Add('FontColor command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontSize := 14';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontSizeTrace.Assign(Harness.Trace);
    FontSizePass :=
      (Pos('ScriptSetFontSize: TReportTextObject "txtTitle" -> 14', FontSizeTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontSizePass then
      Lines.Add('FontSize command subtest: PASS')
    else
      Lines.Add('FontSize command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontName := Arial';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontNameTrace.Assign(Harness.Trace);
    FontNamePass :=
      (Pos('ScriptSetFontName: TReportTextObject "txtTitle" -> "Arial"', FontNameTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontNamePass then
      Lines.Add('FontName command subtest: PASS')
    else
      Lines.Add('FontName command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontBold := True';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontBoldTrace.Assign(Harness.Trace);
    FontBoldPass :=
      (Pos('ScriptSetFontBold: TReportTextObject "txtTitle" -> True', FontBoldTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontBoldPass then
      Lines.Add('FontBold command subtest: PASS')
    else
      Lines.Add('FontBold command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontItalic := True';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontItalicTrace.Assign(Harness.Trace);
    FontItalicPass :=
      (Pos('ScriptSetFontItalic: TReportTextObject "txtTitle" -> True', FontItalicTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontItalicPass then
      Lines.Add('FontItalic command subtest: PASS')
    else
      Lines.Add('FontItalic command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'HAlign := Center';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    HAlignTrace.Assign(Harness.Trace);
    HAlignPass :=
      (Pos('ScriptSetHAlign: TReportTextObject "txtTitle" -> Center', HAlignTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if HAlignPass then
      Lines.Add('HAlign command subtest: PASS')
    else
      Lines.Add('HAlign command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'VAlign := Bottom';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    VAlignTrace.Assign(Harness.Trace);
    VAlignPass :=
      (Pos('ScriptSetVAlign: TReportTextObject "txtTitle" -> Bottom', VAlignTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if VAlignPass then
      Lines.Add('VAlign command subtest: PASS')
    else
      Lines.Add('VAlign command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'PrintWhen := Value > 0';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    PrintWhenTrace.Assign(Harness.Trace);
    PrintWhenPass :=
      (Pos('ScriptSetPrintWhen: TReportTextObject "txtTitle" -> "Value > 0"', PrintWhenTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if PrintWhenPass then
      Lines.Add('PrintWhen command subtest: PASS')
    else
      Lines.Add('PrintWhen command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'DataField := CustomerName';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    DataFieldTrace.Assign(Harness.Trace);
    DataFieldPass :=
      (Pos('ScriptSetDataField: TReportTextObject "txtTitle" -> "CustomerName"', DataFieldTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if DataFieldPass then
      Lines.Add('DataField command subtest: PASS')
    else
      Lines.Add('DataField command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Expression := Value + 1';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    ExpressionTrace.Assign(Harness.Trace);
    ExpressionPass :=
      (Pos('ScriptSetExpression: TReportTextObject "txtTitle" -> "Value + 1"', ExpressionTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if ExpressionPass then
      Lines.Add('Expression command subtest: PASS')
    else
      Lines.Add('Expression command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoFieldTarget) then
      DemoFieldTarget.Visible := True;
    if Assigned(DemoFieldTarget) then
      DemoFieldTarget.OnBeforePrint := 'DisplayFormat := #,##0.00; EditMask := ''!99;0;_''';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FieldDisplayFormatTrace.Assign(Harness.Trace);
    FieldDisplayFormatPass :=
      (Pos('ScriptSetDisplayFormat: TReportFieldObject', FieldDisplayFormatTrace.Text) > 0) and
      (Pos('ScriptSetEditMask: TReportFieldObject', FieldDisplayFormatTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FieldDisplayFormatPass then
      Lines.Add('Field DisplayFormat/EditMask command subtest: PASS')
    else
      Lines.Add('Field DisplayFormat/EditMask command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoImageTarget) then
      DemoImageTarget.Visible := True;
    if Assigned(DemoImageTarget) then
      DemoImageTarget.OnBeforePrint := 'DataField := ImagePath; Stretch := False; Center := True; Proportional := False';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    ImageStretchTrace.Assign(Harness.Trace);
    ImageStretchPass :=
      (Pos('ScriptSetStretch: TReportImageObject', ImageStretchTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    ImageCenterPass := (Pos('ScriptSetCenter: TReportImageObject', ImageStretchTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    ImageProportionalPass := (Pos('ScriptSetProportional: TReportImageObject', ImageStretchTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if ImageStretchPass and ImageCenterPass and ImageProportionalPass then
      Lines.Add('Image fit command subtest: PASS')
    else
      Lines.Add('Image fit command subtest: FAIL');

    ImageDataFieldTrace.Assign(Harness.Trace);
    ImageDataFieldPass :=
      (Pos('ScriptSetDataField: TReportImageObject "rtDemoImageObject" -> "ImagePath"', ImageDataFieldTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if ImageDataFieldPass then
      Lines.Add('Image DataField command subtest: PASS')
    else
      Lines.Add('Image DataField command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BorderColor := clOlive';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BorderColorTrace.Assign(Harness.Trace);
    BorderColorPass :=
      (Pos('ScriptSetBorderColor: TReportTextObject "txtTitle" -> clOlive', BorderColorTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BorderColorPass then
      Lines.Add('BorderColor command subtest: PASS')
    else
      Lines.Add('BorderColor command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Transparent := False';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    TransparentTrace.Assign(Harness.Trace);
    TransparentPass :=
      (Pos('ScriptSetTransparent: TReportTextObject "txtTitle" -> False', TransparentTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if TransparentPass then
      Lines.Add('Transparent command subtest: PASS')
    else
      Lines.Add('Transparent command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'AutoSize := True';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    AutoSizeTrace.Assign(Harness.Trace);
    AutoSizePass :=
      (Pos('ScriptSetAutoSize: TReportTextObject "txtTitle" -> True', AutoSizeTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if AutoSizePass then
      Lines.Add('AutoSize command subtest: PASS')
    else
      Lines.Add('AutoSize command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'WordWrap := True';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    WordWrapTrace.Assign(Harness.Trace);
    WordWrapPass :=
      (Pos('ScriptSetWordWrap: TReportTextObject "txtTitle" -> True', WordWrapTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if WordWrapPass then
      Lines.Add('WordWrap command subtest: PASS')
    else
      Lines.Add('WordWrap command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BorderVisible := True';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BorderVisibleTrace.Assign(Harness.Trace);
    BorderVisiblePass :=
      (Pos('ScriptSetBorderVisible: TReportTextObject "txtTitle" -> True', BorderVisibleTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BorderVisiblePass then
      Lines.Add('BorderVisible command subtest: PASS')
    else
      Lines.Add('BorderVisible command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BorderWidth := 3';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BorderWidthTrace.Assign(Harness.Trace);
    BorderWidthPass :=
      (Pos('ScriptSetBorderWidth: TReportTextObject "txtTitle" -> 3', BorderWidthTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BorderWidthPass then
      Lines.Add('BorderWidth command subtest: PASS')
    else
      Lines.Add('BorderWidth command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'PaddingLeft := 12';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    PaddingLeftTrace.Assign(Harness.Trace);
    PaddingLeftPass :=
      (Pos('ScriptSetPaddingLeft: TReportTextObject "txtTitle" -> 12', PaddingLeftTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if PaddingLeftPass then
      Lines.Add('PaddingLeft command subtest: PASS')
    else
      Lines.Add('PaddingLeft command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'PaddingTop := 7';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    PaddingTopTrace.Assign(Harness.Trace);
    PaddingTopPass :=
      (Pos('ScriptSetPaddingTop: TReportTextObject "txtTitle" -> 7', PaddingTopTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if PaddingTopPass then
      Lines.Add('PaddingTop command subtest: PASS')
    else
      Lines.Add('PaddingTop command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'PaddingRight := 9';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    PaddingRightTrace.Assign(Harness.Trace);
    PaddingRightPass :=
      (Pos('ScriptSetPaddingRight: TReportTextObject "txtTitle" -> 9', PaddingRightTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if PaddingRightPass then
      Lines.Add('PaddingRight command subtest: PASS')
    else
      Lines.Add('PaddingRight command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'PaddingBottom := 4';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    PaddingBottomTrace.Assign(Harness.Trace);
    PaddingBottomPass :=
      (Pos('ScriptSetPaddingBottom: TReportTextObject "txtTitle" -> 4', PaddingBottomTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if PaddingBottomPass then
      Lines.Add('PaddingBottom command subtest: PASS')
    else
      Lines.Add('PaddingBottom command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontColorOnTrue := clMaroon';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontColorOnTrueTrace.Assign(Harness.Trace);
    FontColorOnTruePass :=
      (Pos('ScriptSetFontColorOnTrue: TReportTextObject "txtTitle" -> clMaroon', FontColorOnTrueTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontColorOnTruePass then
      Lines.Add('FontColorOnTrue command subtest: PASS')
    else
      Lines.Add('FontColorOnTrue command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BackgroundOnTrue := clYellow';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BackgroundOnTrueTrace.Assign(Harness.Trace);
    BackgroundOnTruePass :=
      (Pos('ScriptSetBackgroundOnTrue: TReportTextObject "txtTitle" -> clYellow', BackgroundOnTrueTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BackgroundOnTruePass then
      Lines.Add('BackgroundOnTrue command subtest: PASS')
    else
      Lines.Add('BackgroundOnTrue command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BorderColorOnTrue := clRed';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BorderColorOnTrueTrace.Assign(Harness.Trace);
    BorderColorOnTruePass :=
      (Pos('ScriptSetBorderColorOnTrue: TReportTextObject "txtTitle" -> clRed', BorderColorOnTrueTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BorderColorOnTruePass then
      Lines.Add('BorderColorOnTrue command subtest: PASS')
    else
      Lines.Add('BorderColorOnTrue command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BackgroundCondition := Value > 0';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BackgroundConditionTrace.Assign(Harness.Trace);
    BackgroundConditionPass :=
      (Pos('ScriptSetBackgroundCondition: TReportTextObject "txtTitle" -> "Value > 0"', BackgroundConditionTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BackgroundConditionPass then
      Lines.Add('BackgroundCondition command subtest: PASS')
    else
      Lines.Add('BackgroundCondition command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BorderColorCondition := Value < 100';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BorderColorConditionTrace.Assign(Harness.Trace);
    BorderColorConditionPass :=
      (Pos('ScriptSetBorderColorCondition: TReportTextObject "txtTitle" -> "Value < 100"', BorderColorConditionTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BorderColorConditionPass then
      Lines.Add('BorderColorCondition command subtest: PASS')
    else
      Lines.Add('BorderColorCondition command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontColorCondition := Value > 0';
    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontColorConditionTrace.Assign(Harness.Trace);
    FontColorConditionPass :=
      (Pos('ScriptSetFontColorCondition: TReportTextObject "txtTitle" -> "Value > 0"', FontColorConditionTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontColorConditionPass then
      Lines.Add('FontColorCondition command subtest: PASS')
    else
      Lines.Add('FontColorCondition command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoNonTextTarget) then
    begin
      DemoNonTextTarget.OnBeforePrint := 'Text := ''X''; Background := clYellow';
      Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
      try
        Engine.OnBeforePrintReport := Harness.BeforeReport;
        Engine.OnAfterPrintReport := Harness.AfterReport;
        Engine.OnBeforeBand := Harness.BeforeBand;
        Engine.OnAfterBand := Harness.AfterBand;
        Engine.OnBeforeObject := Harness.BeforeObject;
        Engine.OnAfterObject := Harness.AfterObject;
        Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
        Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
        Engine.Prepare;
      finally
        Engine.Free;
        Engine := nil;
      end;
      ObjectTypeMismatchTrace.Assign(Harness.Trace);
      ObjectTypeMismatchPass :=
        (Harness.ScriptUnsupportedCount >= 2) and
        (Pos('ScriptUnsupported[ObjectType]: ' + DemoNonTextTarget.ClassName, ObjectTypeMismatchTrace.Text) > 0);
      if ObjectTypeMismatchPass then
        Lines.Add('Object-type mismatch subtest: PASS')
      else
        Lines.Add('Object-type mismatch subtest: FAIL');
    end
    else
    begin
      // Some reports may not include a non-text object target.
      ObjectTypeMismatchPass := True;
      ObjectTypeMismatchTrace.Clear;
      Lines.Add('Object-type mismatch subtest: SKIP (no non-text object target)');
    end;

    Lines.Add('');
    Lines.Add('Parser edge-case summary:');
    if EscapedQuotePass then
      Lines.Add('  EscapedQuote: PASS')
    else
      Lines.Add('  EscapedQuote: FAIL');
    if WhitespacePass then
      Lines.Add('  WhitespaceNormalization: PASS')
    else
      Lines.Add('  WhitespaceNormalization: FAIL');
    if TrailingSemicolonPass then
      Lines.Add('  TrailingSemicolon: PASS')
    else
      Lines.Add('  TrailingSemicolon: FAIL');

    OverallPass :=
      BasePass and
      CountingInflationPass and
      TargetOrderPass and
      ObjectSkipPass and
      BandSkipPass and
      ScriptCancelPass and
      TargetCancelOrderPass and
      FieldBindPass and
      FieldResolveMissPass and
      FieldResolveMissWithUnsupportedPass and
      BackgroundPass and
      VisiblePass and
      AnchorRightPass and
      AnchorBottomPass and
      EscapedQuotePass and
      WhitespacePass and
      TrailingSemicolonPass and
      UnknownCommandPass and
      FieldSyntaxPass and
      FieldNamePass and
      ColorValuePass and
      VisibleValuePass and
      TextLiteralPass and
      CanPrintValuePass and
      MultiInvalidPass and
      MixedValidInvalidPass and
      CancelShortCircuitPass and
      QuotedSemicolonWithUnsupportedPass and
      ObjectTypeMismatchPass and
      LowercaseTextKeyPass and
      MixedCaseCanPrintPass and
      MixedCaseVisiblePass and
      MixedCaseBackgroundPass and
      FontColorPass and
      FontSizePass and
      FontNamePass and
      FontBoldPass and
      FontItalicPass and
      HAlignPass and
      VAlignPass and
      PrintWhenPass and
      DataFieldPass and
      ExpressionPass and
      FontColorConditionPass and
      FieldDisplayFormatPass and
      ImageStretchPass and
      ImageCenterPass and
      ImageProportionalPass and
      ImageDataFieldPass and
      BorderColorPass and
      AnchorBottomPass and
      TransparentPass and
      AutoSizePass and
      WordWrapPass and
      BorderVisiblePass and
      BorderWidthPass and
      PaddingLeftPass and
      PaddingTopPass and
      PaddingRightPass and
      PaddingBottomPass and
      FontColorOnTruePass and
      BackgroundOnTruePass and
      BorderColorOnTruePass and
      BackgroundConditionPass and
      BorderColorConditionPass;
    Lines.Insert(0, '');
    if OverallPass then
      Lines.Insert(0, 'Overall: PASS')
    else
      Lines.Insert(0, 'Overall: FAIL');
    Lines.Insert(1, 'Runtime Event Callback Demo');
    while (Lines.Count > 2) and SameText(Lines[2], 'Runtime Event Callback Demo') do
      Lines.Delete(2);

    Lines.Add('');
    Lines.Add('Callback inflation guard:');
    Lines.Add(Format('  Baseline BeforeBand=%d, AfterBand=%d',
      [BaseBeforeBand, BaseAfterBand]));
    Lines.Add(Format('  Baseline BeforeObject=%d, AfterObject=%d',
      [BaseBeforeObject, BaseAfterObject]));
    Lines.Add(Format('  Baseline ScriptBeforeObject=%d, ScriptAfterObject=%d',
      [BaseScriptBeforeObject, BaseScriptAfterObject]));

    Lines.Add('');
    Lines.Add('Unsupported command diagnostics:');
    AppendUnsupportedSummary('Baseline', BaselineTrace, Lines);
    AppendUnsupportedSummary('Object-skip', ObjectSkipTrace, Lines);
    AppendUnsupportedSummary('Band-skip', BandSkipTrace, Lines);
    AppendUnsupportedSummary('Script-host cancel', ScriptCancelTrace, Lines);
    AppendUnsupportedSummary('Field() binding', FieldBindTrace, Lines);
    AppendUnsupportedSummary('Field() resolve miss', FieldResolveMissTrace, Lines);
    AppendUnsupportedSummary('Field() resolve miss + unsupported', FieldResolveMissWithUnsupportedTrace, Lines);
    AppendUnsupportedSummary('Background', BackgroundTrace, Lines);
    AppendUnsupportedSummary('Visible', VisibleTrace, Lines);
    AppendUnsupportedSummary('AnchorRight', AnchorRightTrace, Lines);
    AppendUnsupportedSummary('Escaped quote', EscapedQuoteTrace, Lines);
    AppendUnsupportedSummary('Whitespace normalization', WhitespaceTrace, Lines);
    AppendUnsupportedSummary('Trailing semicolon', TrailingSemicolonTrace, Lines);
    AppendUnsupportedSummary('Unknown command', UnknownCommandTrace, Lines);
    AppendUnsupportedSummary('Field syntax', FieldSyntaxTrace, Lines);
    AppendUnsupportedSummary('Field name', FieldNameTrace, Lines);
    AppendUnsupportedSummary('Color value', ColorValueTrace, Lines);
    AppendUnsupportedSummary('Visible value', VisibleValueTrace, Lines);
    AppendUnsupportedSummary('Text literal', TextLiteralTrace, Lines);
    AppendUnsupportedSummary('CanPrint value', CanPrintValueTrace, Lines);
    AppendUnsupportedSummary('Multi-invalid aggregation', MultiInvalidTrace, Lines);
    AppendUnsupportedSummary('Mixed valid+invalid sequence', MixedValidInvalidTrace, Lines);
    AppendUnsupportedSummary('CanPrint short-circuit mixed sequence', CancelShortCircuitTrace, Lines);
    AppendUnsupportedSummary('Quoted semicolon + unsupported', QuotedSemicolonWithUnsupportedTrace, Lines);
    AppendUnsupportedSummary('Object-type mismatch', ObjectTypeMismatchTrace, Lines);
    AppendUnsupportedSummary('Lowercase key (text)', LowercaseTextKeyTrace, Lines);
    AppendUnsupportedSummary('Mixed-case key (CanPrint)', MixedCaseCanPrintTrace, Lines);
    AppendUnsupportedSummary('Mixed-case key (VISIBLE)', MixedCaseVisibleTrace, Lines);
    AppendUnsupportedSummary('Mixed-case key (BaCkGrOuNd)', MixedCaseBackgroundTrace, Lines);
    AppendUnsupportedSummary('BorderColor', BorderColorTrace, Lines);
    AppendUnsupportedSummary('FontSize', FontSizeTrace, Lines);
    AppendUnsupportedSummary('FontName', FontNameTrace, Lines);
    AppendUnsupportedSummary('FontBold', FontBoldTrace, Lines);
    AppendUnsupportedSummary('FontItalic', FontItalicTrace, Lines);
    AppendUnsupportedSummary('HAlign', HAlignTrace, Lines);
    AppendUnsupportedSummary('VAlign', VAlignTrace, Lines);
    AppendUnsupportedSummary('PrintWhen', PrintWhenTrace, Lines);
    AppendUnsupportedSummary('DataField', DataFieldTrace, Lines);
    AppendUnsupportedSummary('Expression', ExpressionTrace, Lines);
    AppendUnsupportedSummary('FontColorCondition', FontColorConditionTrace, Lines);
    AppendUnsupportedSummary('AnchorBottom', AnchorBottomTrace, Lines);
    AppendUnsupportedSummary('FieldDisplayFormat', FieldDisplayFormatTrace, Lines);
    AppendUnsupportedSummary('ImageStretch', ImageStretchTrace, Lines);
    AppendUnsupportedSummary('ImageDataField', ImageDataFieldTrace, Lines);
    AppendUnsupportedSummary('Transparent', TransparentTrace, Lines);
    AppendUnsupportedSummary('AutoSize', AutoSizeTrace, Lines);
    AppendUnsupportedSummary('WordWrap', WordWrapTrace, Lines);
    AppendUnsupportedSummary('BorderVisible', BorderVisibleTrace, Lines);
    AppendUnsupportedSummary('BorderWidth', BorderWidthTrace, Lines);
    AppendUnsupportedSummary('PaddingLeft', PaddingLeftTrace, Lines);
    AppendUnsupportedSummary('PaddingTop', PaddingTopTrace, Lines);
    AppendUnsupportedSummary('PaddingRight', PaddingRightTrace, Lines);
    AppendUnsupportedSummary('PaddingBottom', PaddingBottomTrace, Lines);
    AppendUnsupportedSummary('FontColorOnTrue', FontColorOnTrueTrace, Lines);
    AppendUnsupportedSummary('BackgroundOnTrue', BackgroundOnTrueTrace, Lines);
    AppendUnsupportedSummary('BorderColorOnTrue', BorderColorOnTrueTrace, Lines);
    AppendUnsupportedSummary('BackgroundCondition', BackgroundConditionTrace, Lines);
    AppendUnsupportedSummary('BorderColorCondition', BorderColorConditionTrace, Lines);
    AppendUnsupportedReasonSummary(Lines,
      [BaselineTrace, ObjectSkipTrace, BandSkipTrace, ScriptCancelTrace, FieldBindTrace,
       FieldResolveMissTrace, FieldResolveMissWithUnsupportedTrace, BackgroundTrace, VisibleTrace, EscapedQuoteTrace, WhitespaceTrace, TrailingSemicolonTrace,
       UnknownCommandTrace, FieldSyntaxTrace, FieldNameTrace, ColorValueTrace,
       VisibleValueTrace, TextLiteralTrace, CanPrintValueTrace, MultiInvalidTrace,
       MixedValidInvalidTrace, CancelShortCircuitTrace, QuotedSemicolonWithUnsupportedTrace,
       ObjectTypeMismatchTrace, LowercaseTextKeyTrace, MixedCaseCanPrintTrace,
       MixedCaseVisibleTrace, MixedCaseBackgroundTrace, FontColorTrace, FontSizeTrace,
       FontNameTrace, BorderColorTrace, TransparentTrace, AutoSizeTrace, WordWrapTrace, BorderVisibleTrace,
       BorderWidthTrace, PaddingLeftTrace, PaddingTopTrace, PaddingRightTrace,
       PaddingBottomTrace, FontColorOnTrueTrace, BackgroundOnTrueTrace,
       BorderColorOnTrueTrace, BackgroundConditionTrace, ImageStretchTrace,
       ImageDataFieldTrace, ImageCenterTrace, ImageProportionalTrace,
       BorderColorConditionTrace]);

    Lines.Add('');
    Lines.Add('Baseline trace preview:');
    for I := 0 to Min(TracePreviewMax - 1, BaselineTrace.Count - 1) do
      Lines.Add('  ' + BaselineTrace[I]);
    if BaselineTrace.Count > TracePreviewMax then
      Lines.Add(Format('  ... (%d more lines)', [BaselineTrace.Count - TracePreviewMax]));

    Lines.Add('');
    Lines.Add('Object-skip trace preview:');
    for I := 0 to Min(TracePreviewMax - 1, ObjectSkipTrace.Count - 1) do
      Lines.Add('  ' + ObjectSkipTrace[I]);
    if ObjectSkipTrace.Count > TracePreviewMax then
      Lines.Add(Format('  ... (%d more lines)', [ObjectSkipTrace.Count - TracePreviewMax]));

    Lines.Add('');
    Lines.Add('Band-skip trace preview:');
    for I := 0 to Min(TracePreviewMax - 1, BandSkipTrace.Count - 1) do
      Lines.Add('  ' + BandSkipTrace[I]);
    if BandSkipTrace.Count > TracePreviewMax then
      Lines.Add(Format('  ... (%d more lines)', [BandSkipTrace.Count - TracePreviewMax]));

    Lines.Add('');
    Lines.Add('Script-host cancel trace preview:');
    for I := 0 to Min(TracePreviewMax - 1, ScriptCancelTrace.Count - 1) do
      Lines.Add('  ' + ScriptCancelTrace[I]);
    if ScriptCancelTrace.Count > TracePreviewMax then
      Lines.Add(Format('  ... (%d more lines)', [ScriptCancelTrace.Count - TracePreviewMax]));

    ResultDlg := TForm.Create(Self);
    try
      ResultDlg.Caption := 'Runtime Event Callback Demo Result';
      ResultDlg.Position := poScreenCenter;
      ResultDlg.Width := 900;
      ResultDlg.Height := 700;
      ResultDlg.BorderStyle := bsSizeable;

      ResultMemo := TMemo.Create(ResultDlg);
      ResultMemo.Parent := ResultDlg;
      ResultMemo.Align := alClient;
      ResultMemo.ReadOnly := True;
      ResultMemo.ScrollBars := ssBoth;
      ResultMemo.WordWrap := False;
      ResultMemo.Font.Name := 'Consolas';
      ResultMemo.Font.Size := 10;
      ResultMemo.Lines.Text := Lines.Text;

      BtnClose := TButton.Create(ResultDlg);
      BtnClose.Parent := ResultDlg;
      BtnClose.Caption := 'Close';
      BtnClose.ModalResult := mrOK;
      BtnClose.Anchors := [akRight, akBottom];
      BtnClose.Width := 90;
      BtnClose.Height := 28;
      BtnClose.Left := ResultDlg.ClientWidth - BtnClose.Width - 12;
      BtnClose.Top := ResultDlg.ClientHeight - BtnClose.Height - 8;

      BtnCopy := TButton.Create(ResultDlg);
      BtnCopy.Parent := ResultDlg;
      BtnCopy.Caption := 'Copy';
      BtnCopy.Hint := 'Copy full demo output to clipboard';
      BtnCopy.ShowHint := True;
      BtnCopy.Anchors := [akRight, akBottom];
      BtnCopy.Width := 90;
      BtnCopy.Height := 28;
      BtnCopy.Left := BtnClose.Left - BtnCopy.Width - 8;
      BtnCopy.Top := BtnClose.Top;
      FRuntimeEventDemoOutput := ResultMemo.Lines.Text;
      BtnCopy.OnClick := RuntimeEventDemoCopyClick;

      ResultMemo.AlignWithMargins := True;
      ResultMemo.Margins.Left := 8;
      ResultMemo.Margins.Top := 8;
      ResultMemo.Margins.Right := 8;
      ResultMemo.Margins.Bottom := BtnClose.Height + 16;

      ResultDlg.ActiveControl := BtnClose;
      ResultDlg.ShowModal;
    finally
      ResultDlg.Free;
    end;
  finally
    VisibleTrace.Free;
    AnchorRightTrace.Free;
    BackgroundTrace.Free;
    FieldBindTrace.Free;
    FieldResolveMissTrace.Free;
    FieldResolveMissWithUnsupportedTrace.Free;
    CanPrintValueTrace.Free;
    MultiInvalidTrace.Free;
    MixedValidInvalidTrace.Free;
    CancelShortCircuitTrace.Free;
    QuotedSemicolonWithUnsupportedTrace.Free;
    ObjectTypeMismatchTrace.Free;
    LowercaseTextKeyTrace.Free;
    MixedCaseCanPrintTrace.Free;
    MixedCaseVisibleTrace.Free;
    MixedCaseBackgroundTrace.Free;
    FontColorTrace.Free;
    FontSizeTrace.Free;
    FontNameTrace.Free;
    FontBoldTrace.Free;
    FontItalicTrace.Free;
    HAlignTrace.Free;
    VAlignTrace.Free;
    PrintWhenTrace.Free;
    DataFieldTrace.Free;
    ExpressionTrace.Free;
    FontColorConditionTrace.Free;
    AnchorBottomTrace.Free;
    FieldDisplayFormatTrace.Free;
    ImageStretchTrace.Free;
    ImageDataFieldTrace.Free;
    ImageCenterTrace.Free;
    ImageProportionalTrace.Free;
    BorderColorTrace.Free;
    TransparentTrace.Free;
    AutoSizeTrace.Free;
    WordWrapTrace.Free;
    BorderVisibleTrace.Free;
    BorderWidthTrace.Free;
    PaddingLeftTrace.Free;
    PaddingTopTrace.Free;
    PaddingRightTrace.Free;
    PaddingBottomTrace.Free;
    FontColorOnTrueTrace.Free;
    BackgroundOnTrueTrace.Free;
    BorderColorOnTrueTrace.Free;
    BackgroundConditionTrace.Free;
    BorderColorConditionTrace.Free;
    TextLiteralTrace.Free;
    VisibleValueTrace.Free;
    ColorValueTrace.Free;
    FieldNameTrace.Free;
    FieldSyntaxTrace.Free;
    TrailingSemicolonTrace.Free;
    UnknownCommandTrace.Free;
    WhitespaceTrace.Free;
    EscapedQuoteTrace.Free;
    ScriptCancelTrace.Free;
    BandSkipTrace.Free;
    ObjectSkipTrace.Free;
    BaselineTrace.Free;
    Lines.Free;
    Harness.Free;
    Engine.Free;
    ReportModel.Free;
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
procedure TfrmMain.mnuCenterVClick(Sender: TObject);
begin
  if not ConfirmMixedBandVerticalLayout then
    Exit;
  FDesigner.CenterV;
end;
procedure TfrmMain.mnuDistHClick(Sender: TObject);       begin FDesigner.DistributeH;  end;
procedure TfrmMain.mnuDistVClick(Sender: TObject);
begin
  if not ConfirmMixedBandVerticalLayout then
    Exit;
  FDesigner.DistributeV;
end;
procedure TfrmMain.mnuFrontClick(Sender: TObject);       begin FDesigner.BringToFront; end;
procedure TfrmMain.mnuBackClick(Sender: TObject);        begin FDesigner.SendToBack;   end;

{ =========================================================================== }
{  View / Zoom                                                                 }
{ =========================================================================== }

procedure TfrmMain.mnuZoomInClick(Sender: TObject);
begin
  FDesigner.ZoomIn;
  UpdateZoomControls;
  UpdateStatusBar;
end;

procedure TfrmMain.mnuZoomOutClick(Sender: TObject);
begin
  FDesigner.ZoomOut;
  UpdateZoomControls;
  UpdateStatusBar;
end;

procedure TfrmMain.mnuZoomResetClick(Sender: TObject);
begin
  FDesigner.ZoomReset;
  UpdateZoomControls;
  UpdateStatusBar;
end;

procedure TfrmMain.mnuShowGridClick(Sender: TObject);
begin
  FDesigner.ShowGrid    := not FDesigner.ShowGrid;
  mnuShowGrid.Checked  := FDesigner.ShowGrid;
  UpdateMenuState;
end;

procedure TfrmMain.mnuSnapGridClick(Sender: TObject);
begin
  FDesigner.SnapToGrid  := not FDesigner.SnapToGrid;
  mnuSnapGrid.Checked  := FDesigner.SnapToGrid;
  UpdateMenuState;
end;

procedure TfrmMain.mnuShowRulersClick(Sender: TObject);
begin
  FDesigner.ShowRulers   := not FDesigner.ShowRulers;
  mnuShowRulers.Checked := FDesigner.ShowRulers;
  UpdateMenuState;
end;

procedure TfrmMain.mnuShowMarginsClick(Sender: TObject);
begin
  FDesigner.ShowMargins   := not FDesigner.ShowMargins;
  mnuShowMargins.Checked := FDesigner.ShowMargins;
  UpdateMenuState;
end;

procedure TfrmMain.mnuDesignerOptionsClick(Sender: TObject);
var
  Frm: TfrmDesignerOptions;
begin
  Frm := TfrmDesignerOptions.Create(Self);
  try
    Frm.LoadFromDesigner(FDesigner);
    if Frm.ShowModal = mrOk then
    begin
      Frm.ApplyToDesigner(FDesigner);
      mnuShowGrid.Checked := FDesigner.ShowGrid;
      mnuSnapGrid.Checked := FDesigner.SnapToGrid;
      mnuShowRulers.Checked := FDesigner.ShowRulers;
      mnuShowMargins.Checked := FDesigner.ShowMargins;
      UpdateMenuState;
    end;
  finally
    Frm.Free;
  end;
end;

procedure TfrmMain.ApplyZoom;
var Z: Integer;
begin
  Z := ZoomValueFromEdit;
  if Z > 0 then
  begin
    FDesigner.Zoom := Z;
    UpdateZoomControls;
    UpdateStatusBar;
  end;
end;

function TfrmMain.ZoomValueFromEdit: Integer;
begin
  Result := StrToIntDef(Trim(edtZoom.Text), 0);
end;

function TfrmMain.ZoomPercentFromText(const AText: string): Integer;
var
  S: string;
begin
  S := Trim(AText);
  if (Length(S) > 0) and (S[Length(S)] = '%') then
    S := Trim(Copy(S, 1, Length(S) - 1));
  Result := StrToIntDef(S, 0);
end;

procedure TfrmMain.btnZoomApplyClick(Sender: TObject);
begin
  HandleZoomApply(ApplyZoom);
end;

procedure TfrmMain.InitializeToolbarZoomCombo;
begin
  if not Assigned(cboZoomToolbar) then
    Exit;

  FUpdatingZoomControls := True;
  try
    cboZoomToolbar.Items.BeginUpdate;
    try
      cboZoomToolbar.Items.Clear;
      cboZoomToolbar.Items.Add('25%');
      cboZoomToolbar.Items.Add('50%');
      cboZoomToolbar.Items.Add('75%');
      cboZoomToolbar.Items.Add('100%');
      cboZoomToolbar.Items.Add('150%');
      cboZoomToolbar.Items.Add('200%');
      cboZoomToolbar.Items.Add('Page width');
      cboZoomToolbar.Items.Add('Whole page');
    finally
      cboZoomToolbar.Items.EndUpdate;
    end;
    cboZoomToolbar.Hint := 'Zoom presets and fit modes';
    cboZoomToolbar.ShowHint := True;
  finally
    FUpdatingZoomControls := False;
  end;
end;

function TfrmMain.FitPageWidthZoom: Integer;
var
  AvailW, LogicalW, LeftPad: Integer;
begin
  Result := FDesigner.Zoom;
  if not HasDesignerReport then
    Exit;

  LogicalW := FDesigner.Report.PageSettings.PageWidth;
  if LogicalW <= 0 then
    Exit;

  if FDesigner.ShowRulers then
    LeftPad := RULER_W + PAGE_PAD
  else
    LeftPad := PAGE_PAD;

  AvailW := ScrollBox1.ClientWidth - LeftPad - PAGE_PAD - 8;
  if AvailW <= 0 then
    Exit;

  Result := MulDiv(AvailW, 100, LogicalW);
end;

function TfrmMain.FitWholePageZoom: Integer;
var
  AvailW, AvailH, LogicalW, LogicalH, LeftPad, TopPad: Integer;
  ZW, ZH: Integer;
begin
  Result := FDesigner.Zoom;
  if not HasDesignerReport then
    Exit;

  LogicalW := FDesigner.Report.PageSettings.PageWidth;
  LogicalH := FDesigner.Report.PageSettings.PageHeight;
  if (LogicalW <= 0) or (LogicalH <= 0) then
    Exit;

  if FDesigner.ShowRulers then
  begin
    LeftPad := RULER_W + PAGE_PAD;
    TopPad := RULER_W + PAGE_PAD;
  end
  else
  begin
    LeftPad := PAGE_PAD;
    TopPad := PAGE_PAD;
  end;

  AvailW := ScrollBox1.ClientWidth - LeftPad - PAGE_PAD - 8;
  AvailH := ScrollBox1.ClientHeight - TopPad - PAGE_PAD - 8;
  if (AvailW <= 0) or (AvailH <= 0) then
    Exit;

  ZW := MulDiv(AvailW, 100, LogicalW);
  ZH := MulDiv(AvailH, 100, LogicalH);
  Result := Min(ZW, ZH);
end;

procedure TfrmMain.ApplyToolbarZoomSelection;
var
  S: string;
  Z: Integer;
begin
  if not Assigned(FDesigner) or not Assigned(cboZoomToolbar) then
    Exit;

  S := Trim(cboZoomToolbar.Text);
  if S = '' then
    Exit;

  if SameText(S, 'Page width') then
    Z := FitPageWidthZoom
  else if SameText(S, 'Whole page') then
    Z := FitWholePageZoom
  else if (Length(S) = 0) or (S[Length(S)] <> '%') then
    Exit
  else
    Z := ZoomPercentFromText(S);

  if Z > 0 then
    FDesigner.Zoom := Z;
end;

procedure TfrmMain.UpdateZoomControls;
var
  ZoomText: string;
  I: Integer;
  Found: Boolean;
begin
  if not Assigned(FDesigner) then
    Exit;

  ZoomText := IntToStr(FDesigner.Zoom) + '%';
  edtZoom.Text := IntToStr(FDesigner.Zoom);

  if not Assigned(cboZoomToolbar) then
    Exit;

  FUpdatingZoomControls := True;
  try
    Found := False;
    for I := 0 to cboZoomToolbar.Items.Count - 1 do
      if SameText(cboZoomToolbar.Items[I], ZoomText) then
      begin
        cboZoomToolbar.ItemIndex := I;
        Found := True;
        Break;
      end;
    if not Found then
    begin
      cboZoomToolbar.ItemIndex := -1;
      cboZoomToolbar.Text := ZoomText;
    end;
  finally
    FUpdatingZoomControls := False;
  end;
end;

procedure TfrmMain.cboZoomToolbarChange(Sender: TObject);
begin
  if FUpdatingZoomControls then
    Exit;
  HandleZoomToolbarChange(ApplyToolbarZoomSelection);
end;

procedure TfrmMain.CheckListBox1ClickCheck(Sender: TObject);
begin
  HandleViewToggleIndex(CheckListBox1.ItemIndex,
    procedure
    begin
      mnuShowGridClick(mnuShowGrid);
    end,
    procedure
    begin
      mnuSnapGridClick(mnuSnapGrid);
    end,
    procedure
    begin
      mnuShowRulersClick(mnuShowRulers);
    end,
    procedure
    begin
      mnuShowMarginsClick(mnuShowMargins);
    end);
end;

procedure TfrmMain.edtZoomKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  HandleZoomKeyDown(ApplyZoom, Key);
end;

{ =========================================================================== }
{  Report menu                                                                 }
{ =========================================================================== }

procedure TfrmMain.mnuPreviewClick(Sender: TObject);
var
  Frm: TfrmPreview;
  DS: TDataSet;
begin
  CommitReportMetadataChanges(True);

  if not TryGetPreviewDataSet(DS) then
  begin
    ShowMessage('No dataset is available for preview.');
    Exit;
  end;

  Frm := TfrmPreview.Create(Application);
  try
    Frm.LoadReport(FDesigner.Report, DS);
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TfrmMain.mnuPageSetupClick(Sender: TObject);
var
  Frm: TfrmPageSettings;
  OldSettings: TReportPageSettings;
  NewSettings: TReportPageSettings;
  Cmd: TPageSettingsChangeCommand;
begin
  OldSettings := TReportPageSettings.Create;
  NewSettings := TReportPageSettings.Create;
  Frm := TfrmPageSettings.Create(Application);
  try
    FDesigner.Report.PageSettings.AssignTo(OldSettings);
    Frm.LoadSettings(FDesigner.Report.PageSettings);
    if Frm.ShowModal = mrOk then
    begin
      // Apply into a temporary settings object first, so no-op OK does not
      // mutate the live report or create undo history noise.
      OldSettings.AssignTo(NewSettings);
      Frm.SaveSettings(NewSettings);
      if PageSettingsChanged(OldSettings, NewSettings) then
      begin
        Cmd := TPageSettingsChangeCommand.Create(FDesigner, OldSettings, NewSettings);
        FDesigner.ExecuteUndoCommand(Cmd);
      end;
    end;
  finally
    Frm.Free;
    NewSettings.Free;
    OldSettings.Free;
  end;
end;

procedure TfrmMain.mnuBandMgrClick(Sender: TObject);
var
  Frm: TfrmBandManager;
  StagedReport: TReportModel;
  BeforeJSON: string;
  AfterJSON: string;
begin
  BeforeJSON := TReportSerializer.SaveToJSON(FDesigner.Report);
  StagedReport := nil;
  Frm := TfrmBandManager.Create(Application);
  try
    Frm.LoadReport(FDesigner.Report);
    if Frm.ShowModal = mrOk then
    begin
      StagedReport := Frm.TakeStagedReport;
      if Assigned(StagedReport) then
      begin
        AfterJSON := TReportSerializer.SaveToJSON(StagedReport);
        ApplyBandManagerSnapshot(BeforeJSON, AfterJSON);
      end;
    end;
  finally
    StagedReport.Free;
    Frm.Free;
  end;
end;

procedure TfrmMain.mnuReportPropsClick(Sender: TObject);
begin
  ShowReportPropertiesDialog;
end;

procedure TfrmMain.mnuCreateSimpleSampleReportClick(Sender: TObject);
begin
  RunSampleReportAction(
    procedure
    begin
      BuildSimpleSampleReport;
    end);
end;

procedure TfrmMain.mnuCreateSampleGroupedReportClick(Sender: TObject);
begin
  RunSampleReportAction(
    procedure
    begin
      BuildGroupedSampleReport;
    end);
end;

procedure TfrmMain.mnuCreateCanGrowRemarksTestReportClick(Sender: TObject);
begin
  RunSampleReportAction(
    procedure
    begin
      BuildCanGrowRemarksTestReport;
    end);
end;

procedure TfrmMain.mnuCreateBarcodeTestReportClick(Sender: TObject);
begin
  RunSampleReportAction(
    procedure
    begin
      BuildBarcodeTestReport;
    end);
end;

procedure TfrmMain.mnuCreateImagePathTestReportClick(Sender: TObject);
begin
  RunSampleReportAction(
    procedure
    begin
      BuildImagePathTestReport;
    end);
end;

procedure TfrmMain.mnuOpenSimpleTestReportClick(Sender: TObject);
begin
  RunOpenReportAction('01_simple_masterdata.vrt',
    procedure(AReportName: string)
    begin
      OpenRegressionReport(AReportName);
    end);
end;

procedure TfrmMain.mnuOpenGroupedTestReportClick(Sender: TObject);
begin
  RunOpenReportAction('03_grouped_report.vrt',
    procedure(AReportName: string)
    begin
      OpenRegressionReport(AReportName);
    end);
end;

procedure TfrmMain.mnuOpenCanGrowTestReportClick(Sender: TObject);
begin
  RunOpenReportAction('05_cangrow_remarks.vrt',
    procedure(AReportName: string)
    begin
      OpenRegressionReport(AReportName);
    end);
end;

procedure TfrmMain.mnuOpenBarcodeTestReportClick(Sender: TObject);
begin
  RunOpenReportAction('06_barcode_test.vrt',
    procedure(AReportName: string)
    begin
      OpenRegressionReport(AReportName);
    end);
end;

procedure TfrmMain.mnuOpenImagePathTestReportClick(Sender: TObject);
begin
  RunOpenReportAction('07_imagepath_test.vrt',
    procedure(AReportName: string)
    begin
      OpenRegressionReport(AReportName);
    end);
end;

procedure TfrmMain.mnuOpenExpressionUsageDemoClick(Sender: TObject);
begin
  RunOpenReportAction('22_expression_usage_demo.vrt',
    procedure(AReportName: string)
    begin
      OpenRegressionReport(AReportName);
    end);
end;

procedure TfrmMain.mnuOpenInvalidDataFieldDiagnosticsDemoClick(Sender: TObject);
begin
  RunOpenReportAction('23_invalid_datafield_diagnostics.vrt',
    procedure(AReportName: string)
    begin
      OpenRegressionReport(AReportName);
    end);
end;

procedure TfrmMain.mnuRunRegressionTestReportsClick(Sender: TObject);
begin
  RunRegressionTestReportsAction(
    procedure
    begin
      UseSampleDataSet;
    end,
    procedure
    begin
      RefreshFieldList;
    end,
    procedure
    begin
      RefreshReportStructure;
    end,
    procedure
    begin
      UpdateAll;
    end);
end;

procedure TfrmMain.mnuRunRuntimeEventCallbackDemoClick(Sender: TObject);
begin
  RunRuntimeEventCallbackDemo;
end;

procedure TfrmMain.mnuKeyboardShortcutsClick(Sender: TObject);
begin
  ShowMessage(KeyboardShortcutsText);
end;

procedure TfrmMain.mnuExpressionHelpClick(Sender: TObject);
begin
  ShowMessage(ExpressionHelpText);
end;

{ =========================================================================== }
{  Designer events                                                             }
{ =========================================================================== }

procedure TfrmMain.DesignerSelectionChanged(Sender: TObject);
begin
  HandleDesignerSelectionChanged(
    UpdatePropertyPanel,
    UpdateMenuState,
    SyncReportStructureSelection);
end;

procedure TfrmMain.DesignerModified(Sender: TObject);
begin
  FModified := True;
  HandleDesignerModified(RefreshReportStructure, UpdateAll);
end;

procedure TfrmMain.DesignerViewChanged(Sender: TObject);
begin
  HandleDesignerViewChanged(UpdateZoomControls, UpdateMenuState, UpdateStatusBar);
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

function TfrmMain.SamePropertyValue(const AOld, ANew: TValue): Boolean;
begin
  Result := TPropertyPanelUtils.SamePropertyValue(AOld, ANew);
end;

function TfrmMain.HasDesignerReport: Boolean;
begin
  Result := Assigned(FDesigner) and Assigned(FDesigner.Report);
end;

function TfrmMain.TryGetPreviewDataSet(out ADataSet: TDataSet): Boolean;
begin
  ADataSet := nil;
  if Assigned(FDataSource1) then
    ADataSet := FDataSource1.DataSet;

  if not Assigned(ADataSet) then
  begin
    UseSampleDataSet;
    if Assigned(FDataSource1) then
      ADataSet := FDataSource1.DataSet;
  end;

  Result := Assigned(ADataSet);
end;

procedure TfrmMain.GetReportPropertiesDialogValues(out ATitle, AAuthor: string);
begin
  ATitle := FDesigner.Report.Title;
  AAuthor := FDesigner.Report.Author;
  if FReportMetadataDirty then
  begin
    ATitle := edtReportTitle.Text;
    AAuthor := edtReportAuthor.Text;
  end;
end;

function TfrmMain.PageSettingsChanged(const AOldSettings, ANewSettings: TReportPageSettings): Boolean;
begin
  Result := not PageSettingsEqual(AOldSettings, ANewSettings);
end;

procedure TfrmMain.ApplyBandManagerSnapshot(const ABeforeJSON, AAfterJSON: string);
var
  Cmd: TReportSnapshotCommand;
begin
  if ABeforeJSON = AAfterJSON then
    Exit;

  Cmd := TReportSnapshotCommand.Create(FDesigner, ABeforeJSON, AAfterJSON);
  FDesigner.ExecuteUndoCommand(Cmd);
end;

procedure TfrmMain.ShowReportPropertiesDialog;
var
  Frm: TfrmReportProperties;
  InitialTitle: string;
  InitialAuthor: string;
begin
  Frm := TfrmReportProperties.Create(Application);
  try
    GetReportPropertiesDialogValues(InitialTitle, InitialAuthor);
    Frm.LoadValues(InitialTitle, InitialAuthor, FDesigner.Report.Description);
    if Frm.ShowModal = mrOk then
      CommitReportMetadataValues(
        Frm.ReportTitle,
        Frm.ReportAuthor,
        Frm.ReportDescription,
        True
      );
  finally
    Frm.Free;
  end;
end;

procedure TfrmMain.RefreshAfterUndoRedo;
begin
  UpdateMenuState;
  UpdatePropertyPanel;
  UpdateStatusBar;
  RefreshReportStructure;
  SyncReportStructureSelection;
end;

procedure TfrmMain.RefreshAfterReportStateChange;
begin
  RefreshFieldList;
  RefreshReportStructure;
  UpdatePropertyPanel;
  UpdateTitleBar;
  UpdateStatusBar;
  UpdateMenuState;
  SyncReportStructureSelection;
end;

function TfrmMain.BuildChangedPropertyBatch(
  AObj: TReportObject;
  const AOldByProp: TDictionary<string, TValue>;
  const APropNames: TArray<string>;
  out ChangedNames: TArray<string>;
  out OldValues: TArray<TValue>;
  out NewValues: TArray<TValue>): Boolean;
begin
  Result := TPropertyPanelUtils.BuildChangedPropertyBatch(AObj, AOldByProp,
    APropNames, ChangedNames, OldValues, NewValues);
end;

function TfrmMain.IsControlWithinParent(AControl, AParent: TWinControl): Boolean;
begin
  Result := TPropertyPanelUtils.IsControlWithinParent(AControl, AParent);
end;

function TfrmMain.IsTextEditingControlFocused: Boolean;
var
  FocusedCtrl: TWinControl;
begin
  FocusedCtrl := Screen.ActiveControl;
  if not Assigned(FocusedCtrl) then
    FocusedCtrl := ActiveControl;
  Result := TPropertyPanelUtils.IsTextEditingControlFocused(FocusedCtrl, pnlProperties);
end;

procedure TfrmMain.SendMessageToFocusedControl(AMsg: Cardinal);
begin
  TPropertyPanelUtils.SendMessageToFocusedControl(AMsg);
end;

procedure TfrmMain.SendDeleteToFocusedControl;
begin
  TPropertyPanelUtils.SendDeleteToFocusedControl;
end;

function TfrmMain.CurrentPropertyTarget: TReportObject;
begin
  Result := TPropertyPanelUtils.CurrentPropertyTarget(FDesigner);
end;

function TfrmMain.SelectedObjectsSpanBands: Boolean;
begin
  Result := TPropertyPanelUtils.SelectedObjectsSpanBands(FDesigner);
end;

function TfrmMain.ConfirmMixedBandVerticalLayout: Boolean;
begin
  Result := TPropertyPanelUtils.ConfirmMixedBandVerticalLayout(FDesigner);
end;

function TfrmMain.ShortNodePreview(const S: string; AMaxLen: Integer): string;
begin
  Result := Frm.Main.Structure.ShortNodePreview(S, AMaxLen);
end;

procedure TfrmMain.UpdatePropertyPanel;
var
  Obj: TReportObject;
begin
  FLoadingPropertyPanel := True;
  try
    Obj := CurrentPropertyTarget;
    TReportPropertyBridge.LoadObjectToGrid(Obj, PropEditor);
    Frm.Main.PropertyPanelHelpers.PromoteImportantProperties(PropEditor, Obj);
    Frm.Main.PropertyPanelHelpers.InsertVisualGroupRows(PropEditor, Obj);
    ConfigurePropertyEditors;
  finally
    FLoadingPropertyPanel := False;
  end;

  UpdatePropertyPanelHeader(Obj);
  UpdatePropertyPanelHintForRow(PropEditor.Row);
  SetPropertyPanelDirty(False);
end;

procedure TfrmMain.UpdatePropertyPanelHeader(AObj: TReportObject);
begin
  Frm.Main.PropertyPanelHelpers.UpdatePropertyPanelHeader(FDesigner, lblSelectedProps, AObj);
end;

procedure TfrmMain.ConfigurePropertyEditors;
begin
  Frm.Main.PropertyEditorHelpers.ConfigurePropertyEditors(PropEditor, CurrentPropertyTarget, FDesigner.GetFieldNames);
end;

procedure TfrmMain.ApplyPropertyPanel;
begin
  Frm.Main.ApplyHelpers.ApplyPropertyPanel(
    FDesigner,
    PropEditor,
    CurrentPropertyTarget,
    FPropertyPanelDirty,
    FModified,
    procedure
    begin
      if Assigned(FDesigner) then
        FDesigner.RebuildLayout;
    end,
    procedure
    begin
      UpdateTitleBar;
    end,
    procedure
    begin
      UpdatePropertyPanel;
    end,
    procedure(AValue: Boolean)
    begin
      SetPropertyPanelDirty(AValue);
    end);
end;

procedure TfrmMain.UpdatePropertyPanelHintForRow(ARow: Integer);
begin
  Frm.Main.PropertyPanelHelpers.UpdatePropertyPanelHintForRow(PropEditor, StatusBar1, ARow, CurrentPropertyTarget);
end;

procedure TfrmMain.SetPropertyPanelDirty(AValue: Boolean);
var
  Target: TReportObject;
begin
  Target := CurrentPropertyTarget;
  Frm.Main.PropertyPanelState.SetPropertyPanelDirty(
    Target,
    btnApplyProps,
    FPropertyPanelDirty,
    AValue);
end;

procedure TfrmMain.btnApplyPropsClick(Sender: TObject);
begin
  ApplyPropertyPanel;
end;

procedure TfrmMain.PropEditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (PropEditor.Row > 0) and IsVisualGroupRow(PropEditor.Keys[PropEditor.Row]) then
  begin
    if not (Key in [VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT, VK_HOME, VK_END, VK_PRIOR, VK_NEXT, VK_TAB]) then
      Key := 0;
    Exit;
  end;

  if Key = VK_RETURN then
  begin
    if FPropertyPanelDirty then
      ApplyPropertyPanel;
    Key := 0;
  end;
end;

procedure TfrmMain.PropEditorSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  if (ARow > 0) and IsVisualGroupRow(PropEditor.Keys[ARow]) and (ACol > 0) then
    CanSelect := False;
  UpdatePropertyPanelHintForRow(ARow);
end;

procedure TfrmMain.PropEditorSetEditText(Sender: TObject; ACol, ARow: Integer;
  const Value: string);
begin
  if FLoadingPropertyPanel then
    Exit;

  if (ARow <= 0) or (ARow >= PropEditor.RowCount) then
    Exit;

  if IsVisualGroupRow(Trim(PropEditor.Keys[ARow])) then
    Exit;

  SetPropertyPanelDirty(True);
  UpdatePropertyPanelHintForRow(ARow);
end;

procedure TfrmMain.PropEditorDblClick(Sender: TObject);
begin
  HandlePropEditorDblClick(PropEditor, EditFontPropertyRow);
end;

procedure TfrmMain.PropEditorEditButtonClick(Sender: TObject);
begin
  HandlePropEditorEditButtonClick(PropEditor, EditBandEventScriptRow,
    EditExpressionPropertyRow, EditColorPropertyRow);
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
  if FModified or FReportMetadataDirty then
    Title := Title + ' *';
  Caption := Title;
end;

procedure TfrmMain.ConfigureLayoutGuidance;
begin
  btnAlignLeft.Hint := 'Align selected objects to the leftmost edge in the selection';
  btnAlignRight.Hint := 'Align selected objects to the rightmost edge in the selection';
  btnAlignTop.Hint := 'Align selected objects to the topmost edge in the selection';
  btnAlignBottom.Hint := 'Align selected objects to the bottommost edge in the selection';
  btnSameW.Hint := 'Make same width using last selected object as reference';
  btnSameH.Hint := 'Make same height using last selected object as reference';
  btnCenterH.Hint := 'Center selected objects horizontally on the page';
  btnCenterV.Hint := 'Center vertically within each object''s band';
  btnDistH.Hint := 'Distribute horizontally between current left/right bounds; works best within the same band';
  btnDistV.Hint := 'Distribute vertically using object local band coordinates';
  btnFront.Hint := 'Bring last selected object to front';
  btnBack.Hint := 'Send last selected object to back';
  btnFrontQuick.Hint := 'Bring last selected object to front';
  btnBackQuick.Hint := 'Send last selected object to back';
  btnFrontQuick.ShowHint := True;
  btnBackQuick.ShowHint := True;

  mnuAlignLeft.Hint := btnAlignLeft.Hint;
  mnuAlignRight.Hint := btnAlignRight.Hint;
  mnuAlignTop.Hint := btnAlignTop.Hint;
  mnuAlignBottom.Hint := btnAlignBottom.Hint;
  mnuSameWidth.Hint := btnSameW.Hint;
  mnuSameHeight.Hint := btnSameH.Hint;
  mnuCenterH.Hint := btnCenterH.Hint;
  mnuCenterV.Hint := btnCenterV.Hint;
  mnuDistH.Hint := btnDistH.Hint;
  mnuDistV.Hint := btnDistV.Hint;
  mnuFront.Hint := btnFront.Hint;
  mnuBack.Hint := btnBack.Hint;

  mnuShowGrid.Hint := 'Show or hide the designer grid';
  mnuSnapGrid.Hint := 'Snap moved and resized objects to the designer grid';
  mnuShowRulers.Hint := 'Show or hide page rulers around the designer surface';
  mnuShowMargins.Hint := 'Show or hide page margin guides';
  btnZoomIn.Hint := 'Zoom in the designer surface';
  btnZoomOut.Hint := 'Zoom out the designer surface';
  btnZoomApply.Hint := 'Apply zoom percentage';
  mnuZoomIn.Hint := btnZoomIn.Hint;
  mnuZoomOut.Hint := btnZoomOut.Hint;
  mnuZoomReset.Hint := 'Reset zoom to 100%';
end;

procedure TfrmMain.ConfigureViewToggleStrip;
begin
  Frm.Main.ViewHelpers.ConfigureViewToggleStrip(CheckListBox1);
  CheckListBox1.OnClickCheck := CheckListBox1ClickCheck;
end;

procedure TfrmMain.UpdateStatusBar;
begin
  Frm.Main.ViewHelpers.UpdateStatusBar(StatusBar1, FDesigner);
end;

procedure TfrmMain.UpdateAll;
begin
  UpdatePropertyPanel;
  UpdateTitleBar;
  UpdateStatusBar;
  UpdateMenuState;
  SyncReportStructureSelection;
end;

procedure TfrmMain.UpdateMenuState;
begin
  Frm.Main.MenuStateHelpers.UpdateMenuState(
    FDesigner,
    mnuUndo, mnuRedo, mnuCut, mnuCopy, mnuDelete,
    mnuAlignLeft, mnuAlignRight, mnuAlignTop, mnuAlignBottom,
    mnuSameWidth, mnuSameHeight, mnuCenterH, mnuCenterV,
    mnuDistH, mnuDistV, mnuFront, mnuBack,
    mnuShowGrid, mnuSnapGrid, mnuShowRulers, mnuShowMargins,
    btnUndo, btnRedo, btnDelete, btnCopy,
    btnAlignLeft, btnAlignRight, btnAlignTop, btnAlignBottom,
    btnSameW, btnSameH, btnCenterH, btnCenterV,
    btnDistH, btnDistV, btnFront, btnBack,
    CheckListBox1,
    procedure
    begin
      UpdateStatusBar;
    end);
end;

procedure TfrmMain.ConfirmSaveIfModified;
begin
  if not (FModified or FReportMetadataDirty) then Exit;
  case MessageDlg('The report has unsaved changes. Save now?',
                  mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes:    mnuSaveClick(nil);
    mrCancel: Abort;
  end;
end;

function TfrmMain.StructureBandCaption(ABand: TReportBand): string;
begin
  Result := Frm.Main.Structure.StructureBandCaption(ABand);
end;

function TfrmMain.StructureObjectCaption(AObj: TReportObject): string;
begin
  Result := Frm.Main.Structure.StructureObjectCaption(AObj);
end;

function TfrmMain.StructureObjectIconIndex(AObj: TReportObject): Integer;
begin
  Result := Frm.Main.Structure.StructureObjectIconIndex(AObj);
end;

function TfrmMain.FindStructureNodeByData(AData: Pointer): TTreeNode;
begin
  Result := Frm.Main.Structure.FindStructureNodeByData(FTreeStructure, AData);
end;

procedure TfrmMain.SyncReportStructureSelection;
var
  Node: TTreeNode;
  Target: TReportObject;
begin
  if not Assigned(FTreeStructure) or (FTreeStructure.Items.Count = 0) then
    Exit;

  Target := CurrentPropertyTarget;
  if Assigned(Target) then
    Node := FindStructureNodeByData(Target)
  else
    Node := FTreeStructure.Items.GetFirstNode;

  if Assigned(Node) then
  begin
    FUpdatingStructureSelection := True;
    try
      FTreeStructure.Selected := Node;
      Node.MakeVisible;
    finally
      FUpdatingStructureSelection := False;
    end;
  end;
end;

procedure TfrmMain.StructureTreeChange(Sender: TObject; Node: TTreeNode);
begin
  if FUpdatingStructureSelection or not Assigned(FDesigner) then
    Exit;

  if not Assigned(Node) or not Assigned(Node.Data) then
    FDesigner.SelectObject(nil)
  else
    FDesigner.SelectObject(TReportObject(Node.Data));
end;

procedure TfrmMain.StructureTreeDblClick(Sender: TObject);
var
  Node: TTreeNode;
begin
  if not Assigned(FTreeStructure) or not Assigned(FDesigner) then
    Exit;

  Node := FTreeStructure.Selected;
  if not Assigned(Node) then
    Exit;

  // Reinforce existing selection path without mutating report state.
  if Assigned(Node.Data) then
    FDesigner.SelectObject(TReportObject(Node.Data));

  if Assigned(FDesigner.Parent) and FDesigner.Parent.CanFocus then
    FDesigner.Parent.SetFocus
  else if FDesigner.CanFocus then
    FDesigner.SetFocus;

  FDesigner.Invalidate;
end;

procedure TfrmMain.StructureTreeMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Node: TTreeNode;
begin
  if (Button <> mbRight) or not Assigned(FTreeStructure) then
    Exit;

  Node := FTreeStructure.GetNodeAt(X, Y);
  if Assigned(Node) then
    FTreeStructure.Selected := Node
  else
    FTreeStructure.Selected := nil;
end;

procedure TfrmMain.StructureTreePopupPopup(Sender: TObject);
var
  Node: TTreeNode;
  Target: TObject;
begin
  if not Assigned(FTreeStructure) then
    Exit;

  Node := FTreeStructure.Selected;
  if Assigned(Node) then
    Target := Node.Data
  else
    Target := nil;

  // Can delete any object or band, but not the root node (which has nil Data)
  FStructureTreeDeleteItem.Enabled := Assigned(Target);

  // Can only add a band to the root of the report (nil Data)
  FStructureTreeAddBandItem.Enabled := not Assigned(Target);

  // Can only add an object to a band
  FStructureTreeAddObjectItem.Enabled := Assigned(Target) and (Target is TReportBand);
end;

procedure TfrmMain.StructureTreeDeleteClick(Sender: TObject);
begin
  mnuDeleteClick(Sender);
end;

procedure TfrmMain.StructureTreeExpandAllClick(Sender: TObject);
begin
  if Assigned(FTreeStructure) then
    FTreeStructure.FullExpand;
end;

procedure TfrmMain.StructureTreeCollapseAllClick(Sender: TObject);
var
  RootNode: TTreeNode;
begin
  if not Assigned(FTreeStructure) then
    Exit;

  FTreeStructure.FullCollapse;
  RootNode := FTreeStructure.Items.GetFirstNode;
  if Assigned(RootNode) then
    RootNode.Expand(False);
end;

procedure TfrmMain.RefreshReportStructure;
var
  RootNode, BandNode: TTreeNode;
  TopObj, ChildObj: TReportObject;
  IconIndex: Integer;
begin
  if not Assigned(FTreeStructure) or not HasDesignerReport then
    Exit;

  FUpdatingStructureSelection := True;
  FTreeStructure.Items.BeginUpdate;
  try
    FTreeStructure.Items.Clear;
    RootNode := FTreeStructure.Items.AddChildObject(nil, 'Report', nil);
    RootNode.ImageIndex := TREE_ICON_REPORT;
    RootNode.SelectedIndex := TREE_ICON_REPORT;
    for TopObj in FDesigner.Report.Objects do
    begin
      if TopObj is TReportBand then
      begin
        BandNode := FTreeStructure.Items.AddChildObject(RootNode,
          StructureBandCaption(TReportBand(TopObj)), TopObj);
        BandNode.ImageIndex := TREE_ICON_BAND;
        BandNode.SelectedIndex := TREE_ICON_BAND;
        for ChildObj in TReportBand(TopObj).Children do
        begin
          IconIndex := StructureObjectIconIndex(ChildObj);
          with FTreeStructure.Items.AddChildObject(BandNode,
            StructureObjectCaption(ChildObj), ChildObj) do
          begin
            ImageIndex := IconIndex;
            SelectedIndex := IconIndex;
          end;
        end;
      end
      else
      begin
        IconIndex := StructureObjectIconIndex(TopObj);
        with FTreeStructure.Items.AddChildObject(RootNode,
          StructureObjectCaption(TopObj), TopObj) do
        begin
          ImageIndex := IconIndex;
          SelectedIndex := IconIndex;
        end;
      end;
    end;
    RootNode.Expand(True);
  finally
    FTreeStructure.Items.EndUpdate;
    FUpdatingStructureSelection := False;
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
begin
  Frm.Main.TreeFieldHelpers.RefreshFieldList(FLstFields, FLblFields, FDesigner);
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

function TfrmMain.VariableTokenForNode(ANode: TTreeNode; out AToken: string;
  out ASupported: Boolean): Boolean;
begin
  Result := Frm.Main.TreeFieldHelpers.VariableTokenForNode(ANode, AToken, ASupported);
end;

function TfrmMain.CanInsertVariableIntoCurrentProperty(out AKey: string): Boolean;
begin
  Result := Frm.Main.TreeFieldHelpers.CanInsertVariableIntoCurrentProperty(PropEditor, AKey);
end;

procedure TfrmMain.InsertVariableToken(const AToken: string);
begin
  Frm.Main.TreeFieldHelpers.InsertVariableToken(PropEditor,
    procedure(AValue: Boolean)
    begin
      SetPropertyPanelDirty(AValue);
    end,
    procedure(ARow: Integer)
    begin
      UpdatePropertyPanelHintForRow(ARow);
    end,
    AToken);
end;

procedure TfrmMain.VariableListDblClick(Sender: TObject);
var
  Token: string;
  Supported: Boolean;
begin
  if not Assigned(FTreeVariables) or not Assigned(FTreeVariables.Selected) then
    Exit;

  if not VariableTokenForNode(FTreeVariables.Selected, Token, Supported) then
    Exit;

  if not Supported then
  begin
    ShowMessage('This variable is not supported yet.');
    Exit;
  end;

  InsertVariableToken(Token);
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

procedure TfrmMain.btnFontQuickClick(Sender: TObject);
begin
  Frm.Main.QuickActions.HandleFontQuickClick(PropEditor,
    procedure
    begin
      PropEditorDblClick(PropEditor);
    end);
end;

function TfrmMain.IsVisualGroupRow(const AKey: string): Boolean;
begin
  Result := Frm.Main.PropertyHelpers.IsVisualGroupRow(AKey);
end;

function TfrmMain.IsFontDialogRowKey(const AKey: string): Boolean;
begin
  Result := Frm.Main.PropertyHelpers.IsFontDialogRowKey(AKey);
end;

function TfrmMain.IsColorPropertyKey(const AKey: string): Boolean;
begin
  Result := Frm.Main.PropertyHelpers.IsColorPropertyKey(AKey);
end;

function TfrmMain.IsExpressionPropertyKey(const AKey: string): Boolean;
begin
  Result := Frm.Main.PropertyHelpers.IsExpressionPropertyKey(AKey);
end;

function TfrmMain.IsBandEventScriptRowKey(const AKey: string): Boolean;
begin
  Result := Frm.Main.PropertyHelpers.IsBandEventScriptRowKey(AKey);
end;

function TfrmMain.EditExpressionPropertyRow(ARow: Integer): Boolean;
var
  KeyName: string;
  CurrentValue: string;
  EditedValue: string;
  Helper: TfrmExpressionHelper;
begin
  Result := False;
  if (ARow <= 0) or (ARow >= PropEditor.RowCount) then
    Exit;

  KeyName := Trim(PropEditor.Keys[ARow]);
  if IsVisualGroupRow(KeyName) or not IsExpressionPropertyKey(KeyName) then
    Exit;

  CurrentValue := PropEditor.Values[KeyName];
  Helper := TfrmExpressionHelper.Create(Self);
  try
    if not Helper.PromptExpression(
      CurrentValue,
      FDesigner.GetFieldNames,
      KeyName,
      function: TExpressionContext
      begin
        if Assigned(FDataSource1) then
          Result.DataSet := FDataSource1.DataSet;
        Result.PageNumber := 1;
        Result.TotalPages := 1;
        Result.ReportTitle := edtReportTitle.Text;
        Result.ReportDate := Now;
      end,
      EditedValue) then
      Exit;
  finally
    Helper.Free;
  end;

  PropEditor.Values[KeyName] := EditedValue;
  SetPropertyPanelDirty(True);
  ApplyPropertyPanel;
  Result := True;
end;

function TfrmMain.EditBandEventScriptRow(ARow: Integer): Boolean;
var
  KeyName: string;
  CurrentValue: string;
  Target: TReportObject;
  IsBandTarget: Boolean;
  DialogTitle: string;
  StorageSubject: string;
  Dlg: TfrmScriptEditor;
begin
  Result := False;
  if (ARow <= 0) or (ARow >= PropEditor.RowCount) then
    Exit;

  KeyName := Trim(PropEditor.Keys[ARow]);
  if IsVisualGroupRow(KeyName) or not IsBandEventScriptRowKey(KeyName) then
    Exit;

  Target := CurrentPropertyTarget;
  IsBandTarget := Assigned(Target) and (Target is TReportBand);
  if IsBandTarget then
  begin
    DialogTitle := 'Band Event Script';
    StorageSubject := 'band';
  end
  else
  begin
    DialogTitle := 'Object Event Script';
    StorageSubject := 'object';
  end;

  CurrentValue := PropEditor.Values[KeyName];

  Dlg := TfrmScriptEditor.Create(Self);
  try
    Dlg.Initialize(DialogTitle, StorageSubject, CurrentValue, Target);
    if not Dlg.Execute(CurrentValue) then
      Exit;

    if PropEditor.Values[KeyName] <> CurrentValue then
    begin
      PropEditor.Values[KeyName] := CurrentValue;
      SetPropertyPanelDirty(True);
      UpdatePropertyPanelHintForRow(ARow);
    end;
    Result := True;
  finally
    Dlg.Free;
  end;
end;

function TfrmMain.EditColorPropertyRow(ARow: Integer): Boolean;
var
  KeyName: string;
  ValueText: string;
  Dlg: TColorDialog;
  ColorValue: Integer;
begin
  Result := False;
  if (ARow <= 0) or (ARow >= PropEditor.RowCount) then
    Exit;

  KeyName := PropEditor.Keys[ARow];
  if IsVisualGroupRow(KeyName) or not IsColorPropertyKey(KeyName) then
    Exit;

  ValueText := PropEditor.Values[KeyName];
  if not TryStrToInt(ValueText, ColorValue) then
    ColorValue := clBlack;

  Dlg := TColorDialog.Create(Self);
  try
    Dlg.Color := TColor(ColorValue);
    if not Dlg.Execute then
      Exit;

    PropEditor.Values[KeyName] := IntToStr(Dlg.Color);
    SetPropertyPanelDirty(True);
    Result := True;
  finally
    Dlg.Free;
  end;
end;

function TfrmMain.EditFontPropertyRow(ARow: Integer): Boolean;
begin
  Result := Frm.Main.FontEditHelpers.EditFontPropertyRow(
    Self,
    FDesigner,
    PropEditor,
    ARow,
    CurrentPropertyTarget,
    procedure(AValue: Boolean)
    begin
      SetPropertyPanelDirty(AValue);
    end,
    procedure
    begin
      UpdateTitleBar;
    end,
    procedure
    begin
      UpdatePropertyPanel;
    end,
    procedure
    begin
      UpdateStatusBar;
    end,
    procedure
    begin
      RefreshReportStructure;
    end,
    procedure
    begin
      SyncReportStructureSelection;
    end);
end;

procedure TfrmMain.CreateSampleDataSet;
begin
  if Assigned(FSampleDataSet) then
    Exit;

  FSampleDataSet := TFDMemTable.Create(Self);
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
const
  SampleRowCount = 150;
  ImagePathHint = 'D:\test\sample.bmp'; // For image binding test, create D:\test\sample.bmp or edit this path.
  ImagePathHint2 = 'D:\test\sample2.bmp'; // For image binding test, create D:\test\sample2.bmp or edit this path.
  Customers: array[0..19] of string = (
    'Acme Retail', 'Northwind Foods', 'BluePeak Pharma', 'GreenLeaf Traders',
    'Sunrise Packaging', 'Metro Stationers', 'Delta Logistics', 'Orchid Prints',
    'Crown Labels', 'Polar Cold Chain', 'Silverline Office', 'Rapid Supplies',
    'BrightKart', 'Nimbus Distribution', 'Vertex Stores', 'Prime Exports',
    'Urban Cart', 'EverFresh Foods', 'Galaxy Wholesale', 'Trident Industries'
  );
  Items: array[0..29] of string = (
    'A4 Paper Ream', 'A3 Paper Ream', 'Laser Toner Black', 'Laser Toner Cyan',
    'Thermal Label Roll', 'Barcode Sticker Sheet', 'Cold Storage Box', 'Bubble Wrap Roll',
    'Packing Tape 2inch', 'Corrugated Carton L', 'Corrugated Carton M', 'Inkjet Ink Set',
    'Offset Plate 0.30', 'CTP Plate Standard', 'Flexo Plate 1.14', 'Leaflet Gloss 130gsm',
    'Flyer Matte 170gsm', 'Business Card 300gsm', 'Shipping Label 4x6', 'QR Label 2x2',
    'Poly Mailer Medium', 'Shrink Film Roll', 'Invoice Book 2-Ply', 'Receipt Roll 80mm',
    'Catalog Print A5', 'Poster Print A2', 'Sticker Vinyl Sheet', 'Ribbon Wax 110mm',
    'Pallet Tag Set', 'Misc Consumables Kit'
  );
  Groups: array[0..9] of string = (
    'Stationery', 'Packaging', 'Printing', 'Cold Chain', 'Labels',
    'Leaflets', 'Flexo Plates', 'Offset CTP', 'Digital Print', 'Miscellaneous'
  );
var
  I: Integer;
  Qty: Integer;
  Rate: Currency;
  Amount: Currency;
  CustomerName: string;
  ItemName: string;
  GroupName: string;
  InvoiceNo: string;
  InvoiceDate: TDateTime;
  ImagePath: string;
  BarcodeValue: string;
  Remarks: string;
  JsonFile: string;
begin
  JsonFile := GetRegressionReportPath('sample_data.json');

  CreateSampleDataSet;

  if TFile.Exists(JsonFile) then
  begin
    FSampleDataSet.LoadFromFile(JsonFile, sfJSON);
    Exit;
  end;

  FSampleDataSet.DisableControls;
  try
    if FSampleDataSet.Active then
      FSampleDataSet.EmptyDataSet;
    for I := 1 to SampleRowCount do
    begin
      CustomerName := Customers[(I - 1) mod Length(Customers)];
      ItemName := Items[((I * 3) - 1) mod Length(Items)];
      GroupName := Groups[((I * 2) - 1) mod Length(Groups)];
      InvoiceNo := Format('INV-2026-%.4d', [I]);
      InvoiceDate := EncodeDate(2026, 1, 1) + ((I * 3) mod 180);

      Qty := 1 + ((I * 7) mod 24);
      Rate := 75.00 + ((I * 37) mod 2400) / 10;
      Amount := Qty * Rate;

      if (I mod 15 = 0) then
        ImagePath := ''
      else if (I mod 17 = 0) then
        ImagePath := ImagePathHint2
      else if (I mod 10 = 0) then
        ImagePath := ImagePathHint
      else
        ImagePath := '';

      if (I mod 13 = 0) then
        BarcodeValue := ''
      else if (I mod 17 = 0) then
        BarcodeValue := '890123459999'
      else if (I mod 29 = 0) then
        BarcodeValue := '890123450007'
      else
        BarcodeValue := Format('89012345%.4d', [I]);

      if (I mod 11 = 0) then
        Remarks := ''
      else if (I mod 7 = 0) then
        Remarks := 'Long remarks: customer requested staggered delivery, temperature-safe stacking, barcode scan verification at dispatch and arrival, and carton-level recount before final invoice closure.'
      else if (I mod 5 = 0) then
        Remarks := 'Medium remarks: prioritize packing and dispatch in second half of the day.'
      else
        Remarks := 'Short remarks: standard handling.';

      FSampleDataSet.AppendRecord([
        CustomerName,
        InvoiceNo,
        InvoiceDate,
        ItemName,
        Qty,
        Rate,
        Amount,
        GroupName,
        ImagePath,
        BarcodeValue,
        Remarks
      ]);
    end;
  finally
    FSampleDataSet.EnableControls;
  end;

  FSampleDataSet.SaveToFile(JsonFile, sfJSON);
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
begin
  Frm.Main.InsertMenuHelpers.BuildInsertMenu(
    mnuInsert,
    mnuSep5,
    FStructureTreeAddBandItem,
    FStructureTreeAddObjectItem,
    DynAddBandMenuClick,
    DynInsertMenuClick,
    function: TArray<TReportObjectClass>
    begin
      Result := GetRegisteredReportObjects;
    end,
    BandTypeName);
end;

procedure TfrmMain.DynAddBandMenuClick(Sender: TObject);
begin
  AddBand(TReportBandType(TMenuItem(Sender).Tag));
end;

end.
