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
  Vittix.Report.UserDataSet,
  Vittix.Report.Export.Commands,
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
    FUserDataSet: TVittixUserDataSet;
    FNamedDataSets: TDictionary<string, TDataSet>;
    FNamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
    FScriptEngine: TReportScriptEngine;
    FProgress: IReportProgress;   // optional; nil = no progress feedback
    FParameters: TStrings;
    FPages:    TObjectList<TMetafile>;
    FExportDocument: TReportExportDocument;
    FCurrentExportPage: TReportExportPage;

    FCurrentPage: TMetafile;
    FCanvas:      TMetafileCanvas;
    FCurrentY:    Integer;
    FPageWidth:   Integer;   // cached from PageSettings at Prepare time
    FPageHeight:  Integer;
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
      AUserDataSet:   TVittixUserDataSet;
      ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
      AProgress:      IReportProgress);
    procedure CacheBands;
    function IsCapturingExportCommands: Boolean;
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
    function  CaptureDataSetBookmark(ADataSet: TDataSet; out ABookmark: TBookmark): Boolean;
    procedure RestoreDataSetBookmark(ADataSet: TDataSet; ABookmark: TBookmark; AHasBookmark: Boolean);
    function  ComputeFirstDetailRowsHeight: Integer;
    procedure PrintDetailBandRecords(ABand: TReportBand; ADetailDS: TDataSet;
      ADetailUDS: TVittixUserDataSet);
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
    constructor Create(
      AReport:        TReportModel;
      AUserDataSet:   TVittixUserDataSet;
      ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
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
    property Parameters: TStrings read FParameters;
    property ExportDocument: TReportExportDocument read FExportDocument write FExportDocument;
    property TwoPassRendering: Boolean read FTwoPassRendering write FTwoPassRendering;
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
  FNamedUserDataSets.Free;
  FParameters.Free;
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

function TReportEngine.IsCapturingExportCommands: Boolean;
begin
  Result := FIsRenderingPass and Assigned(FExportDocument);
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
  if IsCapturingExportCommands then
    FCurrentExportPage := FExportDocument.AddPage(FPageWidth, FPageHeight)
  else
    FCurrentExportPage := nil;
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
          Ctx2.UserDataSet := FUserDataSet;
          Ctx2.PageNumber := FPageNumber;
          Ctx2.TotalPages := FTotalPagesForPass;
          Ctx2.RowNumber  := FRowNumber;
          Ctx2.PageBottom := FPageHeight - FReport.PageSettings.Margins.Bottom;
          Ctx2.ReportTitle := FReport.Title;
          Ctx2.ReportDate  := FReportDate;
          Ctx2.Parameters  := FParameters;
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

  EffH := ComputeEffectiveBandHeight(FMasterBand, FDataSet, FUserDataSet);
  EnsurePageSpaceForBand(EffH + ComputeFirstDetailRowsHeight, True);
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
    if Assigned(FUserDataSet) or TryGetField(FDataSet, GH.GroupField, GroupByField) then
      FLastGroupValues[I] := SourceFieldValue(FDataSet, FUserDataSet, GH.GroupField);
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

procedure TReportEngine.PrintBand(ABand: TReportBand; ADataSet: TDataSet;
  AEffectiveHeight: Integer; AUserDataSet: TVittixUserDataSet);
var
  Ctx: TExpressionContext;
  AdjustedObjs: array of TReportObject;
  OriginalBounds: array of TRect;
  AdjustedCount: Integer;
  EffectiveH: Integer;
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

  if BandHasChildPageBreak(ABand, True) and
     (FCurrentY > FReport.PageSettings.Margins.Top) then
  begin
    StartNewPage;
    PrintPageHeader;
  end;

  // Evaluate PrintWhen expression — skip band if result is falsy
  if ABand.PrintWhen <> '' then
  begin
    var Ctx0: TExpressionContext := Default(TExpressionContext);
    Ctx0.DataSet     := ADataSet;
    Ctx0.UserDataSet := AUserDataSet;
    Ctx0.PageNumber := FPageNumber;
    Ctx0.TotalPages := FTotalPagesForPass;
    Ctx0.RowNumber := FRowNumber;
    Ctx0.PageBottom := FPageHeight - FReport.PageSettings.Margins.Bottom - FCurrentY;
    Ctx0.ReportTitle := FReport.Title;
    Ctx0.ReportDate  := FReportDate;
    Ctx0.Parameters  := FParameters;
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

  if BandHasChildPageBreak(ABand, False) then
  begin
    StartNewPage;
    PrintPageHeader;
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
  EnsurePageSpaceForBand(EffH);

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

  // Unknown dataset name: no data for this band.
  Result := nil;
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

  Result := nil;
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

    HasSaveBM := CaptureDataSetBookmark(DetailDS, SaveBM);
    DetailDS.DisableControls;
    try
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
        if (not HasMasterField) or VarSameValue(DetailFld.Value, MasterValue) then
        begin
          Inc(Result, ComputeEffectiveBandHeight(Band, DetailDS));
          Break;
        end;
        DetailDS.Next;
      end;
    finally
      RestoreDataSetBookmark(DetailDS, SaveBM, HasSaveBM);
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
      if (not HasMasterField) or
         VarSameValue(SourceFieldValue(nil, ADetailUDS, ABand.DetailField), MasterValue) then
      begin
        EffH := ComputeEffectiveBandHeight(ABand, nil, ADetailUDS);
        EnsurePageSpaceForBand(EffH, True);
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

    HasSaveBM := CaptureDataSetBookmark(DetailDS, SaveBM);

    DetailDS.DisableControls;
    try
      PrintDetailBandRecords(Band, DetailDS, nil);
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
      if not Assigned(FDataSet) and not Assigned(FUserDataSet) then
        raise EReportException.Create(
          'DataSet must be assigned to the report engine.');

      if not PrimarySourceActive then
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
