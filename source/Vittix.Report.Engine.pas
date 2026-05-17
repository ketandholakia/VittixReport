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
  Vittix.Report.Interfaces;   // IReportProgress

type
  EReportException = class(Exception);

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
    procedure PrintBand(ABand: TReportBand; ADataSet: TDataSet = nil; AEffectiveHeight: Integer = -1);
    procedure PrintBandWithSpaceCheck(ABand: TReportBand; ADataSet: TDataSet = nil);
    function  ComputeEffectiveBandHeight(ABand: TReportBand; ADataSet: TDataSet): Integer;
    function  ResolveBandDataSet(ABand: TReportBand): TDataSet;
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
var
  Obj: TReportObject;
begin
  FTitleBand        := nil;
  FHeaderBand       := nil;
  FColumnHeaderBand := nil;
  FMasterBand       := nil;
  FFooterBand       := nil;
  FSummaryBand      := nil;
  FOverlayBand      := nil;
  
  FGroupHeaders.Clear;
  FGroupFooters.Clear;
  FDetailBands.Clear;

  for Obj in FReport.Objects do
    if Obj is TReportBand then
      case TReportBand(Obj).BandType of
        btReportTitle:   FTitleBand        := TReportBand(Obj);
        btPageHeader:    FHeaderBand       := TReportBand(Obj);
        btColumnHeader:  FColumnHeaderBand := TReportBand(Obj);
        btMasterData:    if not Assigned(FMasterBand) then
                           FMasterBand := TReportBand(Obj);
        btDetail:        FDetailBands.Add(TReportBand(Obj));
        btPageFooter:    FFooterBand       := TReportBand(Obj);
        btReportSummary: FSummaryBand      := TReportBand(Obj);
        btOverlay:       FOverlayBand      := TReportBand(Obj);
        btGroupHeader:   FGroupHeaders.Add(TReportBand(Obj));
        btGroupFooter:   FGroupFooters.Add(TReportBand(Obj));
      end;

  // Backward compatibility: if a legacy report uses btDetail as the only data band,
  // treat the first detail band as the master loop.
  if (not Assigned(FMasterBand)) and (FDetailBands.Count > 0) then
  begin
    FMasterBand := FDetailBands[0];
    FDetailBands.Delete(0);
  end;
      
  FGroupHeaders.Sort(TComparer<TReportBand>.Construct(
    function(const L, R: TReportBand): Integer
    begin
      Result := L.GroupLevel - R.GroupLevel;
    end));
    
  FGroupFooters.Sort(TComparer<TReportBand>.Construct(
    function(const L, R: TReportBand): Integer
    begin
      Result := R.GroupLevel - L.GroupLevel;  // Reverse for footers
    end));
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
          Ctx2.ReportTitle := FReport.Title;
          Ctx2.ReportDate  := FReportDate;
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
  Ctx.ReportTitle := FReport.Title;
  Ctx.ReportDate  := FReportDate;

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
begin
  if RequiredHeight <= 0 then
    RequiredHeight := 1;

  // Reserve space for the bottom margin and the page footer band
  var FooterH := 0;
  if Assigned(FFooterBand) then FooterH := FFooterBand.Height;

  Result :=
    (FCurrentY + RequiredHeight) <=
    (FPageHeight - FReport.PageSettings.Margins.Bottom - FooterH);
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
    Ctx0.ReportTitle := FReport.Title;
    Ctx0.ReportDate  := FReportDate;
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
  Ctx.ReportTitle := FReport.Title;
  Ctx.ReportDate  := FReportDate;
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

  // Translate the DC vertically so the band draws at FCurrentY on the page
  SaveDC(FCanvas.Handle);
  try
    SetViewportOrgEx(FCanvas.Handle, 0, FCurrentY, nil);
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
  if not CheckSpace(EffH) then
  begin
    StartNewPage;
    PrintPageHeader;
  end;

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

procedure TReportEngine.PrintDetailBands;
var
  Band: TReportBand;
  DetailDS: TDataSet;
  SaveBM: TBookmark;
  HasSaveBM: Boolean;
  MasterValue: Variant;
  HasMasterField: Boolean;
  EffH: Integer;
  MasterFld: TField;
  DetailFld: TField;
