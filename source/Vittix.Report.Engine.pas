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

  TReportEngine = class(TObject, IInterface, IReportRenderHooks,
    IReportExportCaptureSink)
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
    FCurrentExportPage: TReportExportPage;
    FExportOriginX: Integer;
    FExportOriginY: Integer;

    FCurrentPage: TMetafile;
    FCanvas:      TMetafileCanvas;
    FCurrentY:    Integer;
    FPageWidth:   Integer;   // cached from PageSettings at Prepare time
    FPageHeight:  Integer;
    FMarginLeft, FMarginTop, FMarginRight, FMarginBottom: Integer;
    FPageNumber:  Integer;   // 1-based current page counter
    FRowNumber:   Integer;   // 1-based current master row counter
    FReportDate:  TDateTime; // set once when Prepare begins
    FTotalPagesForPass: Integer;
    FTwoPassRendering: Boolean;

    FTitleBand:         TReportBand;
    FHeaderBand:        TReportBand;
    FColumnHeaderBand:  TReportBand;   // btColumnHeader
    FMasterBand:        TReportBand;   // primary master loop band
    FDetailBands:       TObjectList<TReportBand>; // btDetail bands that use their own datasets
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
    function TryFlowFlatSubReport(AParentBand: TReportBand): Boolean;
    function TryFlowNestedSubReport(AParentBand: TReportBand;
      AOuterSubReport, AInnerSubReport: TReportSubReportObject;
      AOuterDataSet: TDataSet; AOuterBand: TReportBand): Boolean;
    procedure RejectUnsupportedSubReportOverflow(AParentBand: TReportBand);
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
    procedure PrintDetailBands;
    procedure ClearExecutionCaches;
    function  ExecutePass(ATotalPages: Integer; AReportProgress: Boolean): Integer;
    function  CheckSpace(RequiredHeight: Integer): Boolean;
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
    property PageCount:  Integer                read FPageNumber;
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
  FSubReportModelCache := TObjectList<TSubReportModelCacheEntry>.Create(True);
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
begin
  FAggregateCache.Clear;
  FSubReportModelCache.Clear;
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
  // Note: changing page settings mid-engine could mess up space tracking if not exactly at top of page,
  // but StartNewPage safely resets these coordinates.
end;

procedure TReportEngine.StartNewPage;
begin
  EndCurrentPage;

  Inc(FPageNumber);

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
  if IsCapturingExportCommands then
    FCurrentExportPage := FExportDocument.AddPage(FPageWidth, FPageHeight)
  else
    FCurrentExportPage := nil;
  FCurrentY := FReport.PageSettings.Margins.Top;
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
        FCurrentY := FPageHeight - FReport.PageSettings.Margins.Bottom - FFooterBand.Height;
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
          Ctx2.PageNumber := FPageNumber;
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
    FCurrentExportPage := nil;
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
  Ctx.PageNumber  := FPageNumber;
  Ctx.TotalPages  := FTotalPagesForPass;
  Ctx.RowNumber   := FRowNumber;
  Ctx.PageBottom  := FPageHeight - FReport.PageSettings.Margins.Bottom - FCurrentY;
  Ctx.ReportTitle := FReport.Title;
  Ctx.ReportDate  := FReportDate;
  Ctx.Parameters  := FParameters;
  Ctx.Variables   := FReport.Variables;
  Ctx.IsCountingPass := not FIsRenderingPass;

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

  Result := BandFitsOnPage(
    FCurrentY,
    RequiredHeight,
    FPageHeight,
    FReport.PageSettings.Margins.Bottom,
    FooterH);
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

procedure TReportEngine.BeginPass(
  ATotalPages: Integer; AReportProgress: Boolean; out ATotalRows, ARowNumber: Integer);
var
  I: Integer;
  HasGroupLevelBookmarks: Boolean;
