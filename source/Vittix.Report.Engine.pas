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
  System.Generics.Collections,
  Vcl.Graphics,
  System.Variants,
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Context,
  Vittix.Report.PageSettings,
  Vittix.Report.Scripting,
  Vittix.Report.LayoutCache,
  Vittix.Report.LayoutPagination,
  Vittix.Report.LayoutBookmarks,
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
  TReportEngine = class(TObject, IInterface, IReportRenderHooks)
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
    procedure ApplyPageSettings(ASettings: TReportPageSettings);

    procedure EndCurrentPage;
    procedure PrintPageHeader;  // prints PageHeader + ColumnHeader together
    procedure EnsurePageSpaceForBand(ABand: TReportBand; RequiredHeight: Integer; PrintColumnHeader: Boolean = False);
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
    function  ComputeFirstDetailRowsHeight: Integer;
    procedure PrintDetailBandRecords(ABand: TReportBand; ADetailDS: TDataSet;
      ADetailUDS: TVittixUserDataSet);
    procedure PrintDetailBands;
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
  System.Math,
  System.IOUtils,
  Vcl.Imaging.PNGImage,
  Vittix.Report.Expressions,    // TReportExpression.Evaluate — for PrintWhen
  Vittix.Report.Utils,          // DataSetSupportsBookmarks, SafeRecordCount
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Objects.Table,
  Vittix.Report.Objects.Chart,
  Vittix.Report.Objects.CrossTab,
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

  HasSaveBM := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(FDataSet, SaveBM);
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
      if GH.OverridePageSettings then
        ApplyPageSettings(GH.PageSettings);
      StartNewPage;
      PrintPageHeader;
    end;

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
    PrintPageHeader;
  end;

  // Evaluate PrintWhen expression — skip band if result is falsy
  if ABand.PrintWhen <> '' then
  begin
    var Ctx0: TExpressionContext := Default(TExpressionContext);
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

    HasSaveBM := Vittix.Report.LayoutBookmarks.CaptureDataSetBookmark(DetailDS, SaveBM);
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

procedure TReportEngine.CaptureExportObjectCommand(
  AObject: TReportObject;
  const Context: TExpressionContext);