begin
  for Band in FDetailBands do
  begin
    DetailDS := ResolveBandDataSet(Band);
    if not Assigned(DetailDS) or not DetailDS.Active then
      Continue;

    SaveBM := nil;
    HasSaveBM := False;
    if DataSetSupportsBookmarks(DetailDS) then
    begin
      SaveBM := DetailDS.GetBookmark;
      HasSaveBM := True;
    end;

    DetailDS.DisableControls;
    try
      HasMasterField :=
        Assigned(FDataSet) and FDataSet.Active and
        (Band.MasterField <> '') and (Band.DetailField <> '') and
        TryGetField(FDataSet, Band.MasterField, MasterFld) and
        TryGetField(DetailDS, Band.DetailField, DetailFld);

      if HasMasterField then
        MasterValue := MasterFld.Value
      else
        MasterValue := Null;

      DetailDS.First;
      while not DetailDS.Eof do
      begin
        if (not HasMasterField) or
           VarSameValue(DetailFld.Value, MasterValue) then
        begin
          EffH := ComputeEffectiveBandHeight(Band, DetailDS);
          if not CheckSpace(EffH) then
          begin
            StartNewPage;
            PrintPageHeader;
            if Assigned(FColumnHeaderBand) then
              PrintBandWithSpaceCheck(FColumnHeaderBand, FDataSet);
          end;

          PrintBand(Band, DetailDS, EffH);
        end;

        DetailDS.Next;
      end;
    finally
      if HasSaveBM and (SaveBM <> nil) and DetailDS.BookmarkValid(SaveBM) then
        DetailDS.GotoBookmark(SaveBM);
      if HasSaveBM and (SaveBM <> nil) then
        DetailDS.FreeBookmark(SaveBM);
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
  i, RowNumber, TotalRows: Integer;
  GH, GF: TReportBand;
  GroupByField: TField;
  NewValue: Variant;
  BreakLevel: Integer;
  HasOpenedGroups: Boolean;
  EffH: Integer;
  ActiveGroupHeader: array of Boolean;
  HasAnyActiveGroup: Boolean;
  OpenedThisBreak: Boolean;
  function IsGroupLevelActive(ALevel: Integer): Boolean;
  var
    J: Integer;
  begin
    Result := False;
    for J := 0 to FGroupHeaders.Count - 1 do
      if ActiveGroupHeader[J] and (FGroupHeaders[J].GroupLevel = ALevel) then
        Exit(True);
  end;