begin
  FPages.Clear;
  if AReportProgress and Assigned(FExportDocument) then
    FExportDocument.Pages.Clear;
  FPageNumber := 0;
  FRowNumber := 0;
  FTotalPagesForPass := ATotalPages;

  FPageWidth := FReport.PageSettings.PageWidth;
  FPageHeight := FReport.PageSettings.PageHeight;

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

  if not TryFlowFlatSubReport(FMasterBand) then
  begin
    RejectUnsupportedSubReportOverflow(FMasterBand);
    EffH := ComputeEffectiveBandHeight(FMasterBand, FDataSet, FUserDataSet);
    EnsurePageSpaceForBand(FMasterBand, EffH + ComputeFirstDetailRowsHeight, True);
    PrintBand(FMasterBand, FDataSet, EffH, FUserDataSet);
  end;
  PrintDetailBands;

  Result := True;
  if AReportProgress and Assigned(FProgress) then
  begin
    FProgress.Advance(ARowNumber);
    Result := not FProgress.IsCancelled;
  end;
end;

function TReportEngine.TryFlowFlatSubReport(
  AParentBand: TReportBand): Boolean;
var
  SubReport: TReportSubReportObject;
  ChildModel: TReportModel;
  ChildBand: TReportBand;
  ChildDataSet: TDataSet;
  ChildBookmark: TBookmark;
  HasChildBookmark: Boolean;
  MatchCount: Integer;
  RowsDrawn: Integer;
  FirstOffset: Integer;
  RowTop: Integer;
  RowContext: TExpressionContext;
  ChildOriginX: Integer;
  ChildOriginY: Integer;
  ClipWidth: Integer;
  FooterHeight: Integer;
  MasterField, DetailField: string;
  Child: TReportObject;
  InnerSubReport: TReportSubReportObject;
  ControlsDisabledByUs: Boolean;
  function MatchesCurrentMaster: Boolean;
  var
    MasterValue, DetailValue: Variant;
  begin
    Result := True;
    if (MasterField = '') or (DetailField = '') or
       not Assigned(FDataSet.FindField(MasterField)) or
       not Assigned(ChildDataSet.FindField(DetailField)) then
      Exit;
    MasterValue := FDataSet.FieldByName(MasterField).Value;
    DetailValue := ChildDataSet.FieldByName(DetailField).Value;
    Result := VarSameValue(MasterValue, DetailValue);
  end;
  function BuildRowContext: TExpressionContext;
  begin
    Result := Default(TExpressionContext);
    Result.ExpressionMode := ReportExpressionMode;
    Result.Hooks := Self;
    Result.DataSet := ChildDataSet;
    Result.UserDataSet := FUserDataSet;
    Result.GroupStart := FGroupStartBookmark;
    Result.GroupEnd := FGroupEndBookmark;
    Result.PageNumber := FPageNumber;
    Result.TotalPages := FTotalPagesForPass;
    Result.RowNumber := FRowNumber;
    Result.PageBottom := FPageHeight -
      FReport.PageSettings.Margins.Bottom - FCurrentY;
    Result.ReportTitle := FReport.Title;
    Result.ReportDate := FReportDate;
    Result.Parameters := FParameters;
    Result.Variables := FReport.Variables;
    Result.IsCountingPass := not FIsRenderingPass;
  end;
