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
  Datasnap.DBClient,
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
  Vittix.Report.Undo,
  Vittix.Report.Engine,
  Vittix.Report.Renderer,
  Vittix.Report.Export.PDF,
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Objects.Table, Vcl.Grids,  Vcl.CheckLst,
  System.ImageList, Vcl.VirtualImageList, SVGIconVirtualImageList,
  Vcl.BaseImageCollection, SVGIconImageCollection;

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
    FReportSampleReportsMenu: TMenuItem;
    FReportDemoReportsMenu: TMenuItem;
    FReportRegressionTestsMenu: TMenuItem;
    FReportMenuSeparator: TMenuItem;
    FSampleDataSet: TClientDataSet;
    FExprHelperMemo: TMemo;
    FExprHelperFields: TListBox;
    FExprHelperExamples: TListBox;
    FExprHelperRecent: TListBox;
    // Session-only in-memory expression recents; cleared when designer closes.
    FExprRecentsByKey: TObjectDictionary<string, TStringList>;

    // Command-line mode: set when launched by the component editor
    FCmdLineInputFile : string;   // file to load on startup
    FCmdLineOutputFile: string;   // file to write on save & close

    procedure BuildInsertMenu;

    procedure UpdateTitleBar;
    procedure UpdateStatusBar;
    procedure UpdateMenuState;
    procedure ConfigureLayoutGuidance;
    procedure ConfigureViewToggleStrip;
    procedure UpdatePropertyPanel;
    procedure ApplyPropertyPanel;
    procedure SetPropertyPanelDirty(AValue: Boolean);
    procedure UpdatePropertyPanelHeader(AObj: TReportObject);
    procedure UpdatePropertyPanelHintForRow(ARow: Integer);
    function  PropertyHintText(const AKey: string): string;
    procedure ConfigurePropertyEditors;
    procedure PromoteImportantProperties(AObj: TReportObject);
    procedure InsertVisualGroupRows(AObj: TReportObject);
    function  IsVisualGroupRow(const AKey: string): Boolean;
    function  IsFontDialogRowKey(const AKey: string): Boolean;
    function  IsColorPropertyKey(const AKey: string): Boolean;
    function  IsExpressionPropertyKey(const AKey: string): Boolean;
    function  IsBandEventScriptRowKey(const AKey: string): Boolean;
    function  EditExpressionPropertyRow(ARow: Integer): Boolean;
    function  EditBandEventScriptRow(ARow: Integer): Boolean;
    function  PromptExpressionHelper(const AInitialValue: string;
      const AFields: TArray<string>; const APropertyKey: string;
      out AEditedValue: string): Boolean;
    procedure ExpressionHelperInsertField(Sender: TObject);
    procedure ExpressionHelperFieldDblClick(Sender: TObject);
    procedure ExpressionHelperExampleDblClick(Sender: TObject);
    procedure ExpressionHelperRecentDblClick(Sender: TObject);
    procedure ExpressionHelperOperatorClick(Sender: TObject);
    procedure ExpressionHelperTemplateClick(Sender: TObject);
    procedure ExpressionHelperInsertText(const AText: string);
    function  ExpressionHelperTryGetSelectedField(out AFieldName: string): Boolean;
    procedure ExpressionHelperCheckClick(Sender: TObject);
    function  ExpressionHelperBucketKey(const APropertyKey: string): string;
    function  ExpressionHelperRecentList(const APropertyKey: string;
      ACreate: Boolean): TStringList;
    procedure ExpressionHelperAddRecent(const APropertyKey, AExpr: string);
    function  ExpressionHelperIsRecentHintItem(const AValue: string): Boolean;
    function  SamePropertyValue(const AOld, ANew: TValue): Boolean;
    function  BuildChangedPropertyBatch(
      AObj: TReportObject;
      const AOldByProp: TDictionary<string, TValue>;
      const APropNames: TArray<string>;
      out ChangedNames: TArray<string>;
      out OldValues: TArray<TValue>;
      out NewValues: TArray<TValue>): Boolean;
    function  IsControlWithinParent(AControl, AParent: TWinControl): Boolean;
    function  IsTextEditingControlFocused: Boolean;
    procedure SendMessageToFocusedControl(AMsg: Cardinal);
    procedure SendDeleteToFocusedControl;
    function  CurrentPropertyTarget: TReportObject;
    function  SelectedObjectsSpanBands: Boolean;
    function  ConfirmMixedBandVerticalLayout: Boolean;
    function  EditColorPropertyRow(ARow: Integer): Boolean;
    function  EditFontPropertyRow(ARow: Integer): Boolean;
    procedure ApplyZoom;
    procedure InitializeToolbarZoomCombo;
    procedure UpdateZoomControls;
    procedure ApplyToolbarZoomSelection;
    function  FitPageWidthZoom: Integer;
    function  FitWholePageZoom: Integer;
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
    procedure SyncReportStructureSelection;
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

    function  ZoomFromEdit: Integer;
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

function BandTypeName(BT: TReportBandType): string; forward;