var
  TextObj: TReportTextObject;
  ImageObj: TReportImageObject;
  LineObj: TReportLineObject;
  ShapeObj: TReportShapeObject;
  BarcodeObj: TReportBarcodeObject;
  TableObj: TReportTableObject;
  TextCmd: TReportExportTextCommand;
  ImageCmd: TReportExportImageCommand;
  LineCmd: TReportExportLineCommand;
  RectCmd: TReportExportRectangleCommand;
  FillCmd: TReportExportFillRectangleCommand;
  R: TRect;
  TextR: TRect;
  RowHeight: Integer;
  ColWidth: Integer;
  RowIndex: Integer;
  ColIndex: Integer;
  YPos: Integer;
  XPos: Integer;
  BarTop: Integer;
  BarBottom: Integer;
  DrawW: Integer;
  ImageSource: string;
  TempFile: string;
  Png: TPngImage;
  Bmp: Vcl.Graphics.TBitmap;
  BarcodeText: string;
  Fld: TField;
  PW: Integer;
  PH: Integer;
  BW: Integer;
  BH: Integer;
  ScaleX: Double;
  ScaleY: Double;
  Scale: Double;
  CX: Integer;
  CY: Integer;
  DrawFontColor: TColor;
  DrawBackground: TColor;
  DrawBorderColor: TColor;
  ViewportOrg: TPoint;

  function ExportCode39Pattern(Ch: Char): string;
  begin
    case Ch of
      '0': Result := 'nnnwwnwnn';
      '1': Result := 'wnnwnnnnw';
      '2': Result := 'nnwwnnnnw';
      '3': Result := 'wnwwnnnnn';
      '4': Result := 'nnnwwnnnw';
      '5': Result := 'wnnwwnnnn';
      '6': Result := 'nnwwwnnnn';
      '7': Result := 'nnnwnnwnw';
      '8': Result := 'wnnwnnwnn';
      '9': Result := 'nnwwnnwnn';
      'A': Result := 'wnnnnwnnw';
      'B': Result := 'nnwnnwnnw';
      'C': Result := 'wnwnnwnnn';
      'D': Result := 'nnnnwwnnw';
      'E': Result := 'wnnnwwnnn';
      'F': Result := 'nnwnwwnnn';
      'G': Result := 'nnnnnwwnw';
      'H': Result := 'wnnnnwwnn';
      'I': Result := 'nnwnnwwnn';
      'J': Result := 'nnnnwwwnn';
      'K': Result := 'wnnnnnnww';
      'L': Result := 'nnwnnnnww';
      'M': Result := 'wnwnnnnwn';
      'N': Result := 'nnnnwnnww';
      'O': Result := 'wnnnwnnwn';
      'P': Result := 'nnwnwnnwn';
      'Q': Result := 'nnnnnnwww';
      'R': Result := 'wnnnnnwwn';
      'S': Result := 'nnwnnnwwn';
      'T': Result := 'nnnnwnwwn';
      'U': Result := 'wwnnnnnnw';
      'V': Result := 'nwwnnnnnw';
      'W': Result := 'wwwnnnnnn';
      'X': Result := 'nwnnwnnnw';
      'Y': Result := 'wwnnwnnnn';
      'Z': Result := 'nwwnwnnnn';
      '-': Result := 'nwnnnnwnw';
      '.': Result := 'wwnnnnwnn';
      ' ': Result := 'nwwnnnwnn';
      '$': Result := 'nwnwnwnnn';
      '/': Result := 'nwnwnnnwn';
      '+': Result := 'nwnnnwnwn';
      '%': Result := 'nnnwnwnwn';
      '*': Result := 'nwnnwnwnn';
    else
      Result := '';
    end;
  end;

  function ExportNormalizeCode39Text(const S: string): string;
  var
    I: Integer;
    Ch: Char;
  begin
    Result := '';
    for I := 1 to Length(S) do
    begin
      Ch := UpCase(S[I]);
      if (Ch <> '*') and (ExportCode39Pattern(Ch) <> '') then
        Result := Result + Ch;
    end;
    Result := '*' + Result + '*';
  end;

  procedure AddBarcodeBar(const ARect: TRect; AColor: TColor);
  begin
    if (ARect.Right <= ARect.Left) or (ARect.Bottom <= ARect.Top) then
      Exit;

    FillCmd := TReportExportFillRectangleCommand.Create;
    FillCmd.Bounds := ARect;
    FillCmd.FillColor := AColor;
    FCurrentExportPage.Commands.Add(FillCmd);
  end;

  procedure CaptureLegacyBarcodeBars(
    const S: string;
    const ARect: TRect;
    ABarTop: Integer;
    ABarBottom: Integer;
    ADrawWidth: Integer;
    ABarColor: TColor);
  var
    I: Integer;
    B: Integer;
    XBar: Integer;
  begin
    XBar := ARect.Left + 4;
    for I := 1 to Length(S) do
    begin
      for B := 0 to 6 do
      begin
        if XBar >= ARect.Left + 4 + ADrawWidth then
          Break;

        if ((Ord(S[I]) shr B) and 1) = 1 then
          AddBarcodeBar(Rect(XBar, ABarTop, XBar + 1, ABarBottom), ABarColor);
        Inc(XBar);
      end;
      Inc(XBar);
      if XBar >= ARect.Left + 4 + ADrawWidth then
        Break;
    end;
  end;

  procedure CaptureCode39BarcodeBars(
    const S: string;
    const ARect: TRect;
    ABarTop: Integer;
    ABarBottom: Integer;
    ADrawWidth: Integer;
    ABarColor: TColor);
  var
    Encoded: string;
    Pattern: string;
    I: Integer;
    J: Integer;
    UnitW: Integer;
    ModuleUnits: Integer;
    TotalUnits: Integer;
    XBar: Integer;
    BarWidth: Integer;
  begin
    Encoded := ExportNormalizeCode39Text(S);
    TotalUnits := 0;
    for I := 1 to Length(Encoded) do
    begin
      Pattern := ExportCode39Pattern(Encoded[I]);
      for J := 1 to Length(Pattern) do
        if Pattern[J] = 'w' then
          Inc(TotalUnits, 3)
        else
          Inc(TotalUnits);
      if I < Length(Encoded) then
        Inc(TotalUnits);
    end;

    UnitW := Max(1, ADrawWidth div Max(1, TotalUnits));
    XBar := ARect.Left + 4;
    for I := 1 to Length(Encoded) do
    begin
      Pattern := ExportCode39Pattern(Encoded[I]);
      for J := 1 to Length(Pattern) do
      begin
        if Pattern[J] = 'w' then
          ModuleUnits := 3
        else
          ModuleUnits := 1;
        BarWidth := UnitW * ModuleUnits;
        if Odd(J) then
          AddBarcodeBar(Rect(XBar, ABarTop,
            Min(XBar + BarWidth, ARect.Left + 4 + ADrawWidth), ABarBottom), ABarColor);
        Inc(XBar, BarWidth);
        if XBar >= ARect.Left + 4 + ADrawWidth then
          Exit;
      end;
      Inc(XBar, UnitW);
    end;
  end;

  procedure CaptureElementsBarcodeBars(
    const AElements: string;
    const ARect: TRect;
    ABarTop: Integer;
    ABarBottom: Integer;
    ADrawWidth: Integer;
    ABarColor: TColor);
  var
    I: Integer;
    UnitW: Integer;
    TotalUnits: Integer;
    XBar: Integer;
    BarWidth: Integer;
  begin
    TotalUnits := BarcodeElementTotalUnits(AElements);
    if TotalUnits <= 0 then
      Exit;

    UnitW := Max(1, ADrawWidth div TotalUnits);
    XBar := ARect.Left + 4;
    for I := 1 to Length(AElements) do
    begin
      BarWidth := UnitW * (Ord(AElements[I]) - 48);
      if Odd(I) then
        AddBarcodeBar(Rect(XBar, ABarTop,
          Min(XBar + BarWidth, ARect.Left + 4 + ADrawWidth), ABarBottom), ABarColor);
      Inc(XBar, BarWidth);
      if XBar >= ARect.Left + 4 + ADrawWidth then
        Exit;
    end;
  end;

  procedure CaptureQRMatrixRects(
    const AMatrix: TBarcodeModuleMatrix;
    const ARect: TRect;
    ABarTop: Integer;
    ABarBottom: Integer;
    ADrawWidth: Integer;
    ABarColor: TColor);
  var
    Rects: TArray<TRect>;
    I: Integer;
  begin
    Rects := QRMatrixToRects(AMatrix, ARect, ABarTop, ABarBottom, ADrawWidth);
    for I := 0 to High(Rects) do
      AddBarcodeBar(Rects[I], ABarColor);
  end;

  { Chart/CrossTab objects have no per-primitive capture; render the object
    through its existing Draw onto a temporary bitmap and capture it as an
    image command (1:1 logical resolution, white page background).  The PNG
    file is registered with the export document, which deletes it when the
    document is freed — after all exporters have consumed the command. }
  procedure CaptureRenderableObjectAsImage(AObj: TReportObject);
  var
    R: TRect;
    Bmp: Vcl.Graphics.TBitmap;
    Png: TPngImage;
    ImgCmd: TReportExportImageCommand;
    TempFile: string;
    SavedOrg: TPoint;
  begin
    R := AObj.Bounds;
    OffsetRect(R, ViewportOrg.X, ViewportOrg.Y);
    if (R.Width <= 0) or (R.Height <= 0) then
      Exit;

    Bmp := Vcl.Graphics.TBitmap.Create;
    try
      Bmp.SetSize(R.Width, R.Height);
      Bmp.Canvas.Brush.Color := clWhite;
      Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));
      GetViewportOrgEx(Bmp.Canvas.Handle, SavedOrg);
      SetViewportOrgEx(Bmp.Canvas.Handle, -AObj.Bounds.Left, -AObj.Bounds.Top, nil);
      try
        AObj.Draw(Bmp.Canvas, Context);
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
      FExportDocument.AddTempFile(TempFile);
    finally
      Bmp.Free;
    end;
  end;