begin
  Result := False;
  if not Assigned(AParentBand) or not AParentBand.Visible or
     (AParentBand.BandType <> btMasterData) or
     (AParentBand.Children.Count <> 1) or
     not (AParentBand.Children[0] is TReportSubReportObject) or
     not AParentBand.CanGrow or
     (AParentBand.PrintWhen <> '') or AParentBand.StartNewPage or
     AParentBand.PageBreakBefore or AParentBand.PageBreakAfter or
     AParentBand.OverridePageSettings or AParentBand.CanShrink or
     not AParentBand.BackColorTransparent or
     (AParentBand.BackColorCondition <> '') or
     (AParentBand.OnBeforePrint <> '') or (AParentBand.OnAfterPrint <> '') or
     (FDetailBands.Count <> 0) or (FGroupHeaders.Count <> 0) or
     (FGroupFooters.Count <> 0) or Assigned(FOnBeforeBand) or
     Assigned(FOnAfterBand) or Assigned(FOnBeforeObject) or
     Assigned(FOnAfterObject) then
    Exit;

  SubReport := TReportSubReportObject(AParentBand.Children[0]);
  if not SubReport.Visible or (SubReport.PrintWhen <> '') or
     (SubReport.OnBeforePrint <> '') or (SubReport.OnAfterPrint <> '') or
     SubReport.PageBreakBefore or SubReport.PageBreakAfter or
     not SubReport.Transparent or SubReport.BorderVisible or
     (Trim(SubReport.ReportJSON) = '') then
    Exit;

  ChildDataSet := FDataSet;
  if Trim(SubReport.DataSetName) <> '' then
  begin
    if not Assigned(FNamedDataSets) or
       not FNamedDataSets.TryGetValue(SubReport.DataSetName, ChildDataSet) then
      Exit;
  end;
  if not Assigned(ChildDataSet) or not ChildDataSet.Active then
    Exit;

  ChildModel := TReportModel(GetSubReportModel(SubReport, SubReport.ReportJSON));
  if not Assigned(ChildModel) or (ChildModel.Objects.Count <> 1) or
     not (ChildModel.Objects[0] is TReportBand) then
    Exit;
  ChildBand := TReportBand(ChildModel.Objects[0]);
  if not ChildBand.Visible or (ChildBand.BandType <> btMasterData) or
     (ChildBand.Height <= 0) or ChildBand.CanGrow or ChildBand.CanShrink or
     (ChildBand.PrintWhen <> '') or ChildBand.StartNewPage or
     ChildBand.PageBreakBefore or ChildBand.PageBreakAfter or
     ChildBand.OverridePageSettings or (ChildBand.OnBeforePrint <> '') or
     (ChildBand.OnAfterPrint <> '') then
    Exit;
  if (ChildBand.Children.Count = 1) and
     (ChildBand.Children[0] is TReportSubReportObject) then
  begin
    InnerSubReport := TReportSubReportObject(ChildBand.Children[0]);
    if not InnerSubReport.Visible or (InnerSubReport.PrintWhen <> '') or
       (InnerSubReport.OnBeforePrint <> '') or
       (InnerSubReport.OnAfterPrint <> '') or
       InnerSubReport.PageBreakBefore or InnerSubReport.PageBreakAfter or
       not InnerSubReport.Transparent or InnerSubReport.BorderVisible then
      Exit;
    Result := TryFlowNestedSubReport(AParentBand, SubReport, InnerSubReport,
      ChildDataSet, ChildBand);
    Exit;
  end;
  for Child in ChildBand.Children do
    if Child.PageBreakBefore or Child.PageBreakAfter or
       (Child is TReportSubReportObject) then
      Exit;

  MasterField := Trim(SubReport.MasterField);
  DetailField := Trim(SubReport.DetailField);
  if (MasterField = '') xor (DetailField = '') then
    Exit;

  HasChildBookmark := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(
    ChildDataSet, ChildBookmark);
  MatchCount := 0;
  if (DataSetMasterSourceDataSet(ChildDataSet) = FDataSet) and
     (ChildDataSet.ControlsDisabled or FDataSet.ControlsDisabled) then
    raise EReportException.Create(
      'Linked subreport traversal requires master and detail controls enabled.');
  ControlsDisabledByUs := not ChildDataSet.ControlsDisabled and
    (DataSetMasterSourceDataSet(ChildDataSet) <> FDataSet);
  if ControlsDisabledByUs then
    ChildDataSet.DisableControls;
  try
    ChildDataSet.First;
    while not ChildDataSet.Eof do
    begin
      if MatchesCurrentMaster then
        Inc(MatchCount);
      ChildDataSet.Next;
    end;
  finally
    if ControlsDisabledByUs then
      ChildDataSet.EnableControls;
    if HasChildBookmark then
    begin
      Vittix.Report.LayoutBookmarks.RestoreDataSetBookmark(
        ChildDataSet, ChildBookmark, HasChildBookmark);
    end;
  end;

  if MatchCount = 0 then
    Exit;
  if (Int64(MatchCount) * ChildBand.Height + 2) <=
     (SubReport.Bounds.Bottom - SubReport.Bounds.Top) then
    Exit;

  Result := True;
  FooterHeight := 0;
  if Assigned(FFooterBand) then
    FooterHeight := FFooterBand.Height;
  if ChildBand.Height > (FPageHeight -
      FReport.PageSettings.Margins.Top -
      FReport.PageSettings.Margins.Bottom - FooterHeight) then
    raise EReportException.Create(
      'A flat subreport detail row is taller than the printable page area.');

  if (SubReport.Bounds.Top < 0) or
     ((SubReport.Bounds.Bottom - SubReport.Bounds.Top) <= 0) then
    raise EReportException.Create(
      'A flat subreport must have positive bounds within its parent band.');
  FirstOffset := SubReport.Bounds.Top + 2;
  ClipWidth := SubReport.Bounds.Right - SubReport.Bounds.Left - 2;
  if (ClipWidth <= 0) or (SubReport.Bounds.Left < 0) or
     (SubReport.Bounds.Right > FReport.PageSettings.ContentWidth) then
    raise EReportException.Create(
      'A flat subreport must fit within the printable page width.');

  HasChildBookmark := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(
    ChildDataSet, ChildBookmark);
  ControlsDisabledByUs := not ChildDataSet.ControlsDisabled;
  if ControlsDisabledByUs then
    ChildDataSet.DisableControls;
  try
    ChildDataSet.First;
    RowsDrawn := 0;
    while not ChildDataSet.Eof do
    begin
      if MatchesCurrentMaster then
      begin
        RowTop := 0;
        if RowsDrawn = 0 then
          RowTop := FirstOffset;
        if not CheckSpace(RowTop + ChildBand.Height) then
        begin
          StartNewPage;
          PrintPageHeader(True);
          RowTop := 0;
        end;
        if not CheckSpace(RowTop + ChildBand.Height) then
          raise EReportException.Create(
            'A flat subreport detail row does not fit below the repeated page headers.');

        ChildOriginX := FReport.PageSettings.Margins.Left +
          SubReport.Bounds.Left + 2;
        ChildOriginY := FCurrentY + RowTop;
        RowContext := BuildRowContext;
        RowContext.PageNumber := FPageNumber;
        RowContext.PageBottom := FPageHeight -
          FReport.PageSettings.Margins.Bottom - ChildOriginY;

        if FIsRenderingPass then
          SubReport.DrawPlannedRow(FCanvas, ChildBand, RowContext,
            ChildOriginX, ChildOriginY, ClipWidth,
            FPageHeight - FReport.PageSettings.Margins.Bottom - ChildOriginY);
        Inc(FCurrentY, RowTop + ChildBand.Height);
        Inc(RowsDrawn);
      end;
      ChildDataSet.Next;
    end;
  finally
    if ControlsDisabledByUs then
      ChildDataSet.EnableControls;
    if HasChildBookmark then
    begin
      Vittix.Report.LayoutBookmarks.RestoreDataSetBookmark(
        ChildDataSet, ChildBookmark, HasChildBookmark);
    end;
  end;
