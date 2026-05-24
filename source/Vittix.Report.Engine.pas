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
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Vcl.Graphics,
  System.Variants,
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Context,
  Vittix.Report.Scripting,
  Vittix.Report.LayoutCache,
  Vittix.Report.LayoutPagination,
  Vittix.Report.Interfaces;   // IReportProgress

type
  EReportException = class(Exception);

type
  TBooleanDynArray = array of Boolean;

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
  TReportEngine = class
  private
    FReport:   TReportModel;
    FDataSet:  TDataSet;
    FNamedDataSets: TDictionary<string, TDataSet>;
    FScriptEngine: TReportScriptEngine;
    FProgress: IReportProgress;   // optional; nil = no progress feedback
    FPages:    TObjectList<TMetafile>;

    FCurrentPage: TMetafile;
    FCanvas:      TMetafileCanvas;
    FCurrentY:    Integer;
    FPageWidth:   Integer;   // cached from PageSettings at Prepare time
    FPageHeight:  Integer;
    FPageNumber:  Integer;   // 1-based current page counter
    FRowNumber:   Integer;   // 1-based current master row counter
    FReportDate:  TDateTime; // set once when Prepare begins
    FTotalPagesForPass: Integer;

    FTitleBand:         TReportBand;
    FHeaderBand:        TReportBand;
    FColumnHeaderBand:  TReportBand;   // btColumnHeader
    FMasterBand:        TReportBand;   // primary master loop band
    FDetailBands:       TObjectList<TReportBand>; // btDetail bands that use their own datasets
    FFooterBand:        TReportBand;
    FSummaryBand:       TReportBand;
    FOverlayBand:       TReportBand;   // btOverlay — drawn last over the full page

    FGroupStartBookmark:    TBookmark;
    FGroupEndBookmark:      TBookmark;
    FHasGroupStartBookmark: Boolean;
    FHasGroupEndBookmark:   Boolean;

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
      AProgress:      IReportProgress);
    procedure CacheBands;
    procedure StartNewPage;
    procedure EndCurrentPage;
    procedure PrintPageHeader;  // prints PageHeader + ColumnHeader together
    procedure EnsurePageSpaceForBand(RequiredHeight: Integer; PrintColumnHeader: Boolean = False);
    procedure BeginPass(ATotalPages: Integer; AReportProgress: Boolean; out ATotalRows, ARowNumber: Integer);
    procedure PrintFirstPageBands;
    function InitializeActiveGroupHeaders(out AActiveGroupHeader: TBooleanDynArray): Boolean;
    function DetectGroupBreak(const AActiveGroupHeader: TBooleanDynArray): Integer;
    function ProcessCurrentMasterRecord(AReportProgress: Boolean; var ARowNumber: Integer): Boolean;
    procedure ProcessMasterDataLoop(const AActiveGroupHeader: TBooleanDynArray; AReportProgress: Boolean; var ARowNumber: Integer; var AHasOpenedGroups: Boolean);
    procedure CaptureGroupStartBookmark;
    procedure CaptureGroupEndBookmark;
    function IsGroupLevelActive(const AActiveGroupHeader: TBooleanDynArray; ALevel: Integer): Boolean;
    procedure CloseGroupsForBreak(ABreakLevel: Integer; const AActiveGroupHeader: TBooleanDynArray);
    procedure OpenGroupsForBreak(ABreakLevel: Integer; const AActiveGroupHeader: TBooleanDynArray; var AHasOpenedGroups: Boolean);
    procedure CloseRemainingGroups(const AActiveGroupHeader: TBooleanDynArray; AHasAnyActiveGroup: Boolean; AHasOpenedGroups: Boolean);
    procedure PrintSummaryWithSpaceCheck;
    function FinalizePass(const AActiveGroupHeader: TBooleanDynArray; AHasAnyActiveGroup, AHasOpenedGroups: Boolean): Integer;
    procedure PrintBand(ABand: TReportBand; ADataSet: TDataSet = nil; AEffectiveHeight: Integer = -1);
    procedure PrintBandWithSpaceCheck(ABand: TReportBand; ADataSet: TDataSet = nil);
    function  ComputeEffectiveBandHeight(ABand: TReportBand; ADataSet: TDataSet): Integer;
    function  ResolveBandDataSet(ABand: TReportBand): TDataSet;
    function  CaptureDataSetBookmark(ADataSet: TDataSet; out ABookmark: TBookmark): Boolean;
    procedure RestoreDataSetBookmark(ADataSet: TDataSet; ABookmark: TBookmark; AHasBookmark: Boolean);
    procedure PrintDetailBandRecords(ABand: TReportBand; ADetailDS: TDataSet);
    procedure PrintDetailBands;
    function  ExecutePass(ATotalPages: Integer; AReportProgress: Boolean): Integer;
    function  CheckSpace(RequiredHeight: Integer): Boolean;
    procedure HandleBeforeObjectPrint(
      AObject: TReportObject;
      const Context: TExpressionContext;
      var ACanPrint: Boolean);
    procedure HandleAfterObjectPrint(
      AObject: TReportObject;
      const Context: TExpressionContext);

  public
    /// <param name="AProgress">
    ///   Optional progress/cancellation callback.  Pass nil to skip.
    /// </param>
    constructor Create(
      AReport:   TReportModel;
      ADataSet:  TDataSet;
      AProgress: IReportProgress = nil); overload;
    constructor Create(
      AReport:        TReportModel;
      ADataSet:       TDataSet;
      ANamedDataSets: TDictionary<string, TDataSet>;
      AProgress:      IReportProgress); overload;
    destructor Destroy; override;

    procedure Prepare;
    procedure RegisterDataSet(const AName: string; ADataSet: TDataSet);

    property Pages:      TObjectList<TMetafile> read FPages;
    property PageCount:  Integer                read FPageNumber;
    property GroupStartBookmark: TBookmark      read FGroupStartBookmark;
    property GroupEndBookmark:   TBookmark      read FGroupEndBookmark;
    property NamedDataSets: TDictionary<string, TDataSet> read FNamedDataSets;
    property ScriptEngine: TReportScriptEngine read FScriptEngine;
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
  Vittix.Report.Expressions,    // TReportExpression.Evaluate — for PrintWhen
  Vittix.Report.Utils,          // DataSetSupportsBookmarks, SafeRecordCount
  System.Types,
  System.Generics.Defaults;

