unit Vittix.Report.Engine;

{
  Vittix.Report.Engine
  ====================
  TReportEngine processes a TReportModel against a TDataSet and produces a
  list of TMetafile pages ready for preview or export.

  Key responsibilities
  --------------------
  1. Band layout — title, page header/footer, group headers/footers,
     master-data rows, report summary.
  2. Page lifecycle — starts new pages when vertical space runs out;
     forces page footers to the bottom margin.
  3. Group detection — detects field-value changes and fires the correct
     group header / footer bands.
  4. Progress reporting — via the optional IReportProgress interface so the
     caller can show a progress bar and support cancellation.

  What the engine does NOT do
  ---------------------------
  • Rendering to bitmap  → TReportRenderer
  • File export          → IReportExporter implementations
  • Page settings        → TReportPageSettings (owned by TReportModel)
}

interface

uses
  System.UITypes, System.Classes,
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
  Vcl.Graphics,
  System.Variants,
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Context,
  Vittix.Report.Expression.Mode,
  Vittix.Report.PageSettings,
  Vittix.Report.PagePlanner,
  Vittix.Report.Scripting,
  Vittix.Report.LayoutCache,
  Vittix.Report.LayoutPagination,
  Vittix.Report.LayoutBookmarks,
  Vittix.Report.UserDataSet,
  Vittix.Report.Export.Commands,
  Vittix.Report.MemoExport,
  Vittix.Report.Interfaces;   // IReportProgress

type
  EReportException = class(Exception);

type
  TBooleanDynArray = array of Boolean;
  TBookmarkDynArray = array of TBookmark;