end;

function TReportEngine.TryFlowNestedSubReport(AParentBand: TReportBand;
  AOuterSubReport, AInnerSubReport: TReportSubReportObject;
  AOuterDataSet: TDataSet; AOuterBand: TReportBand): Boolean;
var
  OuterModel, InnerModel: TReportModel;
  InnerBand: TReportBand;
  InnerDataSet: TDataSet;
  OuterBookmark, InnerBookmark: TBookmark;
  HasOuterBookmark, HasInnerBookmark: Boolean;
  OuterMasterField, OuterDetailField: string;
  InnerMasterField, InnerDetailField: string;
  OuterMatchCount, RowCount, RowsDrawn: Integer;
  FirstOffset, RowTop, OriginX, OriginY, ClipWidth, FooterHeight: Integer;
  Obj: TReportObject;
  RowContext: TExpressionContext;
  OuterControlsDisabledByUs, InnerControlsDisabledByUs: Boolean;
  InnerMasterSourceDataSet: TDataSet;
  function OuterMatchesMaster: Boolean;
  var
    MasterValue, DetailValue: Variant;
  begin
    Result := True;
    if (OuterMasterField = '') or (OuterDetailField = '') then
      Exit;
    if not Assigned(FDataSet.FindField(OuterMasterField)) or
       not Assigned(AOuterDataSet.FindField(OuterDetailField)) then
      Exit(False);
    MasterValue := FDataSet.FieldByName(OuterMasterField).Value;
    DetailValue := AOuterDataSet.FieldByName(OuterDetailField).Value;
    Result := VarSameValue(MasterValue, DetailValue);
  end;
  function InnerMatchesOuter: Boolean;
  var
    MasterValue, DetailValue: Variant;
  begin
    Result := True;
    if (InnerMasterField = '') or (InnerDetailField = '') then
      Exit;
    if not Assigned(AOuterDataSet.FindField(InnerMasterField)) or
       not Assigned(InnerDataSet.FindField(InnerDetailField)) then
      Exit(False);
    MasterValue := AOuterDataSet.FieldByName(InnerMasterField).Value;
    DetailValue := InnerDataSet.FieldByName(InnerDetailField).Value;
    Result := VarSameValue(MasterValue, DetailValue);
  end;
  procedure BuildRowContext;
  begin
    RowContext := Default(TExpressionContext);
    RowContext.ExpressionMode := ReportExpressionMode;
    RowContext.Hooks := Self;
    RowContext.DataSet := InnerDataSet;
    RowContext.UserDataSet := FUserDataSet;
    RowContext.GroupStart := FGroupStartBookmark;
    RowContext.GroupEnd := FGroupEndBookmark;
    RowContext.PageNumber := FPageNumber;
    RowContext.TotalPages := FTotalPagesForPass;
    RowContext.RowNumber := FRowNumber;
    RowContext.PageBottom := FPageHeight -
      FReport.PageSettings.Margins.Bottom - FCurrentY;
    RowContext.ReportTitle := FReport.Title;
    RowContext.ReportDate := FReportDate;
    RowContext.Parameters := FParameters;
    RowContext.Variables := FReport.Variables;
    RowContext.IsCountingPass := not FIsRenderingPass;
  end;