{ ================= Constructor ================= }

procedure TReportEngine.Initialize(
  AReport:        TReportModel;
  ADataSet:       TDataSet;
  ANamedDataSets: TDictionary<string, TDataSet>;
  AProgress:      IReportProgress);
begin
  FReport   := AReport;
  FDataSet  := ADataSet;
  FNamedDataSets := TDictionary<string, TDataSet>.Create;
  FScriptEngine := TReportScriptEngine.Create(nil);
  if Assigned(ANamedDataSets) then
    for var Pair in ANamedDataSets do
      FNamedDataSets.AddOrSetValue(Pair.Key, Pair.Value);
  FProgress := AProgress;
  FPages    := TObjectList<TMetafile>.Create(True);

  FGroupHeaders := TObjectList<TReportBand>.Create(False); // does not own — bands owned by report
  FGroupFooters := TObjectList<TReportBand>.Create(False);
  FDetailBands  := TObjectList<TReportBand>.Create(False);

  // Page dimensions are read from PageSettings in Prepare; seed defaults here
  // so StartNewPage can be called safely before Prepare sets them.
  FPageWidth  := 793;
  FPageHeight := 1122;
  FTotalPagesForPass := 0;
end;

constructor TReportEngine.Create(
  AReport:   TReportModel;
  ADataSet:  TDataSet;
  AProgress: IReportProgress);
begin
  inherited Create;
  Initialize(AReport, ADataSet, nil, AProgress);
end;

constructor TReportEngine.Create(
  AReport:        TReportModel;
  ADataSet:       TDataSet;
  ANamedDataSets: TDictionary<string, TDataSet>;
  AProgress:      IReportProgress);
begin
  inherited Create;
  Initialize(AReport, ADataSet, ANamedDataSets, AProgress);
end;

destructor TReportEngine.Destroy;
begin
  FCanvas.Free;
  FCanvas := nil;

  FCurrentPage.Free;
  FCurrentPage := nil;

  // Free any bookmarks we may have allocated
  if DataSetSupportsBookmarks(FDataSet) then
  begin
    if FHasGroupStartBookmark then
      FDataSet.FreeBookmark(FGroupStartBookmark);
    if FHasGroupEndBookmark then
      FDataSet.FreeBookmark(FGroupEndBookmark);
  end;

  FPages.Free;
  FNamedDataSets.Free;
  FScriptEngine.Free;
  FGroupHeaders.Free;
  FGroupFooters.Free;
  FDetailBands.Free;
  inherited;
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