begin
  FIsRenderingPass := AReportProgress;
  SetReportNamedDataSets(FNamedDataSets);
  if FIsRenderingPass then
    SetReportObjectRenderHooks(HandleBeforeObjectPrint, HandleAfterObjectPrint)
  else
    ClearReportObjectRenderHooks;
  try
    FPages.Clear;
    FPageNumber := 0;
    FTotalPagesForPass := ATotalPages;

  // Snapshot page dimensions from the model's PageSettings
  FPageWidth  := FReport.PageSettings.PageWidth;
  FPageHeight := FReport.PageSettings.PageHeight;

  CacheBands;

  if AReportProgress and Assigned(FProgress) then
  begin
    TotalRows := SafeRecordCount(FDataSet);
    FProgress.SetTotal(TotalRows);
  end;
  RowNumber := 0;

  StartNewPage;

  { Title once }
  if Assigned(FTitleBand) then
    PrintBand(FTitleBand);

  { Page header on first page }
  PrintPageHeader;
  { Column header on first page (before first group break or first data row) }
  if Assigned(FColumnHeaderBand) then
    PrintBand(FColumnHeaderBand);

  SetLength(FLastGroupValues, FGroupHeaders.Count);
  SetLength(ActiveGroupHeader, FGroupHeaders.Count);
  HasAnyActiveGroup := False;
  for i := 0 to High(FLastGroupValues) do
  begin
    FLastGroupValues[i] := Null;
    GH := FGroupHeaders[i];
    GroupByField := nil;
    ActiveGroupHeader[i] :=
      Assigned(FDataSet) and FDataSet.Active and
      (Trim(GH.GroupField) <> '') and
      TryGetField(FDataSet, GH.GroupField, GroupByField);
    if ActiveGroupHeader[i] then
      HasAnyActiveGroup := True;
  end;

  FGroupStartBookmark := nil; // Initialize
  FGroupEndBookmark := nil;   // Initialize
  FHasGroupStartBookmark := False;
  FHasGroupEndBookmark := False;
  HasOpenedGroups := False;

  { Master data loop }
  if Assigned(FDataSet) and FDataSet.Active then
  begin
    FDataSet.DisableControls;
    try
      FDataSet.First;

      while not FDataSet.Eof do
      begin
        { -------- GROUP SUPPORT -------- }
        // Detect break level
        BreakLevel := -1;
        for i := 0 to FGroupHeaders.Count-1 do
        begin
          if not ActiveGroupHeader[i] then
            Continue;

          GH := FGroupHeaders[i];
          GroupByField := nil;
          if not TryGetField(FDataSet, GH.GroupField, GroupByField) then
            Continue;

          NewValue := GroupByField.Value;

          if VarIsNull(FLastGroupValues[i]) or
             (NewValue <> FLastGroupValues[i]) then
          begin
            BreakLevel := i;
            Break;
          end;
        end;

        // Close lower groups first (from lowest level up to BreakLevel)
        if (BreakLevel >= 0) and HasOpenedGroups then
        begin
          if DataSetSupportsBookmarks(FDataSet) then
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

          for i := 0 to FGroupFooters.Count-1 do
          begin
            GF := FGroupFooters[i];
            if (GF.GroupLevel >= BreakLevel) and IsGroupLevelActive(GF.GroupLevel) then
              PrintBandWithSpaceCheck(GF);
          end;
        end;

        // Open new groups top-down (from BreakLevel down to lowest level)
        if BreakLevel >= 0 then
        begin
          OpenedThisBreak := False;
          for i := BreakLevel to FGroupHeaders.Count-1 do
          begin
            if not ActiveGroupHeader[i] then
              Continue;

            GH := FGroupHeaders[i];

            if GH.StartNewPage then
            begin
              StartNewPage;
              PrintPageHeader;
            end;

            PrintBandWithSpaceCheck(GH);
            OpenedThisBreak := True;

            // Print column header below each group header
            if Assigned(FColumnHeaderBand) then
              PrintBandWithSpaceCheck(FColumnHeaderBand);

            GroupByField := nil;
            if TryGetField(FDataSet, GH.GroupField, GroupByField) then
              FLastGroupValues[i] := GroupByField.Value;
          end;

          if OpenedThisBreak then
            HasOpenedGroups := True;

          if DataSetSupportsBookmarks(FDataSet) then
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

        { -------- PAGE BREAK -------- }
        EffH := ComputeEffectiveBandHeight(FMasterBand, FDataSet);
        if not CheckSpace(EffH) then
        begin
          StartNewPage;
          PrintPageHeader;
          // Column header always repeats on each page (with or without groups)
          if Assigned(FColumnHeaderBand) then
            PrintBandWithSpaceCheck(FColumnHeaderBand);
        end;
        { -------- PRINT RECORD -------- }
        PrintBand(FMasterBand, FDataSet, EffH);
        PrintDetailBands;

        // Report progress and check for cancellation
        Inc(RowNumber);
        if AReportProgress and Assigned(FProgress) then
        begin
          FProgress.Advance(RowNumber);
          if FProgress.IsCancelled then
            Break;
        end;

        FDataSet.Next;
      end;
    finally
      FDataSet.EnableControls;
    end;
  end;

  { close last group }
  // After the loop, FDataSet is at EOF. The FGroupEndBookmark for the LAST group is set if supported.
  if HasOpenedGroups and HasAnyActiveGroup then
  begin
    if DataSetSupportsBookmarks(FDataSet) then
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
    for GF in FGroupFooters do
      if IsGroupLevelActive(GF.GroupLevel) then
        PrintBandWithSpaceCheck(GF);
  end;

  if Assigned(FSummaryBand) then
  begin
    EffH := ComputeEffectiveBandHeight(FSummaryBand, FDataSet);
    if not CheckSpace(EffH) then
    begin
      StartNewPage;
      PrintPageHeader;
    end;

    PrintBand(FSummaryBand, FDataSet, EffH);
  end;

    EndCurrentPage;
    Result := FPageNumber;
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

    if not Assigned(FMasterBand) then
      raise EReportException.Create(
        'Report must have a MasterData band');

    if not Assigned(FDataSet) then
      raise EReportException.Create(
        'DataSet must be assigned to the report engine.');

    if not FDataSet.Active then
      raise EReportException.Create(
        'DataSet must be active to generate the report.');

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