begin
  Result := False;
  if not Assigned(AParentBand) or not Assigned(AOuterSubReport) or
     not Assigned(AInnerSubReport) or not Assigned(AOuterDataSet) or
     not AOuterDataSet.Active or not Assigned(AOuterBand) or
     (AOuterBand.Children.Count <> 1) or
     (AOuterBand.Children[0] <> AInnerSubReport) or
     (Trim(AInnerSubReport.ReportJSON) = '') then
    Exit;

  InnerDataSet := FDataSet;
  if Trim(AInnerSubReport.DataSetName) <> '' then
  begin
    if not Assigned(FNamedDataSets) or
       not FNamedDataSets.TryGetValue(AInnerSubReport.DataSetName, InnerDataSet) then
      Exit;
  end;
  if not Assigned(InnerDataSet) or not InnerDataSet.Active or
     (InnerDataSet = AOuterDataSet) or (InnerDataSet = FDataSet) or
     not DataSetSupportsBookmarks(AOuterDataSet) or
     not DataSetSupportsBookmarks(InnerDataSet) then
    Exit;

  InnerModel := TReportModel(GetSubReportModel(AInnerSubReport,
    AInnerSubReport.ReportJSON));
  if not Assigned(InnerModel) or (InnerModel.Objects.Count <> 1) or
     not (InnerModel.Objects[0] is TReportBand) then
    Exit;
  InnerBand := TReportBand(InnerModel.Objects[0]);
  if not InnerBand.Visible or (InnerBand.BandType <> btMasterData) or
     (InnerBand.Height <= 0) or InnerBand.CanGrow or InnerBand.CanShrink or
     (InnerBand.PrintWhen <> '') or InnerBand.StartNewPage or
     InnerBand.PageBreakBefore or InnerBand.PageBreakAfter or
     InnerBand.OverridePageSettings or (InnerBand.OnBeforePrint <> '') or
     (InnerBand.OnAfterPrint <> '') then
    Exit;
  for Obj in InnerBand.Children do
    if Obj.PageBreakBefore or Obj.PageBreakAfter or
       (Obj is TReportSubReportObject) then
      Exit;

  OuterMasterField := Trim(AOuterSubReport.MasterField);
  OuterDetailField := Trim(AOuterSubReport.DetailField);
  InnerMasterField := Trim(AInnerSubReport.MasterField);
  InnerDetailField := Trim(AInnerSubReport.DetailField);
  if ((OuterMasterField = '') xor (OuterDetailField = '')) or
     ((InnerMasterField = '') xor (InnerDetailField = '')) then
    Exit;
  if ((OuterMasterField <> '') and
      (not Assigned(FDataSet.FindField(OuterMasterField)) or
       not Assigned(AOuterDataSet.FindField(OuterDetailField)))) or
     ((InnerMasterField <> '') and
      (not Assigned(AOuterDataSet.FindField(InnerMasterField)) or
       not Assigned(InnerDataSet.FindField(InnerDetailField)))) then
    Exit;

  HasOuterBookmark := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(
    AOuterDataSet, OuterBookmark);
  HasInnerBookmark := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(
    InnerDataSet, InnerBookmark);
  OuterMatchCount := 0;
  RowCount := 0;
  InnerMasterSourceDataSet := DataSetMasterSourceDataSet(InnerDataSet);
  if (InnerMasterSourceDataSet = AOuterDataSet) and
     (AOuterDataSet.ControlsDisabled or InnerDataSet.ControlsDisabled) then
    raise EReportException.Create(
      'Nested master/detail traversal requires linked dataset controls enabled.');
  OuterControlsDisabledByUs :=
    not AOuterDataSet.ControlsDisabled and
    (InnerMasterSourceDataSet <> AOuterDataSet);
  InnerControlsDisabledByUs := not InnerDataSet.ControlsDisabled and
    (InnerMasterSourceDataSet <> AOuterDataSet);
  if OuterControlsDisabledByUs then
    AOuterDataSet.DisableControls;
  if InnerControlsDisabledByUs then
    InnerDataSet.DisableControls;
  try
    AOuterDataSet.First;
    while not AOuterDataSet.Eof do
    begin
      if OuterMatchesMaster then
      begin
        Inc(OuterMatchCount);
        InnerDataSet.First;
        while not InnerDataSet.Eof do
        begin
          if InnerMatchesOuter then
            Inc(RowCount);
          InnerDataSet.Next;
        end;
      end;
      AOuterDataSet.Next;
    end;
  finally
    if InnerControlsDisabledByUs then
      InnerDataSet.EnableControls;
    if OuterControlsDisabledByUs then
      AOuterDataSet.EnableControls;
    if HasInnerBookmark then
      Vittix.Report.LayoutBookmarks.RestoreDataSetBookmark(
        InnerDataSet, InnerBookmark, HasInnerBookmark);
    if HasOuterBookmark then
      Vittix.Report.LayoutBookmarks.RestoreDataSetBookmark(
        AOuterDataSet, OuterBookmark, HasOuterBookmark);
  end;

  if (OuterMatchCount = 0) or (RowCount = 0) then
    Exit;
  FirstOffset := AOuterSubReport.Bounds.Top + AInnerSubReport.Bounds.Top + 2;
  if (Int64(RowCount) * InnerBand.Height + FirstOffset) <=
     (AOuterSubReport.Bounds.Bottom - AOuterSubReport.Bounds.Top) then
    Exit;
  if (AOuterSubReport.Bounds.Top < 0) or (AInnerSubReport.Bounds.Top < 0) or
     (AInnerSubReport.Bounds.Bottom <= AInnerSubReport.Bounds.Top) then
    raise EReportException.Create(
      'Nested flat subreports must have positive bounds within their parent bands.');

  Result := True;
  FooterHeight := 0;
  if Assigned(FFooterBand) then
    FooterHeight := FFooterBand.Height;
  if InnerBand.Height > (FPageHeight - FReport.PageSettings.Margins.Top -
      FReport.PageSettings.Margins.Bottom - FooterHeight) then
    raise EReportException.Create(
      'A nested subreport detail row is taller than the printable page area.');
  ClipWidth := AInnerSubReport.Bounds.Right - AInnerSubReport.Bounds.Left - 2;
  if (ClipWidth <= 0) or (AOuterSubReport.Bounds.Left < 0) or
     (AOuterSubReport.Bounds.Right > FReport.PageSettings.ContentWidth) or
     (AInnerSubReport.Bounds.Left < 0) or
     (AInnerSubReport.Bounds.Right >
       (AOuterSubReport.Bounds.Right - AOuterSubReport.Bounds.Left)) then
    raise EReportException.Create(
      'Nested flat subreports must fit within the printable page width.');
  OriginX := FReport.PageSettings.Margins.Left +
    AOuterSubReport.Bounds.Left + AInnerSubReport.Bounds.Left + 2;

  HasOuterBookmark := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(
    AOuterDataSet, OuterBookmark);
  HasInnerBookmark := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(
    InnerDataSet, InnerBookmark);
  InnerMasterSourceDataSet := DataSetMasterSourceDataSet(InnerDataSet);
  if (InnerMasterSourceDataSet = AOuterDataSet) and
     AOuterDataSet.ControlsDisabled then
    raise EReportException.Create(
      'Nested master/detail traversal requires outer dataset controls enabled.');
  OuterControlsDisabledByUs :=
    not AOuterDataSet.ControlsDisabled and
    (InnerMasterSourceDataSet <> AOuterDataSet);
  InnerControlsDisabledByUs := not InnerDataSet.ControlsDisabled;
  if OuterControlsDisabledByUs then
    AOuterDataSet.DisableControls;
  if InnerControlsDisabledByUs then
    InnerDataSet.DisableControls;
  try
    AOuterDataSet.First;
    RowsDrawn := 0;
    while not AOuterDataSet.Eof do
    begin
      if OuterMatchesMaster then
      begin
        InnerDataSet.First;
        while not InnerDataSet.Eof do
        begin
          if InnerMatchesOuter then
          begin
            RowTop := 0;
            if RowsDrawn = 0 then
              RowTop := FirstOffset;
            if not CheckSpace(RowTop + InnerBand.Height) then
            begin
              StartNewPage;
              PrintPageHeader(True);
              RowTop := 0;
            end;
            if not CheckSpace(RowTop + InnerBand.Height) then
              raise EReportException.Create(
                'A nested subreport detail row does not fit below the repeated page headers.');

            OriginY := FCurrentY + RowTop;
            BuildRowContext;
            RowContext.PageNumber := FPageNumber;
            RowContext.PageBottom := FPageHeight -
              FReport.PageSettings.Margins.Bottom - OriginY;
            if FIsRenderingPass then
              AInnerSubReport.DrawPlannedRow(FCanvas, InnerBand, RowContext,
                OriginX, OriginY, ClipWidth,
                FPageHeight - FReport.PageSettings.Margins.Bottom - OriginY);
            Inc(FCurrentY, RowTop + InnerBand.Height);
            Inc(RowsDrawn);
          end;
          InnerDataSet.Next;
        end;
      end;
      AOuterDataSet.Next;
    end;
  finally
    if InnerControlsDisabledByUs then
      InnerDataSet.EnableControls;
    if OuterControlsDisabledByUs then
      AOuterDataSet.EnableControls;
    if HasInnerBookmark then
      Vittix.Report.LayoutBookmarks.RestoreDataSetBookmark(
        InnerDataSet, InnerBookmark, HasInnerBookmark);
    if HasOuterBookmark then
      Vittix.Report.LayoutBookmarks.RestoreDataSetBookmark(
        AOuterDataSet, OuterBookmark, HasOuterBookmark);
  end;