{ ================= Page Lifecycle ================= }

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
  except
    FCurrentPage.Free;
    FCurrentPage := nil;
    raise;
  end;
  FCurrentY := FReport.PageSettings.Margins.Top;
end;

procedure TReportEngine.PrintPageHeader;
begin
  // Page-level header only — column header is printed after group headers
  if Assigned(FHeaderBand) then
    PrintBand(FHeaderBand);
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
        PrintBand(FFooterBand);
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
          Ctx2.DataSet    := FDataSet;
          Ctx2.PageNumber := FPageNumber;
          Ctx2.TotalPages := FTotalPagesForPass;
          Ctx2.RowNumber  := FRowNumber;
          Ctx2.ReportTitle := FReport.Title;
          Ctx2.ReportDate  := FReportDate;
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
  end;
end;

function TReportEngine.ComputeEffectiveBandHeight(ABand: TReportBand;
  ADataSet: TDataSet): Integer;
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

  Ctx := Default(TExpressionContext);
  Ctx.DataSet     := ADataSet;
  Ctx.GroupStart  := FGroupStartBookmark;
  Ctx.GroupEnd    := FGroupEndBookmark;
  Ctx.PageNumber  := FPageNumber;
  Ctx.TotalPages  := FTotalPagesForPass;
  Ctx.RowNumber   := FRowNumber;
  Ctx.ReportTitle := FReport.Title;
  Ctx.ReportDate  := FReportDate;
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
  RequiredHeight: Integer; PrintColumnHeader: Boolean);
begin
  if CheckSpace(RequiredHeight) then
    Exit;

  StartNewPage;
  PrintPageHeader;
  if PrintColumnHeader and Assigned(FColumnHeaderBand) then
    PrintBandWithSpaceCheck(FColumnHeaderBand, FDataSet);
end;

procedure TReportEngine.BeginPass(
  ATotalPages: Integer; AReportProgress: Boolean; out ATotalRows, ARowNumber: Integer);
begin
  FPages.Clear;
  FPageNumber := 0;
  FRowNumber := 0;
  FTotalPagesForPass := ATotalPages;

  FPageWidth := FReport.PageSettings.PageWidth;
  FPageHeight := FReport.PageSettings.PageHeight;

  CacheBands;

  for var Obj in FReport.Objects do
    if Obj is TReportImageObject then
      TReportImageObject(Obj).ResetImageCache;

  ATotalRows := 0;
  if AReportProgress and Assigned(FProgress) then
  begin
    ATotalRows := SafeRecordCount(FDataSet);
    FProgress.SetTotal(ATotalRows);
  end;
  ARowNumber := 0;

  FGroupStartBookmark := nil;
  FGroupEndBookmark := nil;
  FHasGroupStartBookmark := False;
  FHasGroupEndBookmark := False;
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
      Assigned(FDataSet) and FDataSet.Active and
      (Trim(GH.GroupField) <> '') and
      TryGetField(FDataSet, GH.GroupField, GroupByField);
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
    if not TryGetField(FDataSet, GH.GroupField, GroupByField) then
      Continue;

    NewValue := GroupByField.Value;
    if VarIsNull(FLastGroupValues[I]) or (NewValue <> FLastGroupValues[I]) then
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

  EffH := ComputeEffectiveBandHeight(FMasterBand, FDataSet);
  EnsurePageSpaceForBand(EffH, True);
  PrintBand(FMasterBand, FDataSet, EffH);
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
begin
  if not (Assigned(FDataSet) and FDataSet.Active) then
    Exit;

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
    FDataSet.EnableControls;
  end;
end;

procedure TReportEngine.CaptureGroupStartBookmark;
begin
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