begin
  if not IsCapturingExportCommands or not Assigned(FCurrentExportPage) or
     not Assigned(AObject) then
    Exit;

  ViewportOrg := Point(0, 0);
  if Assigned(FCanvas) then
    GetViewportOrgEx(FCanvas.Handle, ViewportOrg);

  if AObject is TReportTextObject then
  begin
    TextObj := TReportTextObject(AObject);
    R := TextObj.Bounds;
    OffsetRect(R, ViewportOrg.X, ViewportOrg.Y);
    TextObj.ResolveTextStyle(Context, DrawFontColor, DrawBackground, DrawBorderColor);

    if not TextObj.Transparent then
    begin
      FillCmd := TReportExportFillRectangleCommand.Create;
      FillCmd.Bounds := R;
      FillCmd.FillColor := DrawBackground;
      FCurrentExportPage.Commands.Add(FillCmd);
    end;

    if TextObj.BorderVisible then
    begin
      RectCmd := TReportExportRectangleCommand.Create;
      RectCmd.Bounds := R;
      RectCmd.BorderColor := DrawBorderColor;
      RectCmd.BorderWidth := TextObj.BorderWidth;
      FCurrentExportPage.Commands.Add(RectCmd);
    end;

    TextR := Rect(
      R.Left + TextObj.PaddingLeft,
      R.Top + TextObj.PaddingTop,
      R.Right - TextObj.PaddingRight,
      R.Bottom - TextObj.PaddingBottom);

    TextCmd := TReportExportTextCommand.Create;
    TextCmd.Bounds := TextR;
    TextCmd.Text := TextObj.ResolveDisplayText(Context);
    TextCmd.FontName := TextObj.Font.Name;
    TextCmd.FontSize := TextObj.Font.Size;
    TextCmd.FontStyle := TextObj.Font.Style;
    TextCmd.FontColor := DrawFontColor;
    TextCmd.HAlign := TextObj.HAlign;
    TextCmd.WordWrap := TextObj.WordWrap;
    FCurrentExportPage.Commands.Add(TextCmd);
  end
  else if AObject is TReportImageObject then
  begin
    ImageObj := TReportImageObject(AObject);
    R := ImageObj.Bounds;
    OffsetRect(R, ViewportOrg.X, ViewportOrg.Y);

    if ImageObj.BorderVisible then
    begin
      RectCmd := TReportExportRectangleCommand.Create;
      RectCmd.Bounds := R;
      RectCmd.BorderColor := ImageObj.BorderColor;
      RectCmd.BorderWidth := ImageObj.BorderWidth;
      FCurrentExportPage.Commands.Add(RectCmd);
    end;

    ImageSource := ImageObj.ResolveImageSource(Context);
    if (ImageSource <> '') and FileExists(ImageSource) then
    begin
      var Ext := LowerCase(ExtractFileExt(ImageSource));
      var IsVectorFormat := (Ext = '.svg') or (Ext = '.emf') or (Ext = '.wmf');
      if IsVectorFormat or (Assigned(ImageObj.Picture.Graphic) and not ImageObj.Picture.Graphic.Empty) then
      begin
        if ImageObj.Stretch then
        begin
          if ImageObj.Proportional then
          begin
            if IsVectorFormat then
            begin
              PW := 100;
              PH := 100;
            end
            else
            begin
              PW := ImageObj.Picture.Width;
              PH := ImageObj.Picture.Height;
            end;
            
            BW := R.Width;
            BH := R.Height;
            if (PW > 0) and (PH > 0) and (BW > 0) and (BH > 0) then
            begin
              ScaleX := BW / PW;
              ScaleY := BH / PH;
            if ScaleX < ScaleY then Scale := ScaleX else Scale := ScaleY;
            R := Rect(R.Left, R.Top,
                      R.Left + Round(PW * Scale),
                      R.Top + Round(PH * Scale));
            if ImageObj.Center then
              OffsetRect(R, (BW - R.Width) div 2, (BH - R.Height) div 2);
          end;
        end;
      end
      else if ImageObj.Center then
      begin
        PW := ImageObj.Picture.Width;
        PH := ImageObj.Picture.Height;
        BW := R.Width;
        BH := R.Height;
        R := Rect(R.Left + (BW - PW) div 2,
                  R.Top + (BH - PH) div 2,
                  R.Left + (BW - PW) div 2 + PW,
                  R.Top + (BH - PH) div 2 + PH);
      end
      else
        R := Rect(R.Left, R.Top,
                  R.Left + ImageObj.Picture.Width,
                  R.Top + ImageObj.Picture.Height);
      end;

      ImageCmd := TReportExportImageCommand.Create;
      ImageCmd.Bounds := R;
      ImageCmd.Source := ImageSource;
      ImageCmd.Stretch := ImageObj.Stretch;
      ImageCmd.Center := ImageObj.Center;
      ImageCmd.Proportional := ImageObj.Proportional;
      FCurrentExportPage.Commands.Add(ImageCmd);
    end
    else if Assigned(ImageObj.Picture.Graphic) and
            not ImageObj.Picture.Graphic.Empty then
    begin
      // Embedded design-time picture (no usable data-bound source): capture
      // the existing graphic as a temporary PNG registered with the export
      // document, so it exports like file-path images and is deleted with
      // the document.  The object's own graphic is not modified.
      if (ImageObj.Picture.Width > 0) and (ImageObj.Picture.Height > 0) then
      begin
        Bmp := Vcl.Graphics.TBitmap.Create;
        Png := TPngImage.Create;
        try
          Bmp.SetSize(ImageObj.Picture.Width, ImageObj.Picture.Height);
          Bmp.Canvas.Brush.Color := clWhite;
          Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));
          Bmp.Canvas.Draw(0, 0, ImageObj.Picture.Graphic);
          Png.Assign(Bmp);

          TempFile := TPath.Combine(TPath.GetTempPath,
            'vittix_export_' + TGUID.NewGuid.ToString + '.png');
          Png.SaveToFile(TempFile);

          ImageCmd := TReportExportImageCommand.Create;
          ImageCmd.Bounds := R;
          ImageCmd.Source := TempFile;
          ImageCmd.Stretch := ImageObj.Stretch;
          ImageCmd.Center := ImageObj.Center;
          ImageCmd.Proportional := ImageObj.Proportional;
          FCurrentExportPage.Commands.Add(ImageCmd);
          FExportDocument.AddTempFile(TempFile);
        finally
          Png.Free;
          Bmp.Free;
        end;
      end;
    end;
  end
  else if AObject is TReportLineObject then
  begin
    LineObj := TReportLineObject(AObject);
    R := LineObj.Bounds;
    if LineObj.ExtendToPageBottom and (LineObj.Orientation = loVertical) and
       (Context.PageBottom > R.Top) then
      R.Bottom := Context.PageBottom;
    OffsetRect(R, ViewportOrg.X, ViewportOrg.Y);
    CX := (R.Left + R.Right) div 2;
    CY := (R.Top + R.Bottom) div 2;

    LineCmd := TReportExportLineCommand.Create;
    LineCmd.Color := LineObj.LineColor;
    LineCmd.Width := LineObj.LineWidth;
    if LineObj.Orientation = loHorizontal then
    begin
      LineCmd.X1 := R.Left;
      LineCmd.Y1 := CY;
      LineCmd.X2 := R.Right;
      LineCmd.Y2 := CY;
    end
    else
    begin
      LineCmd.X1 := CX;
      LineCmd.Y1 := R.Top;
      LineCmd.X2 := CX;
      LineCmd.Y2 := R.Bottom;
    end;
    FCurrentExportPage.Commands.Add(LineCmd);
  end
  else if AObject is TReportShapeObject then
  begin
    ShapeObj := TReportShapeObject(AObject);
    R := ShapeObj.Bounds;
    OffsetRect(R, ViewportOrg.X, ViewportOrg.Y);

    case ShapeObj.ShapeType of
      stRectangle:
      begin
        if ShapeObj.BrushStyle = bsSolid then
        begin
          FillCmd := TReportExportFillRectangleCommand.Create;
          FillCmd.Bounds := R;
          FillCmd.FillColor := ShapeObj.BrushColor;
          FCurrentExportPage.Commands.Add(FillCmd);
        end;

        if ShapeObj.PenStyle <> psClear then
        begin
          RectCmd := TReportExportRectangleCommand.Create;
          RectCmd.Bounds := R;
          RectCmd.BorderColor := ShapeObj.PenColor;
          RectCmd.BorderWidth := ShapeObj.PenWidth;
          FCurrentExportPage.Commands.Add(RectCmd);
        end;
      end;

      stLine, stDiagLine:
      begin
        if ShapeObj.PenStyle <> psClear then
        begin
          LineCmd := TReportExportLineCommand.Create;
          LineCmd.Color := ShapeObj.PenColor;
          LineCmd.Width := ShapeObj.PenWidth;
          if ShapeObj.ShapeType = stLine then
          begin
            LineCmd.X1 := R.Left;
            LineCmd.Y1 := (R.Top + R.Bottom) div 2;
            LineCmd.X2 := R.Right;
            LineCmd.Y2 := LineCmd.Y1;
          end
          else
          begin
            LineCmd.X1 := R.Left;
            LineCmd.Y1 := R.Top;
            LineCmd.X2 := R.Right;
            LineCmd.Y2 := R.Bottom;
          end;
          FCurrentExportPage.Commands.Add(LineCmd);
        end;
      end;
    end;
  end
  else if AObject is TReportBarcodeObject then
  begin
    BarcodeObj := TReportBarcodeObject(AObject);
    R := BarcodeObj.Bounds;
    OffsetRect(R, ViewportOrg.X, ViewportOrg.Y);

    BarcodeText := BarcodeObj.Value;
    if Trim(BarcodeObj.DataField) <> '' then
    begin
      Fld := nil;
      if Assigned(Context.UserDataSet) then
        BarcodeText := SafeSourceFieldAsString(Context.DataSet, Context.UserDataSet, BarcodeObj.DataField)
      else if TryGetField(Context.DataSet, BarcodeObj.DataField, Fld) then
      begin
        try
          BarcodeText := Fld.AsString;
        except
          // Keep fallback static value if provider raises.
        end;
      end;
    end;

    FillCmd := TReportExportFillRectangleCommand.Create;
    FillCmd.Bounds := R;
    FillCmd.FillColor := BarcodeObj.BackgroundColor;
    FCurrentExportPage.Commands.Add(FillCmd);

    RectCmd := TReportExportRectangleCommand.Create;
    RectCmd.Bounds := R;
    RectCmd.BorderColor := clSilver;
    RectCmd.BorderWidth := 1;
    FCurrentExportPage.Commands.Add(RectCmd);

    BarTop := R.Top + 4;
    if BarcodeObj.ShowText then
      BarBottom := R.Bottom - 16
    else
      BarBottom := R.Bottom - 4;

    if BarBottom <= BarTop then
      BarBottom := R.Bottom - 4;

    DrawW := Max(1, R.Right - R.Left - 8);
    case BarcodeObj.Symbology of
      bsCode39:
        CaptureCode39BarcodeBars(BarcodeText, R, BarTop, BarBottom, DrawW, BarcodeObj.BarColor);
      bsCode128, bsEAN13:
        CaptureElementsBarcodeBars(
          EncodeBarcodeElements(BarcodeObj.Symbology, BarcodeText),
          R, BarTop, BarBottom, DrawW, BarcodeObj.BarColor);
      bsQR:
        CaptureQRMatrixRects(
          EncodeQRMatrix(BarcodeText, BarcodeObj.ErrorCorrection),
          R, BarTop, BarBottom, DrawW, BarcodeObj.BarColor);
    else
      CaptureLegacyBarcodeBars(BarcodeText, R, BarTop, BarBottom, DrawW, BarcodeObj.BarColor);
    end;

    if BarcodeObj.ShowText then
    begin
      TextCmd := TReportExportTextCommand.Create;
      TextCmd.Bounds := Rect(R.Left + 2, R.Bottom - 14, R.Right - 2, R.Bottom - 2);
      TextCmd.Text := BarcodeText;
      TextCmd.FontName := 'Arial';
      TextCmd.FontSize := 8;
      TextCmd.FontStyle := [];
      TextCmd.FontColor := clBlack;
      TextCmd.HAlign := taCenter;
      TextCmd.WordWrap := False;
      FCurrentExportPage.Commands.Add(TextCmd);
    end;
  end
  else if AObject is TReportTableObject then
  begin
    TableObj := TReportTableObject(AObject);
    R := TableObj.Bounds;
    OffsetRect(R, ViewportOrg.X, ViewportOrg.Y);
    if (TableObj.Rows <= 0) or (TableObj.Cols <= 0) then
      Exit;

    RowHeight := Max(1, R.Height div TableObj.Rows);
    ColWidth := Max(1, R.Width div TableObj.Cols);

    FillCmd := TReportExportFillRectangleCommand.Create;
    FillCmd.Bounds := R;
    FillCmd.FillColor := clWhite;
    FCurrentExportPage.Commands.Add(FillCmd);

    if TableObj.HeaderRows > 0 then
    begin
      FillCmd := TReportExportFillRectangleCommand.Create;
      FillCmd.Bounds := Rect(R.Left + 1, R.Top + 1, R.Right - 1,
        Min(R.Bottom - 1, R.Top + (RowHeight * TableObj.HeaderRows)));
      FillCmd.FillColor := TableObj.HeaderColor;
      FCurrentExportPage.Commands.Add(FillCmd);
    end;

    RectCmd := TReportExportRectangleCommand.Create;
    RectCmd.Bounds := R;
    RectCmd.BorderColor := TableObj.GridColor;
    RectCmd.BorderWidth := 1;
    FCurrentExportPage.Commands.Add(RectCmd);

    for RowIndex := 1 to TableObj.Rows - 1 do
    begin
      YPos := R.Top + (RowHeight * RowIndex);
      LineCmd := TReportExportLineCommand.Create;
      LineCmd.Color := TableObj.GridColor;
      LineCmd.Width := 1;
      LineCmd.X1 := R.Left;
      LineCmd.Y1 := YPos;
      LineCmd.X2 := R.Right;
      LineCmd.Y2 := YPos;
      FCurrentExportPage.Commands.Add(LineCmd);
    end;

    for ColIndex := 1 to TableObj.Cols - 1 do
    begin
      XPos := R.Left + (ColWidth * ColIndex);
      LineCmd := TReportExportLineCommand.Create;
      LineCmd.Color := TableObj.GridColor;
      LineCmd.Width := 1;
      LineCmd.X1 := XPos;
      LineCmd.Y1 := R.Top;
      LineCmd.X2 := XPos;
      LineCmd.Y2 := R.Bottom;
      FCurrentExportPage.Commands.Add(LineCmd);
    end;
  end
  else if (AObject is TReportChartObject) or (AObject is TReportCrossTabObject) then
    CaptureRenderableObjectAsImage(AObject);
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

end.