end;


procedure TReportEngine.RejectUnsupportedSubReportOverflow(
  AParentBand: TReportBand);
var
  Child: TReportObject;
  SubReport: TReportSubReportObject;
  Context: TExpressionContext;
begin
  if not Assigned(AParentBand) or not Assigned(FCanvas) then
    Exit;
  Context := Default(TExpressionContext);
  Context.ExpressionMode := ReportExpressionMode;
  Context.Hooks := Self;
  Context.DataSet := FDataSet;
  Context.UserDataSet := FUserDataSet;
  Context.GroupStart := FGroupStartBookmark;
  Context.GroupEnd := FGroupEndBookmark;
  Context.PageNumber := FPageNumber;
  Context.TotalPages := FTotalPagesForPass;
  Context.RowNumber := FRowNumber;
  Context.PageBottom := FPageHeight -
    FReport.PageSettings.Margins.Bottom - FCurrentY;
  Context.ReportTitle := FReport.Title;
  Context.ReportDate := FReportDate;
  Context.Parameters := FParameters;
  Context.Variables := FReport.Variables;
  Context.IsCountingPass := not FIsRenderingPass;

  for Child in AParentBand.Children do
    if (Child is TReportSubReportObject) and Child.Visible then
    begin
      SubReport := TReportSubReportObject(Child);
      { Only named or master-linked datasets participate in the continuation
        contract. Unbound subreports retain their legacy measurement path. }
      if Trim(SubReport.DataSetName) = '' then
        Continue;
      if SubReport.MeasuredBottom(FCanvas, Context) > SubReport.Bounds.Bottom then
        raise EReportException.Create(
          'This subreport content exceeds its object bounds, and its layout ' +
          'does not support flat or nested page continuation.');
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
      PageBeforeColumnHeader := FPageNumber;
      EnsurePageSpaceForBand(FColumnHeaderBand, ColumnHeaderH, True);
      if FPageNumber = PageBeforeColumnHeader then
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
  Result := FPageNumber;
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
begin
  if not Assigned(ADataSet) then
    ADataSet := FDataSet;
  if not Assigned(AUserDataSet) then
    AUserDataSet := FUserDataSet;

  if not Assigned(ABand) then Exit;
  if not Assigned(FCanvas) then Exit;
  if ABand.Height <= 0 then Exit;

  // Respect Visible flag
  if not ABand.Visible then Exit;

  if (ABand.StartNewPage or BandHasChildPageBreak(ABand, True)) and
     (FCurrentY > FReport.PageSettings.Margins.Top) and
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
    Ctx0.PageNumber := FPageNumber;
    Ctx0.TotalPages := FTotalPagesForPass;
    Ctx0.RowNumber := FRowNumber;
    Ctx0.PageBottom := FPageHeight - FReport.PageSettings.Margins.Bottom - FCurrentY;
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
  Ctx.PageNumber  := FPageNumber;
  Ctx.TotalPages  := FTotalPagesForPass;
  Ctx.RowNumber   := FRowNumber;
  Ctx.PageBottom  := FPageHeight - FReport.PageSettings.Margins.Bottom - FCurrentY;
  Ctx.ReportTitle := FReport.Title;
  Ctx.ReportDate  := FReportDate;
  Ctx.Parameters  := FParameters;
  Ctx.Variables   := FReport.Variables;
  Ctx.IsCountingPass := not FIsRenderingPass;
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
  // The top margin is tracked via FCurrentY; the left margin applies to all bands.
  SaveDC(FCanvas.Handle);
  try
    FExportOriginX := FReport.PageSettings.Margins.Left;
    FExportOriginY := FCurrentY;
    SetViewportOrgEx(
      FCanvas.Handle,
      FReport.PageSettings.Margins.Left,
      FCurrentY,
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

  Inc(FCurrentY, EffectiveH);

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

procedure TReportEngine.PrintDetailBandRecords(ABand: TReportBand;
  ADetailDS: TDataSet; ADetailUDS: TVittixUserDataSet);
var
  MasterValue: Variant;
  HasMasterField: Boolean;
  EffH: Integer;
  MasterFld: TField;
  DetailFld: TField;
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
      FPageNumber := 0;
      Exit;
    end;

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
  if (ACommand <> nil) and Assigned(FCurrentExportPage) then
    FCurrentExportPage.Commands.Add(ACommand);
end;

function TReportEngine.GetCaptureOrigin: TPoint;
begin
  Result := Point(0, 0);
  if Assigned(FCanvas) then
    GetViewportOrgEx(FCanvas.Handle, Result);
end;

procedure TReportEngine.RegisterTempFile(const AFileName: string);
begin
  if Assigned(FExportDocument) then
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
  if (AObject = nil) or not Assigned(FCurrentExportPage) then
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
    FCurrentExportPage.Commands.Add(ImgCmd);
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
  if not IsCapturingExportCommands or not Assigned(FCurrentExportPage) or
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
      Entry.Model := TReportSerializer.LoadFromJSON(AJSON);
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