procedure TReportEngine.CaptureGroupEndBookmark;
begin
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
  CaptureGroupEndBookmark;
  for I := 0 to FGroupFooters.Count - 1 do
  begin
    GF := FGroupFooters[I];
    if (GF.GroupLevel >= ABreakLevel) and IsGroupLevelActive(AActiveGroupHeader, GF.GroupLevel) then
      PrintBandWithSpaceCheck(GF);
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
      StartNewPage;
      PrintPageHeader;
    end;

    PrintBandWithSpaceCheck(GH);
    OpenedThisBreak := True;

    if Assigned(FColumnHeaderBand) then
    begin
      ColumnHeaderH := ComputeEffectiveBandHeight(FColumnHeaderBand, FDataSet);
      PageBeforeColumnHeader := FPageNumber;
      EnsurePageSpaceForBand(ColumnHeaderH, True);
      if FPageNumber = PageBeforeColumnHeader then
        PrintBand(FColumnHeaderBand, FDataSet, ColumnHeaderH);
    end;

    GroupByField := nil;
    if TryGetField(FDataSet, GH.GroupField, GroupByField) then
      FLastGroupValues[I] := GroupByField.Value;
  end;

  if OpenedThisBreak then
    AHasOpenedGroups := True;

  CaptureGroupStartBookmark;
end;

procedure TReportEngine.CloseRemainingGroups(
  const AActiveGroupHeader: TBooleanDynArray; AHasAnyActiveGroup,
  AHasOpenedGroups: Boolean);
var
  GF: TReportBand;
begin
  if not (AHasOpenedGroups and AHasAnyActiveGroup) then
    Exit;

  CaptureGroupEndBookmark;
  for GF in FGroupFooters do
    if IsGroupLevelActive(AActiveGroupHeader, GF.GroupLevel) then
      PrintBandWithSpaceCheck(GF);
end;

procedure TReportEngine.PrintSummaryWithSpaceCheck;
var
  EffH: Integer;
begin
  if not Assigned(FSummaryBand) then
    Exit;

  EffH := ComputeEffectiveBandHeight(FSummaryBand, FDataSet);
  EnsurePageSpaceForBand(EffH);
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

procedure TReportEngine.PrintBand(ABand: TReportBand; ADataSet: TDataSet; AEffectiveHeight: Integer);
var
  Ctx: TExpressionContext;
  AdjustedObjs: array of TReportObject;
  OriginalBounds: array of TRect;
  AdjustedCount: Integer;
  EffectiveH: Integer;
begin
  if not Assigned(ADataSet) then
    ADataSet := FDataSet;

  if not Assigned(ABand) then Exit;
  if not Assigned(FCanvas) then Exit;
  if ABand.Height <= 0 then Exit;

  // Respect Visible flag
  if not ABand.Visible then Exit;

  // Evaluate PrintWhen expression — skip band if result is falsy
  if ABand.PrintWhen <> '' then
  begin
    var Ctx0: TExpressionContext := Default(TExpressionContext);
    Ctx0.DataSet     := ADataSet;
    Ctx0.PageNumber := FPageNumber;
    Ctx0.TotalPages := FTotalPagesForPass;
    Ctx0.RowNumber := FRowNumber;
    Ctx0.ReportTitle := FReport.Title;
    Ctx0.ReportDate  := FReportDate;
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
  Ctx.DataSet     := ADataSet;
  Ctx.GroupStart  := FGroupStartBookmark;
  Ctx.GroupEnd    := FGroupEndBookmark;
  Ctx.PageNumber  := FPageNumber;
  Ctx.TotalPages  := FTotalPagesForPass;
  Ctx.RowNumber   := FRowNumber;
  Ctx.ReportTitle := FReport.Title;
  Ctx.ReportDate  := FReportDate;
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
    for var I := AdjustedCount - 1 downto 0 do
      AdjustedObjs[I].Bounds := OriginalBounds[I];
    RestoreDC(FCanvas.Handle, -1);
  end;

  Inc(FCurrentY, EffectiveH);
end;

procedure TReportEngine.PrintBandWithSpaceCheck(ABand: TReportBand; ADataSet: TDataSet);
var
  EffH: Integer;
begin
  if not Assigned(ABand) then
    Exit;

  EffH := ComputeEffectiveBandHeight(ABand, ADataSet);
  EnsurePageSpaceForBand(EffH);

  PrintBand(ABand, ADataSet, EffH);
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

  // Unknown dataset name: no data for this band.
  Result := nil;
end;

function TReportEngine.CaptureDataSetBookmark(
  ADataSet: TDataSet; out ABookmark: TBookmark): Boolean;
begin
  ABookmark := nil;
  Result := Assigned(ADataSet) and DataSetSupportsBookmarks(ADataSet);
  if Result then
    ABookmark := ADataSet.GetBookmark;
end;

procedure TReportEngine.RestoreDataSetBookmark(
  ADataSet: TDataSet; ABookmark: TBookmark; AHasBookmark: Boolean);