type
  { Per-pass key index for one detail band's dataset: maps the encoded
    DetailField value to the bookmarks of every row carrying it, so
    master-detail linking is a direct lookup instead of a First..Eof scan
    per master row (O(masters + details) instead of O(masters x details)).
    Built lazily on the first master row of a pass; invalidated with the
    other execution caches at the start of every pass.  Bookmarks are the
    managed TBytes TBookmark values - they stay valid while the dataset is
    open, which is the index's whole lifetime. }
  TDetailBandKeyIndex = class
  public
    Band: TReportBand;
    DS: TDataSet;
    DetailField: TField;
    FirstKey: string;
    HasFirstKey: Boolean;
    Keys: TDictionary<string, TList<TBookmark>>;
    Stale: Boolean;
    constructor Create;
    destructor Destroy; override;
  end;

type
  TReportBeforePrintReportEvent = procedure(
    Sender: TObject;
    AEngine: TObject;
    AReport: TReportModel;
    var ACancel: Boolean) of object;

  TReportAfterPrintReportEvent = procedure(
    Sender: TObject;
    AEngine: TObject;
    AReport: TReportModel) of object;

  TReportBeforeBandEvent = procedure(
    Sender: TObject;
    AEngine: TObject;
    ABand: TReportBand;
    const Context: TExpressionContext;
    var ACanPrint: Boolean) of object;

  TReportAfterBandEvent = procedure(
    Sender: TObject;
    AEngine: TObject;
    ABand: TReportBand;
    const Context: TExpressionContext) of object;

  TReportBeforeObjectEvent = procedure(
    Sender: TObject;
    AEngine: TObject;
    AObject: TReportObject;
    const Context: TExpressionContext;
    var ACanPrint: Boolean) of object;

  TReportAfterObjectEvent = procedure(
    Sender: TObject;
    AEngine: TObject;
    AObject: TReportObject;
    const Context: TExpressionContext) of object;

type
  TAggregateCacheEntry = class
  private
    FDataSet: TDataSet;
    FExpression: string;
    FGroupStart: TBookmark;
    FGroupEnd: TBookmark;
    FPageNumber: Integer;
    FTotalPages: Integer;
    FRowNumber: Integer;
    FIsCountingPass: Boolean;
    FParameters: string;
    FVariables: string;
    FFilter: string;
    FFiltered: Boolean;
    FValue: Variant;
  public
    function Matches(const AExpression: string;
      const AContext: TExpressionContext): Boolean;
    { DP-29: identity match ignoring RowNumber, used by StoreAggregateCache
      to collapse row-scoped duplicates - the stored row can never be
      revisited by a later row, so one entry per non-row identity suffices. }
    function MatchesExceptRowNumber(const AExpression: string;
      const AContext: TExpressionContext): Boolean;
    procedure Capture(const AExpression: string;
      const AContext: TExpressionContext; const AValue: Variant);
    property Value: Variant read FValue;
  end;

  TSubReportModelCacheEntry = class
  public
    Owner: TObject;
    JSON: string;
    Model: TReportModel;
    destructor Destroy; override;
  end;

  { Phase C: engine-owned state for one subreport row stream (one subreport
    Draw invocation). Phase B kept a single pending state; Phase C keeps a LIFO
    stack of these so a nested subreport can continue across pages while its
    parent stream is suspended at the exact row boundary. Created by
    BeginRowStream, driven through PrepareRowFor (in-Draw fit decisions) and
    the band-boundary depth-first flush, released at the band boundary
    (PrintBand finally). }
  TSubReportStreamState = class
  public
    MasterBand: TReportBand;   // subreport's own master band (model-cache owned)
    DS: TDataSet;              // subreport detail source
    MasterField: string;
    DetailField: string;
    Context: TExpressionContext;  // draw context captured at BeginRowStream
    AnchorX: Integer;          // page-space viewport origin at Begin (X)
    AnchorY: Integer;          // page-space viewport origin at Begin (Y)
    BoundsLeft: Integer;
    BoundsTop: Integer;
    BoundsHeight: Integer;     // subreport declared bounds height
    RowHeight: Integer;        // row height (flat: MasterBand.Height for all)
    NextRowY: Integer;         // page-space top for the next in-Draw row
    LastRowTop: Integer;       // page-space top approved by the last PrepareRow
    EmittedCount: Integer;     // matched rows approved/emitted so far
    Deferred: Boolean;         // rows remain for the band-boundary flush
    DrawFinished: Boolean;     // the subreport's Draw loop returned
    LastRowApproved: Boolean;  // fold nested overflow in at the next decision
    MatchAll: Boolean;         // link snapshot: every row matches (legacy rule)
    MasterValue: Variant;      // link snapshot: captured master field value
    SaveBM: TBookmark;         // logical-stream dataset position (single save)
    HasSaveBM: Boolean;
    { Restore points of the approved dataset contract: RestoreDataset is
      repeatable and keeps the bookmark (EndStream restores before the flush,
      the band-boundary release restores after it); FreeDatasetBookmark is the
      single bookmark release, run by that release / BeginPass / destructor. }
    procedure RestoreDataset;
    procedure FreeDatasetBookmark;
  end;

  TReportEngine = class(TObject, IInterface, IReportRenderHooks,
    IReportExportCaptureSink, IReportSubReportRowStream)
  private
    FReport:   TReportModel;
    FDataSet:  TDataSet;
    FUserDataSet: TVittixUserDataSet;
    FNamedDataSets: TDictionary<string, TDataSet>;
    FNamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
    FScriptEngine: TReportScriptEngine;
    FProgress: IReportProgress;   // optional; nil = no progress feedback
    FParameters: TStrings;
    FAggregateCache: TObjectList<TAggregateCacheEntry>;
    FSubReportModelCache: TObjectList<TSubReportModelCacheEntry>;
    FPages:    TObjectList<TMetafile>;
    FExportDocument: TReportExportDocument;
    FPlanner:  TReportPagePlanner;   // Phase A: page-allocation authority
    FStreamStack: TObjectList<TSubReportStreamState>;  // Phase C: stream stack
    FStreamBaseCount: Integer;       // stack depth at the current PrintBand entry
    FInStreamFlush: Boolean;         // a page break is being prepared by the flush
    FExportOriginX: Integer;
    FExportOriginY: Integer;

    FCurrentPage: TMetafile;
    FCanvas:      TMetafileCanvas;
    FPageWidth:   Integer;   // cached from PageSettings at Prepare time
    FPageHeight:  Integer;
    FMarginLeft, FMarginTop, FMarginRight, FMarginBottom: Integer;
    FRowNumber:   Integer;   // 1-based current master row counter
    FReportDate:  TDateTime; // set once when Prepare begins
    FTotalPagesForPass: Integer;
    FTwoPassRendering: Boolean;

    FTitleBand:         TReportBand;
    FHeaderBand:        TReportBand;
    FColumnHeaderBand:  TReportBand;   // btColumnHeader
    FMasterBand:        TReportBand;   // primary master loop band
    FDetailBands:       TObjectList<TReportBand>; // btDetail bands that use their own datasets
    FDetailKeyIndexes:  TObjectList<TDetailBandKeyIndex>; // per-pass master-detail key index
    FFooterBand:        TReportBand;
    FSummaryBand:       TReportBand;
    FOverlayBand:       TReportBand;   // btOverlay — drawn last over the full page
    FPrintingFooter:    Boolean;       // guards against recursive page breaks inside footer rendering

    FGroupStartBookmark:    TBookmark;
    FGroupEndBookmark:      TBookmark;
    FHasGroupStartBookmark: Boolean;
    FHasGroupEndBookmark:   Boolean;
    FGroupStartBookmarks: TBookmarkDynArray;
    FGroupEndBookmarks: TBookmarkDynArray;
    FHasGroupStartBookmarks: TBooleanDynArray;
    FHasGroupEndBookmarks: TBooleanDynArray;

    FGroupHeaders:    TObjectList<TReportBand>;
    FGroupFooters:    TObjectList<TReportBand>;
    FLastGroupValues: array of Variant;
    FIsRenderingPass: Boolean;
    FOnBeforePrintReport: TReportBeforePrintReportEvent;
    FOnAfterPrintReport: TReportAfterPrintReportEvent;
    FOnBeforeBand: TReportBeforeBandEvent;
    FOnAfterBand: TReportAfterBandEvent;
    FOnBeforeObject: TReportBeforeObjectEvent;
    FOnAfterObject: TReportAfterObjectEvent;

    procedure Initialize(
      AReport:        TReportModel;
      ADataSet:       TDataSet;
      ANamedDataSets: TDictionary<string, TDataSet>;
      AUserDataSet:   TVittixUserDataSet;
      ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
      AProgress:      IReportProgress);
    procedure CacheBands;
    procedure ResetObjectCaches(AObjects: TObjectList<TReportObject>);
    function IsCapturingExportCommands: Boolean;

    procedure StartNewPage;
    procedure ApplyPageSettings(ASettings: TReportPageSettings);

    procedure EndCurrentPage;
    procedure PrintPageHeader(AIncludeColumnHeader: Boolean = False);
    procedure EnsurePageSpaceForBand(ABand: TReportBand; RequiredHeight: Integer; PrintColumnHeader: Boolean = False);
    procedure BeginPass(ATotalPages: Integer; AReportProgress: Boolean; out ATotalRows, ARowNumber: Integer);
    procedure PrintFirstPageBands;
    function InitializeActiveGroupHeaders(out AActiveGroupHeader: TBooleanDynArray): Boolean;
    function DetectGroupBreak(const AActiveGroupHeader: TBooleanDynArray): Integer;
    function ProcessCurrentMasterRecord(AReportProgress: Boolean; var ARowNumber: Integer): Boolean;
    procedure ProcessMasterDataLoop(const AActiveGroupHeader: TBooleanDynArray; AReportProgress: Boolean; var ARowNumber: Integer; var AHasOpenedGroups: Boolean);
    procedure CaptureGroupStartBookmark(ALevel: Integer = -1);
    procedure CaptureGroupEndBookmark(ALevel: Integer = -1);
    function IsGroupLevelActive(const AActiveGroupHeader: TBooleanDynArray; ALevel: Integer): Boolean;
    procedure CloseGroupsForBreak(ABreakLevel: Integer; const AActiveGroupHeader: TBooleanDynArray);
    procedure OpenGroupsForBreak(ABreakLevel: Integer; const AActiveGroupHeader: TBooleanDynArray; var AHasOpenedGroups: Boolean);
    procedure CloseRemainingGroups(const AActiveGroupHeader: TBooleanDynArray; AHasAnyActiveGroup: Boolean; AHasOpenedGroups: Boolean);
    procedure PrintSummaryWithSpaceCheck;
    function FinalizePass(const AActiveGroupHeader: TBooleanDynArray; AHasAnyActiveGroup, AHasOpenedGroups: Boolean): Integer;
    procedure PrintBand(ABand: TReportBand; ADataSet: TDataSet = nil;
      AEffectiveHeight: Integer = -1; AUserDataSet: TVittixUserDataSet = nil);
    procedure PrintBandWithSpaceCheck(ABand: TReportBand; ADataSet: TDataSet = nil;
      AUserDataSet: TVittixUserDataSet = nil);
    function  ComputeEffectiveBandHeight(ABand: TReportBand; ADataSet: TDataSet;
      AUserDataSet: TVittixUserDataSet = nil): Integer;
    function  BandHasChildPageBreak(ABand: TReportBand; ABefore: Boolean): Boolean;
    function  ResolveBandDataSet(ABand: TReportBand): TDataSet;
    function  ResolveBandUserDataSet(ABand: TReportBand): TVittixUserDataSet;
    function  PrimarySourceActive: Boolean;
    function  SourceFieldValue(ADataSet: TDataSet; AUserDataSet: TVittixUserDataSet;
      const AFieldName: string): Variant;
    procedure ValidateDetailLinks;
    function  ComputeFirstDetailRowsHeight: Integer;
    procedure PrintDetailBandRecords(ABand: TReportBand; ADetailDS: TDataSet;
      ADetailUDS: TVittixUserDataSet);
    { Lazily builds (once per pass) and returns the DetailField key index
      for ABand's dataset; nil when the dataset cannot carry bookmarks. }
    function  GetDetailKeyIndex(ABand: TReportBand; ADetailDS: TDataSet;
      ADetailFld: TField): TDetailBandKeyIndex;
    procedure PrintDetailBands;
    procedure ClearExecutionCaches;
    function  ExecutePass(ATotalPages: Integer; AReportProgress: Boolean): Integer;
    function  CheckSpace(RequiredHeight: Integer): Boolean;
    { Phase C: IReportSubReportRowStream implementation (subreport row
      streaming, nested-capable). BeginRowStream pushes one stream state and
      returns its session; PrepareRowFor is the planner-owned atomic-row fit
      decision for one state; EndRowStream marks a Draw loop finished and
      restores its dataset; FlushPendingStreams is the band-boundary
      depth-first continuation flush. }
    function BeginRowStream(const AContext: TExpressionContext;
      AMasterBand: TObject; ADS: TDataSet; AMasterField, ADetailField: string;
      AAnchorX, AEntryCursorY, ABoundsLeft, ABoundsTop, ABoundsHeight,
      ABoundsRight, ARowHeight: Integer): IReportNestedRowStream;
    function PrepareRowFor(AState: TSubReportStreamState;
      ARowHeight: Integer): Boolean;
    procedure EndRowStream(AState: TSubReportStreamState);
    procedure AbandonRowStream(AState: TSubReportStreamState);
    procedure PopStreamState(AIndex: Integer);
    procedure ReleaseStreamsAbove(ABaseCount: Integer);
    function AlignDetailToSnapshot(AState: TSubReportStreamState): Boolean;
    function FindNextMatchedRow(AState: TSubReportStreamState): Boolean;
    function StreamLinkMatches(AState: TSubReportStreamState;
      ADS: TDataSet): Boolean;
    procedure PaintStreamRow(AState: TSubReportStreamState);
    procedure FlushPendingStreams(const AContext: TExpressionContext;
      ABaseCount: Integer; var AFlushRan: Boolean);
procedure CaptureExportObjectCommand(
      AObject: TReportObject;
      const Context: TExpressionContext);

  public
    // IInterface implementation
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;

    // IReportRenderHooks implementation
    procedure InvokeBeforeObjectPrint(Sender: TObject; const Context: TExpressionContext; var ACanPrint: Boolean);
    procedure InvokeAfterObjectPrint(Sender: TObject; const Context: TExpressionContext);
    function GetNamedDataSet(const AName: string): TDataSet;
    function TryGetAggregateCache(const AExpression: string;
      const AContext: TExpressionContext; out AValue: Variant): Boolean;
    procedure StoreAggregateCache(const AExpression: string;
      const AContext: TExpressionContext; const AValue: Variant);
    function GetSubReportModel(AObject: TObject; const AJSON: string): TObject;
    function GetPageNumber: Integer;   // Phase A: planner-backed PageCount

    // IReportExportCaptureSink implementation (DP-31 / M-13)
    procedure AddCommand(const ACommand: TReportExportCommand);
    function GetCaptureOrigin: TPoint;
    procedure RegisterTempFile(const AFileName: string);
    procedure CaptureObjectAsImage(AObject: TReportObject;
      const AContext: TExpressionContext);
    /// <summary>
    ///   Creates an engine over a BORROWED report model and dataset.  The
    ///   engine owns neither: both must outlive the engine - or the dataset
    ///   must be released via <see cref="DetachDataSet"/> before it is freed
    ///   (while prepared the engine may hold dataset-owned bookmarks for
    ///   group ranges; DetachDataSet releases them and forgets the dataset).
    ///   The same lifetime contract applies to the UserDataSet overloads.
    /// </summary>
    /// <param name="AProgress">
    ///   Optional progress/cancellation callback.  Pass nil to skip.
    /// </param>
    constructor Create(
      AReport:   TReportModel;
      ADataSet:  TDataSet;
      AProgress: IReportProgress = nil); overload;
    /// <summary>Dataset lifetime contract: see the (AReport, ADataSet, AProgress) overload.</summary>
    constructor Create(
      AReport:        TReportModel;
      ADataSet:       TDataSet;
      ANamedDataSets: TDictionary<string, TDataSet>;
      AProgress:      IReportProgress); overload;
    /// <summary>Dataset lifetime contract: see the (AReport, ADataSet, AProgress) overload.</summary>
    constructor Create(
      AReport:        TReportModel;
      AUserDataSet:   TVittixUserDataSet;
      ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
      AProgress:      IReportProgress); overload;
    destructor Destroy; override;

    procedure Prepare;
    procedure RegisterDataSet(const AName: string; ADataSet: TDataSet);
    { DP-34 / M-22: releases the borrowed dataset - frees any bookmarks the
      engine still holds (while the dataset is valid) and forgets it, so the
      dataset may be destroyed before the engine.  Safe to call repeatedly. }
    procedure DetachDataSet;

    property Pages:      TObjectList<TMetafile> read FPages;
    property PageCount:  Integer                read GetPageNumber;
    property GroupStartBookmark: TBookmark      read FGroupStartBookmark;
    property GroupEndBookmark:   TBookmark      read FGroupEndBookmark;
    property NamedDataSets: TDictionary<string, TDataSet> read FNamedDataSets;
    property ScriptEngine: TReportScriptEngine read FScriptEngine;
    property Parameters: TStrings read FParameters;
    property ExportDocument: TReportExportDocument read FExportDocument write FExportDocument;
    property TwoPassRendering: Boolean read FTwoPassRendering write FTwoPassRendering;

    /// <summary>
    ///   Expression language mode derived from the report model
    ///   (Phase 4B-2B).  0 -> emLegacy (default, unchanged behavior);
    ///   1 -> emModern.  Any other value is treated as emLegacy by the
    ///   engine; the serializer rejects unsupported values on load.
    /// </summary>
    function ReportExpressionMode: TExpressionMode;
    property OnBeforePrintReport: TReportBeforePrintReportEvent
      read FOnBeforePrintReport write FOnBeforePrintReport;
    property OnAfterPrintReport: TReportAfterPrintReportEvent
      read FOnAfterPrintReport write FOnAfterPrintReport;
    property OnBeforeBand: TReportBeforeBandEvent
      read FOnBeforeBand write FOnBeforeBand;
    property OnAfterBand: TReportAfterBandEvent
      read FOnAfterBand write FOnAfterBand;
    property OnBeforeObject: TReportBeforeObjectEvent
      read FOnBeforeObject write FOnBeforeObject;
    property OnAfterObject: TReportAfterObjectEvent
      read FOnAfterObject write FOnAfterObject;
  end;

  { Phase C: per-stream session token handed to TReportSubReportObject. The
    engine owns the TSubReportStreamState; this object is only a refcounted
    accessor, so states can be released at band boundaries without conflicting
    with an outstanding interface reference (a session only lives for the
    duration of one DrawStreamedRows call). EndStream is idempotent; a session
    destroyed without EndStream restores its dataset through the engine, and
    the band-boundary cleanup still releases the state. }
  TSubReportRowStreamSession = class(TInterfacedObject, IReportNestedRowStream)
  private
    FEngine: TReportEngine;
    FState: TSubReportStreamState;
    FEnded: Boolean;
  public
    constructor Create(AEngine: TReportEngine; AState: TSubReportStreamState);
    destructor Destroy; override;
    function PrepareRow(ARowHeight: Integer): Boolean;
    function RowTop: Integer;
    procedure EndStream;
  end;

implementation

uses
  Winapi.Windows,
  System.Math,
  System.IOUtils,
  System.TypInfo,
  Vcl.Imaging.PNGImage,
  Vittix.Report.Expressions,    // TReportExpression.Evaluate — for PrintWhen
  Vittix.Report.Serializer,
  Vittix.Report.Utils,          // DataSetSupportsBookmarks, SafeRecordCount
  Vittix.Report.TraversalDiagnostics,
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Objects.Table,
  Vittix.Report.Objects.Chart,
  Vittix.Report.Objects.CrossTab,
  System.Generics.Defaults;

function BookmarksEqual(const ALeft, ARight: TBookmark): Boolean;
var
  I: Integer;
begin
  Result := Length(ALeft) = Length(ARight);
  if not Result then
    Exit;
  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

function StringsText(AStrings: TStrings): string;
begin
  if Assigned(AStrings) then
    Result := AStrings.Text
  else
    Result := '';
end;

{ A linked detail dataset follows master cursor notifications. Do not suppress
  those notifications while the engine advances the master cursor. }
function DataSetIsMasterLinked(ADataSet: TDataSet): Boolean;
var
  PropInfo: PPropInfo;
  MasterSource: TObject;
begin
  Result := False;
  if not Assigned(ADataSet) then
    Exit;
  PropInfo := GetPropInfo(ADataSet, 'MasterSource');
  if not Assigned(PropInfo) then
    Exit;
  MasterSource := GetObjectProp(ADataSet, PropInfo);
  Result := MasterSource is TDataSource;
end;

function DataSetMasterSourceDataSet(ADataSet: TDataSet): TDataSet;
var
  PropInfo: PPropInfo;
  MasterSource: TObject;
begin
  Result := nil;
  if not Assigned(ADataSet) then
    Exit;
  PropInfo := GetPropInfo(ADataSet, 'MasterSource');
  if not Assigned(PropInfo) then
    Exit;
  MasterSource := GetObjectProp(ADataSet, PropInfo);
  if MasterSource is TDataSource then
    Result := TDataSource(MasterSource).DataSet;
end;

const
  { Phase C: nesting cap. Subreport streams deeper than this fall back to the
    legacy clipped loop, so a pathological self-nesting model terminates
    instead of recursing without bound. }
  MAX_NESTED_STREAM_DEPTH = 16;

  { Aggregate call prefixes that force bookmark-based evaluation. }
  CAggregateCallTokens: array[0..4] of string =
    ('SUM(', 'COUNT(', 'AVG(', 'MIN(', 'MAX(');

{ True when one object needs bookmark-based evaluation (cross-tab/chart
  iterate their dataset through bookmarks; text objects with an aggregate
  call in the Expression or in a bracketed display token reach
  TReportAggregates, which saves/restores the cursor by bookmark). }
function ObjectNeedsBookmarks(AObj: TReportObject): Boolean;
var
  U: string;
  I: Integer;
begin
  Result := False;
  if (AObj is TReportCrossTabObject) or (AObj is TReportChartObject) then
    Exit(True);
  if AObj is TReportTextObject then
  begin
    U := UpperCase(Trim(TReportTextObject(AObj).Expression));
    for I := Low(CAggregateCallTokens) to High(CAggregateCallTokens) do
      if U.StartsWith(CAggregateCallTokens[I]) then
        Exit(True);
    U := UpperCase(TReportTextObject(AObj).Text);
    for I := Low(CAggregateCallTokens) to High(CAggregateCallTokens) do
      if Pos('[' + CAggregateCallTokens[I], U) > 0 then
        Exit(True);
  end;
end;

{ True when the model contains anything that evaluates through dataset
  bookmarks UNCONDITIONALLY: aggregate expressions (TReportAggregates
  saves/restores the cursor with an unguarded GetBookmark), cross-tab
  (unguarded GetBookmark in matrix preparation) and chart data loads.
  Group bands are deliberately NOT a trigger: the engine captures group
  bookmarks only when DataSetSupportsBookmarks and grouping degrades
  gracefully without them - pinned by
  Test_NonBookmark_Grouping_Completes_CurrentBehavior (Phase2).  Used to
  fail a bookmark-incapable dataset (e.g. a TFDQuery with
  FetchOptions.Unidirectional) up front with a clear message instead of
  confusing errors mid-render. }
function ReportModelNeedsBookmarks(AObjects: TObjectList<TReportObject>): Boolean;
var
  I: Integer;
  Obj: TReportObject;
begin
  Result := False;
  for I := 0 to AObjects.Count - 1 do
  begin
    Obj := AObjects[I];
    if ObjectNeedsBookmarks(Obj) then
      Exit(True);
    if Obj is TReportBand then
      if ReportModelNeedsBookmarks(TReportBand(Obj).Children) then
        Exit(True);
  end;
end;

function TAggregateCacheEntry.Matches(const AExpression: string;
  const AContext: TExpressionContext): Boolean;
begin
  Result := (FRowNumber = AContext.RowNumber) and
    MatchesExceptRowNumber(AExpression, AContext);
end;

function TAggregateCacheEntry.MatchesExceptRowNumber(
  const AExpression: string; const AContext: TExpressionContext): Boolean;
var
  DataSetFilter: string;
  DataSetFiltered: Boolean;
begin
  DataSetFilter := '';
  DataSetFiltered := False;
  if Assigned(AContext.DataSet) then
  begin
    DataSetFilter := AContext.DataSet.Filter;
    DataSetFiltered := AContext.DataSet.Filtered;
  end;
  Result := (FDataSet = AContext.DataSet) and
    (FExpression = AExpression) and
    BookmarksEqual(FGroupStart, AContext.GroupStart) and
    BookmarksEqual(FGroupEnd, AContext.GroupEnd) and
    (FPageNumber = AContext.PageNumber) and
    (FTotalPages = AContext.TotalPages) and
    (FIsCountingPass = AContext.IsCountingPass) and
    (FParameters = StringsText(AContext.Parameters)) and
    (FVariables = StringsText(AContext.Variables)) and
    (FFilter = DataSetFilter) and
    (FFiltered = DataSetFiltered);
end;

procedure TAggregateCacheEntry.Capture(const AExpression: string;
  const AContext: TExpressionContext; const AValue: Variant);
begin
  FDataSet := AContext.DataSet;
  FExpression := AExpression;
  FGroupStart := Copy(AContext.GroupStart);
  FGroupEnd := Copy(AContext.GroupEnd);
  FPageNumber := AContext.PageNumber;
  FTotalPages := AContext.TotalPages;
  FRowNumber := AContext.RowNumber;
  FIsCountingPass := AContext.IsCountingPass;
  FParameters := StringsText(AContext.Parameters);
  FVariables := StringsText(AContext.Variables);
  if Assigned(AContext.DataSet) then
  begin
    FFilter := AContext.DataSet.Filter;
    FFiltered := AContext.DataSet.Filtered;
  end
  else
  begin
    FFilter := '';
    FFiltered := False;
  end;
  FValue := AValue;
end;

destructor TSubReportModelCacheEntry.Destroy;
begin
  Model.Free;
  inherited;
end;

{ ================= Constructor ================= }

procedure TReportEngine.Initialize(
  AReport:        TReportModel;
  ADataSet:       TDataSet;
  ANamedDataSets: TDictionary<string, TDataSet>;
  AUserDataSet:   TVittixUserDataSet;
  ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
  AProgress:      IReportProgress);
begin
  FReport   := AReport;
  FDataSet  := ADataSet;
  FUserDataSet := AUserDataSet;
  FNamedDataSets := TDictionary<string, TDataSet>.Create;
  FNamedUserDataSets := TDictionary<string, TVittixUserDataSet>.Create;
  FScriptEngine := TReportScriptEngine.Create(nil);
  FParameters := TStringList.Create;
  FAggregateCache := TObjectList<TAggregateCacheEntry>.Create(True);
  FDetailKeyIndexes := TObjectList<TDetailBandKeyIndex>.Create(True);
  FSubReportModelCache := TObjectList<TSubReportModelCacheEntry>.Create(True);
  FStreamStack := TObjectList<TSubReportStreamState>.Create(True);
  if Assigned(ANamedDataSets) then
    for var Pair in ANamedDataSets do
      FNamedDataSets.AddOrSetValue(Pair.Key, Pair.Value);
  if Assigned(ANamedUserDataSets) then
    for var UserPair in ANamedUserDataSets do
      FNamedUserDataSets.AddOrSetValue(UserPair.Key, UserPair.Value);
  FProgress := AProgress;
  FPages    := TObjectList<TMetafile>.Create(True);

  FGroupHeaders := TObjectList<TReportBand>.Create(False); // does not own — bands owned by report
  FGroupFooters := TObjectList<TReportBand>.Create(False);
  FDetailBands  := TObjectList<TReportBand>.Create(False);

  FPrintingFooter := False;

  // Page dimensions are read from PageSettings in Prepare; seed defaults here
  // so StartNewPage can be called safely before Prepare sets them.
  FPageWidth  := 793;
  FPageHeight := 1122;
  FPlanner := TReportPagePlanner.Create;
  FPlanner.SetPageMetrics(FPageWidth, FPageHeight);
  FTotalPagesForPass := 0;
  FTwoPassRendering := True;
end;

constructor TReportEngine.Create(
  AReport:   TReportModel;
  ADataSet:  TDataSet;
  AProgress: IReportProgress);
begin
  inherited Create;
  Initialize(AReport, ADataSet, nil, nil, nil, AProgress);
end;

constructor TReportEngine.Create(
  AReport:        TReportModel;
  ADataSet:       TDataSet;
  ANamedDataSets: TDictionary<string, TDataSet>;
  AProgress:      IReportProgress);
begin
  inherited Create;
  Initialize(AReport, ADataSet, ANamedDataSets, nil, nil, AProgress);
end;

constructor TReportEngine.Create(
  AReport:        TReportModel;
  AUserDataSet:   TVittixUserDataSet;
  ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
  AProgress:      IReportProgress);
begin
  inherited Create;
  Initialize(AReport, nil, nil, AUserDataSet, ANamedUserDataSets, AProgress);
end;

destructor TReportEngine.Destroy;
begin
  // Phase C: no stale stream state can outlive the engine (restores held
  // stream datasets before releasing them).
  ReleaseStreamsAbove(0);
  FStreamStack.Free;
  FPlanner.Free;
  FCanvas.Free;
  FCanvas := nil;

  FCurrentPage.Free;
  FCurrentPage := nil;

  // Release any bookmarks we still hold, then forget the borrowed dataset
  // (DP-34 / M-22).  Only our own bookmarks-held state makes us reach into
  // the dataset at all; a dataset that must die before the engine has to be
  // released via DetachDataSet beforehand (documented on Create).
  DetachDataSet;

  FPages.Free;
  FNamedDataSets.Free;
  FNamedUserDataSets.Free;
  FParameters.Free;
  FAggregateCache.Free;
  FDetailKeyIndexes.Free;
  FSubReportModelCache.Free;
  FScriptEngine.Free;
  FGroupHeaders.Free;
  FGroupFooters.Free;
  FDetailBands.Free;
  inherited;
end;

{ DP-34 / M-22: releases the borrowed dataset.  Frees the bookmarks the
  engine still holds while the dataset is still valid, then forgets the
  dataset entirely so no later path (including Destroy) touches it.  Safe
  to call repeatedly and when the engine was never prepared. }
procedure TReportEngine.DetachDataSet;
var
  I: Integer;
  HasGroupLevelBookmarks: Boolean;
begin
  if (FDataSet <> nil) and
     (FHasGroupStartBookmark or FHasGroupEndBookmark) and
     DataSetSupportsBookmarks(FDataSet) then
  begin
    if FHasGroupStartBookmark then
      FDataSet.FreeBookmark(FGroupStartBookmark);
    if FHasGroupEndBookmark then
      FDataSet.FreeBookmark(FGroupEndBookmark);
  end;

  FGroupStartBookmark := nil;
  FGroupEndBookmark := nil;
  FHasGroupStartBookmark := False;
  FHasGroupEndBookmark := False;
  HasGroupLevelBookmarks := False;
  for I := 0 to High(FHasGroupStartBookmarks) do
    HasGroupLevelBookmarks := HasGroupLevelBookmarks or FHasGroupStartBookmarks[I];
  for I := 0 to High(FHasGroupEndBookmarks) do
    HasGroupLevelBookmarks := HasGroupLevelBookmarks or FHasGroupEndBookmarks[I];
  if Assigned(FDataSet) and HasGroupLevelBookmarks and
     DataSetSupportsBookmarks(FDataSet) then
  begin
    for I := 0 to High(FGroupStartBookmarks) do
      if (I <= High(FHasGroupStartBookmarks)) and FHasGroupStartBookmarks[I] then
        FDataSet.FreeBookmark(FGroupStartBookmarks[I]);
    for I := 0 to High(FGroupEndBookmarks) do
      if (I <= High(FHasGroupEndBookmarks)) and FHasGroupEndBookmarks[I] then
        FDataSet.FreeBookmark(FGroupEndBookmarks[I]);
  end;
  SetLength(FGroupStartBookmarks, 0);
  SetLength(FGroupEndBookmarks, 0);
  SetLength(FHasGroupStartBookmarks, 0);
  SetLength(FHasGroupEndBookmarks, 0);
  FDataSet := nil;
end;

{ ================= Band Cache ================= }

procedure TReportEngine.CacheBands;
begin
  CacheReportBands(
    FReport,
    FTitleBand,
    FHeaderBand,
    FColumnHeaderBand,
    FMasterBand,
    FFooterBand,
    FSummaryBand,
    FOverlayBand,
    FGroupHeaders,
    FGroupFooters,
    FDetailBands);
end;

{ Per-pass object cache reset (DP-12 / H-6). Recurses into band children:
  report objects normally live inside a band's Children list, and the
  previous flat walk over FReport.Objects never reached them. Data caches
  (chart points, crosstab matrix) MUST drop per pass or a second Prepare
  against changed data redraws the first pass's values; the image cache
  reset is carried along unchanged. }
procedure TReportEngine.ResetObjectCaches(AObjects: TObjectList<TReportObject>);
var
  Obj: TReportObject;
begin
  for Obj in AObjects do
  begin
    if Obj is TReportImageObject then
      TReportImageObject(Obj).ResetImageCache;
    if Obj is TReportChartObject then
      TReportChartObject(Obj).ResetDataCache;
    if Obj is TReportCrossTabObject then
      TReportCrossTabObject(Obj).ResetDataCache;
    if Obj is TReportBand then
      ResetObjectCaches(TReportBand(Obj).Children);
  end;
end;

procedure TReportEngine.ClearExecutionCaches;
var
  I: Integer;
begin
  FAggregateCache.Clear;
  // Phase B: successful subreport models are cleared per pass exactly as
  // before (a model instance must not be reused across passes - band/text
  // state carried by the model affects measurement). Cached PARSE FAILURES
  // survive the pass pair: the same owner+JSON fails deterministically, so
  // a broken subreport streamed in the count pass is not parsed and counted
  // again in the render pass (entries with Model = nil are the failure memo;
  // deleting a success entry frees it because the list owns its objects).
  for I := FSubReportModelCache.Count - 1 downto 0 do
    if FSubReportModelCache[I].Model <> nil then
      FSubReportModelCache.Delete(I);
  // The detail key index must not survive a pass: detail data can change
  // between passes and bookmarks are only stable while the cursor does.
  FDetailKeyIndexes.Clear;
end;

constructor TDetailBandKeyIndex.Create;
begin
  inherited;
  Keys := TDictionary<string, TList<TBookmark>>.Create;
end;

destructor TDetailBandKeyIndex.Destroy;
var
  List: TList<TBookmark>;
begin
  if Assigned(Keys) then
  begin
    for List in Keys.Values do
      List.Free;
    Keys.Free;
  end;
  inherited;
end;

function TReportEngine.ReportExpressionMode: TExpressionMode;
begin
  // Phase 4B-2B: report-level opt-in. Everything else stays legacy.
  if Assigned(FReport) and (FReport.ExpressionLanguageVersion = 1) then
    Result := emModern
  else
    Result := emLegacy;
end;



function TReportEngine.IsCapturingExportCommands: Boolean;
begin
  Result := FIsRenderingPass and Assigned(FExportDocument);
end;

{ ================= Page Lifecycle ================= }

procedure TReportEngine.ApplyPageSettings(ASettings: TReportPageSettings);
begin
  FPageWidth  := ASettings.PageWidth;
  FPageHeight := ASettings.PageHeight;
  FMarginLeft   := ASettings.Margins.Left;
  FMarginTop    := ASettings.Margins.Top;
  FMarginRight  := ASettings.Margins.Right;
  FMarginBottom := ASettings.Margins.Bottom;
  FPlanner.SetPageMetrics(FPageWidth, FPageHeight);
  // Note: changing page settings mid-engine could mess up space tracking if not exactly at top of page,
  // but StartNewPage safely resets these coordinates.
end;

procedure TReportEngine.StartNewPage;
begin
  EndCurrentPage;

  // Phase A: the planner owns page numbering, export-page allocation and
  // the cursor reset.  Canvas/metafile creation below remains engine-owned.
  FPlanner.BeginPage(FReport.PageSettings.Margins.Top);

  FCurrentPage := TMetafile.Create;
  try
    FCurrentPage.Enhanced := True;
    FCurrentPage.Width  := FPageWidth;
    FCurrentPage.Height := FPageHeight;
    FCanvas := TMetafileCanvas.Create(FCurrentPage, 0);
    // DP-14 / H-4: pin the recording canvas font to the 96-dpi geometry
    // reference so any draw that uses the canvas font measures at model
    // scale, not at the host display scale.
    NormalizeFontToReferenceDPI(FCanvas.Font);
  except
    FCurrentPage.Free;
    FCurrentPage := nil;
    raise;
  end;
end;

procedure TReportEngine.PrintPageHeader(AIncludeColumnHeader: Boolean);
begin
  // Column headers are emitted after group headers, so callers that do not
  // own group-header ordering must opt in explicitly.
  if Assigned(FHeaderBand) then
    PrintBand(FHeaderBand);
  if AIncludeColumnHeader and Assigned(FColumnHeaderBand) then
    PrintBandWithSpaceCheck(FColumnHeaderBand, FDataSet);
end;

procedure TReportEngine.EndCurrentPage;
var
  KeepPage: Boolean;
  OverlayOldBounds: TRect;
begin
  if not Assigned(FCanvas) then Exit;

  KeepPage := True;
  try
    try
      { footer forced to bottom }
      if Assigned(FFooterBand) and (FFooterBand.Height > 0) then
      begin
        FPlanner.SetCursor(FPageHeight - FReport.PageSettings.Margins.Bottom - FFooterBand.Height);
        FPrintingFooter := True;
        try
          PrintBand(FFooterBand);
        finally
          FPrintingFooter := False;
        end;
      end;

      { overlay drawn last — spans the full printable area }
      if Assigned(FOverlayBand) and FOverlayBand.Visible then
      begin
        SaveDC(FCanvas.Handle);
        try
          OverlayOldBounds := FOverlayBand.Bounds;
          // Set band Bounds to full page so its children can use absolute positions
          FOverlayBand.Bounds := Rect(0, 0, FPageWidth, FPageHeight);
          var Ctx2: TExpressionContext := Default(TExpressionContext);
          Ctx2.ExpressionMode := ReportExpressionMode;
          Ctx2.Hooks := Self;
          Ctx2.DataSet    := FDataSet;
          Ctx2.UserDataSet := FUserDataSet;
          Ctx2.PageNumber := FPlanner.PageNumber;
          Ctx2.TotalPages := FTotalPagesForPass;
          Ctx2.RowNumber  := FRowNumber;
          Ctx2.PageBottom := FPageHeight - FReport.PageSettings.Margins.Bottom;
          Ctx2.ReportTitle := FReport.Title;
          Ctx2.ReportDate  := FReportDate;
          Ctx2.Parameters  := FParameters;
          Ctx2.Variables   := FReport.Variables;
          Ctx2.IsCountingPass := not FIsRenderingPass;
          var CanPrintBand := True;
          if FIsRenderingPass and Assigned(FOnBeforeBand) then
            FOnBeforeBand(Self, Self, FOverlayBand, Ctx2, CanPrintBand);
          if CanPrintBand then
          begin
            FOverlayBand.Draw(FCanvas, Ctx2);
            if FIsRenderingPass and Assigned(FOnAfterBand) then
              FOnAfterBand(Self, Self, FOverlayBand, Ctx2);
          end;
        finally
          FOverlayBand.Bounds := OverlayOldBounds;
          RestoreDC(FCanvas.Handle, -1);
        end;
      end;
    except
      KeepPage := False;
      raise;
    end;
  finally
    FCanvas.Free; // finalize metafile
    FCanvas := nil;

    if Assigned(FCurrentPage) then
    begin
      if KeepPage then
        FPages.Add(FCurrentPage)
      else
        FCurrentPage.Free;
      FCurrentPage := nil;
    end;
    FPlanner.ClosePage;
  end;
end;

function TReportEngine.ComputeEffectiveBandHeight(ABand: TReportBand;
  ADataSet: TDataSet; AUserDataSet: TVittixUserDataSet): Integer;
var
  Ctx: TExpressionContext;
  MaxBottom: Integer;
begin
  Result := 1;
  if not Assigned(ABand) then Exit;

  Result := ABand.Height;
  if Result <= 0 then
    Result := 1;

  if not (ABand.CanGrow or ABand.CanShrink) then Exit;
  if not Assigned(FCanvas) then Exit;

  if not Assigned(ADataSet) then
    ADataSet := FDataSet;
  if not Assigned(AUserDataSet) then
    AUserDataSet := FUserDataSet;

  Ctx := Default(TExpressionContext);
  Ctx.ExpressionMode := ReportExpressionMode;
  Ctx.Hooks := Self;
  Ctx.DataSet     := ADataSet;
  Ctx.UserDataSet := AUserDataSet;
  Ctx.GroupStart  := FGroupStartBookmark;
  Ctx.GroupEnd    := FGroupEndBookmark;
  Ctx.PageNumber  := FPlanner.PageNumber;
  Ctx.TotalPages  := FTotalPagesForPass;
  Ctx.RowNumber   := FRowNumber;
  Ctx.PageBottom  := FPageHeight - FReport.PageSettings.Margins.Bottom - FPlanner.CursorY;
  Ctx.ReportTitle := FReport.Title;
  Ctx.ReportDate  := FReportDate;
  Ctx.Parameters  := FParameters;
  Ctx.Variables   := FReport.Variables;
  Ctx.IsCountingPass := not FIsRenderingPass;
  // Phase B: measurement contexts report the subreport's natural reserve
  // (bounds bottom) instead of stacking all pending rows.
  Ctx.RowStreaming := True;

  MaxBottom := 0;
  for var Child in ABand.Children do
    if Child.Visible then
    begin
      var CB := Child.MeasuredBottom(FCanvas, Ctx);
      if CB > MaxBottom then
        MaxBottom := CB;
    end;

  if MaxBottom > 0 then
  begin
    var Natural := MaxBottom + 4; // same clearance logic as PrintBand
    if ABand.CanGrow and (Natural > Result) then
      Result := Natural;
    if ABand.CanShrink and (Natural < Result) and (Natural > 0) then
      Result := Natural;
  end;
  if Result <= 0 then
    Result := 1;
end;

function TReportEngine.BandHasChildPageBreak(ABand: TReportBand;
  ABefore: Boolean): Boolean;
begin
  Result := False;
  if not Assigned(ABand) then
    Exit;

  for var Child in ABand.Children do
    if Assigned(Child) and Child.Visible then
      if (ABefore and Child.PageBreakBefore) or
         ((not ABefore) and Child.PageBreakAfter) then
        Exit(True);
end;

{ ================= Space Check ================= }

function TReportEngine.CheckSpace(
  RequiredHeight: Integer): Boolean;
var
  FooterH: Integer;
begin
  FooterH := 0;
  if Assigned(FFooterBand) then
    FooterH := FFooterBand.Height;

  // Phase A: the fit decision is delegated to the planner (same
  // BandFitsOnPage math, planner-owned cursor and page metrics; the live
  // model bottom margin is passed through exactly as before).
  Result := FPlanner.CheckSpace(RequiredHeight,
    FReport.PageSettings.Margins.Bottom, FooterH);
end;

procedure TReportEngine.EnsurePageSpaceForBand(
  ABand: TReportBand; RequiredHeight: Integer; PrintColumnHeader: Boolean);
begin
  if CheckSpace(RequiredHeight) then
    Exit;

  if Assigned(ABand) and ABand.OverridePageSettings then
    ApplyPageSettings(ABand.PageSettings);
  
  StartNewPage;
  PrintPageHeader;
  if PrintColumnHeader and Assigned(FColumnHeaderBand) then
    PrintBandWithSpaceCheck(FColumnHeaderBand, FDataSet);
end;

{ =========== Phase C: nested subreport row streaming (stack) ============ }

{ Restores the logical-stream dataset position. Repeatable on purpose:
  EndStream restores before the band-boundary flush, and the flush itself
  enumerates the dataset, so the final release must restore again. The
  bookmark stays owned by the state until FreeDatasetBookmark. }
procedure TSubReportStreamState.RestoreDataset;
begin
  if not Assigned(DS) then Exit;
  if (not HasSaveBM) or (SaveBM = nil) then Exit;
  if not DS.BookmarkValid(SaveBM) then Exit;
  DS.DisableControls;
  try
    DS.GotoBookmark(SaveBM);
  finally
    DS.EnableControls;
  end;
end;

{ Single bookmark release (the stream state's final release point). }
procedure TSubReportStreamState.FreeDatasetBookmark;
var
  BM: TBookmark;
begin
  BM := SaveBM;
  SaveBM := nil;
  HasSaveBM := False;
  if (BM = nil) or not Assigned(DS) then Exit;
  DS.DisableControls;
  try
    DS.FreeBookmark(BM);
  finally
    DS.EnableControls;
  end;
end;

{ ===== per-stream session token ===== }

constructor TSubReportRowStreamSession.Create(AEngine: TReportEngine;
  AState: TSubReportStreamState);
begin
  inherited Create;
  FEngine := AEngine;
  FState := AState;
end;

{ A session that is destroyed without an explicit EndStream (unexpected
  unwinding between BeginRowStream and the DrawStreamedRows finally) restores
  its dataset; the band-boundary cleanup still releases the state/stack. }
destructor TSubReportRowStreamSession.Destroy;
begin
  if not FEnded then
  begin
    FEnded := True;
    FEngine.AbandonRowStream(FState);
  end;
  inherited;
end;

function TSubReportRowStreamSession.PrepareRow(ARowHeight: Integer): Boolean;
begin
  if FEnded then Exit(False);
  Result := FEngine.PrepareRowFor(FState, ARowHeight);
end;

function TSubReportRowStreamSession.RowTop: Integer;
begin
  Result := FState.LastRowTop;
end;

procedure TSubReportRowStreamSession.EndStream;
begin
  if FEnded then Exit;
  FEnded := True;
  FEngine.EndRowStream(FState);
end;

{ Opens a stream for one subreport Draw invocation and returns its session.
  Unlike Phase B this does NOT refuse when another stream is active: nested
  streams are pushed on the engine stack (Phase C). Refused (nil) only when
  streaming cannot work: depth cap (recursion protection), unusable band,
  inactive dataset. The dataset position is saved exactly once per stream. }
function TReportEngine.BeginRowStream(const AContext: TExpressionContext;
  AMasterBand: TObject; ADS: TDataSet; AMasterField, ADetailField: string;
  AAnchorX, AEntryCursorY, ABoundsLeft, ABoundsTop, ABoundsHeight,
  ABoundsRight, ARowHeight: Integer): IReportNestedRowStream;
var
  S: TSubReportStreamState;
begin
  Result := nil;
  if not Assigned(AMasterBand) then Exit;
  if not Assigned(ADS) or not ADS.Active then Exit;
  if FStreamStack.Count >= MAX_NESTED_STREAM_DEPTH then Exit;

  // Ported from the retired field-based continuation (TryFlowFlatSubReport):
  // linked traversal with suspended controls is a caller-contract violation -
  // fail loudly instead of silently corrupting the traversal.
  if (DataSetMasterSourceDataSet(ADS) = FDataSet) and
     (ADS.ControlsDisabled or FDataSet.ControlsDisabled) then
    raise EReportException.Create(
      'Linked subreport traversal requires master and detail controls enabled.');

  { Geometry validation decision (owner-mandated investigation): the retired
    field-based path raised on non-positive bounds and on bounds exceeding the
    printable width. Those checks are NOT ported: ABounds arrive in band-local
    coordinates, so comparing them against page ContentWidth is a coordinate-
    space mismatch (22 accepted planner/stream fixtures rely on widths that
    exceed it), and the planner/stream design intentionally drops the legacy
    bounds cap - streamed rows are clipped by the canvas page bounds and by
    the engine's page-space flush, exactly like the legacy clipped loop the
    old path fell back to. Removing the checks therefore cannot cause more
    silent clipping than the pre-consolidation behavior. }

  // Release finished-and-complete streams left above the band base (normally
  // already released by EndStream; defensive for abandoned sessions).
  while (FStreamStack.Count > FStreamBaseCount + 1) and
        FStreamStack[FStreamStack.Count - 1].DrawFinished and
        (not FStreamStack[FStreamStack.Count - 1].Deferred) do
    PopStreamState(FStreamStack.Count - 1);

  S := TSubReportStreamState.Create;
  S.MasterBand := TReportBand(AMasterBand);
  S.DS := ADS;
  S.MasterField := AMasterField;
  S.DetailField := ADetailField;
  S.Context := AContext;
  S.AnchorX := AAnchorX;
  S.AnchorY := AEntryCursorY;
  S.BoundsLeft := ABoundsLeft;
  S.BoundsTop := ABoundsTop;
  S.BoundsHeight := ABoundsHeight;
  S.RowHeight := ARowHeight;
  // Page-space top of the first approved row (legacy first-row inset).
  S.NextRowY := AEntryCursorY + ABoundsTop + 2;
  // Link snapshot: deterministic across continuation. A nested stream's parent
  // dataset advances while its rows are drawn, so the band-boundary flush
  // must not depend on the live parent position (Phase B flat streams are
  // unaffected: their master record is the same at Begin and at flush).
  S.MatchAll := True;
  if Assigned(AContext.DataSet) and AContext.DataSet.Active and
     (AMasterField <> '') and (ADetailField <> '') and
     Assigned(AContext.DataSet.FindField(AMasterField)) and
     Assigned(ADS.FindField(ADetailField)) then
  begin
    S.MatchAll := False;
    S.MasterValue := AContext.DataSet.FieldByName(AMasterField).Value;
  end;
  S.HasSaveBM := DataSetSupportsBookmarks(ADS);
  if S.HasSaveBM then
    S.SaveBM := ADS.GetBookmark;
  FStreamStack.Add(S);
  Result := TSubReportRowStreamSession.Create(Self, S);
end;

{ Atomic-row fit decision for one stream. Geometry is page-space
  (NextRowY .. NextRowY + RowHeight) - the same y where DrawStreamedRows
  paints the approved row - measured against the usable bottom every band
  uses (page height - bottom margin - footer reserve), so continued rows can
  never overlap the footer. A deeper, unfinished stream (a deferred nested
  child) defers this stream's next row: the parent must not emit further
  rows until the child has finished (source order at every nesting level). }
function TReportEngine.PrepareRowFor(AState: TSubReportStreamState;
  ARowHeight: Integer): Boolean;
var
  FitBottom, UsableBottom: Integer;
begin
  Result := False;
  if AState = nil then Exit;

  { Oversized-row decision (owner-mandated investigation): the retired
    field-based path raised EReportException for a row taller than the
    printable page area. NOT ported: the accepted planner/stream design
    already terminates such rows with a single forced break and clips them
    (Test_FlatStreaming_OversizedRow_SingleForcedBreak_NoLoop,
    Test_NestedOversizedRow_TerminatesAndClips - bounded page count, rows
    exactly once, content inside physical pages, datasets restored). Raising
    here would contradict that accepted contract. }

  // Deeper pending stream owns the continuation: defer this row so the
  // band-boundary flush resumes the child before this parent row.
  if (FStreamStack.Count > 0) and
     (FStreamStack[FStreamStack.Count - 1] <> AState) then
  begin
    AState.Deferred := True;
    Exit(False);
  end;

  // Nested content of the previous row may have pushed the page cursor below
  // this stream's natural next-row position; never overlap it.
  if AState.LastRowApproved then
    AState.NextRowY := Max(AState.NextRowY, FPlanner.CursorY);

  FitBottom := AState.NextRowY + ARowHeight;
  UsableBottom := FPageHeight - FReport.PageSettings.Margins.Bottom;
  if Assigned(FFooterBand) then
    Dec(UsableBottom, FFooterBand.Height);

  if FitBottom <= UsableBottom then
  begin
    AState.LastRowTop := AState.NextRowY;
    AState.LastRowApproved := True;
    FPlanner.SetCursor(Max(FPlanner.CursorY, FitBottom));
    Inc(AState.EmittedCount);
    Result := True;
  end
  else begin
    AState.Deferred := True;
  end;
end;

{ The subreport's Draw loop returned for this stream. Restore the dataset
  position (the flush re-enumerates deterministically, so it never depends on
  the live position) and release the state when nothing is pending. A
  deferred stream stays on the stack for the band-boundary flush. }
procedure TReportEngine.EndRowStream(AState: TSubReportStreamState);
begin
  if AState = nil then Exit;
  AState.RestoreDataset;
  AState.DrawFinished := True;
  if not AState.Deferred then
    while (FStreamStack.Count > FStreamBaseCount + 1) and
          FStreamStack[FStreamStack.Count - 1].DrawFinished and
          (not FStreamStack[FStreamStack.Count - 1].Deferred) do
      PopStreamState(FStreamStack.Count - 1);
end;

{ Session finalization without EndStream (exception path): restore the
  dataset; the band-boundary cleanup still releases the state. }
procedure TReportEngine.AbandonRowStream(AState: TSubReportStreamState);
begin
  if AState = nil then Exit;
  AState.RestoreDataset;
  AState.DrawFinished := True;
end;

procedure TReportEngine.PopStreamState(AIndex: Integer);
var
  S: TSubReportStreamState;
begin
  if (AIndex < 0) or (AIndex >= FStreamStack.Count) then Exit;
  S := FStreamStack[AIndex];
  S.RestoreDataset;
  S.FreeDatasetBookmark;
  FStreamStack.Delete(AIndex);
end;

{ Releases every stream at or above the band base (restores each dataset
  position first). Used by the band boundary and by per-pass/destructor
  cleanup; safe to call repeatedly. }
procedure TReportEngine.ReleaseStreamsAbove(ABaseCount: Integer);
begin
  while FStreamStack.Count > ABaseCount do
    PopStreamState(FStreamStack.Count - 1);
end;

{ Link matching for a stream: the captured snapshot is compared with the
  candidate detail row, replicating the legacy rule (empty/missing field names
  or unusable master dataset => every row matches). }
function TReportEngine.StreamLinkMatches(AState: TSubReportStreamState;
  ADS: TDataSet): Boolean;
begin
  Result := True;
  if AState.MatchAll then Exit;
  if not Assigned(ADS) then Exit(False);
  if not Assigned(ADS.FindField(AState.DetailField)) then Exit(True);
  Result := VarSameValue(AState.MasterValue,
    ADS.FieldByName(AState.DetailField).Value);
end;

{ Restores the snapshot invariant for MasterSource-linked detail datasets:
  TDataSet.First on a MasterSource-linked detail re-filters the view to the
  LIVE parent's current row, so flush-time enumeration would silently see a
  different row universe than the one the stream captured at BeginRowStream
  (the NestedRows data-loss defect). Re-pointing the parent to the stream's
  captured link value makes the filtered view match the snapshot again, so
  First/Next enumeration plus EmittedCount skipping stays deterministic and
  never depends on the live parent position.

  Raises EReportException when a linked stream's captured parent snapshot
  cannot be aligned: the live detail view then belongs to a DIFFERENT parent
  row, and continuing would either substitute unrelated data or silently
  omit the remaining rows - so the report fails explicitly instead. MatchAll
  and unlinked streams need no alignment and always return True. Every
  failure is also counted in TReportTraversalDiagnostics.StreamAlignFailures. }
function TReportEngine.AlignDetailToSnapshot(AState: TSubReportStreamState): Boolean;
var
  ParentDS: TDataSet;
begin
  Result := True;
  if (AState = nil) or AState.MatchAll then Exit;
  // Distinguish a genuinely unlinked dataset (no MasterSource property
  // assigned - nothing to align, proceed) from a BROKEN linked dataset
  // (MasterSource assigned but its parent cannot be resolved - that is a
  // failure, not an unlinked stream).
  if not DataSetHasMasterSource(AState.DS) then
    Exit(True);
  ParentDS := DataSetMasterSourceDataSet(AState.DS);
  if not Assigned(ParentDS) then
  begin
    TReportTraversalDiagnostics.StreamAlignFailed;
    raise EReportException.CreateFmt(
      'Subreport detail snapshot cannot be aligned: the detail dataset has a ' +
      'MasterSource but its parent dataset cannot be resolved during ' +
      'pagination continuation. The report is aborted rather than rendering ' +
      'rows from an unrelated parent view.', []);
  end;
  // Linked detail: the parent must still exist with the captured link field,
  // and the snapshot row must still be locatable on it.
  if not ParentDS.Active or (AState.MasterField = '') or
     not Assigned(ParentDS.FindField(AState.MasterField)) then
  begin
    TReportTraversalDiagnostics.StreamAlignFailed;
    raise EReportException.CreateFmt(
      'Subreport detail snapshot cannot be aligned: the master-linked parent ' +
      'dataset or its link field "%s" became unavailable during pagination ' +
      'continuation. The report is aborted rather than rendering rows from ' +
      'an unrelated parent view.', [AState.MasterField]);
  end;
  if not ParentDS.Locate(AState.MasterField, AState.MasterValue, []) then
  begin
    TReportTraversalDiagnostics.StreamAlignFailed;
    raise EReportException.CreateFmt(
      'Subreport detail snapshot cannot be aligned: the captured master link ' +
      'value is no longer present in the parent dataset during pagination ' +
      'continuation. The report is aborted rather than rendering rows from ' +
      'an unrelated parent view.', []);
  end;
end;

{ Deterministic enumeration: is there a not-yet-emitted matched row?
  Always enumerates from First and skips the EmittedCount already matched
  rows, never the live dataset position (continuation must not depend on it). }
function TReportEngine.FindNextMatchedRow(AState: TSubReportStreamState): Boolean;
var
  Seen: Integer;
begin
  Result := False;
  if (AState = nil) or not Assigned(AState.DS) or not AState.DS.Active then Exit;
  AlignDetailToSnapshot(AState);   // raises on unalignable linked snapshot
  AState.DS.DisableControls;
  try
    Seen := 0;
    AState.DS.First;
    while not AState.DS.Eof do
    begin
      if StreamLinkMatches(AState, AState.DS) then
      begin
        Inc(Seen);
        if Seen > AState.EmittedCount then Exit(True);
      end;
      AState.DS.Next;
    end;
  finally
    AState.DS.EnableControls;
  end;
end;

{ Paints the next not-yet-emitted matched row at the continuation position
  (the page cursor) with the same page-content clip the engine uses for bands.
  SubCtx keeps RowStream set so a subreport inside a flushed row can continue
  too; PageNumber is refreshed so [PageNo] is the page the row paints on. }
procedure TReportEngine.PaintStreamRow(AState: TSubReportStreamState);
var
  Seen: Integer;
  SubCtx: TExpressionContext;
begin
  if (AState = nil) or not Assigned(AState.DS) or not AState.DS.Active then Exit;
  AlignDetailToSnapshot(AState);   // raises on unalignable linked snapshot
  AState.DS.DisableControls;
  try
    Seen := 0;
    AState.DS.First;
    while not AState.DS.Eof do
    begin
      TReportTraversalDiagnostics.SubReportRowVisited;
      if StreamLinkMatches(AState, AState.DS) then
      begin
        Inc(Seen);
        if Seen > AState.EmittedCount then
        begin
          SubCtx := AState.Context;
          SubCtx.DataSet := AState.DS;
          SubCtx.RowStream := Self;   // nested continuation inside flushed rows
          SubCtx.RowStreaming := False;
          SubCtx.PageNumber := FPlanner.PageNumber;
          SaveDC(FCanvas.Handle);
          try
            SetViewportOrgEx(FCanvas.Handle,
              AState.AnchorX + AState.BoundsLeft + 2,
              FPlanner.CursorY, nil);
            IntersectClipRect(FCanvas.Handle, 0, 0,
              FPageWidth - FReport.PageSettings.Margins.Left -
              FReport.PageSettings.Margins.Right,
              FPageHeight);
            AState.MasterBand.Draw(FCanvas, SubCtx);
          finally
            RestoreDC(FCanvas.Handle, -1);
          end;
          Exit;
        end;
      end;
      AState.DS.Next;
    end;
  finally
    AState.DS.EnableControls;
  end;
end;

{ Band-boundary continuation flush, depth-first: the deepest deferred stream
  emits first, so a child finishes before its parent's next row. Each row is
  one complete atomic unit; the page check is the existing band policy (one
  break + page/column-header re-emission on failure) and the cursor never
  moves backwards. The band's base stream is kept (never popped here) so
  PrintBand can apply the end-of-band rule. A row painted here may push a
  deeper stream; the next iteration flushes that child first. }
procedure TReportEngine.FlushPendingStreams(const AContext: TExpressionContext;
  ABaseCount: Integer; var AFlushRan: Boolean);
var
  S: TSubReportStreamState;
  RowTop: Integer;
begin
  AFlushRan := False;
  while FStreamStack.Count > ABaseCount do
  begin
    S := FStreamStack[FStreamStack.Count - 1];
    if S.DrawFinished and not S.Deferred then
    begin
      if FStreamStack.Count - 1 > ABaseCount then
        PopStreamState(FStreamStack.Count - 1)
      else
        Break;
      Continue;
    end;

    if Assigned(FProgress) and FProgress.IsCancelled then
      Break;

    if not FindNextMatchedRow(S) then
    begin
      S.Deferred := False;
      S.DrawFinished := True;
      if FStreamStack.Count - 1 > ABaseCount then
        PopStreamState(FStreamStack.Count - 1)
      else
        Break;
      Continue;
    end;

    // A page break may only happen here, at the band boundary: page headers
    // printed from it must neither start nor flush streams (FInStreamFlush).
    FInStreamFlush := True;
    try
      EnsurePageSpaceForBand(nil, S.RowHeight, True);
    finally
      FInStreamFlush := False;
    end;

    RowTop := FPlanner.CursorY;
    PaintStreamRow(S);
    FPlanner.SetCursor(Max(FPlanner.CursorY, RowTop + S.RowHeight));
    Inc(S.EmittedCount);
    AFlushRan := True;
  end;
end;

procedure TReportEngine.BeginPass(
  ATotalPages: Integer; AReportProgress: Boolean; out ATotalRows, ARowNumber: Integer);
var
  I: Integer;
  HasGroupLevelBookmarks: Boolean;
begin
  FPages.Clear;
  if AReportProgress and Assigned(FExportDocument) then
    FExportDocument.Pages.Clear;
  FPlanner.ResetSession;
  // Phase C: never leak stream state into the next pass/report.
  ReleaseStreamsAbove(0);
  FRowNumber := 0;
  FTotalPagesForPass := ATotalPages;

  FPageWidth := FReport.PageSettings.PageWidth;
  FPageHeight := FReport.PageSettings.PageHeight;
  FPlanner.SetPageMetrics(FPageWidth, FPageHeight);
  if FIsRenderingPass then
    FPlanner.SetMode(ppmRender)
  else
    FPlanner.SetMode(ppmCount);
  FPlanner.SetDocument(FExportDocument);

  CacheBands;
  ResetObjectCaches(FReport.Objects);

  ATotalRows := 0;
  if AReportProgress and Assigned(FProgress) then
  begin
    // The host hook (see Vittix.Report.Interfaces) may veto the RecordCount
    // total - e.g. a FireDAC on-demand cursor only knows the fetched-so-far
    // count, which must not be published as a total.  With no hook the
    // historical SafeRecordCount behavior is kept.
    if Assigned(ProgressTotalHook) then
    begin
      if ProgressTotalHook(FDataSet, ATotalRows) then
        FProgress.SetTotal(ATotalRows)
      else
        FProgress.SetTotal(0); // unknown total
    end
    else
    begin
      ATotalRows := SafeRecordCount(FDataSet);
      FProgress.SetTotal(ATotalRows);
    end;
  end;
  ARowNumber := 0;

  FGroupStartBookmark := nil;
  FGroupEndBookmark := nil;
  FHasGroupStartBookmark := False;
  FHasGroupEndBookmark := False;
  HasGroupLevelBookmarks := False;
  for I := 0 to High(FHasGroupStartBookmarks) do
    HasGroupLevelBookmarks := HasGroupLevelBookmarks or FHasGroupStartBookmarks[I];
  for I := 0 to High(FHasGroupEndBookmarks) do
    HasGroupLevelBookmarks := HasGroupLevelBookmarks or FHasGroupEndBookmarks[I];
  if Assigned(FDataSet) and HasGroupLevelBookmarks and
     DataSetSupportsBookmarks(FDataSet) then
  begin
    for I := 0 to High(FGroupStartBookmarks) do
      if (I <= High(FHasGroupStartBookmarks)) and FHasGroupStartBookmarks[I] then
        FDataSet.FreeBookmark(FGroupStartBookmarks[I]);
    for I := 0 to High(FGroupEndBookmarks) do
      if (I <= High(FHasGroupEndBookmarks)) and FHasGroupEndBookmarks[I] then
        FDataSet.FreeBookmark(FGroupEndBookmarks[I]);
  end;
  SetLength(FGroupStartBookmarks, 0);
  SetLength(FGroupEndBookmarks, 0);
  SetLength(FHasGroupStartBookmarks, 0);
  SetLength(FHasGroupEndBookmarks, 0);
end;

procedure TReportEngine.PrintFirstPageBands;
begin
  StartNewPage;

  if Assigned(FTitleBand) then
    PrintBand(FTitleBand);

  PrintPageHeader;
  if Assigned(FColumnHeaderBand) then
    PrintBand(FColumnHeaderBand);
end;

function TReportEngine.InitializeActiveGroupHeaders(
  out AActiveGroupHeader: TBooleanDynArray): Boolean;
var
  I: Integer;
  GH: TReportBand;
  GroupByField: TField;
begin
  SetLength(FLastGroupValues, FGroupHeaders.Count);
  SetLength(AActiveGroupHeader, FGroupHeaders.Count);
  Result := False;
  for I := 0 to High(FLastGroupValues) do
  begin
    FLastGroupValues[I] := Null;
    GH := FGroupHeaders[I];
    GroupByField := nil;
    AActiveGroupHeader[I] :=
      PrimarySourceActive and (Trim(GH.GroupField) <> '') and
      (Assigned(FUserDataSet) or TryGetField(FDataSet, GH.GroupField, GroupByField));
    if AActiveGroupHeader[I] then
      Result := True;
  end;
end;

function TReportEngine.DetectGroupBreak(
  const AActiveGroupHeader: TBooleanDynArray): Integer;
var
  I: Integer;
  GH: TReportBand;
  GroupByField: TField;
  NewValue: Variant;
begin
  Result := -1;
  for I := 0 to FGroupHeaders.Count - 1 do
  begin
    if not AActiveGroupHeader[I] then
      Continue;

    GH := FGroupHeaders[I];
    GroupByField := nil;
    if not Assigned(FUserDataSet) and not TryGetField(FDataSet, GH.GroupField, GroupByField) then
      Continue;

    NewValue := SourceFieldValue(FDataSet, FUserDataSet, GH.GroupField);
    // DP-16: strict value identity. The old '<>' coerced across variant
    // types (integer 1 and string '1' compared equal, silently merging
    // groups) - and so does VarSameValue on its own (it delegates to
    // VarCompareValue, which converts numeric strings), hence the explicit
    // VarType guard first. Null handling is explicit and preserves the
    // previous semantics exactly: a Null sentinel/previous value opens,
    // and a value->NULL transition fires ('<>' against Null already
    // evaluated truthy - pinned by Test_GroupBreak_NullTransitions_Fire).
    if VarIsNull(FLastGroupValues[I]) or
       VarIsNull(NewValue) or
       (VarType(NewValue) <> VarType(FLastGroupValues[I])) or
       not VarSameValue(NewValue, FLastGroupValues[I]) then
      Exit(I);
  end;
end;

function TReportEngine.ProcessCurrentMasterRecord(
  AReportProgress: Boolean; var ARowNumber: Integer): Boolean;
var
  EffH: Integer;
begin
  Inc(ARowNumber);
  FRowNumber := ARowNumber;

  EffH := ComputeEffectiveBandHeight(FMasterBand, FDataSet, FUserDataSet);
  EnsurePageSpaceForBand(FMasterBand, EffH + ComputeFirstDetailRowsHeight, True);
  PrintBand(FMasterBand, FDataSet, EffH, FUserDataSet);
  PrintDetailBands;

  Result := True;
  if AReportProgress and Assigned(FProgress) then
  begin
    FProgress.Advance(ARowNumber);
    Result := not FProgress.IsCancelled;
  end;
end;


procedure TReportEngine.ProcessMasterDataLoop(
  const AActiveGroupHeader: TBooleanDynArray; AReportProgress: Boolean;
  var ARowNumber: Integer; var AHasOpenedGroups: Boolean);
var
  BreakLevel: Integer;
  SaveBM: TBookmark;
  HasSaveBM: Boolean;
  Band: TReportBand;
  HasMasterLinkedDetail: Boolean;
begin
  if not PrimarySourceActive then
    Exit;

  if Assigned(FUserDataSet) then
  begin
    FUserDataSet.First;
    while not FUserDataSet.Eof do
    begin
      FRowNumber := ARowNumber + 1;
      BreakLevel := DetectGroupBreak(AActiveGroupHeader);

      if (BreakLevel >= 0) and AHasOpenedGroups then
        CloseGroupsForBreak(BreakLevel, AActiveGroupHeader);

      if BreakLevel >= 0 then
        OpenGroupsForBreak(BreakLevel, AActiveGroupHeader, AHasOpenedGroups);

      if not ProcessCurrentMasterRecord(AReportProgress, ARowNumber) then
        Break;

      FUserDataSet.Next;
    end;
  end;
  if not Assigned(FDataSet) or not FDataSet.Active then
    Exit;

  HasMasterLinkedDetail := False;
  for Band in FDetailBands do
    if (DataSetMasterSourceDataSet(ResolveBandDataSet(Band)) = FDataSet) or
       DataSetIsMasterLinked(ResolveBandDataSet(Band)) then
    begin
      HasMasterLinkedDetail := True;
      Break;
    end;
  if not HasMasterLinkedDetail and Assigned(FNamedDataSets) then
    for var Pair in FNamedDataSets do
      if (DataSetMasterSourceDataSet(Pair.Value) = FDataSet) or
         DataSetIsMasterLinked(Pair.Value) then
      begin
        HasMasterLinkedDetail := True;
        Break;
      end;

  if HasMasterLinkedDetail and FDataSet.ControlsDisabled then
    raise EReportException.Create(
      'Master/detail traversal requires master controls enabled. ' +
      'Enable caller-disabled controls before preparing this report.');

  HasSaveBM := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(FDataSet, SaveBM);
  // MasterSource datasets depend on cursor notifications to refresh their
  // visible rows, so leave master controls enabled for those reports. Other
  // reports retain the existing controls-suppressed traversal.
  if not HasMasterLinkedDetail then
    FDataSet.DisableControls;
  try
    FDataSet.First;
    while not FDataSet.Eof do
    begin
      FRowNumber := ARowNumber + 1;
      BreakLevel := DetectGroupBreak(AActiveGroupHeader);

      if (BreakLevel >= 0) and AHasOpenedGroups then
        CloseGroupsForBreak(BreakLevel, AActiveGroupHeader);

      if BreakLevel >= 0 then
        OpenGroupsForBreak(BreakLevel, AActiveGroupHeader, AHasOpenedGroups);

      if not ProcessCurrentMasterRecord(AReportProgress, ARowNumber) then
        Break;

      FDataSet.Next;
    end;
  finally
    Vittix.Report.LayoutBookmarks.RestoreDataSetBookmark(FDataSet, SaveBM, HasSaveBM);
    if not HasMasterLinkedDetail then
      FDataSet.EnableControls;
  end;
end;

procedure TReportEngine.CaptureGroupStartBookmark(ALevel: Integer);
var
  L: Integer;
begin
  if ALevel >= 0 then
  begin
    L := ALevel;
    if Length(FGroupStartBookmarks) <= L then
    begin
      SetLength(FGroupStartBookmarks, L + 1);
      SetLength(FHasGroupStartBookmarks, L + 1);
    end;
    if Assigned(FDataSet) and DataSetSupportsBookmarks(FDataSet) then
    begin
      if FHasGroupStartBookmarks[L] then
        FDataSet.FreeBookmark(FGroupStartBookmarks[L]);
      FGroupStartBookmarks[L] := FDataSet.GetBookmark;
      FHasGroupStartBookmarks[L] := True;
    end
    else
      FHasGroupStartBookmarks[L] := False;
    Exit;
  end;

  if Assigned(FDataSet) and DataSetSupportsBookmarks(FDataSet) then
  begin
    if FHasGroupStartBookmark then
      FDataSet.FreeBookmark(FGroupStartBookmark);
    FGroupStartBookmark := FDataSet.GetBookmark;
    FHasGroupStartBookmark := True;
  end
  else
  begin
    FGroupStartBookmark := nil;
    FHasGroupStartBookmark := False;
  end;
end;

procedure TReportEngine.CaptureGroupEndBookmark(ALevel: Integer);
var
  L: Integer;
begin
  if ALevel >= 0 then
  begin
    L := ALevel;
    if Length(FGroupEndBookmarks) <= L then
    begin
      SetLength(FGroupEndBookmarks, L + 1);
      SetLength(FHasGroupEndBookmarks, L + 1);
    end;
    if Assigned(FDataSet) and DataSetSupportsBookmarks(FDataSet) then
    begin
      if FHasGroupEndBookmarks[L] then
        FDataSet.FreeBookmark(FGroupEndBookmarks[L]);
      FGroupEndBookmarks[L] := FDataSet.GetBookmark;
      FHasGroupEndBookmarks[L] := True;
    end
    else
      FHasGroupEndBookmarks[L] := False;
    Exit;
  end;

  if Assigned(FDataSet) and DataSetSupportsBookmarks(FDataSet) then
  begin
    if FHasGroupEndBookmark then
      FDataSet.FreeBookmark(FGroupEndBookmark);
    FGroupEndBookmark := FDataSet.GetBookmark;
    FHasGroupEndBookmark := True;
  end
  else
  begin
    FGroupEndBookmark := nil;
    FHasGroupEndBookmark := False;
  end;
end;

function TReportEngine.IsGroupLevelActive(
  const AActiveGroupHeader: TBooleanDynArray; ALevel: Integer): Boolean;
var
  J: Integer;
begin
  Result := False;
  for J := 0 to FGroupHeaders.Count - 1 do
    if AActiveGroupHeader[J] and (FGroupHeaders[J].GroupLevel = ALevel) then
      Exit(True);
end;

procedure TReportEngine.CloseGroupsForBreak(
  ABreakLevel: Integer; const AActiveGroupHeader: TBooleanDynArray);
var
  I: Integer;
  GF: TReportBand;
begin
  for I := 0 to FGroupFooters.Count - 1 do
  begin
    GF := FGroupFooters[I];
    if (GF.GroupLevel >= ABreakLevel) and IsGroupLevelActive(AActiveGroupHeader, GF.GroupLevel) then
    begin
      CaptureGroupEndBookmark(GF.GroupLevel);
      PrintBandWithSpaceCheck(GF);
    end;
  end;
end;

procedure TReportEngine.OpenGroupsForBreak(
  ABreakLevel: Integer; const AActiveGroupHeader: TBooleanDynArray; var AHasOpenedGroups: Boolean);
var
  I: Integer;
  GH: TReportBand;
  GroupByField: TField;
  OpenedThisBreak: Boolean;
  ColumnHeaderH: Integer;
  PageBeforeColumnHeader: Integer;
begin
  OpenedThisBreak := False;
  for I := ABreakLevel to FGroupHeaders.Count - 1 do
  begin
    if not AActiveGroupHeader[I] then
      Continue;

    GH := FGroupHeaders[I];
    if GH.StartNewPage then
    begin
      if GH.OverridePageSettings then
        ApplyPageSettings(GH.PageSettings);
      StartNewPage;
      PrintPageHeader;
    end;

    CaptureGroupStartBookmark(GH.GroupLevel);

    PrintBandWithSpaceCheck(GH);
    OpenedThisBreak := True;

    if Assigned(FColumnHeaderBand) then
    begin
      ColumnHeaderH := ComputeEffectiveBandHeight(FColumnHeaderBand, FDataSet);
      PageBeforeColumnHeader := FPlanner.PageNumber;
      EnsurePageSpaceForBand(FColumnHeaderBand, ColumnHeaderH, True);
      if FPlanner.PageNumber = PageBeforeColumnHeader then
        PrintBand(FColumnHeaderBand, FDataSet, ColumnHeaderH);
    end;

    GroupByField := nil;
    if Assigned(FUserDataSet) or TryGetField(FDataSet, GH.GroupField, GroupByField) then
      FLastGroupValues[I] := SourceFieldValue(FDataSet, FUserDataSet, GH.GroupField);
  end;

  if OpenedThisBreak then
    AHasOpenedGroups := True;

end;

procedure TReportEngine.CloseRemainingGroups(
  const AActiveGroupHeader: TBooleanDynArray; AHasAnyActiveGroup,
  AHasOpenedGroups: Boolean);
var
  GF: TReportBand;
begin
  if not (AHasOpenedGroups and AHasAnyActiveGroup) then
    Exit;

  for GF in FGroupFooters do
    if IsGroupLevelActive(AActiveGroupHeader, GF.GroupLevel) then
    begin
      CaptureGroupEndBookmark(GF.GroupLevel);
      PrintBandWithSpaceCheck(GF);
    end;
end;

procedure TReportEngine.PrintSummaryWithSpaceCheck;
var
  EffH: Integer;
begin
  if not Assigned(FSummaryBand) then
    Exit;

  EffH := ComputeEffectiveBandHeight(FSummaryBand, FDataSet);
  EnsurePageSpaceForBand(FSummaryBand, EffH);
  PrintBand(FSummaryBand, FDataSet, EffH);
end;

function TReportEngine.FinalizePass(
  const AActiveGroupHeader: TBooleanDynArray; AHasAnyActiveGroup,
  AHasOpenedGroups: Boolean): Integer;
begin
  CloseRemainingGroups(AActiveGroupHeader, AHasAnyActiveGroup, AHasOpenedGroups);
  PrintSummaryWithSpaceCheck;
  EndCurrentPage;
  Result := FPlanner.PageNumber;
end;

{ ================= Band Printing ================= }

procedure TReportEngine.PrintBand(ABand: TReportBand; ADataSet: TDataSet;
  AEffectiveHeight: Integer; AUserDataSet: TVittixUserDataSet);
var
  Ctx: TExpressionContext;
  AdjustedObjs: array of TReportObject;
  OriginalBounds: array of TRect;
  AdjustedCount: Integer;
  EffectiveH: Integer;
  GroupLevel: Integer;
  BaseCount: Integer;
begin
  if not Assigned(ADataSet) then
    ADataSet := FDataSet;
  if not Assigned(AUserDataSet) then
    AUserDataSet := FUserDataSet;

  if not Assigned(ABand) then Exit;
  if not Assigned(FCanvas) then Exit;
  if ABand.Height <= 0 then Exit;

  // Phase C: streams created while this band draws belong to this band. A
  // re-entrant PrintBand (page/column header during a continuation flush)
  // records its own base and never touches the enclosing band's streams.
  BaseCount := FStreamStack.Count;

  // Respect Visible flag
  if not ABand.Visible then Exit;

  if (ABand.StartNewPage or BandHasChildPageBreak(ABand, True)) and
     (FPlanner.CursorY > FReport.PageSettings.Margins.Top) and
     not FPrintingFooter then
  begin
    if ABand.OverridePageSettings then
      ApplyPageSettings(ABand.PageSettings);
    StartNewPage;
    PrintPageHeader(True);
  end;

  // Evaluate PrintWhen expression — skip band if result is falsy
  if ABand.PrintWhen <> '' then
  begin
    var Ctx0: TExpressionContext := Default(TExpressionContext);
    Ctx0.ExpressionMode := ReportExpressionMode;
    Ctx0.Hooks := Self;
    Ctx0.DataSet     := ADataSet;
    Ctx0.UserDataSet := AUserDataSet;
    Ctx0.PageNumber := FPlanner.PageNumber;
    Ctx0.TotalPages := FTotalPagesForPass;
    Ctx0.RowNumber := FRowNumber;
    Ctx0.PageBottom := FPageHeight - FReport.PageSettings.Margins.Bottom - FPlanner.CursorY;
    Ctx0.ReportTitle := FReport.Title;
    Ctx0.ReportDate  := FReportDate;
    Ctx0.Parameters  := FParameters;
    Ctx0.Variables   := FReport.Variables;
    Ctx0.IsCountingPass := not FIsRenderingPass;
    var PWResult: Variant;
    var ShouldPrint: Boolean;
    try
      PWResult := TReportExpression.Evaluate(ABand.PrintWhen, Ctx0);
      ShouldPrint := ConditionVariantToBool(PWResult);
    except
      // Frozen fallback: an invalid PrintWhen prints nothing.  Observed via
      // diagnostics only; output is unchanged.
      TReportTraversalDiagnostics.BandPrintWhenException;
{$IFDEF DEBUG}
      OutputDebugString(PChar(Format(
        'VittixReport: band PrintWhen "%s" raised; the band is skipped (legacy silent fallback)',
        [ABand.PrintWhen])));
{$ENDIF}
      ShouldPrint := False;
    end;
    if not ShouldPrint then Exit;
  end;

  // Build render context early — needed for CanGrow MeasuredBottom calls
  Ctx := Default(TExpressionContext);
  Ctx.ExpressionMode := ReportExpressionMode;
  Ctx.Hooks := Self;
  Ctx.DataSet     := ADataSet;
  Ctx.UserDataSet := AUserDataSet;
  Ctx.GroupStart  := FGroupStartBookmark;
  Ctx.GroupEnd    := FGroupEndBookmark;
  GroupLevel := ABand.GroupLevel;
  if ABand.BandType = btGroupFooter then
  begin
    if (GroupLevel >= 0) and (GroupLevel < Length(FGroupStartBookmarks)) and
       FHasGroupStartBookmarks[GroupLevel] then
      Ctx.GroupStart := FGroupStartBookmarks[GroupLevel];
    if (GroupLevel >= 0) and (GroupLevel < Length(FGroupEndBookmarks)) and
       FHasGroupEndBookmarks[GroupLevel] then
      Ctx.GroupEnd := FGroupEndBookmarks[GroupLevel];
  end;
  Ctx.PageNumber  := FPlanner.PageNumber;
  Ctx.TotalPages  := FTotalPagesForPass;
  Ctx.RowNumber   := FRowNumber;
  Ctx.PageBottom  := FPageHeight - FReport.PageSettings.Margins.Bottom - FPlanner.CursorY;
  Ctx.ReportTitle := FReport.Title;
  Ctx.ReportDate  := FReportDate;
  Ctx.Parameters  := FParameters;
  Ctx.Variables   := FReport.Variables;
  Ctx.IsCountingPass := not FIsRenderingPass;
  // Phase C: streaming coordination. RowStreaming switches MeasuredBottom to
  // the natural reserve during measurement below; RowStream hands Draw the
  // engine's stream accessor. A band printed from a continuation flush (page
  // header / column header) must not start or flush streams, so it gets nil.
  Ctx.RowStreaming := True;
  if (FStreamStack.Count = 0) and (not FPrintingFooter) and
     (not FInStreamFlush) then
    Ctx.RowStream := Self;
  var CanPrintBand := True;
  if FIsRenderingPass and Assigned(FOnBeforeBand) then
    FOnBeforeBand(Self, Self, ABand, Ctx, CanPrintBand);
  if not CanPrintBand then
    Exit;

  // CanGrow / CanShrink — compute effective height using MeasuredBottom
  // (TReportMemoObject overrides MeasuredBottom to compute dynamic text height)
  if (ABand.OnBeforePrint <> '') and Assigned(FScriptEngine) then
    FScriptEngine.ExecuteBeforePrint(ABand.OnBeforePrint, Ctx);

  EffectiveH := AEffectiveHeight;
  if EffectiveH <= 0 then
  begin
    EffectiveH := ABand.Height;
    if ABand.CanGrow or ABand.CanShrink then
    begin
      var MaxBottom := 0;
      for var Child in ABand.Children do
        if Child.Visible then
        begin
          var CB := Child.MeasuredBottom(FCanvas, Ctx);
          if CB > MaxBottom then MaxBottom := CB;
        end;
      if MaxBottom > 0 then
      begin
        var Natural := MaxBottom + 4; // 4px bottom clearance
        if ABand.CanGrow and (Natural > EffectiveH) then
          EffectiveH := Natural;
        if ABand.CanShrink and (Natural < EffectiveH) and (Natural > 0) then
          EffectiveH := Natural;
      end;
    end;
  end;

  AdjustedCount := 0;
  if EffectiveH > ABand.Height then
  begin
    for var Child in ABand.Children do
      if Child.Visible then
      begin
        var CB := Child.MeasuredBottom(FCanvas, Ctx);
        if CB > Child.Bounds.Bottom then
        begin
          SetLength(AdjustedObjs, AdjustedCount + 1);
          SetLength(OriginalBounds, AdjustedCount + 1);
          AdjustedObjs[AdjustedCount] := Child;
          OriginalBounds[AdjustedCount] := Child.Bounds;
          Inc(AdjustedCount);

          var NewB := Child.Bounds;
          NewB.Bottom := CB;
          Child.Bounds := NewB;
        end;
      end;
  end;

  // Translate the DC to the printable content origin.
  // The top margin is tracked by the planner cursor; the left margin applies to all bands.
  // Phase B: the outer try/finally guarantees stream cleanup and a dataset
  // restore on every band exit path (completion, cancellation, exception).
  try
    SaveDC(FCanvas.Handle);
    try
      FExportOriginX := FReport.PageSettings.Margins.Left;
      FExportOriginY := FPlanner.CursorY;
      SetViewportOrgEx(
        FCanvas.Handle,
        FReport.PageSettings.Margins.Left,
        FPlanner.CursorY,
        nil);
      IntersectClipRect(
        FCanvas.Handle,
        0,
        0,
        FPageWidth - FReport.PageSettings.Margins.Left - FReport.PageSettings.Margins.Right,
        FPageHeight);
      ABand.Draw(FCanvas, Ctx);
      if FIsRenderingPass and Assigned(FOnAfterBand) then
        FOnAfterBand(Self, Self, ABand, Ctx);
      if (ABand.OnAfterPrint <> '') and Assigned(FScriptEngine) then
        FScriptEngine.ExecuteAfterPrint(ABand.OnAfterPrint, Ctx);
    finally
      FExportOriginX := 0;
      FExportOriginY := 0;
      for var I := AdjustedCount - 1 downto 0 do
        AdjustedObjs[I].Bounds := OriginalBounds[I];
      RestoreDC(FCanvas.Handle, -1);
    end;

    // Phase C: continuation is owned by the engine stream stack and flushed
    // only here, at the band boundary (a page break must never happen inside a
    // band draw). Depth-first: a deferred nested child finishes before its
    // parent's next row. No-defer + no-flush keeps the Phase B end-of-band
    // rule, evaluated on this band's base stream; otherwise the flush already
    // positioned the cursor at the last continued row.
    if (FStreamStack.Count > BaseCount) and (not FInStreamFlush) then
    begin
      var FlushRan := False;
      try
        FlushPendingStreams(Ctx, BaseCount, FlushRan);
        if (not FlushRan) and (FStreamStack.Count > BaseCount) and
           (not FStreamStack[BaseCount].Deferred) then
        begin
          var S0 := FStreamStack[BaseCount];
          var NaturalEnd := S0.AnchorY + S0.BoundsTop + S0.BoundsHeight;
          var StackEnd := S0.AnchorY + S0.BoundsTop +
            (4 + S0.EmittedCount * S0.RowHeight) + 4;
          var LegacyEnd := S0.AnchorY + EffectiveH;
          var NewEnd := LegacyEnd;
          if StackEnd > NewEnd then NewEnd := StackEnd;
          if NaturalEnd > NewEnd then NewEnd := NaturalEnd;
          if FPlanner.CursorY > NewEnd then NewEnd := FPlanner.CursorY;
          FPlanner.SetCursor(NewEnd);
        end;
      finally
        ReleaseStreamsAbove(BaseCount);
      end;
    end
    else
      FPlanner.AdvanceCursor(EffectiveH);
  finally
    // Every band exit path (completion, cancellation, exception during the
    // draw or the flush) restores and releases the streams this band created.
    if FStreamStack.Count > BaseCount then
      ReleaseStreamsAbove(BaseCount);
  end;

  if BandHasChildPageBreak(ABand, False) and not FPrintingFooter then
  begin
    StartNewPage;
    PrintPageHeader(True);
  end;
end;

procedure TReportEngine.PrintBandWithSpaceCheck(ABand: TReportBand;
  ADataSet: TDataSet; AUserDataSet: TVittixUserDataSet);
var
  EffH: Integer;
begin
  if not Assigned(ABand) then
    Exit;

  EffH := ComputeEffectiveBandHeight(ABand, ADataSet, AUserDataSet);
  EnsurePageSpaceForBand(ABand, EffH);

  PrintBand(ABand, ADataSet, EffH, AUserDataSet);
end;

function TReportEngine.ResolveBandDataSet(ABand: TReportBand): TDataSet;
begin
  Result := FDataSet;
  if not Assigned(ABand) then Exit;

  if Trim(ABand.DataSetName) = '' then
    Exit;

  if Assigned(FNamedDataSets)
     and FNamedDataSets.TryGetValue(ABand.DataSetName, Result) then
    Exit;

  // Fallback to the primary dataset when the band name is not registered.
  // This keeps older templates working even when the named dataset wiring is incomplete.
  Result := FDataSet;
end;

function TReportEngine.ResolveBandUserDataSet(
  ABand: TReportBand): TVittixUserDataSet;
begin
  Result := FUserDataSet;
  if not Assigned(ABand) then
    Exit;

  if Trim(ABand.DataSetName) = '' then
    Exit;

  if Assigned(FNamedUserDataSets) and
     FNamedUserDataSets.TryGetValue(ABand.DataSetName, Result) then
    Exit;

  // Fallback to the primary user dataset when the band name is not registered.
  Result := FUserDataSet;
end;

function TReportEngine.PrimarySourceActive: Boolean;
begin
  Result := SourceActive(FDataSet, FUserDataSet);
end;

function TReportEngine.SourceFieldValue(ADataSet: TDataSet;
  AUserDataSet: TVittixUserDataSet; const AFieldName: string): Variant;
begin
  Result := SafeSourceFieldValue(ADataSet, AUserDataSet, AFieldName);
end;

procedure TReportEngine.ValidateDetailLinks;
var
  Band: TReportBand;
  DetailDS, MasterSchema, DetailSchema: TDataSet;
  DetailUDS: TVittixUserDataSet;
  MasterName, DetailName, BandName: string;
begin
  // R-03: an explicitly configured relationship is structural report data.
  // Validate it once before either the look-ahead or print traversal; treating
  // a typo as "unlinked" silently prints every detail row for every master.
  for Band in FDetailBands do
  begin
    MasterName := Trim(Band.MasterField);
    DetailName := Trim(Band.DetailField);

    // Both blank is the established unlinked-detail contract: print all rows.
    if (MasterName = '') and (DetailName = '') then
      Continue;

    BandName := Trim(Band.Name);
    if BandName = '' then
      BandName := '<unnamed detail band>';

    if (MasterName = '') or (DetailName = '') then
      raise EReportException.CreateFmt(
        'Detail band "%s" must define both MasterField and DetailField, or neither.',
        [BandName]);

    MasterSchema := FDataSet;
    if (not Assigned(MasterSchema)) and Assigned(FUserDataSet) then
      MasterSchema := FUserDataSet.DataSet;
    if Assigned(MasterSchema) and MasterSchema.Active and
       not Assigned(MasterSchema.FindField(MasterName)) then
      raise EReportException.CreateFmt(
        'Detail band "%s": master field "%s" was not found.',
        [BandName, MasterName]);

    DetailDS := ResolveBandDataSet(Band);
    DetailUDS := ResolveBandUserDataSet(Band);
    DetailSchema := DetailDS;
    if (not Assigned(DetailSchema)) and Assigned(DetailUDS) then
      DetailSchema := DetailUDS.DataSet;
    if Assigned(DetailSchema) and DetailSchema.Active and
       not Assigned(DetailSchema.FindField(DetailName)) then
      raise EReportException.CreateFmt(
        'Detail band "%s": detail field "%s" was not found.',
        [BandName, DetailName]);
  end;
end;

{ Encodes a variant link value into a comparison key with the same match
  semantics the legacy scan's VarSameValue had: NULL matches only NULL,
  numbers compare by value across their subtypes (VarSameValue(1, 1.0)),
  dates participate as numbers (variant dates are doubles), numeric STRINGS
  coerce into the numeric bucket (VarSameValue delegates to VarCompareValue,
  which converts numeric strings), and values of different families never
  match.  The kind tag keeps the families distinct. }
function DetailKeyValueString(const V: Variant): string;
var
  D: Double;
  S: string;
begin
  if VarIsNull(V) or System.Variants.VarIsEmpty(V) then
    Exit(#1 + 'N');
  case VarType(V) and varTypeMask of
    varSmallint, varInteger, varSingle, varDouble, varCurrency,
    varShortInt, varByte, varWord, varLongWord, varInt64, varDate:
      Result := #1 + 'F' + FloatToStr(Double(V));
    varBoolean:
      if Boolean(V) then
        Result := #1 + 'B1'
      else
        Result := #1 + 'B0';
  else
    begin
      S := VarToStr(V);
      // Legacy VarSameValue coerced numeric strings ('1' = 1); keep that
      // matching behavior by routing parseable strings into the numeric
      // bucket the same way VarCompareValue does.
      if TryStrToFloat(S, D) then
        Result := #1 + 'F' + FloatToStr(D)
      else
        Result := #1 + 'S' + S;
    end;
  end;
end;

function TReportEngine.ComputeFirstDetailRowsHeight: Integer;
var
  Band: TReportBand;
  DetailDS: TDataSet;
  DetailUDS: TVittixUserDataSet;
  SaveBM: TBookmark;
  HasSaveBM: Boolean;
  MasterValue: Variant;
  HasMasterField: Boolean;
  MasterFld: TField;
  DetailFld: TField;
  Idx: TDetailBandKeyIndex;
  BMs: TList<TBookmark>;
begin
  Result := 0;

  for Band in FDetailBands do
  begin
    DetailDS := ResolveBandDataSet(Band);
    DetailUDS := ResolveBandUserDataSet(Band);
    if not SourceActive(DetailDS, DetailUDS) then
      Continue;

    if Assigned(DetailUDS) then
    begin
      TReportTraversalDiagnostics.DetailTraversalStarted;
      HasMasterField :=
        (Band.MasterField <> '') and (Band.DetailField <> '') and
        PrimarySourceActive;

      if HasMasterField then
        MasterValue := SourceFieldValue(FDataSet, FUserDataSet, Band.MasterField)
      else
        MasterValue := Null;

      DetailUDS.First;
      while not DetailUDS.Eof do
      begin
        TReportTraversalDiagnostics.DetailRowVisited;
        if (not HasMasterField) or
           VarSameValue(SourceFieldValue(nil, DetailUDS, Band.DetailField), MasterValue) then
        begin
          Inc(Result, ComputeEffectiveBandHeight(Band, nil, DetailUDS));
          Break;
        end;
        DetailUDS.Next;
      end;
      Continue;
    end;

    HasSaveBM := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(DetailDS, SaveBM);
    DetailDS.DisableControls;
    try
      TReportTraversalDiagnostics.DetailTraversalStarted;
      HasMasterField :=
        PrimarySourceActive and
        (Band.MasterField <> '') and (Band.DetailField <> '') and
        (Assigned(FUserDataSet) or TryGetField(FDataSet, Band.MasterField, MasterFld)) and
        TryGetField(DetailDS, Band.DetailField, DetailFld);

      if HasMasterField then
        MasterValue := SourceFieldValue(FDataSet, FUserDataSet, Band.MasterField)
      else
        MasterValue := Null;

      // Key-index fast path: the legacy look-ahead walks the detail dataset
      // until the FIRST match to measure its band height.  The index holds
      // bookmarks in row order, so the first bookmark is the same row the
      // scan would have stopped at.
      if HasMasterField and Assigned(DetailFld) and
         DataSetSupportsBookmarks(DetailDS) and
         not DataSetIsMasterLinked(DetailDS) then
      begin
        Idx := GetDetailKeyIndex(Band, DetailDS, DetailFld);
        if Assigned(Idx) and not Idx.Stale then
        begin
          if Idx.Keys.TryGetValue(DetailKeyValueString(MasterValue), BMs) and
             (BMs.Count > 0) and DetailDS.BookmarkValid(BMs[0]) then
          begin
            DetailDS.GotoBookmark(BMs[0]);
            if VarSameValue(DetailFld.Value, MasterValue) then
            begin
              TReportTraversalDiagnostics.DetailRowVisited;
              Inc(Result, ComputeEffectiveBandHeight(Band, DetailDS));
              Continue;
            end;
            // The bookmark no longer carries this key: the dataset was
            // mutated mid-pass.  Fall back to the ordered scan below.
            Idx.Stale := True;
          end
          else
            Continue;
        end;
      end;

      DetailDS.First;
      while not DetailDS.Eof do
      begin
        TReportTraversalDiagnostics.DetailRowVisited;
        if (not HasMasterField) or VarSameValue(DetailFld.Value, MasterValue) then
        begin
          Inc(Result, ComputeEffectiveBandHeight(Band, DetailDS));
          Break;
        end;
        DetailDS.Next;
      end;
    finally
      Vittix.Report.LayoutBookmarks.RestoreDataSetBookmark(DetailDS, SaveBM, HasSaveBM);
      DetailDS.EnableControls;
    end;
  end;
end;

function TReportEngine.GetDetailKeyIndex(ABand: TReportBand;
  ADetailDS: TDataSet; ADetailFld: TField): TDetailBandKeyIndex;
var
  Idx: TDetailBandKeyIndex;
  I: Integer;
  SaveBM: TBookmark;
  HasSaveBM: Boolean;
  Key: string;
  List: TList<TBookmark>;
  BM: TBookmark;
  CurKey: string;
begin
  for I := 0 to FDetailKeyIndexes.Count - 1 do
    if (FDetailKeyIndexes[I].Band = ABand) and
       (FDetailKeyIndexes[I].DS = ADetailDS) then
    begin
      Idx := FDetailKeyIndexes[I];
      if Idx.HasFirstKey then
      begin
        // A first-row key mutation can move a detail row into a different
        // master bucket that is not present in that master's cached list.
        // Validate this stable sentinel before trusting any indexed lookup.
        HasSaveBM := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(
          ADetailDS, SaveBM);
        try
          try
            ADetailDS.First;
            if ADetailDS.Eof then
              CurKey := DetailKeyValueString(Null)
            else
              CurKey := DetailKeyValueString(Idx.DetailField.Value);
            if CurKey <> Idx.FirstKey then
              Idx.Stale := True;
          except
            Idx.Stale := True;
          end;
        finally
          Vittix.Report.LayoutBookmarks.RestoreDataSetBookmark(
            ADetailDS, SaveBM, HasSaveBM);
        end;
      end;
      Exit(Idx);
    end;

  // Without bookmarks the matched rows cannot be revisited - the legacy
  // First..Eof scan stays in charge.  Master-linked datasets are excluded
  // too: their visible rows change as the master advances, so a per-pass
  // index would capture only the first master's view.
  if not DataSetSupportsBookmarks(ADetailDS) or
     DataSetIsMasterLinked(ADetailDS) then
    Exit(nil);

  Idx := TDetailBandKeyIndex.Create;
  Idx.Band := ABand;
  Idx.DS := ADetailDS;
  Idx.DetailField := ADetailFld;
  Idx.HasFirstKey := False;
  FDetailKeyIndexes.Add(Idx);

  HasSaveBM := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(ADetailDS, SaveBM);
  ADetailDS.DisableControls;
  try
    ADetailDS.First;
    if not ADetailDS.Eof then
    begin
      Idx.HasFirstKey := True;
      Idx.FirstKey := DetailKeyValueString(ADetailFld.Value);
    end;
    while not ADetailDS.Eof do
    begin
      TReportTraversalDiagnostics.DetailRowVisited;
      Key := DetailKeyValueString(ADetailFld.Value);
      if not Idx.Keys.TryGetValue(Key, List) then
      begin
        List := TList<TBookmark>.Create;
        Idx.Keys.Add(Key, List);
      end;
      BM := ADetailDS.GetBookmark;
      if Assigned(BM) then
        List.Add(BM);
      ADetailDS.Next;
    end;
  finally
    Vittix.Report.LayoutBookmarks.RestoreDataSetBookmark(ADetailDS, SaveBM, HasSaveBM);
    ADetailDS.EnableControls;
  end;
  Result := Idx;
end;

procedure TReportEngine.PrintDetailBandRecords(ABand: TReportBand;
  ADetailDS: TDataSet; ADetailUDS: TVittixUserDataSet);
var
  MasterValue: Variant;
  HasMasterField: Boolean;
  EffH: Integer;
  MasterFld: TField;
  DetailFld: TField;
  Idx: TDetailBandKeyIndex;
  BMs: TList<TBookmark>;
  I: Integer;
begin
  TReportTraversalDiagnostics.DetailTraversalStarted;
  if Assigned(ADetailUDS) then
  begin
    HasMasterField :=
      (ABand.MasterField <> '') and (ABand.DetailField <> '') and
      PrimarySourceActive;

    if HasMasterField then
      MasterValue := SourceFieldValue(FDataSet, FUserDataSet, ABand.MasterField)
    else
      MasterValue := Null;

    ADetailUDS.First;
    while not ADetailUDS.Eof do
    begin
      TReportTraversalDiagnostics.DetailRowVisited;
      if (not HasMasterField) or
         VarSameValue(SourceFieldValue(nil, ADetailUDS, ABand.DetailField), MasterValue) then
      begin
        EffH := ComputeEffectiveBandHeight(ABand, nil, ADetailUDS);
        EnsurePageSpaceForBand(ABand, EffH, True);
        PrintBand(ABand, nil, EffH, ADetailUDS);
      end;
      ADetailUDS.Next;
    end;
    Exit;
  end;

  HasMasterField :=
    PrimarySourceActive and
    (ABand.MasterField <> '') and (ABand.DetailField <> '') and
    (Assigned(FUserDataSet) or TryGetField(FDataSet, ABand.MasterField, MasterFld)) and
    TryGetField(ADetailDS, ABand.DetailField, DetailFld);

  if HasMasterField then
    MasterValue := SourceFieldValue(FDataSet, FUserDataSet, ABand.MasterField)
  else
    MasterValue := Null;

  // Per-pass key index fast path: direct bookmark lookup instead of a
  // First..Eof scan per master row.  Match semantics are encoded in
  // DetailKeyValueString (NULL only matches NULL, numbers by value,
  // distinct kind families never match) and row order is preserved by the
  // bookmark list, so the printed output is identical to the scan below.
  if HasMasterField and Assigned(DetailFld) and
     DataSetSupportsBookmarks(ADetailDS) and
     not DataSetIsMasterLinked(ADetailDS) then
  begin
    Idx := GetDetailKeyIndex(ABand, ADetailDS, DetailFld);
    if Assigned(Idx) and not Idx.Stale then
    begin
      if Idx.Keys.TryGetValue(DetailKeyValueString(MasterValue), BMs) then
      begin
        // Validate the cached row keys before printing: an interior row
        // mutation can leave the bookmark list pointing at a row that no
        // longer carries this master value.  A stale index falls back to
        // the ordered scan for the rest of the pass.
        for I := 0 to BMs.Count - 1 do
          if ADetailDS.BookmarkValid(BMs[I]) then
          begin
            ADetailDS.GotoBookmark(BMs[I]);
            if not VarSameValue(DetailFld.Value, MasterValue) then
            begin
              Idx.Stale := True;
              Break;
            end;
          end
          else
          begin
            Idx.Stale := True;
            Break;
          end;

        if not Idx.Stale then
        begin
          for I := 0 to BMs.Count - 1 do
            if ADetailDS.BookmarkValid(BMs[I]) then
            begin
              ADetailDS.GotoBookmark(BMs[I]);
              TReportTraversalDiagnostics.DetailRowVisited;
              EffH := ComputeEffectiveBandHeight(ABand, ADetailDS);
              EnsurePageSpaceForBand(ABand, EffH, True);
              PrintBand(ABand, ADetailDS, EffH);
            end;
          Exit;
        end;
      end
      else
        Exit;
    end;
  end;

  ADetailDS.First;
  while not ADetailDS.Eof do
  begin
    TReportTraversalDiagnostics.DetailRowVisited;
    if (not HasMasterField) or VarSameValue(DetailFld.Value, MasterValue) then
    begin
      EffH := ComputeEffectiveBandHeight(ABand, ADetailDS);
      EnsurePageSpaceForBand(ABand, EffH, True);
      PrintBand(ABand, ADetailDS, EffH);
    end;
    ADetailDS.Next;
  end;
end;

procedure TReportEngine.PrintDetailBands;
var
  Band: TReportBand;
  DetailDS: TDataSet;
  DetailUDS: TVittixUserDataSet;
  SaveBM: TBookmark;
  HasSaveBM: Boolean;
begin
  for Band in FDetailBands do
  begin
    DetailDS := ResolveBandDataSet(Band);
    DetailUDS := ResolveBandUserDataSet(Band);
    if not SourceActive(DetailDS, DetailUDS) then
      Continue;

    if Assigned(DetailUDS) then
    begin
      PrintDetailBandRecords(Band, nil, DetailUDS);
      Continue;
    end;

    HasSaveBM := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(DetailDS, SaveBM);

    DetailDS.DisableControls;
    try
      PrintDetailBandRecords(Band, DetailDS, nil);
    finally
      Vittix.Report.LayoutBookmarks.RestoreDataSetBookmark(DetailDS, SaveBM, HasSaveBM);
      DetailDS.EnableControls;
    end;
  end;
end;

procedure TReportEngine.RegisterDataSet(const AName: string; ADataSet: TDataSet);
begin
  if Trim(AName) = '' then
    Exit;
  FNamedDataSets.AddOrSetValue(AName, ADataSet);
end;

{ ================= Main Loop ================= }

function TReportEngine.ExecutePass(ATotalPages: Integer; AReportProgress: Boolean): Integer;
var
  RowNumber, TotalRows: Integer;
  HasOpenedGroups: Boolean;
  ActiveGroupHeader: TBooleanDynArray;
  HasAnyActiveGroup: Boolean;
begin
  ClearExecutionCaches;
  FIsRenderingPass := AReportProgress;
try
    BeginPass(ATotalPages, AReportProgress, TotalRows, RowNumber);
    PrintFirstPageBands;
    HasAnyActiveGroup := InitializeActiveGroupHeaders(ActiveGroupHeader);
    HasOpenedGroups := False;
    ProcessMasterDataLoop(ActiveGroupHeader, AReportProgress, RowNumber, HasOpenedGroups);
    Result := FinalizePass(ActiveGroupHeader, HasAnyActiveGroup, HasOpenedGroups);
  finally
    FIsRenderingPass := False;
  end;
end;

procedure TReportEngine.Prepare;
var
  CountedPages: Integer;
  CancelPrint: Boolean;
{$IFDEF DEBUG}
  StartMs: UInt64;
  ElapsedMs: UInt64;
  RowCount: Integer;
  Msg: string;
{$ENDIF}
begin
{$IFDEF DEBUG}
  StartMs := GetTickCount64;
{$ENDIF}
  try
    CacheBands;

    if Assigned(FMasterBand) then
    begin
      if not Assigned(FDataSet) and not Assigned(FUserDataSet) then
        raise EReportException.Create(
          'DataSet must be assigned to the report engine.');

      if not PrimarySourceActive then
        raise EReportException.Create(
          'DataSet must be active to generate the report.');
    end;

    // Unidirectional-cursor guard: groups, aggregates, cross-tab and chart
    // all evaluate through dataset bookmarks.  On a bookmark-incapable
    // dataset (TFDQuery with FetchOptions.Unidirectional := True) those
    // fail mid-render with confusing errors - fail once, up front, with
    // the fix in the message.
    if Assigned(FDataSet) and FDataSet.Active and
       ReportModelNeedsBookmarks(FReport.Objects) and
       not DataSetSupportsBookmarks(FDataSet) then
      raise EReportException.Create(
        'Dataset does not support bookmarks. ' +
        'For TFDQuery set FetchOptions.Unidirectional := False.');

    ValidateDetailLinks;

    FReportDate := Now;
    CancelPrint := False;
    if Assigned(FOnBeforePrintReport) then
      FOnBeforePrintReport(Self, Self, FReport, CancelPrint);
    if CancelPrint then
    begin
      FPages.Clear;
      FPlanner.ResetSession;
      Exit;
    end;

    // Phase B: one subreport-cache lifetime per report execution - a new
    // Prepare never inherits the previous execution's cache (including the
    // failure memo kept across the pass pair by ClearExecutionCaches).
    FSubReportModelCache.Clear;
    if FTwoPassRendering then
    begin
      // Pass 1: count pages with TotalPages unresolved.
      CountedPages := ExecutePass(0, False);

      // Pass 2: final render with resolved TotalPages available to expressions.
      ExecutePass(CountedPages, True);
    end
    else
      ExecutePass(0, True);

    if Assigned(FOnAfterPrintReport) then
      FOnAfterPrintReport(Self, Self, FReport);

{$IFDEF DEBUG}
    ElapsedMs := GetTickCount64 - StartMs;
    RowCount := SafeRecordCount(FDataSet);
    Msg := Format('VittixReport Prepare: %d ms, %d page(s), %d row(s)',
      [ElapsedMs, PageCount, RowCount]);
    OutputDebugString(PChar(Msg));
{$ENDIF}
  except
    on E: EReportException do
      raise; // Re-raise custom report exceptions
    on E: Exception do
      raise EReportException.CreateFmt('Error preparing report: %s', [E.Message]);
  end;
end;

procedure TReportEngine.InvokeBeforeObjectPrint(
  Sender: TObject;
  const Context: TExpressionContext;
  var ACanPrint: Boolean);
var
  AObject: TReportObject;
begin
  AObject := Sender as TReportObject;
  if FIsRenderingPass and Assigned(AObject) and Assigned(FScriptEngine) and
     (AObject.OnBeforePrint <> '') then
  begin
    var ScriptCtx := Context;
    // Object persisted script host runs before runtime OnBeforeObject callback.
    // If the host sets ACanPrint=False, skip runtime callback and drawing/after-hooks.
    FScriptEngine.ExecuteObjectBeforePrint(FReport, AObject, AObject.OnBeforePrint, ScriptCtx, ACanPrint);
    if not ACanPrint then
      Exit;
  end;

  if Assigned(FOnBeforeObject) then
    FOnBeforeObject(Self, Self, AObject, Context, ACanPrint);
end;

procedure TReportEngine.InvokeAfterObjectPrint(
  Sender: TObject;
  const Context: TExpressionContext);
var
  AObject: TReportObject;
begin
  AObject := Sender as TReportObject;
  CaptureExportObjectCommand(AObject, Context);

  if FIsRenderingPass and Assigned(AObject) and Assigned(FScriptEngine) and
     (AObject.OnAfterPrint <> '') then
  begin
    var ScriptCtx := Context;
    FScriptEngine.ExecuteObjectAfterPrint(FReport, AObject, AObject.OnAfterPrint, ScriptCtx);
  end;

  if Assigned(FOnAfterObject) then
    FOnAfterObject(Self, Self, AObject, Context);
end;

{ ================= DP-31 / M-13: export capture ================= }

{ The engine is the capture sink: objects emit their commands through this
  interface while a rendering-pass capture is active.  All per-object logic
  lives on the object classes; CaptureExportObjectCommand is a dispatcher. }

procedure TReportEngine.AddCommand(const ACommand: TReportExportCommand);
begin
  if (ACommand <> nil) and Assigned(FPlanner.CurrentExportPage) then
    FPlanner.CurrentExportPage.Commands.Add(ACommand);
end;

function TReportEngine.GetCaptureOrigin: TPoint;
begin
  Result := Point(0, 0);
  if Assigned(FCanvas) then
    GetViewportOrgEx(FCanvas.Handle, Result);
end;

function TReportEngine.GetPageNumber: Integer;
begin
  // Phase A: the planner is the authoritative page counter.
  Result := FPlanner.PageNumber;
end;

procedure TReportEngine.RegisterTempFile(const AFileName: string);
begin  if Assigned(FExportDocument) then
    FExportDocument.AddTempFile(AFileName);
end;

{ Chart/CrossTab objects have no per-primitive capture; render the object
  through its existing Draw onto a temporary bitmap and capture it as an
  image command (1:1 logical resolution, white page background).  The PNG
  file is registered with the export document, which deletes it when the
  document is freed - after all exporters have consumed the command. }
procedure TReportEngine.CaptureObjectAsImage(AObject: TReportObject;
  const AContext: TExpressionContext);
var
  R: TRect;
  Bmp: Vcl.Graphics.TBitmap;
  Png: TPngImage;
  ImgCmd: TReportExportImageCommand;
  TempFile: string;
  SavedOrg: TPoint;
  Origin: TPoint;
begin
  if (AObject = nil) or not Assigned(FPlanner.CurrentExportPage) then
    Exit;

  Origin := GetCaptureOrigin;
  R := AObject.Bounds;
  OffsetRect(R, Origin.X, Origin.Y);
  if (R.Width <= 0) or (R.Height <= 0) then
    Exit;

  Bmp := Vcl.Graphics.TBitmap.Create;
  try
    Bmp.SetSize(R.Width, R.Height);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));
    GetViewportOrgEx(Bmp.Canvas.Handle, SavedOrg);
    SetViewportOrgEx(Bmp.Canvas.Handle, -AObject.Bounds.Left, -AObject.Bounds.Top, nil);
    try
      // DP-19: the shared guard already approved this object for the
      // current print; the re-draw for capture must not re-evaluate
      // PrintWhen (the object's own Draw now checks ShouldPrintObject).
      var DrawCtx := AContext;
      DrawCtx.PrecheckedObjectForPrintWhen := AObject;
      AObject.Draw(Bmp.Canvas, DrawCtx);
    finally
      SetViewportOrgEx(Bmp.Canvas.Handle, SavedOrg.X, SavedOrg.Y, nil);
    end;

    TempFile := TPath.Combine(TPath.GetTempPath,
      'vittix_export_' + TGUID.NewGuid.ToString + '.png');
    Png := TPngImage.Create;
    try
      Png.Assign(Bmp);
      Png.SaveToFile(TempFile);
    finally
      Png.Free;
    end;

    ImgCmd := TReportExportImageCommand.Create;
    ImgCmd.Bounds := R;
    ImgCmd.Source := TempFile;
    ImgCmd.Stretch := True;
    FPlanner.CurrentExportPage.Commands.Add(ImgCmd);
    if Assigned(FExportDocument) then
      FExportDocument.AddTempFile(TempFile);
  finally
    Bmp.Free;
  end;
end;

procedure TReportEngine.CaptureExportObjectCommand(
  AObject: TReportObject;
  const Context: TExpressionContext);
begin
  if not IsCapturingExportCommands or not Assigned(FPlanner.CurrentExportPage) or
     not Assigned(AObject) then
    Exit;

  // DP-31 / M-13: dispatch to the object's own capture implementation.
  AObject.CaptureExportCommands(Context, Self);
end;

function TReportEngine.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

function TReportEngine._AddRef: Integer;
begin
  Result := -1;
end;

function TReportEngine._Release: Integer;
begin
  Result := -1;
end;

function TReportEngine.GetNamedDataSet(const AName: string): TDataSet;
begin
  if not FNamedDataSets.TryGetValue(AName, Result) then
    Result := nil;
end;

const
  { DP-29 / M-3: hard cap on the aggregate cache.  Row-scoped duplicates
    collapse on store (see StoreAggregateCache); anything else falls off
    oldest-first past the cap so a render can never accumulate entries
    without limit. }
  MAX_AGGREGATE_CACHE_ENTRIES = 4096;

function TReportEngine.TryGetAggregateCache(const AExpression: string;
  const AContext: TExpressionContext; out AValue: Variant): Boolean;
var
  Entry: TAggregateCacheEntry;
begin
  for Entry in FAggregateCache do
    if Entry.Matches(AExpression, AContext) then
    begin
      AValue := Entry.Value;
      Exit(True);
    end;
  Result := False;
end;

procedure TReportEngine.StoreAggregateCache(const AExpression: string;
  const AContext: TExpressionContext; const AValue: Variant);
var
  Entry: TAggregateCacheEntry;
  I: Integer;
begin
  // DP-29 / M-3: row-scoped re-evaluations (identical apart from RowNumber,
  // one per master row) can never be hit by a later row.  Collapse them
  // into the most recent matching entry instead of appending one per row;
  // the value is refreshed, so a re-evaluation within the newest row still
  // hits the cache.
  for I := FAggregateCache.Count - 1 downto 0 do
    if FAggregateCache[I].MatchesExceptRowNumber(AExpression, AContext) then
    begin
      FAggregateCache[I].Capture(AExpression, AContext, AValue);
      TReportTraversalDiagnostics.AggregateCacheSize(FAggregateCache.Count);
      Exit;
    end;

  Entry := TAggregateCacheEntry.Create;
  try
    Entry.Capture(AExpression, AContext, AValue);
    FAggregateCache.Add(Entry);
  except
    Entry.Free;
    raise;
  end;

  // Hard bound: the oldest entries fall off first (FIFO).
  while FAggregateCache.Count > MAX_AGGREGATE_CACHE_ENTRIES do
    FAggregateCache.Delete(0);

  // DP-29: observe the cache size after every mutation (test diagnostics).
  TReportTraversalDiagnostics.AggregateCacheSize(FAggregateCache.Count);
end;

function TReportEngine.GetSubReportModel(AObject: TObject;
  const AJSON: string): TObject;
var
  Entry: TSubReportModelCacheEntry;
  I: Integer;
begin
  Result := nil;
  for I := 0 to FSubReportModelCache.Count - 1 do
  begin
    Entry := FSubReportModelCache[I];
    if Entry.Owner = AObject then
    begin
      if Entry.JSON = AJSON then
      begin
        TReportTraversalDiagnostics.SubReportCacheHit;
        Exit(Entry.Model);
      end;
      FSubReportModelCache.Remove(Entry);
      Break;
    end;
  end;

  TReportTraversalDiagnostics.SubReportCacheMiss;
  try
    TReportTraversalDiagnostics.SubReportParseAttempted;
    Entry := TSubReportModelCacheEntry.Create;
    try
      Entry.Owner := AObject;
      Entry.JSON := AJSON;
      Entry.Model := nil;
      try
        Entry.Model := TReportSerializer.LoadFromJSON(AJSON);
      except
        // Frozen fallback: a subreport whose JSON will not parse is
        // skipped.  The FAILED parse is cached (same owner + same JSON,
        // Model stays nil) so broken JSON is not re-parsed for every
        // master row; later rows take the cache-hit path above and also
        // get nil.  Counted and logged; output is unchanged.
        TReportTraversalDiagnostics.SubReportParseFailed;
{$IFDEF DEBUG}
        OutputDebugString(PChar(
          'VittixReport: subreport JSON parse failed; the object is skipped ' +
          'and the failure is cached (same owner + JSON) so it is not ' +
          're-parsed per master row'));
{$ENDIF}
      end;
      FSubReportModelCache.Add(Entry);
      Result := Entry.Model;
    except
      Entry.Free;
      raise;
    end;
  except
    Result := nil;
  end;
end;

end.