type
  TPropertyBatchChangeCommand = class(TUndoableAction)
  private
    FObj: TObject;
    FPropNames: TArray<string>;
    FOldValues: TArray<TValue>;
    FNewValues: TArray<TValue>;
    procedure ApplyValues(const AValues: TArray<TValue>);
  public
    constructor Create(AObj: TObject; const APropNames: TArray<string>;
      const AOldValues, ANewValues: TArray<TValue>);
    procedure Execute; override;
    procedure Rollback; override;
  end;

  TTextFontChangeCommand = class(TUndoableAction)
  private
    FObj: TReportTextObject;
    FOldFont: TFont;
    FNewFont: TFont;
  public
    constructor Create(AObj: TReportTextObject; const AOldFont, ANewFont: TFont);
    destructor Destroy; override;
    procedure Execute; override;
    procedure Rollback; override;
  end;

  TReportSnapshotCommand = class(TUndoableAction)
  private
    FDesigner: TVittixReportDesigner;
    FBeforeJSON: string;
    FAfterJSON: string;
    procedure ApplyJSON(const AJSON: string);
  public
    constructor Create(ADesigner: TVittixReportDesigner;
      const ABeforeJSON, AAfterJSON: string);
    procedure Execute; override;
    procedure Rollback; override;
  end;

  TPageSettingsChangeCommand = class(TUndoableAction)
  private
    FDesigner: TVittixReportDesigner;
    FOldSettings: TReportPageSettings;
    FNewSettings: TReportPageSettings;
    procedure ApplySettings(ASource: TReportPageSettings);
  public
    constructor Create(ADesigner: TVittixReportDesigner;
      AOldSettings, ANewSettings: TReportPageSettings);
    destructor Destroy; override;
    procedure Execute; override;
    procedure Rollback; override;
  end;

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

  TRuntimeEventDemoHarness = class
  private
    FTrace: TStringList;
    FSkipObjectClassName: string;
    FSkipMasterDataBand: Boolean;
  public
    BeforeReportCount: Integer;
    AfterReportCount: Integer;
    BeforeBandCount: Integer;
    AfterBandCount: Integer;
    BeforeObjectCount: Integer;
    AfterObjectCount: Integer;
    SkippedBandCount: Integer;
    SkippedObjectCount: Integer;

    constructor Create;
    destructor Destroy; override;
    procedure ResetCounts;
    procedure BeforeReport(Sender, AEngine: TObject; AReport: TReportModel;
      var ACancel: Boolean);
    procedure AfterReport(Sender, AEngine: TObject; AReport: TReportModel);
    procedure BeforeBand(Sender, AEngine: TObject; ABand: TReportBand;
      const Context: TExpressionContext; var ACanPrint: Boolean);
    procedure AfterBand(Sender, AEngine: TObject; ABand: TReportBand;
      const Context: TExpressionContext);
    procedure BeforeObject(Sender, AEngine: TObject; AObject: TReportObject;
      const Context: TExpressionContext; var ACanPrint: Boolean);
    procedure AfterObject(Sender, AEngine: TObject; AObject: TReportObject;
      const Context: TExpressionContext);
    property Trace: TStringList read FTrace;
    property SkipObjectClassName: string read FSkipObjectClassName write FSkipObjectClassName;
    property SkipMasterDataBand: Boolean read FSkipMasterDataBand write FSkipMasterDataBand;
  end;

  TBandEventScriptDialogHelper = class
  private
    FDialog: TForm;
    FMemo: TMemo;
    FStatsLabel: TLabel;
    FSnippetCombo: TComboBox;
  public
    constructor Create(ADialog: TForm; AMemo: TMemo; AStatsLabel: TLabel;
      ASnippetCombo: TComboBox);
    procedure UpdateStats;
    procedure MemoChange(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure InsertSnippetClick(Sender: TObject);
  end;

function PageSettingsEqual(A, B: TReportPageSettings): Boolean;
begin
  Result := Assigned(A) and Assigned(B) and
            (A.PaperSize = B.PaperSize) and
            (A.Orientation = B.Orientation) and
            (A.CustomWidth = B.CustomWidth) and
            (A.CustomHeight = B.CustomHeight) and
            (A.Margins.Left = B.Margins.Left) and
            (A.Margins.Top = B.Margins.Top) and
            (A.Margins.Right = B.Margins.Right) and
            (A.Margins.Bottom = B.Margins.Bottom);
end;

{ TRuntimeEventDemoHarness }

constructor TRuntimeEventDemoHarness.Create;
begin
  inherited Create;
  FTrace := TStringList.Create;
  ResetCounts;
end;

destructor TRuntimeEventDemoHarness.Destroy;
begin
  FTrace.Free;
  inherited;
end;

procedure TRuntimeEventDemoHarness.ResetCounts;
begin
  BeforeReportCount := 0;
  AfterReportCount := 0;
  BeforeBandCount := 0;
  AfterBandCount := 0;
  BeforeObjectCount := 0;
  AfterObjectCount := 0;
  SkippedBandCount := 0;
  SkippedObjectCount := 0;
  FTrace.Clear;
  FSkipObjectClassName := '';
  FSkipMasterDataBand := False;
end;

procedure TRuntimeEventDemoHarness.BeforeReport(Sender, AEngine: TObject;
  AReport: TReportModel; var ACancel: Boolean);
begin
  Inc(BeforeReportCount);
  FTrace.Add('BeforeReport');
end;

procedure TRuntimeEventDemoHarness.AfterReport(Sender, AEngine: TObject;
  AReport: TReportModel);
begin
  Inc(AfterReportCount);
  FTrace.Add('AfterReport');
end;

procedure TRuntimeEventDemoHarness.BeforeBand(Sender, AEngine: TObject;
  ABand: TReportBand; const Context: TExpressionContext; var ACanPrint: Boolean);
begin
  Inc(BeforeBandCount);
  FTrace.Add('BeforeBand: ' + BandTypeName(ABand.BandType));
  if FSkipMasterDataBand and (ABand.BandType = btMasterData) then
  begin
    ACanPrint := False;
    Inc(SkippedBandCount);
    FTrace.Add('SkipBand: Master Data');
  end;
end;

procedure TRuntimeEventDemoHarness.AfterBand(Sender, AEngine: TObject;
  ABand: TReportBand; const Context: TExpressionContext);
begin
  Inc(AfterBandCount);
  FTrace.Add('AfterBand: ' + BandTypeName(ABand.BandType));
end;

procedure TRuntimeEventDemoHarness.BeforeObject(Sender, AEngine: TObject;
  AObject: TReportObject; const Context: TExpressionContext; var ACanPrint: Boolean);
begin
  Inc(BeforeObjectCount);
  FTrace.Add('BeforeObject: ' + AObject.ClassName);
  if (FSkipObjectClassName <> '') and SameText(AObject.ClassName, FSkipObjectClassName) then
  begin
    ACanPrint := False;
    Inc(SkippedObjectCount);
    FTrace.Add('SkipObject: ' + AObject.ClassName);
  end;
end;

procedure TRuntimeEventDemoHarness.AfterObject(Sender, AEngine: TObject;
  AObject: TReportObject; const Context: TExpressionContext);
begin
  Inc(AfterObjectCount);
  FTrace.Add('AfterObject: ' + AObject.ClassName);
end;

{ TBandEventScriptDialogHelper }

constructor TBandEventScriptDialogHelper.Create(ADialog: TForm; AMemo: TMemo;
  AStatsLabel: TLabel; ASnippetCombo: TComboBox);
begin
  inherited Create;
  FDialog := ADialog;
  FMemo := AMemo;
  FStatsLabel := AStatsLabel;
  FSnippetCombo := ASnippetCombo;
end;

procedure TBandEventScriptDialogHelper.UpdateStats;
var
  LineCount: Integer;
  CharCount: Integer;
begin
  if not Assigned(FMemo) or not Assigned(FStatsLabel) then
    Exit;

  CharCount := Length(FMemo.Text);
  if FMemo.Text = '' then
    LineCount := 0
  else
    LineCount := FMemo.Lines.Count;

  FStatsLabel.Caption := Format('Lines: %d | Chars: %d', [LineCount, CharCount]);
end;

procedure TBandEventScriptDialogHelper.MemoChange(Sender: TObject);
begin
  UpdateStats;
end;

procedure TBandEventScriptDialogHelper.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (ssCtrl in Shift) then
  begin
    Key := 0;
    if Assigned(FDialog) then
      FDialog.ModalResult := mrOk;
  end;
end;

procedure TBandEventScriptDialogHelper.InsertSnippetClick(Sender: TObject);
var
  S: string;
begin
  if not Assigned(FMemo) or not Assigned(FSnippetCombo) then
    Exit;
  if FSnippetCombo.ItemIndex < 0 then
    Exit;

  case FSnippetCombo.ItemIndex of
    0:
      S :=
        '// Host callback script example' + sLineBreak +
        '// Purpose: describe what this hook should do';
    1:
      S :=
        '// Example: set visibility in host callback' + sLineBreak +
        'Visible := False;';
    2:
      S :=
        '// Example: set variable in host callback' + sLineBreak +
        'Vars[''MyVar''] := ''value'';';
    3:
      S :=
        'if <condition> then' + sLineBreak +
        'begin' + sLineBreak +
        '  // ...' + sLineBreak +
        'end;';
    4:
      S :=
        '// This script is passed as text to the host callback implementation.' + sLineBreak +
        '// VittixReport does not execute this text by itself.';
  else
    Exit;
  end;

  if (FMemo.Text <> '') and (FMemo.SelStart > 0) and
     (FMemo.Text[FMemo.SelStart] <> #10) and (FMemo.Text[FMemo.SelStart] <> #13) then
    FMemo.SelText := sLineBreak + S
  else
    FMemo.SelText := S;
  FMemo.SetFocus;
  UpdateStats;
end;

constructor TPropertyBatchChangeCommand.Create(AObj: TObject;
  const APropNames: TArray<string>; const AOldValues, ANewValues: TArray<TValue>);
begin
  inherited Create;
  ActionName := 'Property Change';
  FObj := AObj;
  FPropNames := APropNames;
  FOldValues := AOldValues;
  FNewValues := ANewValues;
end;

procedure TPropertyBatchChangeCommand.ApplyValues(const AValues: TArray<TValue>);
var
  Ctx: TRttiContext;
  RttiType: TRttiType;
  Prop: TRttiProperty;
  I: Integer;
begin
  if not Assigned(FObj) then
    Exit;

  Ctx := TRttiContext.Create;
  try
    RttiType := Ctx.GetType(FObj.ClassType);
    if not Assigned(RttiType) then
      Exit;

    for I := 0 to High(FPropNames) do
    begin
      Prop := RttiType.GetProperty(FPropNames[I]);
      if Assigned(Prop) and Prop.IsWritable then
        Prop.SetValue(FObj, AValues[I]);
    end;
  finally
    Ctx.Free;
  end;
end;

procedure TPropertyBatchChangeCommand.Execute;
begin
  ApplyValues(FNewValues);
end;

procedure TPropertyBatchChangeCommand.Rollback;
begin
  ApplyValues(FOldValues);
end;

constructor TTextFontChangeCommand.Create(AObj: TReportTextObject;
  const AOldFont, ANewFont: TFont);
begin
  inherited Create;
  ActionName := 'Font Change';
  FObj := AObj;
  FOldFont := TFont.Create;
  FNewFont := TFont.Create;
  FOldFont.Assign(AOldFont);
  FNewFont.Assign(ANewFont);
end;

destructor TTextFontChangeCommand.Destroy;
begin
  FOldFont.Free;
  FNewFont.Free;
  inherited;
end;

procedure TTextFontChangeCommand.Execute;
begin
  if Assigned(FObj) then
    FObj.Font.Assign(FNewFont);
end;

procedure TTextFontChangeCommand.Rollback;
begin
  if Assigned(FObj) then
    FObj.Font.Assign(FOldFont);
end;

constructor TReportSnapshotCommand.Create(ADesigner: TVittixReportDesigner;
  const ABeforeJSON, AAfterJSON: string);
begin
  inherited Create;
  ActionName := 'Band Manager Changes';
  FDesigner := ADesigner;
  FBeforeJSON := ABeforeJSON;
  FAfterJSON := AAfterJSON;
end;

procedure TReportSnapshotCommand.ApplyJSON(const AJSON: string);
var
  Model: TReportModel;
begin
  if not Assigned(FDesigner) then
    Exit;
  Model := TReportSerializer.LoadFromJSON(AJSON);
  FDesigner.LoadReport(Model, True, False);
end;

procedure TReportSnapshotCommand.Execute;
begin
  ApplyJSON(FAfterJSON);
end;

procedure TReportSnapshotCommand.Rollback;
begin
  ApplyJSON(FBeforeJSON);
end;

constructor TPageSettingsChangeCommand.Create(ADesigner: TVittixReportDesigner;
  AOldSettings, ANewSettings: TReportPageSettings);
begin
  inherited Create;
  ActionName := 'Page Setup Change';
  FDesigner := ADesigner;
  FOldSettings := TReportPageSettings.Create;
  FNewSettings := TReportPageSettings.Create;
  if Assigned(AOldSettings) then
    AOldSettings.AssignTo(FOldSettings);
  if Assigned(ANewSettings) then
    ANewSettings.AssignTo(FNewSettings);
end;

destructor TPageSettingsChangeCommand.Destroy;
begin
  FOldSettings.Free;
  FNewSettings.Free;
  inherited;
end;

procedure TPageSettingsChangeCommand.ApplySettings(ASource: TReportPageSettings);
begin
  if not Assigned(FDesigner) or not Assigned(FDesigner.Report) or
     not Assigned(FDesigner.Report.PageSettings) or not Assigned(ASource) then
    Exit;
  ASource.AssignTo(FDesigner.Report.PageSettings);
end;

procedure TPageSettingsChangeCommand.Execute;
begin
  ApplySettings(FNewSettings);
end;

procedure TPageSettingsChangeCommand.Rollback;
begin
  ApplySettings(FOldSettings);
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
  UpdateTitleBar;
  UpdateStatusBar;
  UpdateMenuState;
  SyncReportStructureSelection;

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
  // Designer frees its own TReportModel when it owns it
  FreeAndNil(FExprRecentsByKey);
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
  if not Assigned(FDesigner) or not Assigned(FDesigner.Report) then
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
  if not Assigned(FDesigner) or not Assigned(FDesigner.Report) then
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
  UpdatePropertyPanel;
  UpdateTitleBar;
  UpdateStatusBar;
  UpdateMenuState;
  SyncReportStructureSelection;
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
  UpdateMenuState;
  UpdatePropertyPanel;
  UpdateStatusBar;
  RefreshReportStructure;
  SyncReportStructureSelection;
end;

procedure TfrmMain.mnuRedoClick(Sender: TObject);
begin
  FDesigner.Redo;
  UpdateMenuState;
  UpdatePropertyPanel;
  UpdateStatusBar;
  RefreshReportStructure;
  SyncReportStructureSelection;
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
  RefreshReportStructure;
  RefreshFieldList;
  UpdateTitleBar;
  UpdateMenuState;
  UpdateStatusBar;
  SyncReportStructureSelection;
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
var
  Candidates: array[0..3] of string;
  I: Integer;
begin
  Candidates[0] := TPath.Combine(ExtractFilePath(ParamStr(0)), 'reports\' + AFileName);
  Candidates[1] := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\reports\' + AFileName));
  Candidates[2] := TPath.GetFullPath(TPath.Combine(GetCurrentDir, 'reports\' + AFileName));
  Candidates[3] := TPath.GetFullPath(TPath.Combine(GetCurrentDir, '..\reports\' + AFileName));

  for I := Low(Candidates) to High(Candidates) do
    if TFile.Exists(Candidates[I]) then
      Exit(Candidates[I]);

  Result := Candidates[1];
end;

procedure TfrmMain.OpenRegressionReport(const AFileName: string);
var
  FN: string;
begin
  ConfirmSaveIfModified;
  FN := GetRegressionReportPath(AFileName);
  if not TFile.Exists(FN) then
  begin
    ShowMessage('Test report file not found: ' + FN);
    Exit;
  end;

  try
    LoadDesignerReportFromFile(FN, True);
  except
    on E: Exception do
      ShowMessage('Error loading report: ' + E.Message);
  end;
end;

procedure TfrmMain.RunRegressionTestReports;
const
  // Automatic runner scope:
  // - Includes lightweight, non-interactive regression reports that should
  //   render deterministically using the sample dataset.
  // - Intentionally excludes 16_large_preview_warning.vrt because it is a
  //   manual interactive warning-path test for very large previews.
  // - Intentionally excludes reports/test*.vrt dev artifacts.
  // Manual reports can still be opened directly via OpenRegressionReport.
  ReportFiles: array[0..16] of string = (
    '01_simple_masterdata.vrt',
    '03_grouped_report.vrt',
    '05_cangrow_remarks.vrt',
    '06_barcode_test.vrt',
    '07_imagepath_test.vrt',
    '11_exact_fit_boundary.vrt',
    '12_summary_new_page_header.vrt',
    '13_group_header_pagebreak.vrt',
    '14_group_footer_pagebreak.vrt',
    '15_large_preview_stress.vrt',
    '17_object_printwhen_core.vrt',
    '18_barcode_printwhen.vrt',
    '19_displayformat_values.vrt',
    '20_printwhen_boolean_coercion.vrt',
    '21_condition_color_boolean_coercion.vrt',
    '22_expression_usage_demo.vrt',
    '23_invalid_datafield_diagnostics.vrt'
  );
var
  Lines: TStringList;
  I: Integer;
  FN: string;
  ReportModel: TReportModel;
  Renderer: TReportRenderer;
  PassedCount: Integer;
  FailedCount: Integer;
  PageSuffix: string;
begin
  UseSampleDataSet;

  Lines := TStringList.Create;
  try
    PassedCount := 0;
    FailedCount := 0;

    for I := Low(ReportFiles) to High(ReportFiles) do
    begin
      FN := GetRegressionReportPath(ReportFiles[I]);
      if not TFile.Exists(FN) then
      begin
        Inc(FailedCount);
        Lines.Add('FAIL ' + ReportFiles[I] + ' - Test report file not found: ' + FN);
        Continue;
      end;

      ReportModel := nil;
      Renderer := nil;
      try
        ReportModel := TReportSerializer.LoadFromFile(FN);
        Renderer := TReportRenderer.Create;
        Renderer.Render(ReportModel, FSampleDataSet);
        Inc(PassedCount);
        if Renderer.Pages.Count = 1 then
          PageSuffix := ''
        else
          PageSuffix := 's';
        Lines.Add(Format('PASS %s (%d page%s)',
          [ReportFiles[I], Renderer.Pages.Count, PageSuffix]));
      except
        on E: Exception do
        begin
          Inc(FailedCount);
          Lines.Add('FAIL ' + ReportFiles[I] + ' - ' + E.Message);
        end;
      end;
      Renderer.Free;
      ReportModel.Free;
    end;

    Lines.Insert(0, Format('Failed: %d', [FailedCount]));
    Lines.Insert(0, Format('Passed: %d', [PassedCount]));
    Lines.Insert(0, Format('Total tests: %d', [Length(ReportFiles)]));
    ShowMessage(Lines.Text);
  finally
    Lines.Free;
    RefreshFieldList;
    RefreshReportStructure;
    UpdatePropertyPanel;
    UpdateTitleBar;
    UpdateStatusBar;
    UpdateMenuState;
    SyncReportStructureSelection;
  end;
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
begin
  UseSampleDataSet;

  ReportModel := nil;
  Engine := nil;
  Harness := nil;
  Lines := TStringList.Create;
  BaselineTrace := TStringList.Create;
  ObjectSkipTrace := TStringList.Create;
  BandSkipTrace := TStringList.Create;
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

    Engine := TReportEngine.Create(ReportModel, FSampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;

    BaseBeforeBand := Harness.BeforeBandCount;
    BaseAfterBand := Harness.AfterBandCount;
    BaseBeforeObject := Harness.BeforeObjectCount;
    BaseAfterObject := Harness.AfterObjectCount;
    BaselineTrace.Assign(Harness.Trace);

    BasePass :=
      (Harness.BeforeReportCount = 1) and
      (Harness.AfterReportCount = 1) and
      (Harness.BeforeBandCount > 0) and
      (Harness.AfterBandCount > 0) and
      (Harness.BeforeObjectCount > 0) and
      (Harness.AfterObjectCount > 0) and
      (Harness.BeforeBandCount >= Harness.AfterBandCount) and
      (Harness.BeforeObjectCount >= Harness.AfterObjectCount);
    CountingInflationPass :=
      (Harness.BeforeReportCount = 1) and
      (Harness.AfterReportCount = 1);

    Lines.Add('Runtime Event Callback Demo');
    Lines.Add('');
    Lines.Add('Baseline summary:');
    Lines.Add(Format('  BeforeReport=%d AfterReport=%d  BeforeBand=%d AfterBand=%d  BeforeObject=%d AfterObject=%d  SkippedObject=%d SkippedBand=%d',
      [Harness.BeforeReportCount, Harness.AfterReportCount,
       Harness.BeforeBandCount, Harness.AfterBandCount,
       Harness.BeforeObjectCount, Harness.AfterObjectCount,
       Harness.SkippedObjectCount, Harness.SkippedBandCount]));
    if BasePass then
      Lines.Add('  Baseline: PASS')
    else
      Lines.Add('  Baseline: FAIL');
    if CountingInflationPass then
      Lines.Add('  Counting-pass inflation check: PASS')
    else
      Lines.Add('  Counting-pass inflation check: FAIL');

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
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    ObjectSkipPass := Harness.SkippedObjectCount > 0;
    ObjectSkipTrace.Assign(Harness.Trace);
    Lines.Add('');
    Lines.Add('Object-skip summary:');
    Lines.Add(Format('  BeforeReport=%d AfterReport=%d  BeforeBand=%d AfterBand=%d  BeforeObject=%d AfterObject=%d  SkippedObject=%d SkippedBand=%d',
      [Harness.BeforeReportCount, Harness.AfterReportCount,
       Harness.BeforeBandCount, Harness.AfterBandCount,
       Harness.BeforeObjectCount, Harness.AfterObjectCount,
       Harness.SkippedObjectCount, Harness.SkippedBandCount]));
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
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BandSkipPass := Harness.SkippedBandCount > 0;
    BandSkipTrace.Assign(Harness.Trace);
    Lines.Add('');
    Lines.Add('Band-skip summary:');
    Lines.Add(Format('  BeforeReport=%d AfterReport=%d  BeforeBand=%d AfterBand=%d  BeforeObject=%d AfterObject=%d  SkippedObject=%d SkippedBand=%d',
      [Harness.BeforeReportCount, Harness.AfterReportCount,
       Harness.BeforeBandCount, Harness.AfterBandCount,
       Harness.BeforeObjectCount, Harness.AfterObjectCount,
       Harness.SkippedObjectCount, Harness.SkippedBandCount]));
    if BandSkipPass then
      Lines.Add(Format('Band skip subtest (skip Master Data): PASS (SkippedBandCount=%d)',
        [Harness.SkippedBandCount]))
    else
      Lines.Add(Format('Band skip subtest (skip Master Data): FAIL (SkippedBandCount=%d)',
        [Harness.SkippedBandCount]));
    Lines.Add('');
    Lines.Add('Callback inflation guard:');
    Lines.Add(Format('  Baseline BeforeBand=%d, AfterBand=%d',
      [BaseBeforeBand, BaseAfterBand]));
    Lines.Add(Format('  Baseline BeforeObject=%d, AfterObject=%d',
      [BaseBeforeObject, BaseAfterObject]));

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

    ShowMessage(Lines.Text);
  finally
    BandSkipTrace.Free;
    ObjectSkipTrace.Free;
    BaselineTrace.Free;
    Lines.Free;
    Harness.Free;
    Engine.Free;
    ReportModel.Free;
  end;
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

procedure TfrmMain.ApplyZoom;
var Z: Integer;
begin
  Z := ZoomFromEdit;
  if Z > 0 then
  begin
    FDesigner.Zoom := Z;
    UpdateZoomControls;
    UpdateStatusBar;
  end;
end;

function TfrmMain.ZoomFromEdit: Integer;
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
begin ApplyZoom; end;

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
  if not Assigned(FDesigner) or not Assigned(FDesigner.Report) then
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
  if not Assigned(FDesigner) or not Assigned(FDesigner.Report) then
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
  ApplyToolbarZoomSelection;
end;

procedure TfrmMain.CheckListBox1ClickCheck(Sender: TObject);
begin
  case CheckListBox1.ItemIndex of
    0: mnuShowGridClick(mnuShowGrid);
    1: mnuSnapGridClick(mnuSnapGrid);
    2: mnuShowRulersClick(mnuShowRulers);
    3: mnuShowMarginsClick(mnuShowMargins);
  end;
end;

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
  DS: TDataSet;
begin
  CommitReportMetadataChanges(True);

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
      if not PageSettingsEqual(OldSettings, NewSettings) then
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
  Cmd: TReportSnapshotCommand;
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
        try
          AfterJSON := TReportSerializer.SaveToJSON(StagedReport);
        finally
          StagedReport.Free;
          StagedReport := nil;
        end;

        if BeforeJSON <> AfterJSON then
        begin
          Cmd := TReportSnapshotCommand.Create(FDesigner, BeforeJSON, AfterJSON);
          FDesigner.ExecuteUndoCommand(Cmd);
        end;
      end;
    end;
  finally
    Frm.Free;
  end;
end;

procedure TfrmMain.mnuReportPropsClick(Sender: TObject);
var
  Frm: TfrmReportProperties;
  InitialTitle: string;
  InitialAuthor: string;
begin
  Frm := TfrmReportProperties.Create(Application);
  try
    InitialTitle := FDesigner.Report.Title;
    InitialAuthor := FDesigner.Report.Author;
    if FReportMetadataDirty then
    begin
      InitialTitle := edtReportTitle.Text;
      InitialAuthor := edtReportAuthor.Text;
    end;

    Frm.LoadValues(InitialTitle, InitialAuthor, FDesigner.Report.Description);
    if Frm.ShowModal = mrOk then
    begin
      CommitReportMetadataValues(
        Frm.ReportTitle,
        Frm.ReportAuthor,
        Frm.ReportDescription,
        True
      );
    end;
  finally
    Frm.Free;
  end;
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

procedure TfrmMain.mnuOpenSimpleTestReportClick(Sender: TObject);
begin
  OpenRegressionReport('01_simple_masterdata.vrt');
end;

procedure TfrmMain.mnuOpenGroupedTestReportClick(Sender: TObject);
begin
  OpenRegressionReport('03_grouped_report.vrt');
end;

procedure TfrmMain.mnuOpenCanGrowTestReportClick(Sender: TObject);
begin
  OpenRegressionReport('05_cangrow_remarks.vrt');
end;

procedure TfrmMain.mnuOpenBarcodeTestReportClick(Sender: TObject);
begin
  OpenRegressionReport('06_barcode_test.vrt');
end;

procedure TfrmMain.mnuOpenImagePathTestReportClick(Sender: TObject);
begin
  OpenRegressionReport('07_imagepath_test.vrt');
end;

procedure TfrmMain.mnuOpenExpressionUsageDemoClick(Sender: TObject);
begin
  OpenRegressionReport('22_expression_usage_demo.vrt');
end;

procedure TfrmMain.mnuOpenInvalidDataFieldDiagnosticsDemoClick(Sender: TObject);
begin
  OpenRegressionReport('23_invalid_datafield_diagnostics.vrt');
end;

procedure TfrmMain.mnuRunRegressionTestReportsClick(Sender: TObject);
begin
  RunRegressionTestReports;
end;

procedure TfrmMain.mnuRunRuntimeEventCallbackDemoClick(Sender: TObject);
begin
  RunRuntimeEventCallbackDemo;
end;

procedure TfrmMain.mnuKeyboardShortcutsClick(Sender: TObject);
begin
  ShowMessage(
    'File:' + sLineBreak +
    '- Ctrl+N = New Report' + sLineBreak +
    '- Ctrl+O = Open Report' + sLineBreak +
    '- Ctrl+S = Save Report' + sLineBreak + sLineBreak +
    'Canvas:' + sLineBreak +
    '- Delete = Delete selected object' + sLineBreak +
    '- Arrow Keys = Nudge selected object' + sLineBreak +
    '- Ctrl + Arrow = Move selected object by 1' + sLineBreak +
    '- Shift + Arrow = Resize selected object by 1' + sLineBreak +
    '- Ctrl + Shift + Arrow = Move selected object by grid size' + sLineBreak + sLineBreak +
    'Property Panel:' + sLineBreak +
    '- Ctrl+C = Copy selected text' + sLineBreak +
    '- Ctrl+X = Cut selected text' + sLineBreak +
    '- Ctrl+V = Paste text' + sLineBreak +
    '- Delete = Delete selected text/value' + sLineBreak +
    '- Arrow Keys = Edit/navigate property value' + sLineBreak + sLineBreak +
    'Notes:' + sLineBreak +
    '- Keyboard move/resize works when canvas has focus.' + sLineBreak +
    '- Property panel shortcuts work when editing a property value.'
  );
end;

procedure TfrmMain.mnuExpressionHelpClick(Sender: TObject);
begin
  ShowMessage(
    'Expression Help' + sLineBreak + sLineBreak +
    'Field token syntax:' + sLineBreak +
    '[FieldName]' + sLineBreak + sLineBreak +
    'Common examples:' + sLineBreak +
    '[Qty] * [Rate]' + sLineBreak +
    '[Amount] > 1000' + sLineBreak +
    '[GroupName] = ''Labels''' + sLineBreak +
    '[Qty] > 5' + sLineBreak +
    '[CustomerName] <> ' + QuotedStr('') + sLineBreak +
    '[RecNo]' + sLineBreak + sLineBreak +
    'Use expressions in:' + sLineBreak +
    'Expression' + sLineBreak +
    'PrintWhen' + sLineBreak +
    'BackgroundCondition' + sLineBreak +
    'FontColorCondition' + sLineBreak +
    'BorderColorCondition' + sLineBreak + sLineBreak +
    'Tips:' + sLineBreak +
    'Use the Expression Helper ellipsis button in the property panel.' + sLineBreak +
    'Use Preview to verify the result.' + sLineBreak +
    'Open Report -> Demo Reports -> Expression Usage Demo for live examples.'
  );
end;

{ =========================================================================== }
{  Designer events                                                             }
{ =========================================================================== }

procedure TfrmMain.DesignerSelectionChanged(Sender: TObject);
begin
  UpdatePropertyPanel;
  UpdateMenuState;
  SyncReportStructureSelection;
end;

procedure TfrmMain.DesignerModified(Sender: TObject);
begin
  FModified := True;
  RefreshReportStructure;
  UpdatePropertyPanel;
  UpdateTitleBar;
  UpdateMenuState;
  UpdateStatusBar;
  SyncReportStructureSelection;
end;

procedure TfrmMain.DesignerViewChanged(Sender: TObject);
begin
  UpdateZoomControls;
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
  FLoadingPropertyPanel := True;
  try
    Obj := CurrentPropertyTarget;
    TReportPropertyBridge.LoadObjectToGrid(Obj, PropEditor);
    PromoteImportantProperties(Obj);
    InsertVisualGroupRows(Obj);
    ConfigurePropertyEditors;
  finally
    FLoadingPropertyPanel := False;
  end;

  UpdatePropertyPanelHeader(Obj);
  UpdatePropertyPanelHintForRow(PropEditor.Row);
  SetPropertyPanelDirty(False);
end;

procedure TfrmMain.UpdatePropertyPanelHeader(AObj: TReportObject);
var
  SelCount: Integer;
  Band: TReportBand;
  ObjName: string;
begin
  SelCount := FDesigner.SelectedCount;
  if SelCount > 1 then
    lblSelectedProps.Caption := Format('Selected: %d Objects', [SelCount])
  else if Assigned(AObj) and (AObj is TReportBand) then
  begin
    Band := TReportBand(AObj);
    if Trim(Band.Name) <> '' then
      lblSelectedProps.Caption := 'Selected: ' + BandTypeName(Band.BandType) +
        ' Band (' + Band.Name + ')'
    else
      lblSelectedProps.Caption := 'Selected: ' + BandTypeName(Band.BandType) + ' Band';
  end
  else if Assigned(AObj) then
  begin
    ObjName := Trim(AObj.Name);
    if ObjName <> '' then
      lblSelectedProps.Caption := 'Selected: ' + AObj.ClassName + ' (' + ObjName + ')'
    else
      lblSelectedProps.Caption := 'Selected: ' + AObj.ClassName;
  end
  else
    lblSelectedProps.Caption := 'Selected: None';
end;

procedure TfrmMain.ConfigurePropertyEditors;
var
  I, J: Integer;
  KeyName, ValueText: string;
  Fields: TArray<string>;
  Obj: TReportObject;
  Ctx: TRttiContext;
  RttiType: TRttiType;
  RttiProp: TRttiProperty;
  TypeData: PTypeData;
  EnumValue: Integer;
begin
  Obj := CurrentPropertyTarget;
  Fields := FDesigner.GetFieldNames;
  Ctx := TRttiContext.Create;
  try
    if Assigned(Obj) then
      RttiType := Ctx.GetType(Obj.ClassType)
    else
      RttiType := nil;

    for I := 1 to PropEditor.RowCount - 1 do
    begin
      KeyName := PropEditor.Keys[I];
      ValueText := PropEditor.Values[KeyName];

      if IsVisualGroupRow(KeyName) then
        Continue;

      if SameText(KeyName, 'DataField') then
      begin
        PropEditor.ItemProps[KeyName].EditStyle := esPickList;
        PropEditor.ItemProps[KeyName].PickList.BeginUpdate;
        try
          PropEditor.ItemProps[KeyName].PickList.Clear;
          PropEditor.ItemProps[KeyName].PickList.Add('');
          for J := 0 to High(Fields) do
            PropEditor.ItemProps[KeyName].PickList.Add(Fields[J]);
        finally
          PropEditor.ItemProps[KeyName].PickList.EndUpdate;
        end;
      end
      else if IsBandEventScriptRowKey(KeyName) then
      begin
        PropEditor.ItemProps[KeyName].EditStyle := esEllipsis;
      end
      else if IsExpressionPropertyKey(KeyName) then
      begin
        PropEditor.ItemProps[KeyName].EditStyle := esEllipsis;
      end
      else if IsColorPropertyKey(KeyName) then
      begin
        PropEditor.ItemProps[KeyName].EditStyle := esEllipsis;
      end
      else if SameText(ValueText, 'True') or SameText(ValueText, 'False') then
      begin
        PropEditor.ItemProps[KeyName].EditStyle := esPickList;
        PropEditor.ItemProps[KeyName].PickList.BeginUpdate;
        try
          PropEditor.ItemProps[KeyName].PickList.Clear;
          PropEditor.ItemProps[KeyName].PickList.Add('True');
          PropEditor.ItemProps[KeyName].PickList.Add('False');
        finally
          PropEditor.ItemProps[KeyName].PickList.EndUpdate;
        end;
      end
      else if Assigned(RttiType) then
      begin
        RttiProp := RttiType.GetProperty(KeyName);
        if Assigned(RttiProp) and Assigned(RttiProp.PropertyType) and
           (RttiProp.PropertyType.TypeKind = tkEnumeration) then
        begin
          PropEditor.ItemProps[KeyName].EditStyle := esPickList;
          PropEditor.ItemProps[KeyName].PickList.BeginUpdate;
          try
            PropEditor.ItemProps[KeyName].PickList.Clear;
            TypeData := GetTypeData(RttiProp.PropertyType.Handle);
            if Assigned(TypeData) then
              for EnumValue := TypeData.MinValue to TypeData.MaxValue do
                PropEditor.ItemProps[KeyName].PickList.Add(
                  GetEnumName(RttiProp.PropertyType.Handle, EnumValue));
          finally
            PropEditor.ItemProps[KeyName].PickList.EndUpdate;
          end;
        end;
      end;
    end;
  finally
    Ctx.Free;
  end;
end;

procedure TfrmMain.ApplyPropertyPanel;
var
  Obj: TReportObject;
  I: Integer;
  KeyName: string;
  Ctx: TRttiContext;
  RttiType: TRttiType;
  Prop: TRttiProperty;
  PropNames: TArray<string>;
  ChangedNames: TArray<string>;
  OldValues: TArray<TValue>;
  NewValues: TArray<TValue>;
  OldByProp: TDictionary<string, TValue>;
  PropIndex: Integer;
begin
  if not FPropertyPanelDirty then
    Exit;

  Obj := CurrentPropertyTarget;
  if not Assigned(Obj) then Exit;

  OldByProp := TDictionary<string, TValue>.Create;
  try
    SetLength(PropNames, 0);
    Ctx := TRttiContext.Create;
    try
      RttiType := Ctx.GetType(Obj.ClassType);
      if Assigned(RttiType) then
      begin
        for I := 1 to PropEditor.RowCount - 1 do
        begin
          KeyName := PropEditor.Keys[I];
          if IsVisualGroupRow(KeyName) then
            Continue;
          if OldByProp.ContainsKey(KeyName) then
            Continue;

          Prop := RttiType.GetProperty(KeyName);
          if not Assigned(Prop) or not Prop.IsReadable or not Prop.IsWritable then
            Continue;

          OldByProp.Add(KeyName, Prop.GetValue(Obj));
          PropIndex := Length(PropNames);
          SetLength(PropNames, PropIndex + 1);
          PropNames[PropIndex] := KeyName;
        end;
      end;
    finally
      Ctx.Free;
    end;

    for I := PropEditor.RowCount - 1 downto 0 do
      if IsVisualGroupRow(PropEditor.Keys[I]) then
        PropEditor.Strings.Delete(I);
    TReportPropertyBridge.SaveGridToObject(Obj, PropEditor);

    if BuildChangedPropertyBatch(Obj, OldByProp, PropNames, ChangedNames, OldValues, NewValues) then
    begin
      var Cmd := TPropertyBatchChangeCommand.Create(Obj, ChangedNames, OldValues, NewValues);
      if not Assigned(FDesigner) then
        Cmd.Free;
      if Assigned(FDesigner) then
        FDesigner.ExecuteUndoCommand(Cmd);
    end;
    FDesigner.RebuildLayout;   // repaint with new property values
    FModified := True;
    UpdateTitleBar;
    // Keep the property list stable after Apply (same selected object, same rows).
    UpdatePropertyPanel;
    SetPropertyPanelDirty(False);
  finally
    OldByProp.Free;
  end;
end;

procedure TfrmMain.SetPropertyPanelDirty(AValue: Boolean);
begin
  FPropertyPanelDirty := AValue and (CurrentPropertyTarget <> nil);
  btnApplyProps.Enabled := FPropertyPanelDirty;
  if FPropertyPanelDirty then
  begin
    btnApplyProps.Caption := 'Apply *';
    btnApplyProps.Hint := 'Apply pending changes';
  end
  else
  begin
    btnApplyProps.Caption := 'Apply';
    btnApplyProps.Hint := 'Apply property changes';
  end;
end;

function TfrmMain.PropertyHintText(const AKey: string): string;
begin
  if SameText(AKey, 'Name') then
    Exit('Object name used by expressions and references')
  else if SameText(AKey, 'Left') or SameText(AKey, 'Top') or
          SameText(AKey, 'Width') or SameText(AKey, 'Height') then
    Exit('Object bounds in pixels on the designer')
  else if SameText(AKey, 'DataField') then
    Exit('Dataset field to bind this object to')
  else if SameText(AKey, 'Expression') then
    Exit('Expression evaluated at runtime for value/output')
  else if SameText(AKey, 'PrintWhen') then
    Exit('Condition that controls whether object/band prints')
  else if SameText(AKey, 'FontColor') then
    Exit('Text color')
  else if SameText(AKey, 'BackgroundColor') then
    Exit('Background fill color')
  else if SameText(AKey, 'BorderColor') then
    Exit('Border line color')
  else if SameText(AKey, 'DisplayFormat') then
    Exit('Formatting mask for numbers/dates/text')
  else if SameText(AKey, 'CanGrow') then
    Exit('Allow control height to increase for long content')
  else if SameText(AKey, 'CanShrink') then
    Exit('Allow control height to shrink when content is empty')
  else if SameText(AKey, 'GroupField') then
    Exit('Field used for grouping band sections')
  else if SameText(AKey, 'OnBeforePrint') then
    Exit('Persisted band script hook executed before the band prints. Different from runtime Delphi callbacks.')
  else if SameText(AKey, 'OnAfterPrint') then
    Exit('Persisted band script hook executed after the band prints. Different from runtime Delphi callbacks.');

  Result := '';
end;

procedure TfrmMain.UpdatePropertyPanelHintForRow(ARow: Integer);
var
  KeyName: string;
  HintText: string;
begin
  if (ARow <= 0) or (ARow >= PropEditor.RowCount) then
  begin
    if StatusBar1.Panels.Count > 1 then
      StatusBar1.Panels[1].Text := '';
    Exit;
  end;

  KeyName := Trim(PropEditor.Keys[ARow]);
  if IsVisualGroupRow(KeyName) then
    HintText := ''
  else
    HintText := PropertyHintText(KeyName);

  if (HintText = '') and (KeyName <> '') and not IsVisualGroupRow(KeyName) then
    HintText := KeyName;

  if StatusBar1.Panels.Count > 1 then
    StatusBar1.Panels[1].Text := HintText;
end;

function TfrmMain.SamePropertyValue(const AOld, ANew: TValue): Boolean;
var
  K: TTypeKind;
begin
  if AOld.IsEmpty and ANew.IsEmpty then
    Exit(True);
  if AOld.IsEmpty xor ANew.IsEmpty then
    Exit(False);

  if AOld.TypeInfo <> ANew.TypeInfo then
    Exit(False);

  K := AOld.Kind;
  case K of
    tkString, tkLString, tkWString, tkUString:
      Exit(AOld.AsString = ANew.AsString);
    tkChar, tkWChar:
      Exit(AOld.AsOrdinal = ANew.AsOrdinal);
    tkInteger, tkInt64, tkEnumeration, tkSet:
      Exit(AOld.AsOrdinal = ANew.AsOrdinal);
    tkFloat:
      Exit(SameValue(AOld.AsExtended, ANew.AsExtended, 1E-12));
    tkClass:
      Exit(AOld.AsObject = ANew.AsObject);
    tkMethod:
      Exit(AOld.GetReferenceToRawData = ANew.GetReferenceToRawData);
  else
    // Conservative fallback for unsupported types:
    // treat as changed unless definitely equal was proven above.
    Exit(False);
  end;
end;

function TfrmMain.BuildChangedPropertyBatch(
  AObj: TReportObject;
  const AOldByProp: TDictionary<string, TValue>;
  const APropNames: TArray<string>;
  out ChangedNames: TArray<string>;
  out OldValues: TArray<TValue>;
  out NewValues: TArray<TValue>): Boolean;
var
  Ctx: TRttiContext;
  RttiType: TRttiType;
  Prop: TRttiProperty;
  OldV, NewV: TValue;
  I, OutIdx: Integer;
begin
  SetLength(ChangedNames, 0);
  SetLength(OldValues, 0);
  SetLength(NewValues, 0);
  Result := False;
  if not Assigned(AObj) then
    Exit;

  Ctx := TRttiContext.Create;
  try
    RttiType := Ctx.GetType(AObj.ClassType);
    if not Assigned(RttiType) then
      Exit;

    for I := 0 to High(APropNames) do
    begin
      if not AOldByProp.TryGetValue(APropNames[I], OldV) then
        Continue;

      Prop := RttiType.GetProperty(APropNames[I]);
      if not Assigned(Prop) or not Prop.IsReadable then
        Continue;
      NewV := Prop.GetValue(AObj);

      if SamePropertyValue(OldV, NewV) then
        Continue;

      OutIdx := Length(ChangedNames);
      SetLength(ChangedNames, OutIdx + 1);
      SetLength(OldValues, OutIdx + 1);
      SetLength(NewValues, OutIdx + 1);
      ChangedNames[OutIdx] := APropNames[I];
      OldValues[OutIdx] := OldV;
      NewValues[OutIdx] := NewV;
    end;
  finally
    Ctx.Free;
  end;

  Result := Length(ChangedNames) > 0;
end;

function TfrmMain.IsControlWithinParent(AControl, AParent: TWinControl): Boolean;
begin
  Result := False;
  if not Assigned(AControl) or not Assigned(AParent) then
    Exit;

  while Assigned(AControl) do
  begin
    if AControl = AParent then
      Exit(True);
    AControl := AControl.Parent;
  end;
end;

function TfrmMain.IsTextEditingControlFocused: Boolean;
var
  FocusedCtrl: TWinControl;
begin
  FocusedCtrl := Screen.ActiveControl;
  if not Assigned(FocusedCtrl) then
    FocusedCtrl := ActiveControl;

  Result := False;
  if not Assigned(FocusedCtrl) then
    Exit;

  // Property panel (including TValueListEditor in-place editors) gets
  // normal text/clipboard semantics and must not trigger designer object ops.
  if IsControlWithinParent(FocusedCtrl, pnlProperties) then
    Exit(True);

  Result :=
    (FocusedCtrl is TCustomEdit) or
    (FocusedCtrl is TCustomComboBox);
end;

procedure TfrmMain.SendMessageToFocusedControl(AMsg: Cardinal);
var
  FocusedCtrl: TWinControl;
  FocusedWnd: HWND;
begin
  FocusedWnd := GetFocus;
  if FocusedWnd <> 0 then
  begin
    SendMessage(FocusedWnd, AMsg, 0, 0);
    Exit;
  end;

  FocusedCtrl := Screen.ActiveControl;
  if not Assigned(FocusedCtrl) then
    FocusedCtrl := ActiveControl;

  if Assigned(FocusedCtrl) and FocusedCtrl.HandleAllocated then
    SendMessage(FocusedCtrl.Handle, AMsg, 0, 0);
end;

procedure TfrmMain.SendDeleteToFocusedControl;
var
  FocusedCtrl: TWinControl;
  FocusedWnd: HWND;
begin
  FocusedWnd := GetFocus;
  if FocusedWnd <> 0 then
  begin
    SendMessage(FocusedWnd, WM_CLEAR, 0, 0);
    SendMessage(FocusedWnd, WM_KEYDOWN, VK_DELETE, 0);
    SendMessage(FocusedWnd, WM_KEYUP, VK_DELETE, 0);
    Exit;
  end;

  FocusedCtrl := Screen.ActiveControl;
  if not Assigned(FocusedCtrl) then
    FocusedCtrl := ActiveControl;

  if Assigned(FocusedCtrl) and FocusedCtrl.HandleAllocated then
  begin
    SendMessage(FocusedCtrl.Handle, WM_CLEAR, 0, 0);
    SendMessage(FocusedCtrl.Handle, WM_KEYDOWN, VK_DELETE, 0);
    SendMessage(FocusedCtrl.Handle, WM_KEYUP, VK_DELETE, 0);
  end;
end;

function TfrmMain.CurrentPropertyTarget: TReportObject;
var
  Ctx: TRttiContext;
  T: TRttiType;
  F: TRttiField;
  V: TValue;
begin
  Result := FDesigner.PrimarySelected;
  if Assigned(Result) then
    Exit;

  // Band clicks can set FActiveBand while selection is empty.
  Ctx := TRttiContext.Create;
  try
    T := Ctx.GetType(FDesigner.ClassType);
    if not Assigned(T) then
      Exit(nil);
    F := T.GetField('FActiveBand');
    if not Assigned(F) then
      Exit(nil);

    V := F.GetValue(FDesigner);
    if not V.IsEmpty and (V.AsObject is TReportObject) then
      Result := TReportObject(V.AsObject);
  finally
    Ctx.Free;
  end;
end;

function TfrmMain.SelectedObjectsSpanBands: Boolean;
var
  Ctx: TRttiContext;
  T: TRttiType;
  SelField, MapField: TRttiField;
  SelValue, MapValue: TValue;
  SelList: TList<TReportObject>;
  ObjBandMap: TDictionary<TReportObject, TReportBand>;
  Obj: TReportObject;
  Band, FirstBand: TReportBand;
  HasFirstBand: Boolean;
begin
  Result := False;
  if FDesigner.SelectedCount < 2 then
    Exit;

  Ctx := TRttiContext.Create;
  try
    T := Ctx.GetType(FDesigner.ClassType);
    if not Assigned(T) then
      Exit;

    SelField := T.GetField('FSelected');
    MapField := T.GetField('FObjectBandMap');
    if not Assigned(SelField) or not Assigned(MapField) then
      Exit;

    SelValue := SelField.GetValue(FDesigner);
    MapValue := MapField.GetValue(FDesigner);
    if SelValue.IsEmpty or MapValue.IsEmpty then
      Exit;

    SelList := TList<TReportObject>(SelValue.AsObject);
    ObjBandMap := TDictionary<TReportObject, TReportBand>(MapValue.AsObject);
    if not Assigned(SelList) or not Assigned(ObjBandMap) then
      Exit;

    HasFirstBand := False;
    for Obj in SelList do
    begin
      if not ObjBandMap.TryGetValue(Obj, Band) then
        Band := nil;

      if not HasFirstBand then
      begin
        FirstBand := Band;
        HasFirstBand := True;
      end
      else if FirstBand <> Band then
        Exit(True);
    end;
  finally
    Ctx.Free;
  end;
end;

function TfrmMain.ConfirmMixedBandVerticalLayout: Boolean;
begin
  if not SelectedObjectsSpanBands then
    Exit(True);

  Result :=
    MessageDlg(
      'Selected objects are in different bands. Vertical layout uses local band coordinates and may look unexpected. Continue?',
      mtWarning, [mbYes, mbNo], 0) = mrYes;
end;

procedure TfrmMain.btnApplyPropsClick(Sender: TObject);
begin
  ApplyPropertyPanel;
end;

procedure TfrmMain.PropEditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
const
  NavKeys = [VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT, VK_HOME, VK_END, VK_PRIOR, VK_NEXT, VK_TAB];
begin
  if (PropEditor.Row > 0) and IsVisualGroupRow(PropEditor.Keys[PropEditor.Row]) then
  begin
    if not (Key in NavKeys) then
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
var
  KeyName: string;
begin
  if FLoadingPropertyPanel then
    Exit;

  if (ARow <= 0) or (ARow >= PropEditor.RowCount) then
    Exit;

  KeyName := Trim(PropEditor.Keys[ARow]);
  if IsVisualGroupRow(KeyName) then
    Exit;

  SetPropertyPanelDirty(True);
  UpdatePropertyPanelHintForRow(ARow);
end;

procedure TfrmMain.PropEditorDblClick(Sender: TObject);
begin
  if (PropEditor.Row < 0) or (PropEditor.Row >= PropEditor.RowCount) then
    Exit;

  EditFontPropertyRow(PropEditor.Row);
end;

procedure TfrmMain.PropEditorEditButtonClick(Sender: TObject);
begin
  if EditBandEventScriptRow(PropEditor.Row) then
    Exit;
  if EditExpressionPropertyRow(PropEditor.Row) then
    Exit;
  EditColorPropertyRow(PropEditor.Row);
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
  CheckListBox1.Items.BeginUpdate;
  try
    CheckListBox1.Items.Clear;
    CheckListBox1.Items.Add('Grid');
    CheckListBox1.Items.Add('Snap');
    CheckListBox1.Items.Add('Ruler');
    CheckListBox1.Items.Add('Margin');
  finally
    CheckListBox1.Items.EndUpdate;
  end;
  CheckListBox1.Hint := 'Quick view toggles: Grid, Snap, Ruler, Margin';
  CheckListBox1.ShowHint := True;
  CheckListBox1.OnClickCheck := CheckListBox1ClickCheck;
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
        'Selected: ' + Obj.ClassName +
        ' | X=' + IntToStr(Obj.Bounds.Left) +
        ' Y=' + IntToStr(Obj.Bounds.Top) +
        ' W=' + IntToStr(Obj.Bounds.Width) +
        ' H=' + IntToStr(Obj.Bounds.Height)
    else
      StatusBar1.Panels[0].Text := '1 object selected';
  end
  else
    StatusBar1.Panels[0].Text :=
      IntToStr(SelCount) + ' objects selected | Reference: last selected';

  if StatusBar1.Panels.Count > 2 then
    StatusBar1.Panels[2].Text := 'Zoom: ' + IntToStr(FDesigner.Zoom) + '%';
end;

procedure TfrmMain.UpdateMenuState;
var
  HasSel: Boolean;
  Multi : Boolean;
  UndoName: string;
  RedoName: string;
begin
  HasSel := FDesigner.SelectedCount > 0;
  Multi  := FDesigner.SelectedCount >= 2;

  mnuUndo.Enabled    := FDesigner.CanUndo;
  mnuRedo.Enabled    := FDesigner.CanRedo;
  btnUndo.Enabled    := FDesigner.CanUndo;
  btnRedo.Enabled    := FDesigner.CanRedo;

  UndoName := Trim(FDesigner.NextUndoName);
  RedoName := Trim(FDesigner.NextRedoName);
  if FDesigner.CanUndo and (UndoName <> '') then
  begin
    mnuUndo.Caption := '&Undo ' + UndoName;
    btnUndo.Hint := 'Undo ' + UndoName;
  end
  else
  begin
    mnuUndo.Caption := '&Undo';
    btnUndo.Hint := 'Undo';
  end;
  if FDesigner.CanRedo and (RedoName <> '') then
  begin
    mnuRedo.Caption := '&Redo ' + RedoName;
    btnRedo.Hint := 'Redo ' + RedoName;
  end
  else
  begin
    mnuRedo.Caption := '&Redo';
    btnRedo.Hint := 'Redo';
  end;
  btnUndo.ShowHint := True;
  btnRedo.ShowHint := True;

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
  if CheckListBox1.Items.Count >= 4 then
  begin
    CheckListBox1.Checked[0] := FDesigner.ShowGrid;
    CheckListBox1.Checked[1] := FDesigner.SnapToGrid;
    CheckListBox1.Checked[2] := FDesigner.ShowRulers;
    CheckListBox1.Checked[3] := FDesigner.ShowMargins;
  end;

  UpdateStatusBar;
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

function TfrmMain.ShortNodePreview(const S: string; AMaxLen: Integer): string;
var
  Text: string;
begin
  Text := Trim(StringReplace(StringReplace(S, sLineBreak, ' ', [rfReplaceAll]),
    #10, ' ', [rfReplaceAll]));
  if Length(Text) > AMaxLen then
    Result := Copy(Text, 1, AMaxLen - 3) + '...'
  else
    Result := Text;
end;

function TfrmMain.StructureBandCaption(ABand: TReportBand): string;
var
  BaseCaption: string;
begin
  if not Assigned(ABand) then
    Exit('Band');

  case ABand.BandType of
    btReportTitle:   BaseCaption := 'Report Title Band';
    btPageHeader:    BaseCaption := 'Page Header Band';
    btPageFooter:    BaseCaption := 'Page Footer Band';
    btMasterData:    BaseCaption := 'Master Data Band';
    btGroupHeader:   BaseCaption := 'Group Header Band';
    btGroupFooter:   BaseCaption := 'Group Footer Band';
    btColumnHeader:  BaseCaption := 'Column Header Band';
    btDetail:        BaseCaption := 'Detail Band';
    btReportSummary: BaseCaption := 'Report Summary Band';
    btOverlay:       BaseCaption := 'Overlay Band';
  else
    BaseCaption := 'Band';
  end;

  if Trim(ABand.Name) <> '' then
    Result := BaseCaption + ': ' + ABand.Name
  else
    Result := BaseCaption;
end;

function TfrmMain.StructureObjectCaption(AObj: TReportObject): string;
  function NamedValue(const APrefix, AName, AValue, AWrapLeft, AWrapRight: string): string;
  begin
    if Trim(AName) <> '' then
    begin
      if Trim(AValue) <> '' then
        Result := APrefix + ': ' + AName + ' ' + AWrapLeft + AValue + AWrapRight
      else
        Result := APrefix + ': ' + AName;
    end
    else if Trim(AValue) <> '' then
      Result := APrefix + ': ' + AWrapLeft + AValue + AWrapRight
    else
      Result := APrefix;
  end;
var
  ObjName: string;
begin
  ObjName := Trim(AObj.Name);
  if AObj is TReportFieldObject then
    Result := NamedValue('Field', ObjName, TReportFieldObject(AObj).DataField, '[', ']')
  else if AObj is TReportMemoObject then
  begin
    if Trim(TReportMemoObject(AObj).DataField) <> '' then
      Result := NamedValue('Memo', ObjName, TReportMemoObject(AObj).DataField, '[', ']')
    else if Trim(TReportMemoObject(AObj).Text) <> '' then
      Result := NamedValue('Memo', ObjName, ShortNodePreview(TReportMemoObject(AObj).Text), '"', '"')
    else
      Result := NamedValue('Memo', ObjName, '', '', '');
  end
  else if AObj is TReportImageObject then
  begin
    if Trim(TReportImageObject(AObj).DataField) <> '' then
      Result := NamedValue('Image', ObjName, TReportImageObject(AObj).DataField, '[', ']')
    else
      Result := NamedValue('Image', ObjName, '', '', '');
  end
  else if AObj is TReportBarcodeObject then
  begin
    if Trim(TReportBarcodeObject(AObj).DataField) <> '' then
      Result := NamedValue('Barcode', ObjName, TReportBarcodeObject(AObj).DataField, '[', ']')
    else if Trim(TReportBarcodeObject(AObj).Value) <> '' then
      Result := NamedValue('Barcode', ObjName, ShortNodePreview(TReportBarcodeObject(AObj).Value), '"', '"')
    else
      Result := NamedValue('Barcode', ObjName, '', '', '');
  end
  else if AObj is TReportShapeObject then
    Result := NamedValue('Shape', ObjName,
      GetEnumName(TypeInfo(TReportShapeType), Ord(TReportShapeObject(AObj).ShapeType)), '[', ']')
  else if AObj is TReportLineObject then
    Result := NamedValue('Line', ObjName, '', '', '')
  else if AObj is TReportSubReportObject then
    Result := NamedValue('SubReport', ObjName, '', '', '')
  else if AObj is TReportTableObject then
    Result := NamedValue('Table', ObjName, '', '', '')
  else if AObj is TReportTextObject then
  begin
    if Trim(TReportTextObject(AObj).Text) <> '' then
      Result := NamedValue('Text', ObjName, ShortNodePreview(TReportTextObject(AObj).Text), '"', '"')
    else
      Result := NamedValue('Text', ObjName, '', '', '');
  end
  else
    Result := NamedValue(TReportObjectClass(AObj.ClassType).DisplayName, ObjName, '', '', '');
end;

function TfrmMain.StructureObjectIconIndex(AObj: TReportObject): Integer;
begin
  if AObj is TReportBand then
    Exit(TREE_ICON_BAND);

  if AObj is TReportFieldObject then
    Exit(TREE_ICON_FIELD);
  if AObj is TReportMemoObject then
    Exit(TREE_ICON_MEMO);
  if AObj is TReportImageObject then
    Exit(TREE_ICON_IMAGE);
  if AObj is TReportBarcodeObject then
    Exit(TREE_ICON_BARCODE);
  if AObj is TReportShapeObject then
    Exit(TREE_ICON_SHAPE);
  if AObj is TReportLineObject then
    Exit(TREE_ICON_LINE);
  if AObj is TReportSubReportObject then
    Exit(TREE_ICON_SUBREPORT);
  if AObj is TReportTableObject then
    Exit(TREE_ICON_TABLE);
  if AObj is TReportTextObject then
    Exit(TREE_ICON_TEXT);

  Result := TREE_ICON_REPORT;
end;

function TfrmMain.FindStructureNodeByData(AData: Pointer): TTreeNode;
begin
  Result := nil;
  if not Assigned(FTreeStructure) then
    Exit;

  Result := FTreeStructure.Items.GetFirstNode;
  while Assigned(Result) do
  begin
    if Result.Data = AData then
      Exit;
    Result := Result.GetNext;
  end;
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
begin
  if not Assigned(FTreeStructure) then
    Exit;

  Node := FTreeStructure.Selected;
  FStructureTreeDeleteItem.Enabled := Assigned(Node) and Assigned(Node.Data);
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
  if not Assigned(FTreeStructure) or not Assigned(FDesigner) or not Assigned(FDesigner.Report) then
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

function TfrmMain.VariableTokenForNode(ANode: TTreeNode; out AToken: string;
  out ASupported: Boolean): Boolean;
var
  S: string;
begin
  Result := False;
  AToken := '';
  ASupported := False;
  if not Assigned(ANode) then
    Exit;

  S := Trim(ANode.Text);
  if Pos('(', S) > 0 then
    S := Trim(Copy(S, 1, Pos('(', S) - 1));

  if SameText(S, 'Date') then
    AToken := '[Date]'
  else if SameText(S, 'Time') then
    AToken := '[Time]'
  else if SameText(S, 'Page') then
    AToken := '[Page]'
  else if SameText(S, 'Page#') then
    AToken := '[Page#]'
  else if SameText(S, 'TotalPages') then
    AToken := '[TotalPages]'
  else if SameText(S, 'TotalPages#') then
    AToken := '[TotalPages#]'
  else if SameText(S, 'Line') then
    AToken := '[Line]'
  else if SameText(S, 'Line#') then
    AToken := '[Line#]';

  ASupported := AToken <> '';
  Result := ASupported or SameText(S, 'CopyName#') or SameText(S, 'TableRow') or SameText(S, 'TableColumn');
end;

function TfrmMain.CanInsertVariableIntoCurrentProperty(out AKey: string): Boolean;
begin
  Result := False;
  AKey := '';
  if (PropEditor.Row <= 0) or (PropEditor.Row >= PropEditor.RowCount) then
    Exit;

  AKey := Trim(PropEditor.Keys[PropEditor.Row]);
  if IsVisualGroupRow(AKey) then
    Exit;

  Result :=
    SameText(AKey, 'Text') or
    SameText(AKey, 'Expression') or
    SameText(AKey, 'PrintWhen') or
    SameText(AKey, 'BackgroundCondition') or
    SameText(AKey, 'FontColorCondition') or
    SameText(AKey, 'BorderColorCondition');
end;

procedure TfrmMain.InsertVariableToken(const AToken: string);
var
  KeyName: string;
  CurV: string;
begin
  if CanInsertVariableIntoCurrentProperty(KeyName) then
  begin
    CurV := Trim(PropEditor.Values[KeyName]);
    if CurV = '' then
      PropEditor.Values[KeyName] := AToken
    else if (Length(CurV) > 0) and (CurV[Length(CurV)] = ' ') then
      PropEditor.Values[KeyName] := CurV + AToken
    else
      PropEditor.Values[KeyName] := CurV + ' ' + AToken;

    SetPropertyPanelDirty(True);
    UpdatePropertyPanelHintForRow(PropEditor.Row);
    Exit;
  end;

  Clipboard.AsText := AToken;
  ShowMessage('No compatible property row is active. Token copied to clipboard: ' + AToken);
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
var
  I: Integer;
begin
  for I := 1 to PropEditor.RowCount - 1 do
    if SameText(PropEditor.Keys[I], 'Font') then
    begin
      PropEditor.Row := I;
      Break;
    end;
  PropEditorDblClick(PropEditor);
end;

function TfrmMain.IsVisualGroupRow(const AKey: string): Boolean;
begin
  Result := (Length(AKey) >= 3) and (AKey[1] = '[') and (AKey[Length(AKey)] = ']');
end;

function TfrmMain.IsFontDialogRowKey(const AKey: string): Boolean;
begin
  Result :=
    SameText(AKey, 'Font') or
    SameText(AKey, 'FontName') or
    SameText(AKey, 'FontSize') or
    SameText(AKey, 'FontBold') or
    SameText(AKey, 'FontItalic') or
    SameText(AKey, 'FontColor');
end;

function TfrmMain.IsColorPropertyKey(const AKey: string): Boolean;
begin
  Result :=
    SameText(AKey, 'FontColor') or
    SameText(AKey, 'Background') or
    SameText(AKey, 'BorderColor') or
    SameText(AKey, 'BackColor') or
    SameText(AKey, 'BackgroundOnTrue') or
    SameText(AKey, 'BorderColorOnTrue') or
    SameText(AKey, 'FontColorOnTrue');
end;

function TfrmMain.IsExpressionPropertyKey(const AKey: string): Boolean;
begin
  Result :=
    SameText(AKey, 'Expression') or
    SameText(AKey, 'PrintWhen') or
    SameText(AKey, 'FontColorCondition') or
    SameText(AKey, 'BackgroundCondition') or
    SameText(AKey, 'BorderColorCondition');
end;

function TfrmMain.IsBandEventScriptRowKey(const AKey: string): Boolean;
begin
  Result :=
    SameText(AKey, 'OnBeforePrint') or
    SameText(AKey, 'OnAfterPrint');
end;

function TfrmMain.PromptExpressionHelper(const AInitialValue: string;
  const AFields: TArray<string>; const APropertyKey: string;
  out AEditedValue: string): Boolean;
var
  Dlg: TForm;
  PnlTop, PnlBottom, PnlLeft, PnlRight, PnlCenter, PnlOperators, PnlTemplates: TPanel;
  LblFields, LblExamples, LblRecent: TLabel;
  BtnInsert, BtnCheck, BtnOK, BtnCancel, Btn: TButton;
  I: Integer;
  ExampleItems: array[0..7] of string;
  RecentItems: TStringList;

  procedure AddQuickButton(AParent: TWinControl; const ACaption, AInsertText: string;
    ALeft, ATop, AWidth: Integer; AOnClick: TNotifyEvent; ATag: NativeInt = 0);
  begin
    Btn := TButton.Create(Dlg);
    Btn.Parent := AParent;
    Btn.Caption := ACaption;
    Btn.Left := ALeft;
    Btn.Top := ATop;
    Btn.Width := AWidth;
    Btn.Height := 24;
    Btn.Hint := AInsertText;
    Btn.Tag := ATag;
    Btn.OnClick := AOnClick;
  end;
begin
  Result := False;
  AEditedValue := AInitialValue;

  Dlg := TForm.Create(Self);
  try
    Dlg.Caption := 'Expression Helper';
    Dlg.Position := poScreenCenter;
    Dlg.BorderStyle := bsDialog;
    Dlg.BorderIcons := [biSystemMenu];
    Dlg.ClientWidth := 760;
    Dlg.ClientHeight := 430;

    PnlTop := TPanel.Create(Dlg);
    PnlTop.Parent := Dlg;
    PnlTop.Align := alClient;
    PnlTop.BevelOuter := bvNone;

    PnlBottom := TPanel.Create(Dlg);
    PnlBottom.Parent := Dlg;
    PnlBottom.Align := alBottom;
    PnlBottom.Height := 44;
    PnlBottom.BevelOuter := bvNone;

    PnlLeft := TPanel.Create(Dlg);
    PnlLeft.Parent := PnlTop;
    PnlLeft.Align := alLeft;
    PnlLeft.Width := 210;
    PnlLeft.BevelOuter := bvNone;

    PnlRight := TPanel.Create(Dlg);
    PnlRight.Parent := PnlTop;
    PnlRight.Align := alRight;
    PnlRight.Width := 240;
    PnlRight.BevelOuter := bvNone;

    PnlCenter := TPanel.Create(Dlg);
    PnlCenter.Parent := PnlTop;
    PnlCenter.Align := alClient;
    PnlCenter.BevelOuter := bvNone;

    LblFields := TLabel.Create(Dlg);
    LblFields.Parent := PnlLeft;
    LblFields.Align := alTop;
    LblFields.Caption := 'Available Fields';
    LblFields.Height := 20;
    LblFields.Font.Style := [fsBold];

    FExprHelperFields := TListBox.Create(Dlg);
    FExprHelperFields.Parent := PnlLeft;
    FExprHelperFields.Align := alClient;
    for I := 0 to High(AFields) do
      FExprHelperFields.Items.Add(AFields[I]);

    BtnInsert := TButton.Create(Dlg);
    BtnInsert.Parent := PnlLeft;
    BtnInsert.Align := alBottom;
    BtnInsert.Caption := 'Insert Field';
    BtnInsert.Height := 30;
    BtnInsert.OnClick := ExpressionHelperInsertField;
    FExprHelperFields.OnDblClick := ExpressionHelperFieldDblClick;

    LblExamples := TLabel.Create(Dlg);
    LblExamples.Parent := PnlRight;
    LblExamples.Align := alTop;
    LblExamples.Caption := 'Examples';
    LblExamples.Height := 20;
    LblExamples.Font.Style := [fsBold];

    FExprHelperExamples := TListBox.Create(Dlg);
    FExprHelperExamples.Parent := PnlRight;
    FExprHelperExamples.Align := alBottom;
    FExprHelperExamples.Height := 150;

    ExampleItems[0] := '[Qty] * [Rate]';
    ExampleItems[1] := '[Amount] > 1000';
    ExampleItems[2] := '[GroupName] = ''Labels''';
    ExampleItems[3] := '[Qty] > 5';
    ExampleItems[4] := '[CustomerName] <> ' + QuotedStr('');
    ExampleItems[5] := '[RecNo]';
    ExampleItems[6] := '1=1';
    ExampleItems[7] := '1=0';
    for I := Low(ExampleItems) to High(ExampleItems) do
      FExprHelperExamples.Items.Add(ExampleItems[I]);

    // Double-click replaces the entire expression for faster template usage.
    FExprHelperExamples.OnDblClick := ExpressionHelperExampleDblClick;

    LblRecent := TLabel.Create(Dlg);
    LblRecent.Parent := PnlRight;
    LblRecent.Align := alTop;
    LblRecent.Caption := 'Recent';
    LblRecent.Height := 20;
    LblRecent.Font.Style := [fsBold];

    FExprHelperRecent := TListBox.Create(Dlg);
    FExprHelperRecent.Parent := PnlRight;
    FExprHelperRecent.Align := alClient;
    FExprHelperRecent.OnDblClick := ExpressionHelperRecentDblClick;

    RecentItems := ExpressionHelperRecentList(APropertyKey, False);
    if Assigned(RecentItems) and (RecentItems.Count > 0) then
      for I := 0 to RecentItems.Count - 1 do
        FExprHelperRecent.Items.Add(RecentItems[I]);
    if FExprHelperRecent.Items.Count = 0 then
      FExprHelperRecent.Items.Add('No recent expressions (session only)');

    PnlOperators := TPanel.Create(Dlg);
    PnlOperators.Parent := PnlCenter;
    PnlOperators.Align := alTop;
    PnlOperators.Height := 56;
    PnlOperators.BevelOuter := bvNone;

    AddQuickButton(PnlOperators, '+',  ' + ', 8,   6, 42, ExpressionHelperOperatorClick);
    AddQuickButton(PnlOperators, '-',  ' - ', 54,  6, 42, ExpressionHelperOperatorClick);
    AddQuickButton(PnlOperators, '*',  ' * ', 100, 6, 42, ExpressionHelperOperatorClick);
    AddQuickButton(PnlOperators, '/',  ' / ', 146, 6, 42, ExpressionHelperOperatorClick);
    AddQuickButton(PnlOperators, '=',  ' = ', 192, 6, 42, ExpressionHelperOperatorClick);
    AddQuickButton(PnlOperators, '<>', ' <> ',238, 6, 42, ExpressionHelperOperatorClick);
    AddQuickButton(PnlOperators, '>',  ' > ', 284, 6, 42, ExpressionHelperOperatorClick);
    AddQuickButton(PnlOperators, '>=', ' >= ',330, 6, 42, ExpressionHelperOperatorClick);
    AddQuickButton(PnlOperators, '<',  ' < ', 376, 6, 42, ExpressionHelperOperatorClick);
    AddQuickButton(PnlOperators, '<=', ' <= ',422, 6, 42, ExpressionHelperOperatorClick);
    AddQuickButton(PnlOperators, '(',  '(',   468, 6, 36, ExpressionHelperOperatorClick);
    AddQuickButton(PnlOperators, ')',  ')',   508, 6, 36, ExpressionHelperOperatorClick);
    AddQuickButton(PnlOperators, QuotedStr(''), QuotedStr(''), 548, 6, 44, ExpressionHelperOperatorClick);

    PnlTemplates := TPanel.Create(Dlg);
    PnlTemplates.Parent := PnlCenter;
    PnlTemplates.Align := alTop;
    PnlTemplates.Height := 32;
    PnlTemplates.BevelOuter := bvNone;

    AddQuickButton(PnlTemplates, '[Field] > 0', '', 8, 4, 92, ExpressionHelperTemplateClick, 1);
    Btn.ShowHint := True;
    Btn.Hint := 'Uses selected field from Available Fields';
    AddQuickButton(PnlTemplates, '[Field] = ''Text''', '', 104, 4, 108, ExpressionHelperTemplateClick, 2);
    Btn.ShowHint := True;
    Btn.Hint := 'Uses selected field from Available Fields';
    AddQuickButton(PnlTemplates, '[Field] <> ' + QuotedStr(''), '', 216, 4, 94, ExpressionHelperTemplateClick, 3);
    Btn.ShowHint := True;
    Btn.Hint := 'Uses selected field from Available Fields';
    AddQuickButton(PnlTemplates, '[Amount] > 1000', '', 314, 4, 116, ExpressionHelperTemplateClick, 4);
    Btn.ShowHint := True;
    Btn.Hint := 'Inserts fixed example';
    AddQuickButton(PnlTemplates, '[Qty] > 5', '', 434, 4, 92, ExpressionHelperTemplateClick, 5);
    Btn.ShowHint := True;
    Btn.Hint := 'Inserts fixed example';

    FExprHelperMemo := TMemo.Create(Dlg);
    FExprHelperMemo.Parent := PnlCenter;
    FExprHelperMemo.Align := alClient;
    FExprHelperMemo.ScrollBars := ssBoth;
    FExprHelperMemo.WordWrap := False;
    FExprHelperMemo.Lines.Text := AInitialValue;

    BtnOK := TButton.Create(Dlg);
    BtnOK.Parent := PnlBottom;
    BtnOK.Caption := 'OK';
    BtnOK.ModalResult := mrOk;
    BtnOK.Left := Dlg.ClientWidth - 180;
    BtnOK.Top := 8;
    BtnOK.Width := 80;
    BtnOK.Anchors := [akRight, akBottom];

    BtnCancel := TButton.Create(Dlg);
    BtnCancel.Parent := PnlBottom;
    BtnCancel.Caption := 'Cancel';
    BtnCancel.ModalResult := mrCancel;
    BtnCancel.Left := Dlg.ClientWidth - 92;
    BtnCancel.Top := 8;
    BtnCancel.Width := 80;
    BtnCancel.Anchors := [akRight, akBottom];

    BtnCheck := TButton.Create(Dlg);
    BtnCheck.Parent := PnlBottom;
    BtnCheck.Caption := 'Check';
    BtnCheck.Left := 8;
    BtnCheck.Top := 8;
    BtnCheck.Width := 80;
    BtnCheck.Anchors := [akLeft, akBottom];
    BtnCheck.OnClick := ExpressionHelperCheckClick;

    Dlg.ActiveControl := FExprHelperMemo;
    if Dlg.ShowModal = mrOk then
    begin
      AEditedValue := FExprHelperMemo.Lines.Text;
      ExpressionHelperAddRecent(APropertyKey, AEditedValue);
      Result := True;
    end;
  finally
    FExprHelperMemo := nil;
    FExprHelperFields := nil;
    FExprHelperExamples := nil;
    FExprHelperRecent := nil;
    Dlg.Free;
  end;
end;

function TfrmMain.EditExpressionPropertyRow(ARow: Integer): Boolean;
var
  KeyName: string;
  CurrentValue: string;
  EditedValue: string;
begin
  Result := False;
  if (ARow <= 0) or (ARow >= PropEditor.RowCount) then
    Exit;

  KeyName := Trim(PropEditor.Keys[ARow]);
  if IsVisualGroupRow(KeyName) or not IsExpressionPropertyKey(KeyName) then
    Exit;

  CurrentValue := PropEditor.Values[KeyName];
  if not PromptExpressionHelper(CurrentValue, FDesigner.GetFieldNames, KeyName, EditedValue) then
    Exit;

  PropEditor.Values[KeyName] := EditedValue;
  SetPropertyPanelDirty(True);
  ApplyPropertyPanel;
  Result := True;
end;

function TfrmMain.EditBandEventScriptRow(ARow: Integer): Boolean;
var
  KeyName: string;
  CurrentValue: string;
  Dlg: TForm;
  PnlBottom: TPanel;
  LblHelp: TLabel;
  LblTip: TLabel;
  LblStats: TLabel;
  LblSnippets: TLabel;
  CboSnippets: TComboBox;
  BtnInsertSnippet: TButton;
  MemoScript: TMemo;
  BtnOK: TButton;
  BtnCancel: TButton;
  Helper: TBandEventScriptDialogHelper;
begin
  Result := False;
  if (ARow <= 0) or (ARow >= PropEditor.RowCount) then
    Exit;

  KeyName := Trim(PropEditor.Keys[ARow]);
  if IsVisualGroupRow(KeyName) or not IsBandEventScriptRowKey(KeyName) then
    Exit;

  CurrentValue := PropEditor.Values[KeyName];

  Dlg := TForm.Create(Self);
  Helper := nil;
  try
    Dlg.Caption := 'Band Event Script';
    Dlg.Position := poScreenCenter;
    Dlg.BorderStyle := bsDialog;
    Dlg.BorderIcons := [biSystemMenu];
    Dlg.KeyPreview := True;
    Dlg.ClientWidth := 760;
    Dlg.ClientHeight := 460;

    LblHelp := TLabel.Create(Dlg);
    LblHelp.Parent := Dlg;
    LblHelp.Left := 12;
    LblHelp.Top := 10;
    LblHelp.Width := Dlg.ClientWidth - 24;
    LblHelp.Height := 34;
    LblHelp.WordWrap := True;
    LblHelp.Caption :=
      'This text is stored with the band and passed to the host script callback.' + sLineBreak +
      'Runtime Delphi callbacks are separate and are not stored in the report.';

    LblTip := TLabel.Create(Dlg);
    LblTip.Parent := Dlg;
    LblTip.Left := 12;
    LblTip.Top := 46;
    LblTip.Width := Dlg.ClientWidth - 24;
    LblTip.Caption := 'Tip: Ctrl+Enter to save';

    LblSnippets := TLabel.Create(Dlg);
    LblSnippets.Parent := Dlg;
    LblSnippets.Left := 12;
    LblSnippets.Top := 86;
    LblSnippets.Caption := 'Host-script example snippets (text only):';

    CboSnippets := TComboBox.Create(Dlg);
    CboSnippets.Parent := Dlg;
    CboSnippets.Left := 12;
    CboSnippets.Top := 104;
    CboSnippets.Width := Dlg.ClientWidth - 118;
    CboSnippets.Style := csDropDownList;
    CboSnippets.Anchors := [akLeft, akTop, akRight];
    CboSnippets.Items.Add('Comment/Header block');
    CboSnippets.Items.Add('Set visibility placeholder');
    CboSnippets.Items.Add('Set variable placeholder');
    CboSnippets.Items.Add('If/Then pseudo-template');
    CboSnippets.Items.Add('Host callback note');
    CboSnippets.ItemIndex := 0;

    BtnInsertSnippet := TButton.Create(Dlg);
    BtnInsertSnippet.Parent := Dlg;
    BtnInsertSnippet.Caption := 'Insert';
    BtnInsertSnippet.Left := Dlg.ClientWidth - 98;
    BtnInsertSnippet.Top := 102;
    BtnInsertSnippet.Width := 86;
    BtnInsertSnippet.Height := 25;
    BtnInsertSnippet.Anchors := [akTop, akRight];

    MemoScript := TMemo.Create(Dlg);
    MemoScript.Parent := Dlg;
    MemoScript.Left := 12;
    MemoScript.Top := 136;
    MemoScript.Width := Dlg.ClientWidth - 24;
    MemoScript.Height := Dlg.ClientHeight - 172;
    MemoScript.Anchors := [akLeft, akTop, akRight, akBottom];
    MemoScript.ScrollBars := ssBoth;
    MemoScript.WordWrap := False;
    MemoScript.Font.Name := 'Consolas';
    MemoScript.Font.Size := 10;
    MemoScript.Lines.Text := CurrentValue;

    PnlBottom := TPanel.Create(Dlg);
    PnlBottom.Parent := Dlg;
    PnlBottom.Align := alBottom;
    PnlBottom.Height := 44;
    PnlBottom.BevelOuter := bvNone;

    LblStats := TLabel.Create(Dlg);
    LblStats.Parent := PnlBottom;
    LblStats.Left := 12;
    LblStats.Top := 14;
    LblStats.Caption := 'Lines: 0 | Chars: 0';

    BtnOK := TButton.Create(Dlg);
    BtnOK.Parent := PnlBottom;
    BtnOK.Caption := 'OK';
    BtnOK.ModalResult := mrOk;
    BtnOK.Left := Dlg.ClientWidth - 180;
    BtnOK.Top := 8;
    BtnOK.Width := 80;
    BtnOK.Anchors := [akRight, akBottom];

    BtnCancel := TButton.Create(Dlg);
    BtnCancel.Parent := PnlBottom;
    BtnCancel.Caption := 'Cancel';
    BtnCancel.ModalResult := mrCancel;
    BtnCancel.Left := Dlg.ClientWidth - 92;
    BtnCancel.Top := 8;
    BtnCancel.Width := 80;
    BtnCancel.Anchors := [akRight, akBottom];

    Helper := TBandEventScriptDialogHelper.Create(Dlg, MemoScript, LblStats, CboSnippets);
    MemoScript.OnChange := Helper.MemoChange;
    Dlg.OnKeyDown := Helper.FormKeyDown;
    BtnInsertSnippet.OnClick := Helper.InsertSnippetClick;
    Helper.UpdateStats;

    Dlg.ActiveControl := MemoScript;
    if Dlg.ShowModal <> mrOk then
      Exit;

    if PropEditor.Values[KeyName] <> MemoScript.Lines.Text then
    begin
      PropEditor.Values[KeyName] := MemoScript.Lines.Text;
      SetPropertyPanelDirty(True);
      UpdatePropertyPanelHintForRow(ARow);
    end;
    Result := True;
  finally
    Helper.Free;
    Dlg.Free;
  end;
end;

procedure TfrmMain.ExpressionHelperInsertField(Sender: TObject);
var
  FieldName: string;
begin
  if not Assigned(FExprHelperFields) or not Assigned(FExprHelperMemo) then
    Exit;
  if FExprHelperFields.ItemIndex < 0 then
    Exit;

  FieldName := Trim(FExprHelperFields.Items[FExprHelperFields.ItemIndex]);
  if FieldName = '' then
    Exit;

  FExprHelperMemo.SelText := '[' + FieldName + ']';
  FExprHelperMemo.SetFocus;
end;

procedure TfrmMain.ExpressionHelperInsertText(const AText: string);
begin
  if not Assigned(FExprHelperMemo) then
    Exit;
  FExprHelperMemo.SelText := AText;
  FExprHelperMemo.SetFocus;
end;

function TfrmMain.ExpressionHelperTryGetSelectedField(out AFieldName: string): Boolean;
begin
  AFieldName := '';
  Result := Assigned(FExprHelperFields) and (FExprHelperFields.ItemIndex >= 0);
  if not Result then
    Exit;

  AFieldName := Trim(FExprHelperFields.Items[FExprHelperFields.ItemIndex]);
  Result := AFieldName <> '';
end;

procedure TfrmMain.ExpressionHelperOperatorClick(Sender: TObject);
var
  InsertText: string;
begin
  if not (Sender is TButton) then
    Exit;
  InsertText := TButton(Sender).Hint;
  ExpressionHelperInsertText(InsertText);
end;

procedure TfrmMain.ExpressionHelperTemplateClick(Sender: TObject);
var
  FieldName: string;
  InsertText: string;
begin
  if not (Sender is TButton) then
    Exit;

  InsertText := '';
  case TButton(Sender).Tag of
    1:
      begin
        if not ExpressionHelperTryGetSelectedField(FieldName) then
        begin
          ShowMessage('Select a field first.');
          Exit;
        end;
        InsertText := '[' + FieldName + '] > 0';
      end;
    2:
      begin
        if not ExpressionHelperTryGetSelectedField(FieldName) then
        begin
          ShowMessage('Select a field first.');
          Exit;
        end;
        InsertText := '[' + FieldName + '] = ''Text''';
      end;
    3:
      begin
        if not ExpressionHelperTryGetSelectedField(FieldName) then
        begin
          ShowMessage('Select a field first.');
          Exit;
        end;
        InsertText := '[' + FieldName + '] <> ' + QuotedStr('');
      end;
    4: InsertText := '[Amount] > 1000';
    5: InsertText := '[Qty] > 5';
  end;

  if InsertText <> '' then
    ExpressionHelperInsertText(InsertText);
end;

procedure TfrmMain.ExpressionHelperCheckClick(Sender: TObject);
var
  ExprText: string;
  EvalResult: Variant;
  Ctx: TExpressionContext;
begin
  if not Assigned(FExprHelperMemo) then
    Exit;

  ExprText := Trim(FExprHelperMemo.Lines.Text);
  if ExprText = '' then
  begin
    ShowMessage('Nothing to check.');
    Exit;
  end;

  Ctx := Default(TExpressionContext);
  if Assigned(FDataSource1) then
    Ctx.DataSet := FDataSource1.DataSet;
  Ctx.PageNumber := 1;
  Ctx.TotalPages := 1;
  Ctx.ReportTitle := edtReportTitle.Text;
  Ctx.ReportDate := Now;

  try
    EvalResult := TReportExpression.Evaluate(ExprText, Ctx);

    ShowMessage(
      'Check OK.' + sLineBreak +
      'Result: ' + VarToStr(EvalResult) + sLineBreak + sLineBreak +
      'Check uses the current dataset row and runtime fallback rules.'
    );
  except
    on E: Exception do
      ShowMessage(
        'Check Error:' + sLineBreak +
        E.Message + sLineBreak + sLineBreak +
        'You can still click OK to save the expression.'
      );
  end;
end;

function TfrmMain.ExpressionHelperBucketKey(const APropertyKey: string): string;
begin
  if SameText(APropertyKey, 'Expression') then
    Exit('expression');
  if SameText(APropertyKey, 'PrintWhen') then
    Exit('printwhen');
  if SameText(APropertyKey, 'BackgroundCondition') then
    Exit('backgroundcondition');
  if SameText(APropertyKey, 'FontColorCondition') then
    Exit('fontcolorcondition');
  if SameText(APropertyKey, 'BorderColorCondition') then
    Exit('bordercolorcondition');
  Result := '';
end;

function TfrmMain.ExpressionHelperRecentList(const APropertyKey: string;
  ACreate: Boolean): TStringList;
var
  Key: string;
begin
  Result := nil;
  Key := ExpressionHelperBucketKey(APropertyKey);
  if Key = '' then
    Exit;

  if not Assigned(FExprRecentsByKey) then
  begin
    if not ACreate then
      Exit;
    FExprRecentsByKey := TObjectDictionary<string, TStringList>.Create([doOwnsValues]);
  end;

  if not FExprRecentsByKey.TryGetValue(Key, Result) and ACreate then
  begin
    Result := TStringList.Create;
    FExprRecentsByKey.Add(Key, Result);
  end;
end;

procedure TfrmMain.ExpressionHelperAddRecent(const APropertyKey, AExpr: string);
const
  CMaxRecentItems = 20;
var
  ExprText: string;
  Recent: TStringList;
  I: Integer;
begin
  ExprText := Trim(AExpr);
  if ExprText = '' then
    Exit;
  if ExpressionHelperIsRecentHintItem(ExprText) then
    Exit;

  Recent := ExpressionHelperRecentList(APropertyKey, True);
  if not Assigned(Recent) then
    Exit;

  for I := Recent.Count - 1 downto 0 do
    if SameText(Trim(Recent[I]), ExprText) then
      Recent.Delete(I);

  Recent.Insert(0, ExprText);
  while Recent.Count > CMaxRecentItems do
    Recent.Delete(Recent.Count - 1);
end;

function TfrmMain.ExpressionHelperIsRecentHintItem(const AValue: string): Boolean;
begin
  Result := SameText(Trim(AValue), 'No recent expressions (session only)');
end;

procedure TfrmMain.ExpressionHelperFieldDblClick(Sender: TObject);
begin
  ExpressionHelperInsertField(Sender);
end;

procedure TfrmMain.ExpressionHelperExampleDblClick(Sender: TObject);
begin
  if not Assigned(FExprHelperExamples) or not Assigned(FExprHelperMemo) then
    Exit;
  if FExprHelperExamples.ItemIndex < 0 then
    Exit;

  // Simpler Phase 1 behavior: replace editor content with selected example.
  FExprHelperMemo.Lines.Text := FExprHelperExamples.Items[FExprHelperExamples.ItemIndex];
  FExprHelperMemo.SetFocus;
end;

procedure TfrmMain.ExpressionHelperRecentDblClick(Sender: TObject);
var
  SelectedText: string;
begin
  if not Assigned(FExprHelperRecent) or not Assigned(FExprHelperMemo) then
    Exit;
  if FExprHelperRecent.ItemIndex < 0 then
    Exit;
  SelectedText := Trim(FExprHelperRecent.Items[FExprHelperRecent.ItemIndex]);
  if ExpressionHelperIsRecentHintItem(SelectedText) then
    Exit;

  // Keep behavior aligned with examples: replace editor content.
  FExprHelperMemo.Lines.Text := SelectedText;
  FExprHelperMemo.SetFocus;
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
var
  Obj: TReportObject;
  KeyName: string;
  Dlg: TFontDialog;
  OldFont: TFont;
  NewFont: TFont;
  Cmd: TTextFontChangeCommand;
begin
  Result := False;
  if (ARow <= 0) or (ARow >= PropEditor.RowCount) then
    Exit;

  KeyName := PropEditor.Keys[ARow];
  if IsVisualGroupRow(KeyName) or not IsFontDialogRowKey(KeyName) then
    Exit;

  Obj := CurrentPropertyTarget;
  if not (Obj is TReportTextObject) then
    Exit;

  Dlg := TFontDialog.Create(Self);
  OldFont := TFont.Create;
  NewFont := TFont.Create;
  try
    OldFont.Assign(TReportTextObject(Obj).Font);
    Dlg.Font.Assign(TReportTextObject(Obj).Font);
    if not Dlg.Execute then
      Exit;

    NewFont.Assign(Dlg.Font);
    if (OldFont.Name = NewFont.Name) and
       (OldFont.Size = NewFont.Size) and
       (OldFont.Style = NewFont.Style) and
       (OldFont.Color = NewFont.Color) and
       (OldFont.Charset = NewFont.Charset) then
      Exit;

    Cmd := TTextFontChangeCommand.Create(TReportTextObject(Obj), OldFont, NewFont);
    if Assigned(FDesigner) then
      FDesigner.ExecuteUndoCommand(Cmd)
    else
      Cmd.Free;

    FDesigner.RebuildLayout;
    FModified := True;
    UpdateTitleBar;
    UpdatePropertyPanel;
    UpdateStatusBar;
    RefreshReportStructure;
    SyncReportStructureSelection;
    Result := True;
  finally
    NewFont.Free;
    OldFont.Free;
    Dlg.Free;
  end;
end;

procedure TfrmMain.PromoteImportantProperties(AObj: TReportObject);
const
  BandKeys: array[0..13] of string = (
    'BandType', 'Height', 'DataSetName', 'GroupField', 'GroupLevel',
    'CanGrow', 'CanShrink', 'StartNewPage', 'Visible', 'PrintWhen',
    'BackColor', 'BackColorTransparent',
    'OnBeforePrint', 'OnAfterPrint'
  );
  TextKeys: array[0..21] of string = (
    'Text', 'DataField', 'Expression', 'DisplayFormat',
    'Bounds', 'Left', 'Top', 'Width', 'Height',
    'FontName', 'FontSize', 'FontBold', 'FontItalic', 'FontColor',
    'WordWrap', 'AutoSize', 'Transparent', 'Background',
    'BorderVisible', 'BorderColor', 'BorderWidth', 'PrintWhen'
  );
  ImageKeys: array[0..14] of string = (
    'DataField', 'ImagePath', 'Picture', 'Stretch', 'Proportional', 'Center',
    'Bounds', 'Left', 'Top', 'Width', 'Height',
    'BorderVisible', 'BorderColor', 'Visible', 'PrintWhen'
  );
  BarcodeKeys: array[0..12] of string = (
    'Value', 'DataField', 'Symbology', 'BarcodeType', 'ShowText',
    'Bounds', 'Left', 'Top', 'Width', 'Height', 'Visible', 'PrintWhen', 'BarColor'
  );
var
  Keys: TArray<string>;
  I, Idx: Integer;
  K, Val: string;
  procedure AddKeys(const AKeys: array of string);
  var J: Integer;
  begin
    for J := Low(AKeys) to High(AKeys) do
    begin
      SetLength(Keys, Length(Keys) + 1);
      Keys[High(Keys)] := AKeys[J];
    end;
  end;
begin
  if PropEditor.RowCount <= 1 then Exit;

  Keys := nil;
  if AObj is TReportBand then
    AddKeys(BandKeys)
  else if (AObj is TReportTextObject) or (AObj is TReportFieldObject) or (AObj is TReportMemoObject) then
    AddKeys(TextKeys)
  else if AObj is TReportImageObject then
    AddKeys(ImageKeys)
  else if AObj is TReportBarcodeObject then
    AddKeys(BarcodeKeys)
  else
    AddKeys(['Bounds', 'Left', 'Top', 'Width', 'Height', 'Visible', 'PrintWhen']);

  for I := High(Keys) downto Low(Keys) do
  begin
    K := Keys[I];
    Idx := PropEditor.Strings.IndexOfName(K);
    if Idx > 0 then
    begin
      Val := PropEditor.Values[K];
      PropEditor.Strings.Delete(Idx);
      PropEditor.Strings.Insert(1, K + '=' + Val);
    end;
  end;
end;

procedure TfrmMain.InsertVisualGroupRows(AObj: TReportObject);
var
  I: Integer;
  procedure InsertGroupAt(const GroupName: string; AIndex: Integer);
  var
    GroupKey: string;
  begin
    GroupKey := '[' + GroupName + ']';
    if PropEditor.Strings.IndexOfName(GroupKey) >= 0 then
      Exit;
    if AIndex < 1 then
      AIndex := 1;
    if AIndex > PropEditor.RowCount then
      AIndex := PropEditor.RowCount;
    PropEditor.Strings.Insert(AIndex, GroupKey + '=');
  end;

  function FindFirstExistingIndex(const KeyNames: array of string): Integer;
  var
    J, Idx: Integer;
  begin
    Result := -1;
    for J := Low(KeyNames) to High(KeyNames) do
    begin
      Idx := PropEditor.Strings.IndexOfName(KeyNames[J]);
      if Idx > 0 then
      begin
        Result := Idx;
        Exit;
      end;
    end;
  end;
begin
  if not Assigned(AObj) then Exit;

  for I := PropEditor.RowCount - 1 downto 0 do
    if IsVisualGroupRow(PropEditor.Keys[I]) then
      PropEditor.Strings.Delete(I);

  InsertGroupAt('Common', FindFirstExistingIndex(['Visible', 'Name', 'PrintWhen', 'Bounds']));
  InsertGroupAt('Layout', FindFirstExistingIndex(['Bounds', 'Left', 'Top', 'Width', 'Height']));
  InsertGroupAt('Data', FindFirstExistingIndex(['DataField', 'DataSetName', 'Expression', 'Value']));
  InsertGroupAt('Appearance', FindFirstExistingIndex(['Transparent', 'Background', 'BackColor', 'BrushColor']));
  InsertGroupAt('Font', FindFirstExistingIndex(['FontName', 'FontSize', 'FontBold', 'Font']));
  InsertGroupAt('Border', FindFirstExistingIndex(['BorderVisible', 'BorderColor', 'BorderWidth', 'PenColor']));
  InsertGroupAt('Behavior', FindFirstExistingIndex(['PrintWhen', 'CanGrow', 'CanShrink', 'StartNewPage']));
  if FindFirstExistingIndex(['OnBeforePrint', 'OnAfterPrint']) > 0 then
    InsertGroupAt('Events', FindFirstExistingIndex(['OnBeforePrint', 'OnAfterPrint']));

  if AObj is TReportBand then
  begin
    if PropEditor.Strings.IndexOfName('[Data]') < 0 then
      InsertGroupAt('Data', FindFirstExistingIndex(['DataSetName', 'GroupField', 'GroupLevel']));
    if PropEditor.Strings.IndexOfName('[Behavior]') < 0 then
      InsertGroupAt('Behavior', FindFirstExistingIndex(['CanGrow', 'CanShrink', 'StartNewPage']));
  end;
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
begin
  CreateSampleDataSet;
  FSampleDataSet.DisableControls;
  try
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