begin
  if not AHasBookmark then
    Exit;
  if Assigned(ADataSet) and (ABookmark <> nil) and ADataSet.BookmarkValid(ABookmark) then
    ADataSet.GotoBookmark(ABookmark);
  if Assigned(ADataSet) and (ABookmark <> nil) then
    ADataSet.FreeBookmark(ABookmark);
end;

procedure TReportEngine.PrintDetailBandRecords(ABand: TReportBand; ADetailDS: TDataSet);
var
  MasterValue: Variant;
  HasMasterField: Boolean;
  EffH: Integer;
  MasterFld: TField;
  DetailFld: TField;
begin
  HasMasterField :=
    Assigned(FDataSet) and FDataSet.Active and
    (ABand.MasterField <> '') and (ABand.DetailField <> '') and
    TryGetField(FDataSet, ABand.MasterField, MasterFld) and
    TryGetField(ADetailDS, ABand.DetailField, DetailFld);

  if HasMasterField then
    MasterValue := MasterFld.Value
  else
    MasterValue := Null;

  ADetailDS.First;
  while not ADetailDS.Eof do
  begin
    if (not HasMasterField) or VarSameValue(DetailFld.Value, MasterValue) then
    begin
      EffH := ComputeEffectiveBandHeight(ABand, ADetailDS);
      EnsurePageSpaceForBand(EffH, True);
      PrintBand(ABand, ADetailDS, EffH);
    end;
    ADetailDS.Next;
  end;
end;

procedure TReportEngine.PrintDetailBands;
var
  Band: TReportBand;
  DetailDS: TDataSet;
  SaveBM: TBookmark;
  HasSaveBM: Boolean;
begin
  for Band in FDetailBands do
  begin
    DetailDS := ResolveBandDataSet(Band);
    if not Assigned(DetailDS) or not DetailDS.Active then
      Continue;

    HasSaveBM := CaptureDataSetBookmark(DetailDS, SaveBM);

    DetailDS.DisableControls;
    try
      PrintDetailBandRecords(Band, DetailDS);
    finally
      RestoreDataSetBookmark(DetailDS, SaveBM, HasSaveBM);
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
  FIsRenderingPass := AReportProgress;
  SetReportNamedDataSets(FNamedDataSets);
  if FIsRenderingPass then
    SetReportObjectRenderHooks(HandleBeforeObjectPrint, HandleAfterObjectPrint)
  else
    ClearReportObjectRenderHooks;
  try
    BeginPass(ATotalPages, AReportProgress, TotalRows, RowNumber);
    PrintFirstPageBands;
    HasAnyActiveGroup := InitializeActiveGroupHeaders(ActiveGroupHeader);
    HasOpenedGroups := False;
    ProcessMasterDataLoop(ActiveGroupHeader, AReportProgress, RowNumber, HasOpenedGroups);
    Result := FinalizePass(ActiveGroupHeader, HasAnyActiveGroup, HasOpenedGroups);
  finally
    ClearReportObjectRenderHooks;
    FIsRenderingPass := False;
    SetReportNamedDataSets(nil);
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
      if not Assigned(FDataSet) then
        raise EReportException.Create(
          'DataSet must be assigned to the report engine.');

      if not FDataSet.Active then
        raise EReportException.Create(
          'DataSet must be active to generate the report.');
    end;

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

    // Pass 1: count pages with TotalPages unresolved.
    CountedPages := ExecutePass(0, False);

    // Pass 2: final render with resolved TotalPages available to expressions.
    ExecutePass(CountedPages, True);

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

procedure TReportEngine.HandleBeforeObjectPrint(
  AObject: TReportObject;
  const Context: TExpressionContext;
  var ACanPrint: Boolean);
begin
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

procedure TReportEngine.HandleAfterObjectPrint(
  AObject: TReportObject;
  const Context: TExpressionContext);
begin
  if FIsRenderingPass and Assigned(AObject) and Assigned(FScriptEngine) and
     (AObject.OnAfterPrint <> '') then
  begin
    var ScriptCtx := Context;
    FScriptEngine.ExecuteObjectAfterPrint(FReport, AObject, AObject.OnAfterPrint, ScriptCtx);
  end;

  if Assigned(FOnAfterObject) then
    FOnAfterObject(Self, Self, AObject, Context);
end;

end.
